import asyncio
import os
from pathlib import Path

import pytest

from firesafe_api.ocr.image_validation import ImageValidator
from firesafe_api.ocr.paddle_recognizer import PaddleDateRecognizer
from firesafe_api.ocr.service import DateExtractionService


@pytest.mark.integration
def test_paddle_recognizer_with_opt_in_local_image() -> None:
    if os.getenv("RUN_OCR_INTEGRATION") != "1":
        pytest.skip("Set RUN_OCR_INTEGRATION=1 and OCR_TEST_IMAGE to run PaddleOCR")
    image_value = os.getenv("OCR_TEST_IMAGE")
    if image_value is None:
        pytest.fail("OCR_TEST_IMAGE must point to a local JPEG, PNG, or WebP image")
    image_path = Path(image_value)
    mime_type = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }.get(image_path.suffix.lower())
    if mime_type is None:
        pytest.fail("OCR_TEST_IMAGE must be JPEG, PNG, or WebP")

    recognizer = PaddleDateRecognizer()
    expected_date = os.getenv("OCR_EXPECTED_DATE")
    if expected_date is None:
        assert recognizer.recognize(image_path.read_bytes(), mime_type)
        return

    service = DateExtractionService(
        validator=ImageValidator(
            max_bytes=10 * 1024 * 1024,
            min_dimension=32,
            max_dimension=12_000,
            max_pixels=40_000_000,
            blur_warning_threshold=50.0,
        ),
        recognizer=recognizer,
    )
    candidate = asyncio.run(service.extract(content=image_path.read_bytes(), mime_type=mime_type))
    assert candidate.normalized_date == expected_date
    assert candidate.requires_confirmation is True
