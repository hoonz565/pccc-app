# FireSafe Mobile

Android-first Flutter walking skeleton for FireSafe Sprint 0.

From this directory:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=APP_ENV=development
```

`API_BASE_URL` is required. The current screen is a development connectivity probe only; it is not production UI or a business feature.
