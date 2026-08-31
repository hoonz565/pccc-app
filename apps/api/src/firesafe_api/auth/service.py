from datetime import UTC, datetime, timedelta
from uuid import UUID

from anyio import to_thread
from email_validator import validate_email
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from firesafe_api.api.errors import ApiError
from firesafe_api.auth.models import AuthSession
from firesafe_api.auth.schemas import (
    AuthResponse,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenPair,
)
from firesafe_api.core.config import Settings
from firesafe_api.core.security import (
    create_access_token,
    create_refresh_token,
    digest_refresh_token,
    hash_password,
    verify_password,
)
from firesafe_api.users.models import User
from firesafe_api.users.service import build_user_response

_DUMMY_PASSWORD_HASH = hash_password("dummy password used only for login timing")


def normalize_email(email: str) -> str:
    result = validate_email(email, check_deliverability=False)
    return result.normalized.casefold()


def _is_duplicate_email(error: IntegrityError) -> bool:
    diagnostic = getattr(error.orig, "diag", None)
    return getattr(diagnostic, "constraint_name", None) == "uq_users_email_normalized"


def build_auth_response(
    *,
    user: User,
    auth_session: AuthSession,
    refresh_token: str,
    settings: Settings,
) -> AuthResponse:
    access_token = create_access_token(
        user_id=user.id,
        session_id=auth_session.id,
        signing_secret=settings.auth_signing_secret,
        lifetime_minutes=settings.access_token_ttl_minutes,
    )
    return AuthResponse(
        user=build_user_response(user),
        tokens=TokenPair(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=settings.access_token_ttl_minutes * 60,
        ),
    )


async def register_user(
    *,
    request: RegisterRequest,
    session: AsyncSession,
    settings: Settings,
) -> AuthResponse:
    email_normalized = normalize_email(str(request.email))
    password_hash = await to_thread.run_sync(hash_password, request.password)
    accepted_at = datetime.now(UTC)
    refresh_token = create_refresh_token()
    user = User(
        email_normalized=email_normalized,
        password_hash=password_hash,
        terms_version=settings.terms_version,
        terms_accepted_at=accepted_at,
        privacy_version=settings.privacy_version,
        privacy_accepted_at=accepted_at,
    )
    auth_session = AuthSession(
        user_id=user.id,
        refresh_token_hash=digest_refresh_token(refresh_token),
        expires_at=accepted_at + timedelta(days=settings.refresh_token_ttl_days),
    )

    try:
        async with session.begin():
            session.add(user)
            await session.flush()
            auth_session.user_id = user.id
            session.add(auth_session)
            await session.flush()
    except IntegrityError as error:
        if _is_duplicate_email(error):
            raise ApiError(
                status_code=409,
                code="EMAIL_ALREADY_REGISTERED",
                message="Không thể đăng ký tài khoản với email này.",
            ) from None
        raise

    return build_auth_response(
        user=user,
        auth_session=auth_session,
        refresh_token=refresh_token,
        settings=settings,
    )


async def login_user(
    *,
    request: LoginRequest,
    session: AsyncSession,
    settings: Settings,
) -> AuthResponse:
    email_normalized = normalize_email(str(request.email))
    user = await session.scalar(select(User).where(User.email_normalized == email_normalized))
    password_hash = user.password_hash if user is not None else _DUMMY_PASSWORD_HASH
    password_matches = await to_thread.run_sync(
        verify_password,
        request.password,
        password_hash,
    )
    if user is None or not password_matches:
        raise ApiError(
            status_code=401,
            code="INVALID_CREDENTIALS",
            message="Email hoặc mật khẩu không chính xác.",
        )

    created_at = datetime.now(UTC)
    refresh_token = create_refresh_token()
    auth_session = AuthSession(
        user_id=user.id,
        refresh_token_hash=digest_refresh_token(refresh_token),
        expires_at=created_at + timedelta(days=settings.refresh_token_ttl_days),
    )
    try:
        session.add(auth_session)
        await session.flush()
        await session.commit()
    except Exception:
        await session.rollback()
        raise

    return build_auth_response(
        user=user,
        auth_session=auth_session,
        refresh_token=refresh_token,
        settings=settings,
    )


def _invalid_refresh_token() -> ApiError:
    return ApiError(
        status_code=401,
        code="INVALID_REFRESH_TOKEN",
        message="Phiên đăng nhập không hợp lệ hoặc đã hết hạn.",
    )


async def refresh_authentication(
    *,
    request: RefreshRequest,
    session: AsyncSession,
    settings: Settings,
) -> AuthResponse:
    refreshed_at = datetime.now(UTC)
    refresh_token_hash = digest_refresh_token(request.refresh_token)
    auth_session = await session.scalar(
        select(AuthSession)
        .where(
            AuthSession.refresh_token_hash == refresh_token_hash,
            AuthSession.revoked_at.is_(None),
            AuthSession.expires_at > refreshed_at,
        )
        .with_for_update()
    )
    if auth_session is None:
        raise _invalid_refresh_token()

    user = await session.get(User, auth_session.user_id)
    if user is None:
        raise _invalid_refresh_token()

    rotated_refresh_token = create_refresh_token()
    auth_session.refresh_token_hash = digest_refresh_token(rotated_refresh_token)
    auth_session.last_refreshed_at = refreshed_at
    try:
        await session.flush()
        await session.commit()
    except Exception:
        await session.rollback()
        raise

    return build_auth_response(
        user=user,
        auth_session=auth_session,
        refresh_token=rotated_refresh_token,
        settings=settings,
    )


async def logout_session(
    *,
    session_id: UUID,
    user_id: UUID,
    session: AsyncSession,
) -> None:
    auth_session = await session.scalar(
        select(AuthSession)
        .where(
            AuthSession.id == session_id,
            AuthSession.user_id == user_id,
        )
        .with_for_update()
    )
    if auth_session is not None and auth_session.revoked_at is None:
        auth_session.revoked_at = datetime.now(UTC)
        await session.flush()
    await session.commit()
