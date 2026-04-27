# Supabase Setup

## Current status

Supabase project is not wired yet.

## Required project

Create staging first:

```txt
prestige-serviceos-staging
```

Production comes later:

```txt
prestige-serviceos-prod
```

## Secrets rule

Do not commit secrets.

Safe to expose in frontend:

```txt
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
```

Server-side only:

```txt
SUPABASE_SERVICE_ROLE_KEY
```

## Migration policy

The uploaded v0.1.4 schema pack must be normalized before execution.

No migration should be run in production until it has passed staging checks.
