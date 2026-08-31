from datetime import UTC, datetime
from typing import Annotated

import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from firesafe_api.api.errors import ApiError
from firesafe_api.auth.models import AuthSession
from firesafe_api.core.config import Settings, get_settings
from firesafe_api.core.security import AccessTokenClaims, decode_access_token
from firesafe_api.db.session import get_database_session
from firesafe_api.users.models import User

_bearer = HTTPBearer(auto_error=False)


def _unauthenticated() -> ApiError:
    return ApiError(
        status_code=401,
        code="UNAUTHENTICATED",
        message="Phiên đăng nhập không hợp lệ hoặc đã hết hạn.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_access_token_claims(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> AccessTokenClaims:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthenticated()
    try:
        return decode_access_token(credentials.credentials, settings.auth_signing_secret)
    except (jwt.InvalidTokenError, TypeError, ValueError):
        raise _unauthenticated() from None


async def get_current_user(
    claims: Annotated[AccessTokenClaims, Depends(get_access_token_claims)],
    session: Annotated[AsyncSession, Depends(get_database_session)],
) -> User:
    auth_session = await session.get(AuthSession, claims.session_id)
    if (
        auth_session is None
        or auth_session.user_id != claims.user_id
        or auth_session.revoked_at is not None
        or auth_session.expires_at <= datetime.now(UTC)
    ):
        raise _unauthenticated()

    user = await session.get(User, claims.user_id)
    if user is None:
        raise _unauthenticated()
    return user
