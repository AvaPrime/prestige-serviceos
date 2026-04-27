# Prestige ServiceOS

Prestige ServiceOS is the governed operating system for Prestige Property Solutions' field-service workflow.

It is not a generic CRM and not a simple job board. The Phase 1 product spine is:

```txt
Customer -> Property -> Asset -> Service Request -> Work Order -> Job Report -> Reminder -> Notification Outbox
```

The strategic rule is simple: **do not flatten assets into jobs**. Asset history is the moat.

## Current build status

This repository was bootstrapped from the uploaded Prestige ServiceOS schema/prototype pack.

- Canonical functional scope: Prestige ServiceOS v0.1.4 schema pack.
- Deployment target: Supabase + Next.js + Vercel.
- Current repo stage: engineering foundation and deployment runbook.
- Production status: not launched.

## Deployment path

```txt
GitHub -> Supabase staging -> Next.js app -> Vercel staging -> production pilot
```

## Required release gates

Before production:

1. Admin can read/write operational records.
2. Technician can only access assigned work.
3. Customer can only access own records.
4. Estate manager can only access estate-linked records.
5. Anonymous users cannot access protected data.
6. Work order status changes queue notification_outbox rows.
7. Service-role secrets are never exposed client-side.
8. Storage buckets are private.
9. Job reports link back to work orders.
10. Asset service history survives across jobs.

## Repository layout

```txt
docs/                  Deployment, architecture, scope, and smoke-test docs
supabase/              Supabase notes, seed placeholders, and migrations
supabase/migrations/   SQL migrations once normalized and verified
```

## Next command phase

Create a Supabase staging project and run the schema only after the schema source audit is resolved. The uploaded v0.1.4 pack is canonical in scope, but the uploaded text artifact needs SQL normalization before it is treated as run-ready.
