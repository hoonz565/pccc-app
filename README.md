# FireSafe

**FireSafe** is a mobile-first fire-safety asset management application designed to help organizations digitize, inspect, monitor, and maintain fire-protection equipment across one or multiple facilities.

The product is initially focused on equipment such as **fire extinguishers**, where important maintenance and inspection information is often stored on physical labels, warranty stickers, or regulatory inspection stickers attached directly to the equipment.

Instead of manually entering all information, FireSafe is designed to allow users to capture these labels using a mobile camera and use **OCR (Optical Character Recognition)** to extract relevant information, including dates that may be:

- printed,
- typed,
- stamped,
- or handwritten.

The OCR result is treated only as **candidate data**. Users must review and confirm extracted information before it becomes authoritative asset data.

The authoritative product and architecture specification is [`FireSafe_SystemDesign_v1.0_FINAL.md`](FireSafe_SystemDesign_v1.0_FINAL.md).

---

## Sprint 1 vertical slice

Sprint 1 builds the first real product path on the verified Sprint 0 foundation:

```text
Register/Login -> authenticated session -> first Facility -> Home
Cold start -> refresh session -> Facility routing
Home -> logout -> Login/Register
```

The slice crosses Flutter, a FastAPI modular monolith, PostgreSQL ownership, and append-only Facility creation audit. Access tokens are short-lived JWTs; opaque refresh tokens rotate through revocable PostgreSQL sessions.

OCR/QR, inspections, reminders, notifications, file storage, reporting, offline synchronization, password reset, advanced RBAC, and Facility edit/delete remain out of scope for Sprint 1.

## Sprint 2 vertical slice

Sprint 2 extends the authenticated product path:

```text
Home -> select Facility -> Area list/create -> Asset list
     -> manual Asset create -> Asset Detail -> revision-safe Asset edit
```

Area ownership is derived through Facility. Asset ownership uses the single normalized path `Asset → Area → Facility → User`; neither `user_id` nor `facility_id` is duplicated on Asset. Manual Assets receive a server-generated `AST-<UUID>` code, `ACTIVE` lifecycle, `MANUAL` provenance, and revision `1`.

The manual `AssetDraft` form is the authoritative creation boundary. Future OCR may pre-fill that draft, but cannot bypass user review and explicit save. OCR, milestone persistence, operational-status derivation, inspection, reminder, image, and offline-sync infrastructure are not implemented in Sprint 2.

## Sprint 3 OCR date-extraction vertical slice

Sprint 3 adds a stateless, authenticated recognition path:

```text
Camera/gallery image -> image validation -> PP-OCRv5 text boxes
-> Vietnamese date anchor -> layout candidate -> deterministic parser
-> calendar validation -> editable mobile review -> explicit confirmation
```

OCR output remains candidate evidence. The extraction endpoint does not create or update an Asset, Inspection, service milestone, image record, or audit event. The Flutter review controller returns the reviewed ISO date and whether the user accepted the OCR value unchanged; a later authoritative workflow must decide how to consume it.

PP-OCRv5 runs server-side behind a replaceable `DateRecognizer` boundary. DARE and TrOCR are future adapters, not dependencies of the current application. No Sprint 3 database migration is required.

## Prerequisites

- Windows 11 and PowerShell
- Git
- Python 3.12
- Docker Desktop with Linux containers
- Flutter stable and Android tooling for the mobile application

Verify the toolchain:

```powershell
git --version
python --version
docker info
docker compose version
flutter doctor -v
```

## Configuration

Create the local configuration file. `.env` is intentionally ignored by Git.

```powershell
Copy-Item .env.example .env
```

The example credentials are for local development only. Use externally managed secrets in deployed environments.

Authentication requires `AUTH_SIGNING_SECRET` (at least 32 characters). The example also documents the 15-minute access-token lifetime, 30-day refresh-session lifetime, and the current `draft-v1` consent versions. Never commit `.env` or a production signing secret.

## Start PostgreSQL

```powershell
docker compose up -d postgres
docker compose ps
docker compose exec -T postgres pg_isready -U firesafe -d firesafe
```

PostgreSQL data is stored in the named `firesafe_postgres_data` volume.

## Backend setup

From the repository root:

```powershell
python -m venv apps\api\.venv
& .\apps\api\.venv\Scripts\Activate.ps1
python -m pip install -r apps\api\requirements-dev.lock
python -m pip install --no-deps -e apps\api
```

The deterministic API and test runtime includes Pillow and multipart parsing but excludes the large ML stack. To enable local PP-OCRv5 inference:

```powershell
python -m pip install -e ".\apps\api[ocr]"
```

