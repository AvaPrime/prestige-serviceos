# RLS Smoke Tests

These checks must pass before staging is considered usable and before production is even discussed.

## Test personas

Create one Supabase Auth user for each role:

```txt
admin
technician
customer
estate_mgr
```

Each user must have `app_metadata.role` set correctly.

## Required checks

### Anonymous user

Expected result: cannot read protected operational tables.

Tables:

- `customers`
- `properties`
- `assets`
- `service_requests`
- `work_orders`
- `job_reports`
- `reminders`
- `notification_outbox`

### Admin

Expected result: can read/write operational tables.

Check:

```sql
select count(*) from public.work_orders;
select count(*) from public.customers;
select count(*) from public.assets;
```

### Technician

Expected result: can read only assigned work orders and safe linked job data.

Must not be able to update:

- `technician_id`
- `customer_id`
- `property_id`
- `request_id`
- `service_category`
- `urgency`
- `scheduled_start`
- `scheduled_end`
- `title`

Allowed field updates should be bounded to field-work data, such as status, notes, checklist, parts used, actual start/end, follow-up fields, and report submission.

### Customer

Expected result: can read only own customer/property/asset/work-order/report/reminder data.

Must not see other customer records.

### Estate manager

Expected result: can read only estate-linked customer/property/asset/job/report data.

Must not see non-estate or unrelated estate records.

## Workflow checks

### Work-order notification enqueue

When a work order changes status to one of:

```txt
assigned
en_route
on_site
completed
```

Expected result: a row is inserted into `notification_outbox`.

### Asset reminder enqueue

When an asset has `next_service_date` set or changed:

Expected result: active reminder exists for that asset.

## Production block rule

If any smoke test fails, production deployment is blocked.
