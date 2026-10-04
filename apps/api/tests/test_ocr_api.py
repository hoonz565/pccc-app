from collections.abc import AsyncIterator
from io import BytesIO
from typing import cast

import httpx
import pytest
import pytest_asyncio
from fastapi import FastAPI
from PIL import Image

from firesafe_api.auth.dependencies import get_current_user
from firesafe_api.core.config import get_settings
from firesafe_api.main import create_app, lifespan
from firesafe_api.ocr.router import get_date_recognizer
from firesafe_api.ocr.types import BoundingBox, OCRTextBox
from firesafe_api.users.models import User


class FakeRecognizer:
    def __init__(self, boxes: list[OCRTextBox]) -> None:
        self.boxes = boxes

    @property
    def name(self) -> str:
        return "fake-ocr"

    def recognize(self, image: bytes, mime_type: str) -> list[OCRTextBox]:
        assert image
        assert mime_type in {"image/jpeg", "image/png", "image/webp"}
        return self.boxes


def _authenticated_user() -> User:
    return cast(User, object())


@pytest_asyncio.fixture
async def ocr_app_client(
    monkeypatch: pytest.MonkeyPatch,
) -> AsyncIterator[tuple[FastAPI, httpx.AsyncClient]]:
    monkeypatch.setenv("APP_ENV", "test")
    monkeypatch.setenv(
        "AUTH_SIGNING_SECRET",
        "test-only-signing-secret-with-at-least-32-characters",
    )
    monkeypatch.setenv(
        "DATABASE_URL",
        "postgresql+psycopg://firesafe:firesafe_dev_password@127.0.0.1:1/firesafe",
    )
    get_settings.cache_clear()
    application = create_app()
    application.dependency_overrides[get_current_user] = _authenticated_user
    application.dependency_overrides[get_date_recognizer] = lambda: FakeRecognizer([])
    async with lifespan(application):
        transport = httpx.ASGITransport(app=application)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            yield application, client
    get_settings.cache_clear()


def _png_bytes() -> bytes:
    output = BytesIO()
    Image.new("RGB", (64, 64), color="white").save(output, format="PNG")
    return output.getvalue()


async def test_ocr_endpoint_requires_authentication(
    client: httpx.AsyncClient,
) -> None:
    response = await client.post(
        "/api/v1/ocr/date-extractions",
        files={"image": ("label.png", _png_bytes(), "image/png")},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHENTICATED"


async def test_ocr_endpoint_rejects_unsupported_mime(
    ocr_app_client: tuple[FastAPI, httpx.AsyncClient],
) -> None:
    _, client = ocr_app_client
    response = await client.post(
        "/api/v1/ocr/date-extractions",
        files={"image": ("label.gif", b"GIF89a", "image/gif")},
    )

    assert response.status_code == 415
    assert response.json()["error"]["code"] == "UNSUPPORTED_IMAGE_TYPE"


async def test_ocr_endpoint_rejects_corrupted_image(
    ocr_app_client: tuple[FastAPI, httpx.AsyncClient],
) -> None:
    _, client = ocr_app_client
    response = await client.post(
        "/api/v1/ocr/date-extractions",
        files={"image": ("label.png", b"not-an-image", "image/png")},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "IMAGE_DECODING_FAILED"


async def test_ocr_endpoint_maps_no_text_result(
    ocr_app_client: tuple[FastAPI, httpx.AsyncClient],
) -> None:
    _, client = ocr_app_client
    response = await client.post(
        "/api/v1/ocr/date-extractions",
        files={"image": ("label.png", _png_bytes(), "image/png")},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "OCR_NO_TEXT"


async def test_ocr_endpoint_maps_no_plausible_date(
    ocr_app_client: tuple[FastAPI, httpx.AsyncClient],
) -> None:
    application, client = ocr_app_client
    application.dependency_overrides[get_date_recognizer] = lambda: FakeRecognizer(
        [OCRTextBox(text="Ngày thực hiện", confidence=0.96)]
    )
    response = await client.post(
        "/api/v1/ocr/date-extractions",
        files={"image": ("label.png", _png_bytes(), "image/png")},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "OCR_NO_DATE_CANDIDATE"


async def test_ocr_endpoint_returns_structured_confirmation_required_candidate(
    ocr_app_client: tuple[FastAPI, httpx.AsyncClient],
) -> None:
    application, client = ocr_app_client
    application.dependency_overrides[get_date_recognizer] = lambda: FakeRecognizer(
        [
            OCRTextBox(
                text="Ngày thực hiện",
                confidence=0.96,
                bbox=BoundingBox(10, 10, 160, 40),
            ),
            OCRTextBox(
                text="15 - 07 - 2026",
                confidence=0.94,
                bbox=BoundingBox(170, 10, 310, 40),
            ),
        ]
    )
    response = await client.post(
        "/api/v1/ocr/date-extractions",
        files={"image": ("label.png", _png_bytes(), "image/png")},
        data={"expected_field_type": "inspection_date"},
    )

    assert response.status_code == 200
    candidate = response.json()
    assert candidate["raw_text"] == "15 - 07 - 2026"
    assert candidate["corrected_text"] == "15-07-2026"
    assert candidate["normalized_date"] == "2026-07-15"
    assert candidate["validation"]["calendar_valid"] is True
    assert candidate["provenance"]["selection_strategy"] == "anchor_associated"
    assert candidate["requires_confirmation"] is True
