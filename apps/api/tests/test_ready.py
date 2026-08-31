import httpx
import pytest

from firesafe_api.api.routes import operational


async def test_ready_returns_connected_when_database_probe_succeeds(
    client: httpx.AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def successful_check(_: object) -> None:
        return None

    monkeypatch.setattr(operational, "check_database", successful_check)

    response = await client.get("/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready", "database": "connected"}


async def test_ready_hides_database_exception(
    client: httpx.AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    async def failing_check(_: object) -> None:
        raise RuntimeError("sensitive internal database detail")

    monkeypatch.setattr(operational, "check_database", failing_check)

    response = await client.get("/ready")

    assert response.status_code == 503
    assert response.json() == {"status": "not_ready", "database": "unavailable"}
    assert "sensitive" not in response.text
