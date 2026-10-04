import math

from firesafe_api.ocr.anchors import find_anchor
from firesafe_api.ocr.date_parser import parse_date_candidate
from firesafe_api.ocr.types import AnchorMatch, BoundingBox, CandidateSelection, OCRTextBox


def select_date_candidate(boxes: list[OCRTextBox]) -> CandidateSelection | None:
    anchor = find_anchor(boxes)
    candidates = [
        (index, box, parsed)
        for index, box in enumerate(boxes)
        if (parsed := parse_date_candidate(box.text)) is not None
    ]
    if not candidates:
        return None

    if anchor is None:
        _, box, parsed = max(
            candidates,
            key=lambda candidate: (
                candidate[2].calendar_valid,
                _bounded_score(candidate[1].confidence),
            ),
        )
        return CandidateSelection(
            box=box,
            parsed_date=parsed,
            anchor=None,
            layout_score=0.25,
            used_fallback=True,
        )

    index, box, parsed = max(
        candidates,
        key=lambda candidate: (
            _layout_score(anchor, candidate[0], candidate[1]),
            candidate[2].calendar_valid,
            _bounded_score(candidate[1].confidence),
        ),
    )
    return CandidateSelection(
        box=box,
        parsed_date=parsed,
        anchor=anchor,
        layout_score=_layout_score(anchor, index, box),
        used_fallback=False,
    )


def _layout_score(anchor: AnchorMatch, candidate_index: int, candidate: OCRTextBox) -> float:
    if candidate_index == anchor.box_index:
        return 1.0
    if anchor.box.bbox is None or candidate.bbox is None:
        distance = candidate_index - anchor.box_index
        if 0 < distance <= 2:
            return 0.65
        return 0.3
    return _geometric_layout_score(anchor.box.bbox, candidate.bbox)


def _geometric_layout_score(anchor: BoundingBox, candidate: BoundingBox) -> float:
    minimum_height = max(1.0, min(anchor.height, candidate.height))
    overlap_y = max(0.0, min(anchor.y_max, candidate.y_max) - max(anchor.y_min, candidate.y_min))
    same_row = overlap_y / minimum_height >= 0.5
    scale = max(1.0, anchor.height, candidate.height)

    if same_row and candidate.center_x >= anchor.center_x:
        right_gap = max(0.0, candidate.x_min - anchor.x_max)
        return max(0.75, 1.0 - right_gap / (scale * 12))
    if same_row:
        horizontal_gap = max(0.0, anchor.x_min - candidate.x_max)
        return max(0.55, 0.8 - horizontal_gap / (scale * 12))

    overlap_x = max(0.0, min(anchor.x_max, candidate.x_max) - max(anchor.x_min, candidate.x_min))
    minimum_width = max(1.0, min(anchor.width, candidate.width))
    below_gap = candidate.y_min - anchor.y_max
    if overlap_x / minimum_width >= 0.25 and 0 <= below_gap <= scale * 4:
        return max(0.6, 0.8 - below_gap / (scale * 20))

    center_distance = math.hypot(
        candidate.center_x - anchor.center_x,
        candidate.center_y - anchor.center_y,
    )
    return max(0.2, 0.55 - center_distance / (scale * 30))


def _bounded_score(value: float) -> float:
    return min(1.0, max(0.0, value))
