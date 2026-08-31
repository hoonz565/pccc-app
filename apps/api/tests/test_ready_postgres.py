import os

import httpx
import pytest

from firesafe_api.core.config import get_settings
from firesafe_api.main import create_app, lifespan


@pytest.mark.integration
async def test_ready_connects_to_postgres(monkeypatch: pytest.MonkeyPatch) -> None:
    if os.getenv("RUN_DATABASE_TESTS") != "1":
        pytest.skip("Set RUN_DATABASE_TESTS=1 to run PostgreSQL integration tests")

    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv(
        "AUTH_SIGNING_SECRET",
        "test-only-signing-secret-with-at-least-32-characters",
    )
    get_settings.cache_clear()
    application = create_app()
    async with lifespan(application):
        transport = httpx.ASGITransport(app=application)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready", "database": "connected"}
    get_settings.cache_clear()
