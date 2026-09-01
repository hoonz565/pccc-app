from typing import Any, cast
from uuid import UUID

import httpx
import pytest
from sqlalchemy import event, func, select
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker

from firesafe_api.areas.models import Area
from firesafe_api.areas.schemas import AreaCreateRequest
from firesafe_api.areas.service import create_area
from firesafe_api.audit.models import AuditEvent
from firesafe_api.facilities.models import Facility
from firesafe_api.users.models import User

pytestmark = pytest.mark.integration


async def _register(client: httpx.AsyncClient, email: str) -> dict[str, str]:
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
    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


async def _create_facility(
    client: httpx.AsyncClient,
    headers: dict[str, str],
) -> dict[str, Any]:
    response = await client.post(
        "/api/v1/facilities",
        headers=headers,
        json={
            "name": "Nhà máy An Toàn",
            "type": "Nhà máy",
            "province": "Đà Nẵng",
            "address": "1 Đường Bình An",
        },
    )
    assert response.status_code == 201
    return cast(dict[str, Any], response.json())


async def test_create_and_list_area_is_owned_revised_and_audited(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    headers = await _register(database_client, "area-owner@example.com")
    facility = await _create_facility(database_client, headers)

    created = await database_client.post(
        f"/api/v1/facilities/{facility['id']}/areas",
        headers=headers,
        json={"name": "  Tầng 1  "},
    )
    listed = await database_client.get(
        f"/api/v1/facilities/{facility['id']}/areas",
        headers=headers,
    )

    assert created.status_code == 201
    assert created.json()["name"] == "Tầng 1"
    assert created.json()["facility_id"] == facility["id"]
    assert created.json()["revision"] == 1
    assert listed.status_code == 200
    assert [item["id"] for item in listed.json()] == [created.json()["id"]]
    assert "user_id" not in created.text

    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        area = await session.get(Area, UUID(created.json()["id"]))
        audit = await session.scalar(
            select(AuditEvent).where(AuditEvent.event_type == "area_created")
        )
    assert area is not None
    assert audit is not None
    assert audit.area_id == area.id
    assert audit.facility_id == area.facility_id


async def test_area_rejects_blank_and_spoofed_fields(
    database_client: httpx.AsyncClient,
) -> None:
    headers = await _register(database_client, "area-strict@example.com")
    facility = await _create_facility(database_client, headers)

    response = await database_client.post(
        f"/api/v1/facilities/{facility['id']}/areas",
        headers=headers,
        json={
            "name": "   ",
            "facility_id": facility["id"],
            "owner_user_id": "00000000-0000-0000-0000-000000000000",
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


async def test_cross_user_area_create_and_list_use_safe_not_found(
    database_client: httpx.AsyncClient,
) -> None:
    user_a = await _register(database_client, "area-a@example.com")
    user_b = await _register(database_client, "area-b@example.com")
    facility = await _create_facility(database_client, user_a)

    create = await database_client.post(
        f"/api/v1/facilities/{facility['id']}/areas",
        headers=user_b,
        json={"name": "Khu vực lạ"},
    )
    listed = await database_client.get(
        f"/api/v1/facilities/{facility['id']}/areas",
        headers=user_b,
    )

    assert create.status_code == listed.status_code == 404
    assert create.json() == listed.json()
    assert create.json()["error"]["code"] == "FACILITY_NOT_FOUND"


async def test_area_and_audit_event_are_atomic(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    headers = await _register(database_client, "area-atomic@example.com")
    facility_response = await _create_facility(database_client, headers)
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        user = (await session.scalars(select(User))).one()
        facility = await session.get(Facility, UUID(facility_response["id"]))
    assert facility is not None

    def fail_audit_insert(*_: object) -> None:
        raise RuntimeError("forced area audit failure")

    event.listen(AuditEvent, "before_insert", fail_audit_insert)
    try:
        async with session_factory() as session:
            with pytest.raises(RuntimeError, match="forced area audit failure"):
                await create_area(
                    facility_id=facility.id,
                    request=AreaCreateRequest(name="Tầng lỗi"),
                    current_user=user,
                    session=session,
                )
    finally:
        event.remove(AuditEvent, "before_insert", fail_audit_insert)

    async with session_factory() as session:
        count = await session.scalar(select(func.count()).select_from(Area))
    assert count == 0