The optional versions are pinned to PaddleOCR `3.7.0`, PaddlePaddle `3.3.1`, and PaddleX OCR core `3.7.2`, all supporting Python 3.12. PyYAML is held at `6.0.2` because that PaddleX release requires it. Only PaddleOCR's default general-OCR capability is installed; document parsing, translation, and other `[all]` extras are deliberately excluded. The Windows CPU baseline disables MKL-DNN because the pinned native runtime otherwise fails on the PP-OCRv5 graph; ordinary Paddle CPU inference remains enabled. PaddleOCR constructs the PP-OCRv5 pipeline lazily on the first OCR request. When model directories are not already cached, PaddleOCR downloads its official model weights (Hugging Face is its default source; `PADDLE_PDX_MODEL_SOURCE=BOS` selects the documented BOS source). Pre-cache models during deployment preparation when runtime egress is unavailable. Model weights and caches must never be committed.

If the optional runtime or model is unavailable, the API starts normally and the OCR endpoint returns the controlled `OCR_UNAVAILABLE` error rather than downloading models during unrelated tests.

Start the API with the Windows-compatible event loop entry point:

```powershell
python -m firesafe_api
```

The default address is `http://127.0.0.1:8000`.

### Operational endpoints

- `GET /health` returns `{"status":"ok"}` and never accesses PostgreSQL.
- `GET /ready` checks PostgreSQL and returns `{"status":"ready","database":"connected"}` on success.
- `GET /ready` returns HTTP 503 with a sanitized response when PostgreSQL is unavailable.
- Sprint 1 business endpoints are under `/api/v1`.

### Business API

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/v1/auth/register` | Register, record consent, and create a session |
| `POST` | `/api/v1/auth/login` | Authenticate with a generic invalid-credential response |
| `POST` | `/api/v1/auth/refresh` | Rotate the refresh token and issue a new access token |
| `POST` | `/api/v1/auth/logout` | With Bearer access auth, idempotently revoke the stable session identified by JWT `sid` |
| `GET` | `/api/v1/me` | Resolve the authenticated user |
| `POST` | `/api/v1/facilities` | Create an owner-scoped first Facility and audit event |
| `GET` | `/api/v1/facilities` | List only the current user's Facilities |
| `GET` | `/api/v1/facilities/{facility_id}/areas` | List Areas under an owned Facility |
| `POST` | `/api/v1/facilities/{facility_id}/areas` | Create Area and `area_created` audit atomically |
| `GET` | `/api/v1/areas/{area_id}/assets?limit=50&offset=0` | Owner-scoped bounded Asset list (`limit` 1–100) |
| `POST` | `/api/v1/areas/{area_id}/assets` | Create a manual Asset and `asset_created` audit atomically |
| `GET` | `/api/v1/assets/{asset_id}` | Get owner-scoped Asset Detail |
| `PATCH` | `/api/v1/assets/{asset_id}` | Edit profile/location with required `base_revision`; stale writes return `409 VERSION_CONFLICT` |
| `POST` | `/api/v1/ocr/date-extractions` | Authenticated multipart image extraction; returns a stateless, confirmation-required date candidate |

Example OCR request using an access token already obtained from login:

```powershell
curl.exe -X POST http://127.0.0.1:8000/api/v1/ocr/date-extractions `
  -H "Authorization: Bearer $env:FIRESAFE_ACCESS_TOKEN" `
  -F "image=@C:\path\to\label.jpg;type=image/jpeg" `
  -F "expected_field_type=inspection_date"
```

The response distinguishes raw OCR, normalized date, corrections, anchor/layout provenance, validation, image quality, and `requires_confirmation`. Expected failures use `UNSUPPORTED_IMAGE_TYPE`, `IMAGE_TOO_LARGE`, `IMAGE_DECODING_FAILED`, `IMAGE_DIMENSIONS_INVALID`, `OCR_NO_TEXT`, `OCR_NO_DATE_CANDIDATE`, `OCR_UNAVAILABLE`, or `OCR_ENGINE_FAILURE`; stack traces and image contents are not returned.

Run the optional local engine check only after installing the OCR extra and supplying a private image:

```powershell
$env:RUN_OCR_INTEGRATION = '1'
$env:OCR_TEST_IMAGE = 'C:\path\to\label.jpg'
& .\apps\api\.venv\Scripts\python.exe -m pytest apps\api\tests\test_ocr_paddle_integration.py -m integration
```

Benchmark setup and commands are documented in [`research/ocr/README.md`](research/ocr/README.md). Known Sprint 3 limitations include uncalibrated confidence categories, no production handwritten-date adapter, sensitivity to severe blur/glare/curvature, and layouts whose anchor and date are both missed by OCR.

Verify locally:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
Invoke-RestMethod http://127.0.0.1:8000/ready
```

