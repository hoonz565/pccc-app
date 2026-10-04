import asyncio
from typing import Literal

from firesafe_api.ocr.candidate_selector import select_date_candidate
from firesafe_api.ocr.errors import NoDateCandidateError, NoTextFoundError
from firesafe_api.ocr.image_validation import ImageValidator
from firesafe_api.ocr.schemas import (
    BoundingBoxResponse,
    DateCorrectionResponse,
    ImageQualityResponse,
    OcrAnchorResponse,
    OcrConfidenceResponse,
    OcrDateCandidateResponse,
    OcrProvenanceResponse,
    OcrValidationResponse,
)
from firesafe_api.ocr.types import BoundingBox, CandidateSelection, DateRecognizer


class DateExtractionService:
    def __init__(self, *, validator: ImageValidator, recognizer: DateRecognizer) -> None:
        self._validator = validator
        self._recognizer = recognizer

    @property
    def engine_name(self) -> str:
        return self._recognizer.name

    async def extract(self, *, content: bytes, mime_type: str | None) -> OcrDateCandidateResponse:
        image = self._validator.validate(content, mime_type)
        boxes = await asyncio.to_thread(
            self._recognizer.recognize,
            image.content,
            image.mime_type,
        )
        if not boxes:
            raise NoTextFoundError
        selection = select_date_candidate(boxes)
        if selection is None:
            raise NoDateCandidateError

        confidence_level = _confidence_level(selection, bool(image.warnings))
        parsed = selection.parsed_date
        anchor = selection.anchor
        return OcrDateCandidateResponse(
            raw_text=parsed.raw_text,
            corrected_text=parsed.corrected_text,
            normalized_date=parsed.normalized_date,
            candidate_bbox=_bbox_response(selection.box.bbox),
            confidence=OcrConfidenceResponse(
                level=confidence_level,
                ocr_score=_bounded_score(selection.box.confidence),
                anchor_score=anchor.score if anchor is not None else None,
                layout_score=_bounded_score(selection.layout_score),
            ),
            anchor=(
                OcrAnchorResponse(
                    text=anchor.box.text,
                    configured_phrase=anchor.configured_phrase,
                    bbox=_bbox_response(anchor.box.bbox),
                )
                if anchor is not None
                else None
            ),
            validation=OcrValidationResponse(
                calendar_valid=parsed.calendar_valid,
                warnings=list(parsed.warnings),
            ),
            image_quality=ImageQualityResponse(
                width=image.width,
                height=image.height,
                sharpness_score=image.sharpness_score,
                warnings=list(image.warnings),
            ),
            provenance=OcrProvenanceResponse(
                engine=self._recognizer.name,
                selection_strategy=("fallback" if selection.used_fallback else "anchor_associated"),
                corrections=[
                    DateCorrectionResponse(
                        position=correction.position,
                        type=correction.kind,
                        original=correction.original,
                        replacement=correction.replacement,
                    )
                    for correction in parsed.corrections
                ],
            ),
        )


def _confidence_level(
    selection: CandidateSelection,
    has_image_warning: bool,
) -> Literal["high", "medium", "low"]:
    parsed = selection.parsed_date
    anchor = selection.anchor
    if selection.used_fallback or not parsed.calendar_valid:
        return "low"
    if (
        anchor is not None
        and anchor.score >= 0.95
        and selection.layout_score >= 0.75
        and selection.box.confidence >= 0.8
        and not parsed.corrections
        and not has_image_warning
    ):
        return "high"
    return "medium"


def _bbox_response(bbox: BoundingBox | None) -> BoundingBoxResponse | None:
    if bbox is None:
        return None
    return BoundingBoxResponse(
        x_min=bbox.x_min,
        y_min=bbox.y_min,
        x_max=bbox.x_max,
        y_max=bbox.y_max,
    )


def _bounded_score(value: float) -> float:
    return min(1.0, max(0.0, value))
