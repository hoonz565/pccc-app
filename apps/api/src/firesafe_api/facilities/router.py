from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from firesafe_api.auth.dependencies import get_current_user
from firesafe_api.db.session import get_database_session
from firesafe_api.facilities.schemas import FacilityCreateRequest, FacilityResponse
from firesafe_api.facilities.service import create_facility, list_facilities
from firesafe_api.users.models import User

router = APIRouter(prefix="/facilities", tags=["facilities"])


@router.get("", response_model=list[FacilityResponse])
async def get_facilities(
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
) -> list[FacilityResponse]:
    return await list_facilities(current_user=current_user, session=session)


@router.post(
    "",
    response_model=FacilityResponse,
    status_code=status.HTTP_201_CREATED,
)
async def post_facility(
    request: FacilityCreateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
) -> FacilityResponse:
    return await create_facility(
        request=request,
        current_user=current_user,
        session=session,
    )
