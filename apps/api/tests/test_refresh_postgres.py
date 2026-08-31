import asyncio
from datetime import UTC, datetime, timedelta
from typing import Any, cast

import httpx
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker

from firesafe_api.auth.models import AuthSession
from firesafe_api.core.security import digest_refresh_token

pytestmark = pytest.mark.integration


async def _register(client: httpx.AsyncClient, email: str) -> dict[str, Any]:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "a secure passphrase",
            "terms_accepted": True,
            "privacy_accepted": True,
        },
    )
    assert response.status_code == 201
    return cast(dict[str, Any], response.json())


def _invalid_refresh_response() -> dict[str, object]:
    return {
        "error": {
            "code": "INVALID_REFRESH_TOKEN",
            "message": "Phiên đăng nhập không hợp lệ hoặc đã hết hạn.",
        }
    }


async def test_refresh_rotates_token_and_rejects_previous_token(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    registration = await _register(database_client, "rotate@example.com")
    old_refresh_token = registration["tokens"]["refresh_token"]

    refreshed = await database_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh_token},
    )

    assert refreshed.status_code == 200
    new_refresh_token = refreshed.json()["tokens"]["refresh_token"]
    assert new_refresh_token != old_refresh_token
    assert old_refresh_token not in refreshed.text

    previous = await database_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": old_refresh_token},
    )
    assert previous.status_code == 401
    assert previous.json() == _invalid_refresh_response()

    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        auth_session = (await session.scalars(select(AuthSession))).one()
    assert auth_session.refresh_token_hash == digest_refresh_token(new_refresh_token)
    assert auth_session.last_refreshed_at is not None


@pytest.mark.parametrize("state", ["expired", "revoked"])
async def test_expired_or_revoked_refresh_is_rejected(
    state: str,
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    registration = await _register(database_client, f"{state}@example.com")
    refresh_token = registration["tokens"]["refresh_token"]
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        auth_session = (await session.scalars(select(AuthSession))).one()
        if state == "expired":
            auth_session.expires_at = datetime.now(UTC) - timedelta(minutes=1)
        else:
            auth_session.revoked_at = datetime.now(UTC)
        await session.commit()

    response = await database_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )

    assert response.status_code == 401
    assert response.json() == _invalid_refresh_response()
    assert refresh_token not in response.text


async def test_invalid_refresh_is_rejected_without_internal_details(
    database_client: httpx.AsyncClient,
) -> None:
    response = await database_client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "not-a-valid-refresh-token"},
    )

    assert response.status_code == 401
    assert response.json() == _invalid_refresh_response()
    assert "sql" not in response.text.lower()


async def test_concurrent_refresh_allows_only_one_rotation(
    database_client: httpx.AsyncClient,
) -> None:
    registration = await _register(database_client, "refresh-race@example.com")
    refresh_token = registration["tokens"]["refresh_token"]

    responses = await asyncio.gather(
        *[
            database_client.post(
                "/api/v1/auth/refresh",
                json={"refresh_token": refresh_token},
            )
            for _ in range(2)
        ]
    )

    assert sorted(response.status_code for response in responses) == [200, 401]
