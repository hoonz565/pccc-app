from typing import Any, cast
from uuid import UUID

import httpx
import pytest
from sqlalchemy import event, func, select
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker

from firesafe_api.assets.models import Asset
from firesafe_api.assets.schemas import AssetCreateRequest, AssetUpdateRequest
from firesafe_api.assets.service import create_asset, update_asset
from firesafe_api.audit.models import AuditEvent
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


async def _create_area(
    client: httpx.AsyncClient,
    headers: dict[str, str],
) -> dict[str, Any]:
    facility = await client.post(
        "/api/v1/facilities",
        headers=headers,
        json={
            "name": "Kho trung tâm",
            "type": "Kho",
            "province": "Hà Nội",
            "address": "1 Đường An Toàn",
        },
    )
    assert facility.status_code == 201
    area = await client.post(
        f"/api/v1/facilities/{facility.json()['id']}/areas",
        headers=headers,
        json={"name": "Tầng 1"},
    )
    assert area.status_code == 201
    return cast(dict[str, Any], area.json())


async def test_create_minimal_asset_generates_server_fields_and_detail(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    headers = await _register(database_client, "asset-minimal@example.com")
    area = await _create_area(database_client, headers)

    created = await database_client.post(
        f"/api/v1/areas/{area['id']}/assets",
        headers=headers,
        json={"type": "Bình chữa cháy"},
    )
    detail = await database_client.get(
        f"/api/v1/assets/{created.json()['id']}",
        headers=headers,
    )

    assert created.status_code == 201
    body = created.json()
    assert body["asset_code"] == f"AST-{body['id'].upper()}"
    assert body["area_id"] == area["id"]
    assert body["type"] == "Bình chữa cháy"
    assert body["lifecycle_state"] == "ACTIVE"
    assert body["source"] == "MANUAL"
    assert body["revision"] == 1
    assert body["operational_status"] is None
    assert detail.status_code == 200
    assert detail.json() == body
    for server_field in ("user_id", "facility_id", "owner_user_id"):
        assert server_field not in created.text
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        audit = await session.scalar(
            select(AuditEvent).where(AuditEvent.event_type == "asset_created")
        )
    assert audit is not None
    assert str(audit.asset_id) == body["id"]
    assert str(audit.area_id) == area["id"]


async def test_create_full_asset_normalizes_optional_profile(
    database_client: httpx.AsyncClient,
) -> None:
    headers = await _register(database_client, "asset-full@example.com")
    area = await _create_area(database_client, headers)
    response = await database_client.post(
        f"/api/v1/areas/{area['id']}/assets",
        headers=headers,
        json={
            "type": "  Bình chữa cháy  ",
            "subtype": "  CO2  ",
            "capacity_value": 5.5,
            "capacity_unit": "  kg  ",
            "manufacturer": "  FireSafe  ",
            "model": "  FS-55  ",
            "serial": "  SN-001  ",
            "location_text": "  Cạnh cửa thoát hiểm số 2  ",
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["type"] == "Bình chữa cháy"
    assert body["subtype"] == "CO2"
    assert body["capacity_value"] == 5.5
    assert body["capacity_unit"] == "kg"
    assert body["serial"] == "SN-001"
    assert body["location_text"] == "Cạnh cửa thoát hiểm số 2"


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"type": "   "},
        {"type": "Bình", "capacity_value": 5},
        {"type": "Bình", "capacity_unit": "kg"},
        {"type": "Bình", "capacity_value": 0, "capacity_unit": "kg"},
        {"type": "Bình", "source": "OCR"},
        {"type": "Bình", "area_id": "00000000-0000-0000-0000-000000000000"},
        {"type": "Bình", "lifecycle_state": "ARCHIVED"},
    ],
)
async def test_asset_create_rejects_invalid_or_server_controlled_fields(
    payload: dict[str, object],
    database_client: httpx.AsyncClient,
) -> None:
    headers = await _register(database_client, "asset-invalid@example.com")
    area = await _create_area(database_client, headers)
    response = await database_client.post(
        f"/api/v1/areas/{area['id']}/assets",
        headers=headers,
        json=payload,
    )
    assert response.status_code == 422


async def test_asset_list_uses_bounded_offset_pagination(
    database_client: httpx.AsyncClient,
) -> None:
    headers = await _register(database_client, "asset-page@example.com")
    area = await _create_area(database_client, headers)
    created_ids: list[str] = []
    asset_codes: list[str] = []
    for asset_type in ("Type A", "Type B", "Type C"):
        response = await database_client.post(
            f"/api/v1/areas/{area['id']}/assets",
            headers=headers,
            json={"type": asset_type},
        )
        created_ids.append(response.json()["id"])
        asset_codes.append(response.json()["asset_code"])

    page = await database_client.get(
        f"/api/v1/areas/{area['id']}/assets?limit=1&offset=1",
        headers=headers,
    )
    invalid_limit = await database_client.get(
        f"/api/v1/areas/{area['id']}/assets?limit=101",
        headers=headers,
    )

    assert page.status_code == 200
    assert [item["id"] for item in page.json()] == [created_ids[1]]
    assert len(set(asset_codes)) == 3
    assert invalid_limit.status_code == 422


