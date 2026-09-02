import importlib
from collections.abc import Callable, Iterable, Mapping, Sequence
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Lock
from typing import Protocol, cast

from firesafe_api.ocr.errors import OcrDependencyUnavailableError, OcrEngineError
from firesafe_api.ocr.types import BoundingBox, OCRTextBox

_SUFFIX_BY_MIME = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}


class _PaddlePipeline(Protocol):
    def predict(self, image_path: str) -> object: ...


class PaddleDateRecognizer:
    """Lazy PP-OCRv5 adapter that keeps Paddle-specific results at the boundary."""

    def __init__(self) -> None:
        self._pipeline: object | None = None
        self._lock = Lock()

    @property
    def name(self) -> str:
        return "paddleocr-pp-ocrv5"

    def recognize(self, image: bytes, mime_type: str) -> list[OCRTextBox]:
        suffix = _SUFFIX_BY_MIME.get(mime_type)
        if suffix is None:
            raise OcrEngineError
        with TemporaryDirectory(prefix="firesafe-ocr-") as directory:
            image_path = Path(directory) / f"input{suffix}"
            image_path.write_bytes(image)
            try:
                with self._lock:
                    pipeline = cast(_PaddlePipeline, self._get_pipeline())
                    raw_results = pipeline.predict(str(image_path))
                    return self._translate_results(raw_results)
            except OcrDependencyUnavailableError:
                raise
            except Exception as error:
                raise OcrEngineError from error

    def _get_pipeline(self) -> object:
        if self._pipeline is not None:
            return self._pipeline
        try:
            module = importlib.import_module("paddleocr")
            factory = cast(Callable[..., object], vars(module)["PaddleOCR"])
            self._pipeline = factory(
                ocr_version="PP-OCRv5",
                lang="en",
                use_doc_orientation_classify=False,
                use_doc_unwarping=False,
                use_textline_orientation=False,
                enable_mkldnn=False,
                engine="paddle",
            )
        except Exception as error:
            raise OcrDependencyUnavailableError from error
        return self._pipeline

    @classmethod
    def _translate_results(cls, raw_results: object) -> list[OCRTextBox]:
        if not isinstance(raw_results, Iterable):
            raise OcrEngineError
        boxes: list[OCRTextBox] = []
        for raw_result in raw_results:
            payload = cls._result_payload(raw_result)
            texts = cls._as_sequence(payload.get("rec_texts"))
            scores = cls._as_sequence(payload.get("rec_scores"))
            polygons = cls._as_sequence(payload.get("rec_polys"))
            for index, raw_text in enumerate(texts):
                if not isinstance(raw_text, str) or not raw_text.strip():
                    continue
                score = cls._score_at(scores, index)
                bbox = cls._bbox_at(polygons, index)
                boxes.append(OCRTextBox(text=raw_text, confidence=score, bbox=bbox))
        return boxes

    @classmethod
    def _result_payload(cls, raw_result: object) -> Mapping[str, object]:
        value: object = raw_result
        if not isinstance(value, Mapping):
            json_value = getattr(value, "json", None)
            value = json_value() if callable(json_value) else json_value
        if not isinstance(value, Mapping):
            raise OcrEngineError
        payload = value.get("res", value)
        if not isinstance(payload, Mapping):
            raise OcrEngineError
        return cast(Mapping[str, object], payload)

    @staticmethod
    def _as_sequence(value: object) -> Sequence[object]:
        to_list = getattr(value, "tolist", None)
        if callable(to_list):
            value = to_list()
        if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
            return cast(Sequence[object], value)
        return ()

    @staticmethod
    def _score_at(scores: Sequence[object], index: int) -> float:
        if index >= len(scores):
            return 0.0
        score = scores[index]
        if not isinstance(score, (int, float)):
            return 0.0
        return min(1.0, max(0.0, float(score)))

    @classmethod
    def _bbox_at(cls, polygons: Sequence[object], index: int) -> BoundingBox | None:
        if index >= len(polygons):
            return None
        points = cls._as_sequence(polygons[index])
        coordinates: list[tuple[float, float]] = []
        for point in points:
            pair = cls._as_sequence(point)
            if (
                len(pair) >= 2
                and isinstance(pair[0], (int, float))
                and isinstance(pair[1], (int, float))
            ):
                coordinates.append((float(pair[0]), float(pair[1])))
        if not coordinates:
            return None
        return BoundingBox(
            x_min=min(point[0] for point in coordinates),
            y_min=min(point[1] for point in coordinates),
            x_max=max(point[0] for point in coordinates),
            y_max=max(point[1] for point in coordinates),
        )
