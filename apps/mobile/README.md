# FireSafe Mobile

Android-first Flutter client for the Sprint 1 identity and first-Facility vertical slice.

From this directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=APP_ENV=development
```

`API_BASE_URL` is required. `10.0.2.2` is the Android Emulator alias for the host machine.

The application state drives all routing:

```text
bootstrap -> login/register -> first Facility -> Home
          -> refresh restore -> first Facility or Home
```

The refresh token is stored only through `flutter_secure_storage`; the access token stays in application memory. The authenticated Dio client attaches the access token, shares one refresh among concurrent 401 responses, retries once, and clears invalid sessions. Logout prevents new refreshes, invalidates late refresh results, and reports secure-storage deletion failures without claiming the user is logged out. The Sprint 1 Android baseline is API 24.

The consent labels currently use `draft-v1`. They are development placeholders and require Product/Legal approval before a production release.
