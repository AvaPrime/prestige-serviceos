-- Prestige ServiceOS Supabase preflight checks
-- Run after the baseline migration succeeds.

-- 1. Core tables exist
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'profiles','customers','estate_accounts','properties','assets','technicians',
    'service_requests','work_orders','work_order_assets','asset_photos',
    'service_request_photos','job_photos','job_reports','quotes','invoices',
    'maintenance_plans','reminders','notification_outbox','whatsapp_inbox','activity_log'
  )
order by table_name;

-- 2. RLS enabled on protected tables
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in (
    'profiles','customers','estate_accounts','properties','assets','technicians',
    'service_requests','work_orders','job_reports','quotes','invoices',
    'maintenance_plans','reminders','notification_outbox','whatsapp_inbox','activity_log'
  )
order by tablename;

-- 3. Key triggers exist
select event_object_table, trigger_name, action_timing, event_manipulation
from information_schema.triggers
where trigger_schema = 'public'
  and trigger_name in ('trg_wo_status_notification','trg_asset_reminder')
order by event_object_table, trigger_name;

-- 4. Storage buckets exist and are private
select id, name, public
from storage.buckets
where id in ('asset-photos','job-photos','job-reports','service-request-photos')
order by id;

-- 5. Policy count sanity check
select schemaname, tablename, count(*) as policy_count
from pg_policies
where schemaname = 'public'
group by schemaname, tablename
order by tablename;

-- 6. Role helper smoke check in SQL editor context
select
  public.current_app_role() as current_app_role,
  public.is_admin() as is_admin,
  public.is_technician() as is_technician,
  public.is_customer() as is_customer,
  public.is_estate_mgr() as is_estate_mgr;