async def test_asset_create_is_audited_and_atomic(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    headers = await _register(database_client, "asset-atomic@example.com")
    area = await _create_area(database_client, headers)
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        user = (await session.scalars(select(User))).one()

    def fail_audit_insert(*_: object) -> None:
        raise RuntimeError("forced asset audit failure")

    event.listen(AuditEvent, "before_insert", fail_audit_insert)
    try:
        async with session_factory() as session:
            with pytest.raises(RuntimeError, match="forced asset audit failure"):
                await create_asset(
                    area_id=UUID(area["id"]),
                    request=AssetCreateRequest(type="Bình lỗi"),
                    current_user=user,
                    session=session,
                )
    finally:
        event.remove(AuditEvent, "before_insert", fail_audit_insert)

    async with session_factory() as session:
        asset_count = await session.scalar(select(func.count()).select_from(Asset))
    assert asset_count == 0


async def test_cross_user_asset_operations_are_safe_not_found(
    database_client: httpx.AsyncClient,
) -> None:
    user_a = await _register(database_client, "asset-a@example.com")
    user_b = await _register(database_client, "asset-b@example.com")
    area = await _create_area(database_client, user_a)
    asset = await database_client.post(
        f"/api/v1/areas/{area['id']}/assets",
        headers=user_a,
        json={"type": "Bình A"},
    )
    asset_id = asset.json()["id"]

    responses = [
        await database_client.get(
            f"/api/v1/areas/{area['id']}/assets",
            headers=user_b,
        ),
        await database_client.post(
            f"/api/v1/areas/{area['id']}/assets",
            headers=user_b,
            json={"type": "Bình B"},
        ),
        await database_client.get(f"/api/v1/assets/{asset_id}", headers=user_b),
        await database_client.patch(
            f"/api/v1/assets/{asset_id}",
            headers=user_b,
            json={"base_revision": 1, "type": "Bình B"},
        ),
    ]

    assert {response.status_code for response in responses} == {404}
    assert responses[2].json() == responses[3].json()
    missing = await database_client.get(
        "/api/v1/assets/00000000-0000-0000-0000-000000000000",
        headers=user_b,
    )
    assert missing.status_code == 404
    assert missing.json() == responses[2].json()


async def test_asset_edit_increments_revision_and_creates_audit(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    headers = await _register(database_client, "asset-edit@example.com")
    area = await _create_area(database_client, headers)
    created = await database_client.post(
        f"/api/v1/areas/{area['id']}/assets",
        headers=headers,
        json={"type": "Bình cũ", "serial": " OLD "},
    )
    response = await database_client.patch(
        f"/api/v1/assets/{created.json()['id']}",
        headers=headers,
        json={
            "base_revision": 1,
            "type": "  Bình mới  ",
            "serial": "   ",
            "capacity_value": 5,
            "capacity_unit": " kg ",
        },
    )

    assert response.status_code == 200
    assert response.json()["revision"] == 2
    assert response.json()["type"] == "Bình mới"
    assert response.json()["serial"] is None
    assert response.json()["capacity_unit"] == "kg"
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        audit = await session.scalar(
            select(AuditEvent).where(AuditEvent.event_type == "asset_updated")
        )
    assert audit is not None
    assert str(audit.asset_id) == created.json()["id"]


async def test_asset_edit_rejects_stale_revision_and_immutable_fields(
    database_client: httpx.AsyncClient,
) -> None:
    headers = await _register(database_client, "asset-conflict@example.com")
    area = await _create_area(database_client, headers)
    created = await database_client.post(
        f"/api/v1/areas/{area['id']}/assets",
        headers=headers,
        json={"type": "Bình"},
    )
    asset_id = created.json()["id"]
    first = await database_client.patch(
        f"/api/v1/assets/{asset_id}",
        headers=headers,
        json={"base_revision": 1, "location_text": "Cửa số 1"},
    )
    stale = await database_client.patch(
        f"/api/v1/assets/{asset_id}",
        headers=headers,
        json={"base_revision": 1, "location_text": "Cửa số 2"},
    )
    immutable = await database_client.patch(
        f"/api/v1/assets/{asset_id}",
        headers=headers,
        json={"base_revision": 2, "asset_code": "AST-SPOOF"},
    )

    assert first.status_code == 200
    assert stale.status_code == 409
    assert stale.json()["error"]["code"] == "VERSION_CONFLICT"
    assert immutable.status_code == 422
    detail = await database_client.get(f"/api/v1/assets/{asset_id}", headers=headers)
    assert detail.json()["location_text"] == "Cửa số 1"
    assert detail.json()["revision"] == 2


async def test_asset_update_and_audit_are_atomic(
    database_client: httpx.AsyncClient,
    database_engine: AsyncEngine,
) -> None:
    headers = await _register(database_client, "asset-update-atomic@example.com")
    area = await _create_area(database_client, headers)
    created = await database_client.post(
        f"/api/v1/areas/{area['id']}/assets",
        headers=headers,
        json={"type": "Bình trước lỗi"},
    )
    asset_id = UUID(created.json()["id"])
    session_factory = async_sessionmaker(database_engine, expire_on_commit=False)
    async with session_factory() as session:
        user = (await session.scalars(select(User))).one()

    def fail_audit_insert(*_: object) -> None:
        raise RuntimeError("forced update audit failure")

    event.listen(AuditEvent, "before_insert", fail_audit_insert)
    try:
        async with session_factory() as session:
            with pytest.raises(RuntimeError, match="forced update audit failure"):
                await update_asset(
                    asset_id=asset_id,
                    request=AssetUpdateRequest(base_revision=1, type="Bình sau lỗi"),
                    current_user=user,
                    session=session,
                )
    finally:
        event.remove(AuditEvent, "before_insert", fail_audit_insert)

    async with session_factory() as session:
        asset = await session.get(Asset, asset_id)
        updated_audit_count = await session.scalar(
            select(func.count())
            .select_from(AuditEvent)
            .where(AuditEvent.event_type == "asset_updated")
        )
    assert asset is not None
    assert asset.type == "Bình trước lỗi"
    assert asset.revision == 1
    assert updated_audit_count == 0
