# Prestige ServiceOS Deployment Runbook

## Deployment doctrine

Prestige ServiceOS is deployed as a schema-backed operational system, not as a static prototype.

Preferred path:

```txt
GitHub -> Supabase staging -> Next.js app -> Vercel staging -> production pilot
```

## Phase 0: Repository baseline

Status: in progress.

Required baseline files:

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/PHASE_1_SCOPE.md`
- `docs/RLS_SMOKE_TESTS.md`
- `docs/SCHEMA_AUDIT.md`
- `supabase/README.md`
- `supabase/migrations/`
- `.env.example`

## Phase 1: Supabase staging

User actions:

1. Create Supabase project: `prestige-serviceos-staging`.
2. Store database password in a password manager.
3. Do not paste database password or service-role key into chat.
4. Share only the project URL and anon public key when needed.

Engineer actions:

1. Normalize canonical schema into run-ready migration.
2. Run migration in staging.
3. Create test Auth users.
4. Set `app_metadata.role` for test users.
5. Generate TypeScript database types.
6. Run RLS smoke tests.

## Phase 2: App scaffold

Target stack:

- Next.js
- TypeScript
- Tailwind
- Supabase JS client
- Supabase Auth
- Server routes for privileged operations
- Vercel deployment

Minimum routes:

```txt
/auth/login
/admin/dashboard
/admin/customers
/admin/properties
/admin/assets
/admin/service-requests
/admin/work-orders
/admin/reminders
/admin/notifications
/technician/jobs
/customer/portal
/estate/portfolio
```

## Phase 3: Vercel staging

Required environment variables:

```txt
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
CRON_SECRET=
```

Optional later:

```txt
WHATSAPP_PROVIDER=
WHATSAPP_API_KEY=
EMAIL_PROVIDER=
EMAIL_API_KEY=
```

## Release gates

Production is blocked until:

1. Admin reads/writes operational records.
2. Technician only sees assigned work.
3. Customer only sees own records.
4. Estate manager only sees estate-linked portfolio records.
5. Anonymous user sees nothing protected.
6. Status changes create `notification_outbox` rows.
7. Service role key is server-side only.
8. Storage buckets are private.
9. Job reports link to work orders.
10. Asset history survives across jobs.

## Current blocker

The uploaded v0.1.4 schema pack is canonical in scope but the text artifact contains malformed SQL function bodies. It must be normalized into a run-ready migration before being executed in Supabase.
