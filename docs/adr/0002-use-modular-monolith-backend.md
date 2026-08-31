# ADR 0002: Use a Modular Monolith Backend

- Status: Accepted
- Date: 2026-08-31

## Context

FireSafe has several logical domains, but the MVP does not need independent deployment, distributed transactions, or service-to-service infrastructure. Premature microservices would increase operational and consistency costs.

## Decision

Build one FastAPI application and one PostgreSQL database as a modular monolith. Business capabilities will be added as vertical slices with explicit internal boundaries when their implementation begins.

Sprint 0 creates only application configuration, database connectivity, operational routes, tests, and migration infrastructure. It does not create empty future domain modules or generic repository/service base classes.

Operational endpoints remain at `/health` and `/ready`. Future business APIs use the `/api/v1` prefix.

## Consequences

- Deployment and local development remain simple.
- Transactions can preserve data integrity within one database.
- Domain boundaries remain enforceable in code without network boundaries.
- Extracting a module into a service later requires demonstrated need, explicit approval, and a new ADR.
