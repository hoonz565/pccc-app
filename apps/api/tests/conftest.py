import os
from collections.abc import AsyncIterator

import httpx
import pytest
import pytest_asyncio

from firesafe_api.core.config import get_settings
from firesafe_api.main import create_app, lifespan


@pytest_asyncio.fixture
async def client(monkeypatch: pytest.MonkeyPatch) -> AsyncIterator[httpx.AsyncClient]:
    monkeypatch.setenv("APP_ENV", "test")
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
