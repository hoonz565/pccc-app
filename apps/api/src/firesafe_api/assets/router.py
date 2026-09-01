from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from firesafe_api.assets.schemas import AssetCreateRequest, AssetResponse, AssetUpdateRequest
from firesafe_api.assets.service import create_asset, get_asset, list_assets, update_asset
from firesafe_api.auth.dependencies import get_current_user
from firesafe_api.db.session import get_database_session
from firesafe_api.users.models import User

router = APIRouter(tags=["assets"])


@router.get("/areas/{area_id}/assets", response_model=list[AssetResponse])
async def get_assets(
    area_id: UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[AssetResponse]:
    return await list_assets(
        area_id=area_id,
        limit=limit,
        offset=offset,
        current_user=current_user,
        session=session,
    )


@router.post(
    "/areas/{area_id}/assets",
    response_model=AssetResponse,
    status_code=status.HTTP_201_CREATED,
)
async def post_asset(
    area_id: UUID,
    request: AssetCreateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
) -> AssetResponse:
    return await create_asset(
        area_id=area_id,
        request=request,
        current_user=current_user,
        session=session,
    )


@router.get("/assets/{asset_id}", response_model=AssetResponse)
async def get_asset_detail(
    asset_id: UUID,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
) -> AssetResponse:
    return await get_asset(
        asset_id=asset_id,
        current_user=current_user,
        session=session,
    )


@router.patch("/assets/{asset_id}", response_model=AssetResponse)
async def patch_asset(
    asset_id: UUID,
    request: AssetUpdateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
) -> AssetResponse:
    return await update_asset(
        asset_id=asset_id,
        request=request,
        current_user=current_user,
        session=session,
    )
