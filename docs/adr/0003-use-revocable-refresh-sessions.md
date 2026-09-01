# ADR 0003: Use Short-Lived JWTs with Revocable Refresh Sessions

- Status: Accepted
- Date: 2026-08-31

## Context

Sprint 1 introduces authentication and session restoration on a mobile device. A long-lived, self-contained JWT cannot be revoked reliably at logout without additional infrastructure. Storing a bearer credential in ordinary preferences would also expose it beyond the security boundary expected for authentication material.

FireSafe remains one FastAPI modular monolith backed by PostgreSQL. Sprint 1 does not justify Redis, a separate identity service, or an external session platform.

## Decision

- Hash passwords with Argon2id. Passwords are accepted at 12–128 characters and are never logged or returned.
- Issue an HS256 JWT access token with only `sub`, `sid`, `iat`, and `exp`. Its default lifetime is 15 minutes and its signing secret comes from configuration.
- Issue at least 256 bits of random opaque refresh-token material. Store only its SHA-256 digest in `auth_sessions`.
- Give refresh sessions an absolute default lifetime of 30 days. The `AuthSession.id` carried as JWT `sid` is stable while the refresh token rotates under a PostgreSQL row lock on every successful refresh.
- Authenticate logout with the access-token Bearer credential, cryptographically validate its required claims and expiry, and revoke the stable `AuthSession` selected by `sid`. Refresh and logout serialize on that same row. Logout remains idempotent even when the referenced session is already revoked or no longer present; this does not weaken active-session checks on other protected endpoints.
- Keep the access token only in application memory. Store the refresh token with `flutter_secure_storage`; never use `SharedPreferences` for credentials.
- Serialize concurrent mobile refresh attempts, retry an authenticated request at most once, and clear local authentication when refresh is invalid or revoked. Logout excludes new refreshes and invalidates late refresh results before deleting the secure refresh credential; a deletion failure remains an authenticated, recoverable error rather than a successful logout.
- Keep `/health` and `/ready` outside authentication and outside `/api/v1`.

## Consequences

- Logout and server-side revocation invalidate both refresh and access use for the current session.
- Protected requests require a PostgreSQL session lookup in addition to JWT verification. This is acceptable for Sprint 1 and avoids adding Redis solely for authentication.
- Refresh-token replay after a successful rotation fails. Concurrent rotation requests allow only one winner.
- Regardless of whether refresh rotation or logout first acquires the session row lock, a completed logout leaves that stable session revoked.
- If logout occurs while offline, the mobile app still removes its local credential; the unreachable server session remains bounded by its expiry.
- Signing-secret rotation, key identifiers, device/session management UI, and distributed rate limiting remain future hardening work.

## Alternatives Considered

- **Long-lived JWT only:** rejected because logout cannot revoke it promptly.
- **Refresh JWT stored in plaintext server-side:** rejected because a database leak would expose live bearer credentials.
- **Redis-backed sessions:** rejected because PostgreSQL provides the required locking, expiry, and revocation semantics at current scale.
- **Persisting both tokens on device:** rejected because the short-lived access token does not need durable storage.
