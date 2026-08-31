# FireSafe Engineering Instructions

- `FireSafe_SystemDesign_v1.0_FINAL.md` is the authoritative product specification.
- The backend is a modular monolith. Implement features as vertical slices.
- Do not introduce microservices without explicit approval and an ADR.
- OCR-derived values remain candidates until explicit human confirmation.
- Future offline writes must preserve idempotency and revision semantics.
- Audit and history requirements must not be weakened.
- Never commit secrets, credentials, `.env`, or machine-local configuration.
- Inspect existing code before introducing abstractions; prefer the smallest correct change.
- Run relevant tests after changes and do not silently modify unrelated files.
- Code identifiers are English. User-facing copy may be Vietnamese.
- Architecture-changing decisions require ADRs.
