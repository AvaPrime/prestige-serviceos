# Supabase Setup

## Current status

Supabase staging project exists.

Project URL:

```txt
https://axwxxvpgahueenwhhhwp.supabase.co
```

## Required projects

Staging:

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
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
```

Compatibility alias if older examples/components expect it:

```txt
NEXT_PUBLIC_SUPABASE_ANON_KEY
```

Server-side only:

```txt
SUPABASE_SERVICE_ROLE_KEY
```

## Supabase package setup

Once the Next.js app exists, install:

```bash
npm install @supabase/supabase-js @supabase/ssr
```

Optional Supabase shadcn helper:

```bash
npx shadcn@latest add @supabase/supabase-client-nextjs
```

## Migration policy

The uploaded v0.1.4 schema pack must be normalized before execution.

No migration should be run in production until it has passed staging checks.
