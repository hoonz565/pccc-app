"""Run local OCR date benchmarks without reading or writing application data."""

import argparse
import asyncio
import csv
import json
import mimetypes
import time
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from statistics import median
from typing import Any

from firesafe_api.ocr.errors import OcrError
from firesafe_api.ocr.image_validation import ImageValidator
from firesafe_api.ocr.paddle_recognizer import PaddleDateRecognizer
from firesafe_api.ocr.service import DateExtractionService


@dataclass(frozen=True)
class Sample:
    image: str
    raw_label: str
    normalized_date: str
    type: str
    quality: str
    physical_tag_id: str
    split: str


@dataclass
class Metrics:
    count: int = 0
    normalized_correct: int = 0
    exact_raw_correct: int = 0
    invalid_dates: int = 0
    failures: int = 0
    edit_distance: int = 0
    reference_characters: int = 0
    latency_ms: float = 0.0
    latencies_ms: list[float] = field(default_factory=list)

    def record(
        self,
        *,
        expected_raw: str,
        expected_normalized: str,
        actual_raw: str | None,
        actual_normalized: str | None,
        calendar_valid: bool,
        latency_ms: float,
        failed: bool,
    ) -> None:
        self.count += 1
        self.latency_ms += latency_ms
        self.latencies_ms.append(latency_ms)
        self.reference_characters += len(expected_raw)
        if failed:
            self.failures += 1
            self.edit_distance += len(expected_raw)
            return
        self.normalized_correct += int(actual_normalized == expected_normalized)
        self.exact_raw_correct += int(actual_raw == expected_raw)
        self.invalid_dates += int(not calendar_valid)
        self.edit_distance += _levenshtein(actual_raw or "", expected_raw)

    def as_dict(self) -> dict[str, int | float]:
        denominator = self.count or 1
        character_denominator = self.reference_characters or 1
        return {
            "samples": self.count,
            "normalized_date_accuracy": self.normalized_correct / denominator,
            "exact_ocr_string_accuracy": self.exact_raw_correct / denominator,
            "character_error_rate": self.edit_distance / character_denominator,
            "invalid_date_rate": self.invalid_dates / denominator,
            "failure_rate": self.failures / denominator,
            "mean_latency_ms": self.latency_ms / denominator,
            "median_latency_ms": median(self.latencies_ms)
            if self.latencies_ms
            else 0.0,
            "p95_latency_ms": _percentile(self.latencies_ms, 0.95),
        }


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--metadata",
        type=Path,
        default=Path("research/ocr/benchmark/metadata.csv"),
        help="CSV metadata path; image paths are resolved under --samples-dir",
    )
    parser.add_argument(
        "--samples-dir",
        type=Path,
        default=Path("research/ocr/samples"),
    )
    return parser.parse_args()


def _load_samples(path: Path) -> list[Sample]:
    if not path.is_file():
        raise SystemExit(
            f"No benchmark metadata found at {path}. Copy metadata.example.csv to "
            "metadata.csv and add local images under research/ocr/samples/."
        )
    with path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    required = {field.name for field in Sample.__dataclass_fields__.values()}
    if not rows or not required.issubset(rows[0]):
        raise SystemExit(
            f"Metadata must contain columns: {', '.join(sorted(required))}"
        )
    samples = [Sample(**{field: row[field] for field in required}) for row in rows]
    _validate_physical_tag_splits(samples)
    return samples


def _validate_physical_tag_splits(samples: list[Sample]) -> None:
    splits_by_tag: dict[str, set[str]] = defaultdict(set)
    for sample in samples:
        splits_by_tag[sample.physical_tag_id].add(sample.split)
    leaking = sorted(tag for tag, splits in splits_by_tag.items() if len(splits) > 1)
    if leaking:
        raise SystemExit(
            "Physical tag split leakage detected for: " + ", ".join(leaking)
        )


