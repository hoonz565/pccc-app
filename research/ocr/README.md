# FireSafe OCR Research and Benchmarking

This directory is local research scaffolding for the stateless Sprint 3 date-extraction pipeline. It never writes FireSafe application data and must not contain production images, model weights, or generated outputs in Git.

## Local dataset

Copy `benchmark/metadata.example.csv` to the ignored `benchmark/metadata.csv`, then place local JPEG, PNG, or WebP images in the ignored `samples/` directory.

Required columns:

```text
image,raw_label,normalized_date,type,quality,physical_tag_id,split
```

Suggested values include:

- `type`: `printed`, `stamped`, or `handwritten`
- `quality`: `good`, `blur`, `glare`, or `skew`
- `split`: `train`, `validation`, or `test`

Every photo of one physical tag must use the same `physical_tag_id` and the same split. The harness rejects metadata that places one physical tag in multiple splits. This prevents near-duplicate captures from leaking between training and evaluation.

## Run

Install the API and optional OCR dependencies first, then from the repository root run:

```powershell
& .\apps\api\.venv\Scripts\python.exe research\ocr\benchmark.py
```

The report contains real measurements only:

- normalized date accuracy
- exact OCR string accuracy
- character error rate (CER)
- invalid-date rate
- failure rate
- mean processing latency
- median and p95 processing latency
- per-capture results and unique physical-tag count
- breakdowns by label type and image quality

If local metadata or images are absent, the command explains what to add and exits without claiming results.

PP-OCRv5 is the Sprint 3 baseline. The application-level recognizer boundary is intended to support later DARE, TrOCR, or digit-only CRNN comparisons using the same parser and metrics.
