from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from firesafe_api.audit.models import AuditEvent
from firesafe_api.facilities.models import Facility
from firesafe_api.facilities.schemas import FacilityCreateRequest, FacilityResponse
from firesafe_api.users.models import User


def build_facility_response(facility: Facility) -> FacilityResponse:
    return FacilityResponse(
        id=facility.id,
        name=facility.name,
        type=facility.type,
        province=facility.province,
        address=facility.address,
        revision=facility.revision,
        created_at=facility.created_at,
        updated_at=facility.updated_at,
    )


async def create_facility(
    *,
    request: FacilityCreateRequest,
    current_user: User,
    session: AsyncSession,
) -> FacilityResponse:
    facility = Facility(
        user_id=current_user.id,
        name=request.name,
        type=request.type,
        province=request.province,
        address=request.address,
    )
    try:
        session.add(facility)
        await session.flush()
        session.add(
            AuditEvent(
                user_id=current_user.id,
                facility_id=facility.id,
                event_type="facility_created",
            )
        )
        await session.flush()
        await session.commit()
    except Exception:
        await session.rollback()
        raise

    return build_facility_response(facility)


async def list_facilities(
    *,
    current_user: User,
    session: AsyncSession,
) -> list[FacilityResponse]:
    statement = (
        select(Facility)
        .where(Facility.user_id == current_user.id)
        .order_by(Facility.created_at, Facility.id)
    )
    facilities = await session.scalars(statement)
    return [build_facility_response(facility) for facility in facilities]
