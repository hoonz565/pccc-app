from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class BoundingBox:
    x_min: float
    y_min: float
    x_max: float
    y_max: float

    @property
    def width(self) -> float:
        return max(0.0, self.x_max - self.x_min)

    @property
    def height(self) -> float:
        return max(0.0, self.y_max - self.y_min)

    @property
    def center_x(self) -> float:
        return (self.x_min + self.x_max) / 2

    @property
    def center_y(self) -> float:
        return (self.y_min + self.y_max) / 2


@dataclass(frozen=True)
class OCRTextBox:
    text: str
    confidence: float
    bbox: BoundingBox | None = None


@dataclass(frozen=True)
class DateCorrection:
    position: int
    kind: str
    original: str
    replacement: str


@dataclass(frozen=True)
class ParsedDate:
    raw_text: str
    corrected_text: str
    day: int
    month: int
    year: int
    normalized_date: str | None
    calendar_valid: bool
    warnings: tuple[str, ...]
    corrections: tuple[DateCorrection, ...]


@dataclass(frozen=True)
class AnchorDefinition:
    field_type: str
    phrases: tuple[str, ...]


@dataclass(frozen=True)
class AnchorMatch:
    box: OCRTextBox
    box_index: int
    configured_phrase: str
    score: float


@dataclass(frozen=True)
class CandidateSelection:
    box: OCRTextBox
    parsed_date: ParsedDate
    anchor: AnchorMatch | None
    layout_score: float
    used_fallback: bool


@dataclass(frozen=True)
class ValidatedImage:
    content: bytes
    mime_type: str
    width: int
    height: int
    sharpness_score: float
    warnings: tuple[str, ...]


class DateRecognizer(Protocol):
    @property
    def name(self) -> str: ...

    def recognize(self, image: bytes, mime_type: str) -> list[OCRTextBox]: ...
