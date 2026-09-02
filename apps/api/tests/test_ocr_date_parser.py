import pytest

from firesafe_api.ocr.date_parser import parse_date_candidate


@pytest.mark.parametrize(
    ("raw", "normalized"),
    [
        ("15-07-2026", "2026-07-15"),
        ("15 / 07 / 2026", "2026-07-15"),
        ("15.07.2026", "2026-07-15"),
        ("15 07 2026", "2026-07-15"),
        ("29-02-2024", "2024-02-29"),
    ],
)
def test_date_parser_accepts_supported_dates(raw: str, normalized: str) -> None:
    parsed = parse_date_candidate(raw)

    assert parsed is not None
    assert parsed.calendar_valid is True
    assert parsed.normalized_date == normalized


@pytest.mark.parametrize("raw", ["35-07-2026", "15-19-2026", "31-02-2026", "29-02-2025"])
def test_date_parser_flags_invalid_calendar_dates(raw: str) -> None:
    parsed = parse_date_candidate(raw)

    assert parsed is not None
    assert parsed.calendar_valid is False
    assert parsed.normalized_date is None
    assert "INVALID_CALENDAR_DATE" in parsed.warnings


def test_date_parser_records_bounded_ocr_correction() -> None:
    parsed = parse_date_candidate("Ngày thực hiện: 15-O7-2026")

    assert parsed is not None
    assert parsed.raw_text == "15-O7-2026"
    assert parsed.corrected_text == "15-07-2026"
    assert parsed.normalized_date == "2026-07-15"
    assert [correction.kind for correction in parsed.corrections] == ["O_TO_ZERO"]


@pytest.mark.parametrize("raw", ["1.5.07.2026", ".1.5...7..2026"])
def test_date_parser_joins_observed_split_day_artifact(raw: str) -> None:
    parsed = parse_date_candidate(raw)

    assert parsed is not None
    assert parsed.raw_text in {"1.5.07.2026", "1.5...7..2026"}
    assert parsed.corrected_text == "15-07-2026"
    assert parsed.normalized_date == "2026-07-15"
    assert parsed.calendar_valid is True
    assert [correction.kind for correction in parsed.corrections] == ["SPLIT_DAY_DIGITS_JOINED"]


@pytest.mark.parametrize(
    "raw",
    ["version 4.5.07.2026", "1.5.07.26", "1.5.123.2026"],
)
def test_date_parser_rejects_unbounded_split_day_shapes(raw: str) -> None:
    assert parse_date_candidate(raw) is None


def test_date_parser_does_not_treat_phone_number_as_date() -> None:
    assert parse_date_candidate("0963901357") is None
