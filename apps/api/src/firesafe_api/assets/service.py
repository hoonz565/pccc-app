from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from firesafe_api.api.errors import ApiError
from firesafe_api.areas.models import Area
from firesafe_api.assets.models import Asset
from firesafe_api.assets.schemas import AssetCreateRequest, AssetResponse, AssetUpdateRequest
from firesafe_api.audit.models import AuditEvent
from firesafe_api.facilities.models import Facility
from firesafe_api.users.models import User


def build_asset_response(asset: Asset) -> AssetResponse:
    return AssetResponse(
        id=asset.id,
        area_id=asset.area_id,
        asset_code=asset.asset_code,
        type=asset.type,
        subtype=asset.subtype,
        capacity_value=(float(asset.capacity_value) if asset.capacity_value is not None else None),
        capacity_unit=asset.capacity_unit,
        manufacturer=asset.manufacturer,
        model=asset.model,
        serial=asset.serial,
        location_text=asset.location_text,
        lifecycle_state=asset.lifecycle_state,
        source=asset.source,
        revision=asset.revision,
        created_at=asset.created_at,
        updated_at=asset.updated_at,
        operational_status=None,
    )


async def _get_owned_area(
    *,
    area_id: UUID,
    current_user: User,
    session: AsyncSession,
) -> tuple[Area, UUID]:
    row = (
        await session.execute(
            select(Area, Facility.id)
            .join(Facility, Facility.id == Area.facility_id)
            .where(Area.id == area_id, Facility.user_id == current_user.id)
        )
    ).one_or_none()
    if row is None:
        raise ApiError(
            status_code=404,
            code="AREA_NOT_FOUND",
            message="Không tìm thấy khu vực.",
        )
    return row[0], row[1]


async def _get_owned_asset(
    *,
    asset_id: UUID,
    current_user: User,
    session: AsyncSession,
    for_update: bool = False,
) -> tuple[Asset, Area, Facility]:
    statement = (
        select(Asset, Area, Facility)
        .join(Area, Area.id == Asset.area_id)
        .join(Facility, Facility.id == Area.facility_id)
        .where(Asset.id == asset_id, Facility.user_id == current_user.id)
    )
    if for_update:
        statement = statement.with_for_update(of=Asset)
    row = (await session.execute(statement)).one_or_none()
    if row is None:
        raise ApiError(
            status_code=404,
            code="ASSET_NOT_FOUND",
            message="Không tìm thấy thiết bị.",
        )
    return row[0], row[1], row[2]


async def create_asset(
    *,
    area_id: UUID,
    request: AssetCreateRequest,
    current_user: User,
    session: AsyncSession,
) -> AssetResponse:
    area, facility_id = await _get_owned_area(
        area_id=area_id,
        current_user=current_user,
        session=session,
    )
    asset_id = uuid4()
    asset = Asset(
        id=asset_id,
        area_id=area.id,
        asset_code=f"AST-{str(asset_id).upper()}",
        type=request.type,
        subtype=request.subtype,
        capacity_value=request.capacity_value,
        capacity_unit=request.capacity_unit,
        manufacturer=request.manufacturer,
        model=request.model,
        serial=request.serial,
        location_text=request.location_text,
        lifecycle_state="ACTIVE",
        source="MANUAL",
        revision=1,
    )
    try:
        session.add(asset)
        await session.flush()
        session.add(
            AuditEvent(
                user_id=current_user.id,
                facility_id=facility_id,
                area_id=area.id,
                asset_id=asset.id,
                event_type="asset_created",
            )
        )
        await session.flush()
        await session.commit()
    except Exception:
        await session.rollback()
        raise
    return build_asset_response(asset)


async def list_assets(
    *,
    area_id: UUID,
    limit: int,
    offset: int,
    current_user: User,
    session: AsyncSession,
) -> list[AssetResponse]:
    area, _ = await _get_owned_area(
        area_id=area_id,
        current_user=current_user,
        session=session,
    )
    assets = await session.scalars(
        select(Asset)
        .where(Asset.area_id == area.id)
        .order_by(Asset.created_at, Asset.id)
        .limit(limit)
        .offset(offset)
    )
    return [build_asset_response(asset) for asset in assets]


async def get_asset(
    *,
    asset_id: UUID,
    current_user: User,
    session: AsyncSession,
) -> AssetResponse:
    asset, _, _ = await _get_owned_asset(
        asset_id=asset_id,
        current_user=current_user,
        session=session,
    )
    return build_asset_response(asset)


def _validate_resulting_capacity(
    *,
    capacity_value: Decimal | None,
    capacity_unit: str | None,
) -> None:
    if (capacity_value is None) != (capacity_unit is None):
        raise ApiError(
            status_code=422,
            code="CAPACITY_PAIR_REQUIRED",
            message="Giá trị và đơn vị sức chứa phải được nhập cùng nhau.",
        )


async def update_asset(
    *,
    asset_id: UUID,
    request: AssetUpdateRequest,
    current_user: User,
    session: AsyncSession,
) -> AssetResponse:
    asset, area, facility = await _get_owned_asset(
        asset_id=asset_id,
        current_user=current_user,
        session=session,
        for_update=True,
    )
    if asset.revision != request.base_revision:
        await session.rollback()
        raise ApiError(
            status_code=409,
            code="VERSION_CONFLICT",
            message="Thiết bị đã được cập nhật. Hãy tải lại dữ liệu và thử lại.",
        )

    changes = request.model_dump(exclude={"base_revision"}, exclude_unset=True)
    resulting_capacity_value = changes.get("capacity_value", asset.capacity_value)
    resulting_capacity_unit = changes.get("capacity_unit", asset.capacity_unit)
    _validate_resulting_capacity(
        capacity_value=resulting_capacity_value,
        capacity_unit=resulting_capacity_unit,
    )
    try:
        for field, value in changes.items():
            setattr(asset, field, value)
        asset.revision += 1
        asset.updated_at = datetime.now(UTC)
        await session.flush()
        session.add(
            AuditEvent(
                user_id=current_user.id,
                facility_id=facility.id,
                area_id=area.id,
                asset_id=asset.id,
                event_type="asset_updated",
            )
        )
        await session.flush()
        await session.commit()
    except Exception:
        await session.rollback()
        raise
    return build_asset_response(asset)
