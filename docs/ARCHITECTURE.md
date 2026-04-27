# Prestige ServiceOS Architecture

## Product identity

Prestige ServiceOS is a vertical field-service operating system for Prestige Property Solutions.

It is designed around property infrastructure memory rather than generic contact management.

## Core spine

```txt
Customer
  -> Property
    -> Asset
      -> Service Request
        -> Work Order
          -> Job Report
            -> Reminder
              -> Notification Outbox
```

## Non-negotiable model rule

Do not flatten assets into jobs.

A geyser, pump, tank, valve, filtration unit, drainage line, or sensor must remain a durable asset with service history across multiple jobs.

## Roles

- `admin`: full operational access.
- `technician`: assigned work only plus bounded field updates.
- `customer`: own records only.
- `estate_mgr`: estate portfolio records only.

## System boundaries

### Public website

Marketing and lead capture only.

### ServiceOS app

Operational system of record for jobs, properties, assets, reports, reminders, and notifications.

### Supabase

Backend source of truth:

- Auth
- Postgres data
- Row-level security
- Private storage
- Server-side operational tables

### Vercel

Application hosting:

- Next.js frontend
- server routes
- notification cron endpoint
- report/PDF generation endpoints

## Notification design

Client code never sends WhatsApp directly.

Work-order status changes enqueue records into `notification_outbox`. A server-side worker processes those rows with privileged credentials and provider adapters.

## Phase 1 exclusions

- No autonomous billing actions.
- No AI decision automation.
- No automatic WhatsApp mutation of jobs from inbound messages.
- No production launch until RLS smoke tests pass.
