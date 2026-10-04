# FireSafe Mobile

Android-first Flutter client for the FireSafe vertical slices.

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

## Sprint 3 OCR review flow

Authenticated users can open **Nhận dạng ngày trên tem** from Home, take a photo or select one from the gallery, and upload it through the OCR repository. The controller exposes selecting, uploading, processing, candidate, error, and confirmed states.

The review screen shows raw OCR text, an editable `DD/MM/YYYY` value, confidence guidance, and retry/change-image actions. **Xác nhận** returns a `ReviewedOcrDate` containing the reviewed ISO date and whether the OCR suggestion was accepted unchanged. It does not call the Asset repository or persist a milestone. That separation is intentional: recognition is candidate data until a future authoritative domain workflow explicitly consumes it.
