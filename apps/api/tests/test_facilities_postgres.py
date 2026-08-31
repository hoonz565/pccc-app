from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

import httpx
import pytest
from pydantic import SecretStr
from sqlalchemy import event, func, select
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker

from firesafe_api.audit.models import AuditEvent
from firesafe_api.core.security import create_access_token
from firesafe_api.facilities.models import Facility
from firesafe_api.facilities.schemas import FacilityCreateRequest
from firesafe_api.facilities.service import create_facility
from firesafe_api.users.models import User

pytestmark = pytest.mark.integration


def registration_payload(email: str) -> dict[str, object]:
    return {
        "email": email,
        "password": "a secure passphrase",
        "terms_accepted": True,
        "privacy_accepted": True,
    }


async def register(
    client: httpx.AsyncClient,
    email: str,
) -> tuple[dict[str, str], dict[str, Any]]:
    response = await client.post(
        "/api/v1/auth/register",
        json=registration_payload(email),
    )
    assert response.status_code == 201
    body = response.json()
    return (
        {"Authorization": f"Bearer {body['tokens']['access_token']}"},
        body,
    )


def facility_payload() -> dict[str, str]:
    return {
        "name": "Nhà máy Bình An",
        "type": "Nhà máy sản xuất",
        "province": "Bình Dương",
        "address": "123 Đường An Toàn",
    }


async def test_me_and_facility_endpoints_require_authentication(
    database_client: httpx.AsyncClient,
) -> None:
    me_response = await database_client.get("/api/v1/me")
    facilities_response = await database_client.get("/api/v1/facilities")

    assert me_response.status_code == 401
    assert facilities_response.status_code == 401
    assert me_response.headers["www-authenticate"] == "Bearer"


async def test_valid_access_token_resolves_current_user(
    database_client: httpx.AsyncClient,
) -> None:
    headers, registration = await register(database_client, "me@example.com")

    response = await database_client.get("/api/v1/me", headers=headers)

    assert response.status_code == 200
    assert response.json()["id"] == registration["user"]["id"]
    assert response.json()["email"] == "me@example.com"
    assert "password_hash" not in response.text


async def test_malformed_and_expired_access_tokens_are_rejected(
    database_client: httpx.AsyncClient,
) -> None:
    _, registration = await register(database_client, "expired@example.com")
    expired = create_access_token(
        user_id=UUID(registration["user"]["id"]),
        session_id=uuid4(),
        signing_secret=SecretStr("local-integration-test-signing-secret-at-least-32-characters"),
        lifetime_minutes=1,
        now=datetime.now(UTC) - timedelta(minutes=2),
    )

    malformed_response = await database_client.get(
        "/api/v1/me",
        headers={"Authorization": "Bearer malformed"},
    )
    expired_response = await database_client.get(
        "/api/v1/me",
        headers={"Authorization": f"Bearer {expired}"},
    )

    assert malformed_response.status_code == 401
    assert expired_response.status_code == 401


async def test_facility_creation_is_owned_revised_and_audited(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    headers, registration = await register(database_client, "owner@example.com")

    response = await database_client.post(
        "/api/v1/facilities",
        headers=headers,
        json=facility_payload(),
    )

    assert response.status_code == 201
    assert response.json()["revision"] == 1
    assert "user_id" not in response.text
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        facility = (await session.scalars(select(Facility))).one()
        audit_event = (await session.scalars(select(AuditEvent))).one()
    assert str(facility.user_id) == registration["user"]["id"]
    assert audit_event.facility_id == facility.id
    assert audit_event.user_id == facility.user_id
    assert audit_event.event_type == "facility_created"


async def test_facility_list_is_owner_scoped(
    database_client: httpx.AsyncClient,
) -> None:
    user_a_headers, _ = await register(database_client, "user-a@example.com")
    user_b_headers, _ = await register(database_client, "user-b@example.com")
    created = await database_client.post(
        "/api/v1/facilities",
        headers=user_a_headers,
        json=facility_payload(),
    )

    user_a_list = await database_client.get(
        "/api/v1/facilities",
        headers=user_a_headers,
    )
    user_b_list = await database_client.get(
        "/api/v1/facilities",
        headers=user_b_headers,
    )

    assert created.status_code == 201
    assert [item["id"] for item in user_a_list.json()] == [created.json()["id"]]
    assert user_b_list.json() == []


async def test_facility_rejects_required_and_owner_spoof_fields(
    database_client: httpx.AsyncClient,
) -> None:
    headers, _ = await register(database_client, "strict@example.com")
    invalid = facility_payload()
    invalid["name"] = "   "
    invalid["owner_user_id"] = "00000000-0000-0000-0000-000000000000"

    response = await database_client.post(
        "/api/v1/facilities",
        headers=headers,
        json=invalid,
    )

    assert response.status_code == 422
    assert "owner_user_id" in response.text


async def test_facility_and_audit_event_are_atomic(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    await register(database_client, "atomic@example.com")
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        user = (await session.scalars(select(User))).one()

    def fail_audit_insert(*_: object) -> None:
        raise RuntimeError("forced audit insert failure")

    event.listen(AuditEvent, "before_insert", fail_audit_insert)
    try:
        async with session_factory() as session:
            with pytest.raises(RuntimeError, match="forced audit insert failure"):
                await create_facility(
                    request=FacilityCreateRequest(**facility_payload()),
                    current_user=user,
                    session=session,
                )
    finally:
        event.remove(AuditEvent, "before_insert", fail_audit_insert)

    async with session_factory() as session:
        facility_count = await session.scalar(select(func.count()).select_from(Facility))
        audit_count = await session.scalar(select(func.count()).select_from(AuditEvent))
    assert facility_count == 0
    assert audit_count == 0
