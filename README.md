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

Areas, Assets, OCR/QR, inspections, reminders, notifications, file storage, reporting, offline synchronization, password reset, advanced RBAC, and Facility edit/delete remain out of scope.

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

### Sprint 1 API

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/v1/auth/register` | Register, record consent, and create a session |
| `POST` | `/api/v1/auth/login` | Authenticate with a generic invalid-credential response |
| `POST` | `/api/v1/auth/refresh` | Rotate the refresh token and issue a new access token |
| `POST` | `/api/v1/auth/logout` | With Bearer access auth, idempotently revoke the stable session identified by JWT `sid` |
| `GET` | `/api/v1/me` | Resolve the authenticated user |
| `POST` | `/api/v1/facilities` | Create an owner-scoped first Facility and audit event |
| `GET` | `/api/v1/facilities` | List only the current user's Facilities |

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

Use a dedicated local test database because the integration fixture truncates Sprint 1 tables between tests. Create and migrate it once:

```powershell
docker compose exec -T postgres createdb -U firesafe firesafe_test
$env:DATABASE_URL = 'postgresql+psycopg://firesafe:firesafe_dev_password@127.0.0.1:5432/firesafe_test'
$env:AUTH_SIGNING_SECRET = 'local-test-only-signing-secret-with-at-least-32-characters'
& .\apps\api\.venv\Scripts\python.exe -m alembic -c apps\api\alembic.ini upgrade head
$env:RUN_DATABASE_TESTS = '1'
& .\apps\api\.venv\Scripts\python.exe -m pytest apps\api\tests
```

## Alembic

Sprint 1 contains two ordered migrations: identity/auth sessions, then owned Facilities/audit events.

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

Routing is driven by application state: bootstrap, unauthenticated login/register, authenticated first-Facility onboarding, or Home. The refresh token is stored in Android secure storage and the access token remains in memory. Logout excludes concurrent refresh, deletes the secure credential before reporting success, and uses the access-token `sid` for best-effort server revocation.

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
- [`Sprint 1 requirement traceability`](docs/traceability.md)
