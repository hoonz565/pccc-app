from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class BoundingBoxResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    x_min: float
    y_min: float
    x_max: float
    y_max: float


class DateCorrectionResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    position: int = Field(ge=0)
    type: str
    original: str
    replacement: str


class OcrConfidenceResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    level: Literal["high", "medium", "low"]
    ocr_score: float = Field(ge=0, le=1)
    anchor_score: float | None = Field(default=None, ge=0, le=1)
    layout_score: float = Field(ge=0, le=1)


class OcrAnchorResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: str
    configured_phrase: str
    bbox: BoundingBoxResponse | None


class OcrValidationResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    calendar_valid: bool
    warnings: list[str]


class ImageQualityResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    width: int = Field(ge=1)
    height: int = Field(ge=1)
    sharpness_score: float = Field(ge=0)
    warnings: list[str]


class OcrProvenanceResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    engine: str
    selection_strategy: Literal["anchor_associated", "fallback"]
    corrections: list[DateCorrectionResponse]


class OcrDateCandidateResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: Literal["candidate"] = "candidate"
    field_type: Literal["inspection_date"] = "inspection_date"
    raw_text: str
    corrected_text: str
    normalized_date: str | None
    recognition_type: Literal["printed_or_stamped"] = "printed_or_stamped"
    candidate_bbox: BoundingBoxResponse | None
    confidence: OcrConfidenceResponse
    anchor: OcrAnchorResponse | None
    validation: OcrValidationResponse
    image_quality: ImageQualityResponse
    provenance: OcrProvenanceResponse
    requires_confirmation: Literal[True] = True
