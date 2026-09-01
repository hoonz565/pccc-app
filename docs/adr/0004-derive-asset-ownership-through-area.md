# ADR 0004: Derive Asset Ownership Through Area

- Status: Accepted
- Date: 2026-09-01

## Context

The conceptual Asset table in the System Design includes `user_id`, `facility_id`, and `area_id`. Persisting all three would create multiple ownership paths for the same Asset. A malformed or incomplete write could make those values disagree and weaken server-side authorization.

Sprint 2 introduces Area and Asset as real domain resources. Area already belongs to Facility, and Facility is the authoritative owner-scoped resource established in Sprint 1.

## Decision

Normalize Asset ownership through one chain:

```text
Asset.area_id -> Area.facility_id -> Facility.user_id -> User.id
```

The `assets` table does not contain `user_id` or `facility_id`. Area and Asset authorization queries join through this chain and filter by the authenticated principal. Client request bodies cannot provide ownership or parent identifiers; the trusted parent comes from route context. Missing and foreign-owned resources share the same safe `404` semantics.

## Consequences

- There is one authoritative ownership path and no conflicting owner/Facility copies on Asset.
- Moving an Asset to another Area is a domain operation rather than an uncoordinated owner-field update; Area reassignment remains deferred.
- Authorization and Facility-scoped queries require indexed joins through `areas.facility_id` and `assets.area_id`.
- If production profiling later demonstrates a real bottleneck, controlled denormalization may be reconsidered with explicit consistency rules and a new architecture decision.

## Alternatives Considered

- **Duplicate `user_id` and `facility_id` on Asset:** rejected because it permits contradictory ownership state and increases the number of server-controlled fields that every write must keep synchronized.
- **Trust Facility/owner IDs from the client:** rejected because the mobile UI is not an authorization boundary and this would enable IDOR/ownership spoofing.
