import asyncio
from typing import Any, cast
from uuid import UUID, uuid4

import httpx
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker

from firesafe_api.api.errors import ApiError
from firesafe_api.auth.models import AuthSession
from firesafe_api.auth.schemas import RefreshRequest
from firesafe_api.auth.service import logout_session, refresh_authentication
from firesafe_api.core.config import get_settings
from firesafe_api.core.security import create_access_token

pytestmark = pytest.mark.integration


async def _register(client: httpx.AsyncClient) -> dict[str, Any]:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "logout@example.com",
            "password": "a secure passphrase",
            "terms_accepted": True,
            "privacy_accepted": True,
        },
    )
    assert response.status_code == 201
    return cast(dict[str, Any], response.json())


def _authorization(access_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {access_token}"}


async def _session_identity(database_engine: AsyncEngine) -> tuple[UUID, UUID]:
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        auth_session = (await session.scalars(select(AuthSession))).one()
    return auth_session.id, auth_session.user_id


async def test_logout_revokes_refresh_and_access_session(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    registration = await _register(database_client)
    access_token = registration["tokens"]["access_token"]
    refresh_token = registration["tokens"]["refresh_token"]

    response = await database_client.post(
        "/api/v1/auth/logout",
        headers=_authorization(access_token),
    )

    assert response.status_code == 204
    assert response.content == b""

    refresh_response = await database_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    me_response = await database_client.get(
        "/api/v1/me",
        headers=_authorization(access_token),
    )
    assert refresh_response.status_code == 401
    assert me_response.status_code == 401

    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        auth_session = (await session.scalars(select(AuthSession))).one()
    assert auth_session.revoked_at is not None


async def test_logout_is_idempotent_for_revoked_or_unknown_session(
    database_client: httpx.AsyncClient,
) -> None:
    registration = await _register(database_client)
    access_token = registration["tokens"]["access_token"]
    unknown_session_token = create_access_token(
        user_id=UUID(registration["user"]["id"]),
        session_id=uuid4(),
        signing_secret=get_settings().auth_signing_secret,
        lifetime_minutes=15,
    )

    first = await database_client.post(
        "/api/v1/auth/logout",
        headers=_authorization(access_token),
    )
    repeated = await database_client.post(
        "/api/v1/auth/logout",
        headers=_authorization(access_token),
    )
    unknown = await database_client.post(
        "/api/v1/auth/logout",
        headers=_authorization(unknown_session_token),
    )

    assert first.status_code == repeated.status_code == unknown.status_code == 204


async def test_logout_requires_a_cryptographically_valid_access_token(
    database_client: httpx.AsyncClient,
) -> None:
    missing = await database_client.post("/api/v1/auth/logout")
    malformed = await database_client.post(
        "/api/v1/auth/logout",
        headers=_authorization("malformed"),
    )

    assert missing.status_code == malformed.status_code == 401


async def test_refresh_first_then_logout_revokes_stable_session(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    registration = await _register(database_client)
    old_refresh_token = registration["tokens"]["refresh_token"]
    session_id, user_id = await _session_identity(database_engine)
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    refresh_locked = asyncio.Event()
    release_refresh = asyncio.Event()
    logout_attempted = asyncio.Event()

    async with (
        session_factory() as refresh_database_session,
        session_factory() as logout_database_session,
    ):
        original_refresh_scalar = refresh_database_session.scalar
        original_logout_scalar = logout_database_session.scalar

        async def pause_refresh_after_lock(*args: Any, **kwargs: Any) -> Any:
            result = await original_refresh_scalar(*args, **kwargs)
            refresh_locked.set()
            await release_refresh.wait()
            return result

        async def signal_logout_attempt(*args: Any, **kwargs: Any) -> Any:
            logout_attempted.set()
            return await original_logout_scalar(*args, **kwargs)

        monkeypatch.setattr(refresh_database_session, "scalar", pause_refresh_after_lock)
        monkeypatch.setattr(logout_database_session, "scalar", signal_logout_attempt)

        refresh_task = asyncio.create_task(
            refresh_authentication(
                request=RefreshRequest(refresh_token=old_refresh_token),
                session=refresh_database_session,
                settings=get_settings(),
            )
        )
        await refresh_locked.wait()
        logout_task = asyncio.create_task(
            logout_session(
                session_id=session_id,
                user_id=user_id,
                session=logout_database_session,
            )
        )
        await logout_attempted.wait()
        release_refresh.set()
        refreshed, _ = await asyncio.gather(refresh_task, logout_task)

    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        auth_session = await session.get(AuthSession, session_id)
    assert auth_session is not None
    assert auth_session.revoked_at is not None

    rotated_refresh = await database_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refreshed.tokens.refresh_token},
    )
    assert rotated_refresh.status_code == 401


async def test_logout_first_then_refresh_is_rejected(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    registration = await _register(database_client)
    refresh_token = registration["tokens"]["refresh_token"]
    session_id, user_id = await _session_identity(database_engine)
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    logout_locked = asyncio.Event()
    release_logout = asyncio.Event()
    refresh_attempted = asyncio.Event()

    async with (
        session_factory() as logout_database_session,
        session_factory() as refresh_database_session,
    ):
        original_logout_scalar = logout_database_session.scalar
        original_refresh_scalar = refresh_database_session.scalar

        async def pause_logout_after_lock(*args: Any, **kwargs: Any) -> Any:
            result = await original_logout_scalar(*args, **kwargs)
            logout_locked.set()
            await release_logout.wait()
            return result

        async def signal_refresh_attempt(*args: Any, **kwargs: Any) -> Any:
            refresh_attempted.set()
            return await original_refresh_scalar(*args, **kwargs)

        monkeypatch.setattr(logout_database_session, "scalar", pause_logout_after_lock)
        monkeypatch.setattr(refresh_database_session, "scalar", signal_refresh_attempt)

        logout_task = asyncio.create_task(
            logout_session(
                session_id=session_id,
                user_id=user_id,
                session=logout_database_session,
            )
        )
        await logout_locked.wait()
        refresh_task = asyncio.create_task(
            refresh_authentication(
                request=RefreshRequest(refresh_token=refresh_token),
                session=refresh_database_session,
                settings=get_settings(),
            )
        )
        await refresh_attempted.wait()
        release_logout.set()
        await logout_task
        with pytest.raises(ApiError) as refresh_error:
            await refresh_task

    assert refresh_error.value.status_code == 401
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        auth_session = await session.get(AuthSession, session_id)
    assert auth_session is not None
    assert auth_session.revoked_at is not None
