from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from firesafe_api.auth.dependencies import get_access_token_claims
from firesafe_api.auth.schemas import (
    AuthResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
)
from firesafe_api.auth.service import (
    login_user,
    logout_session,
    refresh_authentication,
    register_user,
)
from firesafe_api.core.config import Settings, get_settings
from firesafe_api.core.security import AccessTokenClaims
from firesafe_api.db.session import get_database_session

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    request: RegisterRequest,
    session: Annotated[AsyncSession, Depends(get_database_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AuthResponse:
    return await register_user(request=request, session=session, settings=settings)


@router.post("/login", response_model=AuthResponse)
async def login(
    request: LoginRequest,
    session: Annotated[AsyncSession, Depends(get_database_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AuthResponse:
    return await login_user(request=request, session=session, settings=settings)


@router.post("/refresh", response_model=AuthResponse)
async def refresh(
    request: RefreshRequest,
    session: Annotated[AsyncSession, Depends(get_database_session)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AuthResponse:
    return await refresh_authentication(
        request=request,
        session=session,
        settings=settings,
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    claims: Annotated[AccessTokenClaims, Depends(get_access_token_claims)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
) -> Response:
    await logout_session(
        session_id=claims.session_id,
        user_id=claims.user_id,
        session=session,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
