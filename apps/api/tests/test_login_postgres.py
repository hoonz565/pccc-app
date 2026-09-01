import httpx
import pytest
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker

from firesafe_api.auth.models import AuthSession

pytestmark = pytest.mark.integration

VALID_PASSWORD = "a secure passphrase"


async def _register(client: httpx.AsyncClient, email: str) -> None:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": VALID_PASSWORD,
            "terms_accepted": True,
            "privacy_accepted": True,
        },
    )
    assert response.status_code == 201


async def test_valid_login_normalizes_email_and_creates_session(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    await _register(database_client, "login@example.com")

    response = await database_client.post(
        "/api/v1/auth/login",
        json={"email": "LOGIN@EXAMPLE.COM", "password": VALID_PASSWORD},
    )

    assert response.status_code == 200
    assert response.json()["user"]["email"] == "login@example.com"
    assert response.json()["tokens"]["access_token"]
    assert response.json()["tokens"]["refresh_token"]
    assert VALID_PASSWORD not in response.text

    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        session_count = await session.scalar(select(func.count()).select_from(AuthSession))
    assert session_count == 2


async def test_invalid_login_uses_one_generic_response(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    await _register(database_client, "known@example.com")
    expected = {
        "error": {
            "code": "INVALID_CREDENTIALS",
            "message": "Email hoặc mật khẩu không chính xác.",
        }
    }

    unknown = await database_client.post(
        "/api/v1/auth/login",
        json={
            "email": "unknown@example.com",
            "password": "wrong secure passphrase",
        },
    )
    wrong_password = await database_client.post(
        "/api/v1/auth/login",
        json={
            "email": "known@example.com",
            "password": "wrong secure passphrase",
        },
    )

    assert unknown.status_code == wrong_password.status_code == 401
    assert unknown.json() == wrong_password.json() == expected
    assert "wrong secure passphrase" not in unknown.text
    assert "wrong secure passphrase" not in wrong_password.text

    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        session_count = await session.scalar(select(func.count()).select_from(AuthSession))
    assert session_count == 1
