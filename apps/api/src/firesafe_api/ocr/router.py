import logging
import time
from functools import lru_cache
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile

from firesafe_api.api.errors import ApiError
from firesafe_api.auth.dependencies import get_current_user
from firesafe_api.core.config import Settings, get_settings
from firesafe_api.ocr.errors import (
    ImageDecodingError,
    ImageDimensionsError,
    ImageTooLargeError,
    NoDateCandidateError,
    NoTextFoundError,
    OcrDependencyUnavailableError,
    OcrEngineError,
    UnsupportedImageTypeError,
)
from firesafe_api.ocr.image_validation import ImageValidator
from firesafe_api.ocr.paddle_recognizer import PaddleDateRecognizer
from firesafe_api.ocr.schemas import OcrDateCandidateResponse
from firesafe_api.ocr.service import DateExtractionService
from firesafe_api.ocr.types import DateRecognizer
from firesafe_api.users.models import User

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/ocr", tags=["ocr"])


@lru_cache
def _paddle_recognizer() -> PaddleDateRecognizer:
    return PaddleDateRecognizer()


def get_date_recognizer(
    settings: Annotated[Settings, Depends(get_settings)],
) -> DateRecognizer:
    if settings.ocr_engine == "paddle":
        return _paddle_recognizer()
    raise OcrDependencyUnavailableError


def get_date_extraction_service(
    settings: Annotated[Settings, Depends(get_settings)],
    recognizer: Annotated[DateRecognizer, Depends(get_date_recognizer)],
) -> DateExtractionService:
    return DateExtractionService(
        validator=ImageValidator(
            max_bytes=settings.ocr_max_image_bytes,
            min_dimension=settings.ocr_min_image_dimension,
            max_dimension=settings.ocr_max_image_dimension,
            max_pixels=settings.ocr_max_image_pixels,
            blur_warning_threshold=settings.ocr_blur_warning_threshold,
        ),
        recognizer=recognizer,
    )


@router.post("/date-extractions", response_model=OcrDateCandidateResponse)
async def extract_date(
    request: Request,
    image: Annotated[UploadFile, File(description="JPEG, PNG, or WebP label image")],
    _current_user: Annotated[User, Depends(get_current_user)],
    service: Annotated[DateExtractionService, Depends(get_date_extraction_service)],
    settings: Annotated[Settings, Depends(get_settings)],
    expected_field_type: Annotated[
        Literal["inspection_date"],
        Form(),
    ] = "inspection_date",
) -> OcrDateCandidateResponse:
    del expected_field_type
    request_id = getattr(request.state, "request_id", "unknown")
    started_at = time.perf_counter()
    logger.info(
        "event=ocr.request.started request_id=%s engine=%s",
        request_id,
        service.engine_name,
    )
    try:
        content = await image.read(settings.ocr_max_image_bytes + 1)
        candidate = await service.extract(content=content, mime_type=image.content_type)
    except UnsupportedImageTypeError as error:
        raise ApiError(
            status_code=415,
            code="UNSUPPORTED_IMAGE_TYPE",
            message="Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP.",
        ) from error
    except ImageTooLargeError as error:
        raise ApiError(
            status_code=413,
            code="IMAGE_TOO_LARGE",
            message="Ảnh vượt quá dung lượng cho phép.",
        ) from error
    except ImageDecodingError as error:
        raise ApiError(
            status_code=422,
            code="IMAGE_DECODING_FAILED",
            message="Không thể đọc nội dung ảnh. Hãy chọn ảnh khác.",
        ) from error
    except ImageDimensionsError as error:
        raise ApiError(
            status_code=422,
            code="IMAGE_DIMENSIONS_INVALID",
            message="Kích thước ảnh không nằm trong giới hạn hỗ trợ.",
        ) from error
    except NoTextFoundError as error:
        logger.info("event=ocr.no_text request_id=%s", request_id)
        raise ApiError(
            status_code=422,
            code="OCR_NO_TEXT",
            message="Không nhận dạng được chữ trong ảnh. Hãy chụp lại rõ hơn.",
        ) from error
    except NoDateCandidateError as error:
        logger.info("event=ocr.no_date_candidate request_id=%s", request_id)
        raise ApiError(
            status_code=422,
            code="OCR_NO_DATE_CANDIDATE",
            message="Không tìm thấy ngày phù hợp. Hãy chụp lại hoặc nhập thủ công.",
        ) from error
    except OcrDependencyUnavailableError as error:
        logger.warning("event=ocr.engine.unavailable request_id=%s", request_id)
        raise ApiError(
            status_code=503,
            code="OCR_UNAVAILABLE",
            message="Dịch vụ nhận dạng hiện chưa sẵn sàng. Vui lòng thử lại sau.",
        ) from error
    except OcrEngineError as error:
        logger.exception("event=ocr.engine.failure request_id=%s", request_id)
        raise ApiError(
            status_code=502,
            code="OCR_ENGINE_FAILURE",
            message="Không thể xử lý ảnh nhận dạng. Vui lòng thử lại.",
        ) from error
    finally:
        await image.close()

    logger.info(
        "event=ocr.request.completed request_id=%s engine=%s result=%s duration_ms=%d",
        request_id,
        service.engine_name,
        candidate.confidence.level,
        round((time.perf_counter() - started_at) * 1000),
    )
    return candidate
