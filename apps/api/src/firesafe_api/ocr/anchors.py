import re
import unicodedata

from firesafe_api.ocr.types import AnchorDefinition, AnchorMatch, OCRTextBox

DEFAULT_DATE_ANCHORS = AnchorDefinition(
    field_type="inspection_date",
    phrases=(
        "ngày thực hiện",
        "ngày kiểm tra",
        "ngày kiểm định",
        "ngày bảo trì",
        "ngày bảo dưỡng",
    ),
)

_CONTROLLED_OCR_ALIASES = {
    "ngay thye hin": "ngày thực hiện",
}


def normalize_anchor_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value.casefold()).replace("đ", "d")
    without_marks = "".join(
        character for character in normalized if not unicodedata.combining(character)
    )
    return re.sub(r"\s+", " ", without_marks).strip()


def find_anchor(
    boxes: list[OCRTextBox],
    definition: AnchorDefinition = DEFAULT_DATE_ANCHORS,
) -> AnchorMatch | None:
    configured = [(phrase, normalize_anchor_text(phrase)) for phrase in definition.phrases]
    best: AnchorMatch | None = None
    for box_index, box in enumerate(boxes):
        normalized_box = normalize_anchor_text(box.text)
        alias_candidate = normalized_box.strip(" :;,.")
        for phrase, normalized_phrase in configured:
            score = 0.0
            if normalized_box == normalized_phrase:
                score = 1.0
            elif normalized_phrase in normalized_box:
                score = 0.95
            elif _CONTROLLED_OCR_ALIASES.get(alias_candidate) == phrase:
                score = 0.9
            if score and (best is None or score > best.score):
                best = AnchorMatch(
                    box=box,
                    box_index=box_index,
                    configured_phrase=phrase,
                    score=score,
                )
    return best
