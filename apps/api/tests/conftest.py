import os
from collections.abc import AsyncIterator
from typing import cast

import httpx
import pytest
import pytest_asyncio
from fastapi import FastAPI
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine

from firesafe_api.core.config import get_settings
from firesafe_api.main import create_app, lifespan

TEST_SIGNING_SECRET = "test-only-signing-secret-with-at-least-32-characters"


@pytest_asyncio.fixture
async def client(monkeypatch: pytest.MonkeyPatch) -> AsyncIterator[httpx.AsyncClient]:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv(
        "AUTH_SIGNING_SECRET",
        TEST_SIGNING_SECRET,
    )
    monkeypatch.setenv(
        "DATABASE_URL",
        "postgresql+psycopg://firesafe:firesafe_dev_password@127.0.0.1:1/firesafe",
    )
    get_settings.cache_clear()
    application = create_app()
    async with lifespan(application):
        transport = httpx.ASGITransport(app=application)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as test_client:
            yield test_client
    get_settings.cache_clear()


@pytest.fixture
def database_url() -> str:
    return os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg://firesafe:firesafe_dev_password@127.0.0.1:5432/firesafe",
    )


@pytest_asyncio.fixture
async def database_app(
    monkeypatch: pytest.MonkeyPatch,
    database_url: str,
) -> AsyncIterator[FastAPI]:
    if os.getenv("RUN_DATABASE_TESTS") != "1":
        pytest.skip("Set RUN_DATABASE_TESTS=1 to run PostgreSQL integration tests")

    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv("DATABASE_URL", database_url)
    monkeypatch.setenv("AUTH_SIGNING_SECRET", TEST_SIGNING_SECRET)
    get_settings.cache_clear()
    application = create_app()
    async with lifespan(application):
        engine: AsyncEngine = application.state.database_engine
        async with engine.begin() as connection:
            await connection.execute(
                text(
                    "TRUNCATE TABLE auth_sessions, users RESTART IDENTITY CASCADE"
                )
            )
        yield application
        async with engine.begin() as connection:
            await connection.execute(
                text(
                    "TRUNCATE TABLE auth_sessions, users RESTART IDENTITY CASCADE"
                )
            )
    get_settings.cache_clear()


@pytest_asyncio.fixture
async def database_client(database_app: FastAPI) -> AsyncIterator[httpx.AsyncClient]:
    transport = httpx.ASGITransport(app=database_app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as test_client:
        yield test_client


@pytest.fixture
def database_engine(database_app: FastAPI) -> AsyncEngine:
    return cast(AsyncEngine, database_app.state.database_engine)
