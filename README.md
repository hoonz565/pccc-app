# FireSafe

FireSafe is a mobile-first fire-safety asset management application. The authoritative product and architecture specification is [`FireSafe_SystemDesign_v1.0_FINAL.md`](FireSafe_SystemDesign_v1.0_FINAL.md).

This repository is a monorepo. The backend is a FastAPI modular monolith, the mobile client is Flutter for Android, and PostgreSQL is the system of record for synchronized data.

## Sprint 0 scope

Sprint 0 builds only the engineering walking skeleton:

```text
Flutter Android -> FastAPI -> PostgreSQL
```

It does not include authentication, facility or asset CRUD, OCR, QR scanning, inspections, reminders, notifications, offline synchronization, reporting, or production UI.

The backend, PostgreSQL, and Android Flutter foundations are implemented. The development-only mobile screen probes the API and database readiness without introducing business functionality.

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
- Future business endpoints are reserved under `/api/v1`.

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

Run the PostgreSQL integration test while the Compose service is healthy:

```powershell
$env:DATABASE_URL = 'postgresql+psycopg://firesafe:firesafe_dev_password@127.0.0.1:5432/firesafe'
$env:RUN_DATABASE_TESTS = '1'
& .\apps\api\.venv\Scripts\python.exe -m pytest apps\api\tests\test_ready_postgres.py
```

## Alembic

Sprint 0 initializes migration infrastructure but intentionally contains no schema revision or business table.

```powershell
& .\apps\api\.venv\Scripts\python.exe -m alembic -c apps\api\alembic.ini upgrade head
& .\apps\api\.venv\Scripts\python.exe -m alembic -c apps\api\alembic.ini current
```

## Mobile setup and connectivity

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

The development screen reports these states independently:

- `API: Connected`, `Database: Connected` when `/health` and `/ready` succeed.
- `API: Connected`, `Database: Unavailable` when the API is alive but PostgreSQL is not ready.
- `API: Unavailable`, `Database: Unknown` when `/health` cannot be reached or returns an invalid response.

An Android debug APK can be built with:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=APP_ENV=development
```

Android builds require the Android SDK command-line tools and accepted SDK licenses. Verify both with `flutter doctor -v` and `flutter doctor --android-licenses`.

## Continuous integration

GitHub Actions runs independent backend and mobile jobs. The backend job validates linting, typing, Alembic, unit tests, and PostgreSQL integration. The mobile job restores the locked dependencies, checks formatting, runs `flutter analyze`, and runs all Flutter tests.

## Architecture decisions

- [`ADR 0001: Use Flutter for the Mobile Application`](docs/adr/0001-use-flutter-for-mobile.md)
- [`ADR 0002: Use a Modular Monolith Backend`](docs/adr/0002-use-modular-monolith-backend.md)
