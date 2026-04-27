# Schema Audit

## Current finding

The uploaded `PRESTIGE SERVICEOS v0.1.4 SCHEMA PACK` is the canonical scope artifact, but the uploaded text version is not safe to execute directly yet.

Several SQL function bodies appear malformed, for example missing `AS $$ ... $$` delimiters around PL/pgSQL or SQL bodies.

Examples of affected areas:

- `auth.user_profile_id()`
- `public.set_updated_at()`
- `public.enqueue_wo_status_notification()`
- v0.1.4 corrective helper functions
- storage helper functions

## Engineering decision

Do not paste the uploaded v0.1.4 artifact directly into Supabase.

Instead:

1. Preserve v0.1.4 as canonical scope.
2. Normalize it into a run-ready migration.
3. Run SQL lint/review manually.
4. Execute only in Supabase staging.
5. Run preflight and RLS smoke tests.
6. Promote only after validation.

## Acceptance criteria for normalized migration

A migration is acceptable only when:

- All functions have valid SQL/PLpgSQL bodies.
- All enum creation is rerun-safe.
- All triggers are rerun-safe.
- All policies are rerun-safe.
- RLS is enabled on protected tables.
- Storage policies match private-bucket expectations.
- Preflight checks pass.
- Role smoke tests pass.

## Canonical schema intent

The schema must preserve this spine:

```txt
Customer -> Property -> Asset -> Service Request -> Work Order -> Job Report -> Reminder -> Notification Outbox
```

and this rule:

```txt
Do not flatten assets into jobs.
```
