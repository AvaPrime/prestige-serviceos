# Phase 1 Scope

## Goal

Ship a working Supabase-backed MVP for Prestige ServiceOS that supports real operational tracking from customer intake through work order completion and service history.

## In scope

### Admin

- Login
- Dashboard
- Customer records
- Property records
- Asset registry
- Service requests
- Work orders
- Job reports
- Reminders
- Notification outbox monitor

### Technician

- Assigned jobs
- Job status updates
- Checklist updates
- Parts used
- Job notes
- Photo upload path
- Job report submission

### Customer

- Own profile/customer record
- Own properties
- Own assets
- Own completed reports
- Own reminders

### Estate manager

- Estate portfolio view
- Estate-linked properties/assets/jobs/reports

## Out of scope for Phase 1

- Full accounting automation
- Payment processing
- WhatsApp send-provider production wiring
- Inbound WhatsApp automation
- AI report writing
- AI computer vision
- Inventory control
- Technician GPS tracking
- Native mobile apps

## Build order

1. Normalize schema.
2. Run Supabase staging.
3. Verify RLS.
4. Scaffold Next.js app.
5. Add auth and role routing.
6. Build admin CRUD around the core spine.
7. Build technician assigned-work flow.
8. Build customer/estate read portals.
9. Add notification worker stub.
10. Deploy staging.

## Definition of done

Phase 1 is done when one real job can move through:

```txt
Customer -> Property -> Asset -> Service Request -> Work Order -> Job Report -> Reminder / Notification Outbox
```

and all role boundaries hold under RLS smoke tests.
