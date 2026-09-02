class OcrError(Exception):
    """Base class for expected OCR pipeline failures."""


class UnsupportedImageTypeError(OcrError):
    pass


class ImageTooLargeError(OcrError):
    pass


class ImageDecodingError(OcrError):
    pass


class ImageDimensionsError(OcrError):
    pass


class OcrDependencyUnavailableError(OcrError):
    pass


class OcrEngineError(OcrError):
    pass


class NoTextFoundError(OcrError):
    pass


class NoDateCandidateError(OcrError):
    pass
