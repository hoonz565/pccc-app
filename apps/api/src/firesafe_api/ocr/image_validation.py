from io import BytesIO

from PIL import Image, ImageFilter, ImageStat, UnidentifiedImageError

from firesafe_api.ocr.errors import (
    ImageDecodingError,
    ImageDimensionsError,
    ImageTooLargeError,
    UnsupportedImageTypeError,
)
from firesafe_api.ocr.types import ValidatedImage

_SUPPORTED_FORMATS = {
    "image/jpeg": "JPEG",
    "image/png": "PNG",
    "image/webp": "WEBP",
}


class ImageValidator:
    def __init__(
        self,
        *,
        max_bytes: int,
        min_dimension: int,
        max_dimension: int,
        max_pixels: int,
        blur_warning_threshold: float,
    ) -> None:
        self._max_bytes = max_bytes
        self._min_dimension = min_dimension
        self._max_dimension = max_dimension
        self._max_pixels = max_pixels
        self._blur_warning_threshold = blur_warning_threshold

    def validate(self, content: bytes, mime_type: str | None) -> ValidatedImage:
        normalized_mime = (mime_type or "").split(";", maxsplit=1)[0].strip().lower()
        expected_format = _SUPPORTED_FORMATS.get(normalized_mime)
        if expected_format is None:
            raise UnsupportedImageTypeError
        if not content:
            raise ImageDecodingError
        if len(content) > self._max_bytes:
            raise ImageTooLargeError

        try:
            with Image.open(BytesIO(content)) as image:
                detected_format = image.format
                width, height = image.size
                image.verify()
            if detected_format != expected_format:
                raise ImageDecodingError
            self._validate_dimensions(width, height)
            with Image.open(BytesIO(content)) as image:
                image.load()
                sharpness_score = self._sharpness_score(image)
        except (
            UnidentifiedImageError,
            OSError,
            SyntaxError,
            Image.DecompressionBombError,
        ) as error:
            raise ImageDecodingError from error

        warnings: tuple[str, ...] = (
            ("IMAGE_MAY_BE_BLURRY",) if sharpness_score < self._blur_warning_threshold else ()
        )
        return ValidatedImage(
            content=content,
            mime_type=normalized_mime,
            width=width,
            height=height,
            sharpness_score=round(sharpness_score, 2),
            warnings=warnings,
        )

    def _validate_dimensions(self, width: int, height: int) -> None:
        if (
            width < self._min_dimension
            or height < self._min_dimension
            or width > self._max_dimension
            or height > self._max_dimension
            or width * height > self._max_pixels
        ):
            raise ImageDimensionsError

    @staticmethod
    def _sharpness_score(image: Image.Image) -> float:
        sample = image.convert("L")
        sample.thumbnail((512, 512), Image.Resampling.LANCZOS)
        edges = sample.filter(ImageFilter.FIND_EDGES)
        return float(ImageStat.Stat(edges).var[0])
