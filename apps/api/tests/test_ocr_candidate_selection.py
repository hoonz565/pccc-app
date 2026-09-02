import pytest

from firesafe_api.ocr.anchors import find_anchor, normalize_anchor_text
from firesafe_api.ocr.candidate_selector import select_date_candidate
from firesafe_api.ocr.types import BoundingBox, OCRTextBox


@pytest.mark.parametrize(
    "value",
    ["Ngày thực hiện", "NGÀY THỰC HIỆN", "ngày   thực hiện", "Ngay thuc hien"],
)
def test_anchor_normalization_matches_supported_vietnamese_variants(value: str) -> None:
    assert normalize_anchor_text(value) == "ngay thuc hien"
    match = find_anchor([OCRTextBox(text=value, confidence=0.9)])
    assert match is not None
    assert match.configured_phrase == "ngày thực hiện"


def test_anchor_matches_bounded_observed_ocr_alias() -> None:
    match = find_anchor([OCRTextBox(text="Ngay thye hin:", confidence=0.97)])

    assert match is not None
    assert match.configured_phrase == "ngày thực hiện"
    assert match.score == 0.9


@pytest.mark.parametrize(
    "value",
    ["Có giá trị: 06 Tháng", "PHIẾU BẢO HÀNH", "c hen", "thực hiện bảo trì"],
)
def test_anchor_does_not_match_unrelated_or_severely_degraded_text(value: str) -> None:
    assert find_anchor([OCRTextBox(text=value, confidence=0.99)]) is None


def test_candidate_selection_uses_anchor_and_layout_not_phone_number() -> None:
    boxes = [
        OCRTextBox(
            text="Ngày thực hiện",
            confidence=0.96,
            bbox=BoundingBox(10, 10, 160, 40),
        ),
        OCRTextBox(
            text="15-07-2026",
            confidence=0.94,
            bbox=BoundingBox(170, 10, 280, 40),
        ),
        OCRTextBox(
            text="0963901357",
            confidence=0.99,
            bbox=BoundingBox(10, 80, 200, 110),
        ),
    ]

    selection = select_date_candidate(boxes)

    assert selection is not None
    assert selection.box.text == "15-07-2026"
    assert selection.anchor is not None
    assert selection.used_fallback is False
    assert selection.layout_score >= 0.75


def test_fallback_candidate_is_explicitly_lower_provenance() -> None:
    selection = select_date_candidate([OCRTextBox(text="15.07.2026", confidence=0.99)])

    assert selection is not None
    assert selection.used_fallback is True
    assert selection.anchor is None
    assert selection.layout_score == 0.25
