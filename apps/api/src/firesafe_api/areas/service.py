from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from firesafe_api.api.errors import ApiError
from firesafe_api.areas.models import Area
from firesafe_api.areas.schemas import AreaCreateRequest, AreaResponse
from firesafe_api.audit.models import AuditEvent
from firesafe_api.facilities.models import Facility
from firesafe_api.users.models import User


def build_area_response(area: Area) -> AreaResponse:
    return AreaResponse(
        id=area.id,
        facility_id=area.facility_id,
        name=area.name,
        revision=area.revision,
        created_at=area.created_at,
        updated_at=area.updated_at,
    )


async def get_owned_facility(
    *,
    facility_id: UUID,
    current_user: User,
    session: AsyncSession,
) -> Facility:
    facility = await session.scalar(
        select(Facility).where(
            Facility.id == facility_id,
            Facility.user_id == current_user.id,
        )
    )
    if facility is None:
        raise ApiError(
            status_code=404,
            code="FACILITY_NOT_FOUND",
            message="Không tìm thấy cơ sở.",
        )
    return facility


async def create_area(
    *,
    facility_id: UUID,
    request: AreaCreateRequest,
    current_user: User,
    session: AsyncSession,
) -> AreaResponse:
    facility = await get_owned_facility(
        facility_id=facility_id,
        current_user=current_user,
        session=session,
    )
    area = Area(facility_id=facility.id, name=request.name)
    try:
        session.add(area)
        await session.flush()
        session.add(
            AuditEvent(
                user_id=current_user.id,
                facility_id=facility.id,
                area_id=area.id,
                event_type="area_created",
            )
        )
        await session.flush()
        await session.commit()
    except Exception:
        await session.rollback()
        raise
    return build_area_response(area)


async def list_areas(
    *,
    facility_id: UUID,
    current_user: User,
    session: AsyncSession,
) -> list[AreaResponse]:
    facility = await get_owned_facility(
        facility_id=facility_id,
        current_user=current_user,
        session=session,
    )
    areas = await session.scalars(
        select(Area).where(Area.facility_id == facility.id).order_by(Area.created_at, Area.id)
    )
    return [build_area_response(area) for area in areas]