## Backend quality gates

```powershell
& .\apps\api\.venv\Scripts\python.exe -m ruff check apps\api
& .\apps\api\.venv\Scripts\python.exe -m ruff format --check apps\api
& .\apps\api\.venv\Scripts\python.exe -m mypy apps\api\src apps\api\tests
& .\apps\api\.venv\Scripts\python.exe -m pytest apps\api\tests -m "not integration"
```

Use a dedicated local test database because the integration fixture truncates implemented domain tables between tests. Create and migrate it once:

```powershell
docker compose exec -T postgres createdb -U firesafe firesafe_test
$env:DATABASE_URL = 'postgresql+psycopg://firesafe:firesafe_dev_password@127.0.0.1:5432/firesafe_test'
$env:AUTH_SIGNING_SECRET = 'local-test-only-signing-secret-with-at-least-32-characters'
& .\apps\api\.venv\Scripts\python.exe -m alembic -c apps\api\alembic.ini upgrade head
$env:RUN_DATABASE_TESTS = '1'
& .\apps\api\.venv\Scripts\python.exe -m pytest apps\api\tests
```

## Alembic

Migrations are ordered by vertical slice: identity/auth sessions, Facilities/audit, Areas, then manual Assets.

```powershell
& .\apps\api\.venv\Scripts\python.exe -m alembic -c apps\api\alembic.ini upgrade head
& .\apps\api\.venv\Scripts\python.exe -m alembic -c apps\api\alembic.ini current
```

## Mobile setup and runtime

Add the Flutter SDK `bin` directory to `PATH`, then restore and verify the mobile project:

```powershell
Set-Location apps\mobile
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

The Android application requires its base URL at compile time. Start PostgreSQL and the API first, then run:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=APP_ENV=development
```

`10.0.2.2` is the standard Android Emulator alias for the host machine. Local cleartext HTTP must be enabled only in the Android debug manifest; production configuration must remain HTTPS-only.

Routing is driven by application state: bootstrap, unauthenticated login/register, authenticated first-Facility onboarding, or authenticated product routes. Home holds an explicit Facility selection; Area and Asset route IDs form the visible context while the backend independently enforces ownership. The refresh token is stored in Android secure storage and the access token remains in memory. Logout excludes concurrent refresh, deletes the secure credential before reporting success, and uses the access-token `sid` for best-effort server revocation.

Create requests are not automatically retried after an ambiguous network failure. Without the future `client_operation_id`/idempotency protocol, a lost response may follow a successful server commit. The app retains the draft and instructs the user to inspect the relevant list before manually retrying.

An Android debug APK can be built with:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=APP_ENV=development
```

Android builds require the Android SDK command-line tools and accepted SDK licenses. Verify both with `flutter doctor -v` and `flutter doctor --android-licenses`.

The Sprint 1 client sets Android API 24 as the minimum and Android backup is disabled to prevent encrypted credential material from being restored without its Keystore key.

## Sprint 1 release boundaries

- Consent copy/version `draft-v1` is a development placeholder. Product/Legal approval is required before production.
- Login/registration rate limiting and abuse lockout are intentionally deferred; deploy Sprint 1 only in a controlled environment until a reviewed policy is implemented.
- Production traffic must use HTTPS. Cleartext HTTP remains enabled only in the Android debug manifest for emulator development.

## Continuous integration

GitHub Actions runs independent backend and mobile jobs. The backend job validates linting, typing, Alembic, unit tests, and PostgreSQL integration. The mobile job restores the locked dependencies, checks formatting, runs `flutter analyze`, and runs all Flutter tests.

## Architecture decisions

- [`ADR 0001: Use Flutter for the Mobile Application`](docs/adr/0001-use-flutter-for-mobile.md)
- [`ADR 0002: Use a Modular Monolith Backend`](docs/adr/0002-use-modular-monolith-backend.md)
- [`ADR 0003: Use Short-Lived JWTs with Revocable Refresh Sessions`](docs/adr/0003-use-revocable-refresh-sessions.md)
- [`ADR 0004: Derive Asset Ownership Through Area`](docs/adr/0004-derive-asset-ownership-through-area.md)
- [`ADR 0005: Use a Server-Side Replaceable OCR Recognizer`](docs/adr/0005-use-server-side-replaceable-ocr.md)
- [`Implemented requirement traceability`](docs/traceability.md)
