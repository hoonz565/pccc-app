# ADR 0001: Use Flutter for the Mobile Application

- Status: Accepted
- Date: 2026-08-31

## Context

FireSafe is a mobile-first application used during field work. The initial development environment is Windows 11 with Android as the Sprint 0 target. The application must later support offline workflows without coupling presentation code directly to network access.

## Decision

Use Flutter stable and Dart for the mobile application. Organize code by feature with presentation, application, and data boundaries where a feature requires them. Use Riverpod for state orchestration and Dio for HTTP.

Sprint 0 contains one technical `DevelopmentScreen`; navigation infrastructure is deferred until Sprint 1. Drift, SQLite, and secure credential storage are also deferred until their vertical slices require them.

## Consequences

- Android development can run natively on Windows.
- Flutter and Dart versions must be pinned in CI and recorded in project metadata.
- Local API addresses are supplied with `--dart-define`.
- Cleartext HTTP is allowed only in the Android debug manifest.
