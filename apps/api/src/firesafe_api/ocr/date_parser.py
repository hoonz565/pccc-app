import re
from datetime import date

from firesafe_api.ocr.types import DateCorrection, ParsedDate

_DATE_PATTERN = re.compile(
    r"(?<![0-9A-Za-z])"
    r"(?P<day>[0-9Oo]{1,2})"
    r"(?:\s*[-/.]\s*|\s+)"
    r"(?P<month>[0-9Oo]{1,2})"
    r"(?:\s*[-/.]\s*|\s+)"
    r"(?P<year>[0-9Oo]{4}|[0-9Oo]{2})"
    r"(?![0-9A-Za-z])"
)

_SPLIT_DAY_PATTERN = re.compile(
    r"(?<![0-9A-Za-z])"
    r"(?P<day_tens>[0-3Oo])\s*\.\s*(?P<day_ones>[0-9Oo])"
    r"(?:\s*[-/.]\s*)+"
    r"(?P<month>[0-9Oo]{1,2})"
    r"(?:\s*[-/.]\s*)+"
    r"(?P<year>[0-9Oo]{4})"
    r"(?![0-9A-Za-z])"
)

_FOUR_NUMERIC_GROUP_PATTERN = re.compile(
    r"(?<![0-9A-Za-z])"
    r"[0-9Oo]{1,2}(?:\s*[-/.]\s*)+"
    r"[0-9Oo]{1,2}(?:\s*[-/.]\s*)+"
    r"[0-9Oo]{1,3}(?:\s*[-/.]\s*)+"
    r"[0-9Oo]{2,4}"
    r"(?![0-9A-Za-z])"
)


def parse_date_candidate(text: str) -> ParsedDate | None:
    """Parse a bounded day-first OCR date without silently guessing its meaning."""
    split_day_match = _SPLIT_DAY_PATTERN.search(text)
    if split_day_match is not None:
        return _parse_match(split_day_match, split_day=True)
    if _FOUR_NUMERIC_GROUP_PATTERN.search(text) is not None:
        return None

    match = _DATE_PATTERN.search(text)
    if match is None:
        return None

    return _parse_match(match, split_day=False)


def _parse_match(match: re.Match[str], *, split_day: bool) -> ParsedDate | None:
    pattern = _SPLIT_DAY_PATTERN if split_day else _DATE_PATTERN

    raw_text = match.group(0)
    corrections: list[DateCorrection] = []
    corrected_characters: list[str] = []
    for position, character in enumerate(raw_text):
        if character in {"O", "o"}:
            corrected_characters.append("0")
            corrections.append(
                DateCorrection(
                    position=position,
                    kind="O_TO_ZERO",
                    original=character,
                    replacement="0",
                )
            )
        else:
            corrected_characters.append(character)

    corrected_match = pattern.fullmatch("".join(corrected_characters))
    if corrected_match is None:
        return None

    if split_day:
        day = int(corrected_match.group("day_tens") + corrected_match.group("day_ones"))
        split_value = match.group("day_tens") + "." + match.group("day_ones")
        corrections.append(
            DateCorrection(
                position=raw_text.index("."),
                kind="SPLIT_DAY_DIGITS_JOINED",
                original=split_value,
                replacement=f"{day:02d}",
            )
        )
    else:
        day = int(corrected_match.group("day"))
    month = int(corrected_match.group("month"))
    raw_year = corrected_match.group("year")
    warnings: list[str] = []
    if len(raw_year) == 2:
        two_digit_year = int(raw_year)
        year = 2000 + two_digit_year if two_digit_year <= 69 else 1900 + two_digit_year
        warnings.append("TWO_DIGIT_YEAR_EXPANDED")
    else:
        year = int(raw_year)

    corrected_text = f"{day:02d}-{month:02d}-{year:04d}"
    try:
        normalized_date = date(year, month, day).isoformat()
        calendar_valid = True
    except ValueError:
        normalized_date = None
        calendar_valid = False
        warnings.append("INVALID_CALENDAR_DATE")

    return ParsedDate(
        raw_text=raw_text,
        corrected_text=corrected_text,
        day=day,
        month=month,
        year=year,
        normalized_date=normalized_date,
        calendar_valid=calendar_valid,
        warnings=tuple(warnings),
        corrections=tuple(corrections),
    )
