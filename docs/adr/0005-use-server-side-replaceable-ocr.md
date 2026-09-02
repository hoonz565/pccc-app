# ADR 0005: Use a Server-Side Replaceable OCR Recognizer

- Status: Accepted
- Date: 2026-09-02

## Context

Sprint 3 must extract structured dates from printed or stamped fire-extinguisher labels while the team is still evaluating OCR approaches. The observed target is a Vietnamese anchor such as `Ngày thực hiện` near a date such as `15 - 07 - 2026`. Future handwritten labels may require DARE, TrOCR, or a specialized digit recognizer.

Embedding a model into Flutter now would couple model selection to mobile packaging, platform runtimes, and release cycles. Persisting extraction results would also create an entity before a confirmed domain workflow needs one.

## Decision

- Run Sprint 3 OCR inference inside the existing FastAPI modular monolith.
- Put OCR behind the internal `DateRecognizer` protocol. PP-OCRv5 is the first `PaddleDateRecognizer`; Paddle-specific result objects are translated immediately into FireSafe text boxes with confidence and optional bounding boxes.
- Keep PaddleOCR/PaddlePaddle in an optional dependency group. Model construction is lazy, so normal startup and deterministic tests never download weights.
- Disable MKL-DNN in the initial Paddle adapter. The pinned Windows CPU runtime otherwise raises a oneDNN/PIR graph-conversion error for the PP-OCRv5 detector; this compatibility setting is adapter-local and can be revisited when the runtime is upgraded and benchmarked.
- Keep image validation, anchor matching, geometric selection, date parsing, calendar validation, and confidence derivation separate from recognition.
- Return a stateless candidate with raw text, normalized value, corrections, confidence signals, image-quality warnings, and `requires_confirmation=true`.
- Do not write Asset, Inspection, milestone, media, or audit rows during extraction. The mobile review flow returns the explicitly reviewed date to its caller and records in memory whether it was accepted unchanged or corrected.

## Consequences

- The recognizer can later be replaced by DARE, TrOCR, or CRNN without changing parsing, API, or review code.
- The API process needs the optional ML runtime only where OCR is enabled. A missing runtime/model produces a controlled `OCR_UNAVAILABLE` response.
- First model initialization may download weights unless they were pre-cached; deployment must pre-cache them where outbound network access is unavailable.
- Confidence is an application category derived from component signals, not a calibrated probability.
- Handwritten accuracy, glare, curvature, and unfamiliar layouts remain benchmark questions rather than assumed capabilities.

## Alternatives Considered

- **On-device Flutter inference:** deferred because Sprint 3 is still comparing recognizers and does not justify TFLite/ONNX/native platform work.
- **OCR microservice:** rejected because it adds deployment and network boundaries without a demonstrated scaling or isolation need.
- **Persist every OCR candidate:** rejected because this stateless extraction slice has no confirmed domain consumer requiring persistence.
- **Hard-code template coordinates:** rejected because labels vary and the date is selected from bounded anchor/layout relationships.