async def _run(samples: list[Sample], samples_dir: Path) -> dict[str, Any]:
    service = DateExtractionService(
        validator=ImageValidator(
            max_bytes=10 * 1024 * 1024,
            min_dimension=32,
            max_dimension=12_000,
            max_pixels=40_000_000,
            blur_warning_threshold=50.0,
        ),
        recognizer=PaddleDateRecognizer(),
    )
    overall = Metrics()
    by_type: dict[str, Metrics] = defaultdict(Metrics)
    by_quality: dict[str, Metrics] = defaultdict(Metrics)
    captures: list[dict[str, Any]] = []
    for sample in samples:
        requires_confirmation: bool
        error_type: str | None
        image_path = samples_dir / sample.image
        if not image_path.is_file():
            raise SystemExit(f"Missing benchmark image: {image_path}")
        mime_type = mimetypes.guess_type(image_path.name)[0]
        started_at = time.perf_counter()
        try:
            candidate = await service.extract(
                content=image_path.read_bytes(),
                mime_type=mime_type,
            )
            actual_raw = candidate.raw_text
            actual_normalized = candidate.normalized_date
            calendar_valid = candidate.validation.calendar_valid
            requires_confirmation = candidate.requires_confirmation
            failed = False
            error_type = None
        except OcrError as error:
            actual_raw = None
            actual_normalized = None
            calendar_valid = False
            requires_confirmation = False
            failed = True
            error_type = type(error).__name__
        latency_ms = (time.perf_counter() - started_at) * 1000
        for metrics in (overall, by_type[sample.type], by_quality[sample.quality]):
            metrics.record(
                expected_raw=sample.raw_label,
                expected_normalized=sample.normalized_date,
                actual_raw=actual_raw,
                actual_normalized=actual_normalized,
                calendar_valid=calendar_valid,
                latency_ms=latency_ms,
                failed=failed,
            )
        captures.append(
            {
                "image": sample.image,
                "physical_tag_id": sample.physical_tag_id,
                "type": sample.type,
                "quality": sample.quality,
                "expected_raw": sample.raw_label,
                "actual_raw": actual_raw,
                "expected_normalized": sample.normalized_date,
                "actual_normalized": actual_normalized,
                "calendar_valid": calendar_valid,
                "requires_confirmation": requires_confirmation,
                "latency_ms": latency_ms,
                "passed": (
                    not failed
                    and actual_normalized == sample.normalized_date
                    and calendar_valid
                    and requires_confirmation
                ),
                "error": error_type,
            }
        )
    return {
        "engine": service.engine_name,
        "capture_count": len(samples),
        "unique_physical_tag_count": len(
            {sample.physical_tag_id for sample in samples}
        ),
        "overall": overall.as_dict(),
        "captures": captures,
        "by_type": {key: metrics.as_dict() for key, metrics in sorted(by_type.items())},
        "by_quality": {
            key: metrics.as_dict() for key, metrics in sorted(by_quality.items())
        },
    }


def _percentile(values: list[float], quantile: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    position = (len(ordered) - 1) * quantile
    lower_index = int(position)
    upper_index = min(lower_index + 1, len(ordered) - 1)
    fraction = position - lower_index
    return (
        ordered[lower_index] + (ordered[upper_index] - ordered[lower_index]) * fraction
    )


def _levenshtein(value: str, reference: str) -> int:
    previous = list(range(len(reference) + 1))
    for value_index, value_character in enumerate(value, start=1):
        current = [value_index]
        for reference_index, reference_character in enumerate(reference, start=1):
            current.append(
                min(
                    current[-1] + 1,
                    previous[reference_index] + 1,
                    previous[reference_index - 1]
                    + int(value_character != reference_character),
                )
            )
        previous = current
    return previous[-1]


def main() -> None:
    arguments = _parse_args()
    samples = _load_samples(arguments.metadata)
    report = asyncio.run(_run(samples, arguments.samples_dir))
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
