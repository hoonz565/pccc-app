from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from firesafe_api.areas.schemas import AreaCreateRequest, AreaResponse
from firesafe_api.areas.service import create_area, list_areas
from firesafe_api.auth.dependencies import get_current_user
from firesafe_api.db.session import get_database_session
from firesafe_api.users.models import User

router = APIRouter(tags=["areas"])


@router.get("/facilities/{facility_id}/areas", response_model=list[AreaResponse])
async def get_areas(
    facility_id: UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
) -> list[AreaResponse]:
    return await list_areas(
        facility_id=facility_id,
        current_user=current_user,
        session=session,
    )


@router.post(
    "/facilities/{facility_id}/areas",
    response_model=AreaResponse,
    status_code=status.HTTP_201_CREATED,
)
async def post_area(
    facility_id: UUID,
    request: AreaCreateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
) -> AreaResponse:
    return await create_area(
        facility_id=facility_id,
        request=request,
        current_user=current_user,
        session=session,
    )
