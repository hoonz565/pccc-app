import asyncio

import httpx
import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from firesafe_api.auth.models import AuthSession
from firesafe_api.core.security import digest_refresh_token, verify_password
from firesafe_api.users.models import User

pytestmark = pytest.mark.integration

VALID_PASSWORD = "a secure passphrase"


def registration_payload(email: str) -> dict[str, object]:
    return {
        "email": email,
        "password": VALID_PASSWORD,
        "terms_accepted": True,
        "privacy_accepted": True,
    }


async def test_registration_creates_hashed_user_and_session(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    response = await database_client.post(
        "/api/v1/auth/register",
        json=registration_payload("New.User@Example.COM"),
    )

    assert response.status_code == 201
    body = response.json()
    assert body["user"]["email"] == "new.user@example.com"
    assert body["user"]["terms_version"] == "draft-v1"
    assert body["user"]["privacy_version"] == "draft-v1"
    assert body["tokens"]["token_type"] == "bearer"
    assert VALID_PASSWORD not in response.text

    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        user = (await session.scalars(select(User))).one()
        auth_session = (await session.scalars(select(AuthSession))).one()

    refresh_token = body["tokens"]["refresh_token"]
    assert user.password_hash != VALID_PASSWORD
    assert verify_password(VALID_PASSWORD, user.password_hash)
    assert auth_session.refresh_token_hash == digest_refresh_token(refresh_token)
    assert refresh_token != auth_session.refresh_token_hash


async def test_duplicate_email_is_safe_conflict(
    database_client: httpx.AsyncClient,
) -> None:
    first = await database_client.post(
        "/api/v1/auth/register",
        json=registration_payload("duplicate@example.com"),
    )
    duplicate = await database_client.post(
        "/api/v1/auth/register",
        json=registration_payload("DUPLICATE@example.com"),
    )

    assert first.status_code == 201
    assert duplicate.status_code == 409
    assert duplicate.json() == {
        "error": {
            "code": "EMAIL_ALREADY_REGISTERED",
            "message": "Không thể đăng ký tài khoản với email này.",
        }
    }
    assert "sql" not in duplicate.text.lower()


async def test_concurrent_duplicate_registration_creates_one_user(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    responses = await asyncio.gather(
        *[
            database_client.post(
                "/api/v1/auth/register",
                json=registration_payload("race@example.com"),
            )
            for _ in range(2)
        ]
    )

    assert sorted(response.status_code for response in responses) == [201, 409]
    session_factory = async_sessionmaker(database_engine, class_=AsyncSession)
    async with session_factory() as session:
        users = list(await session.scalars(select(User)))
    assert len(users) == 1
