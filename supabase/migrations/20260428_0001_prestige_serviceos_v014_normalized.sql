-- Prestige ServiceOS v0.1.4 normalized baseline migration
-- Run in Supabase staging first. Do not run in production before RLS smoke tests pass.
-- Core spine: Customer -> Property -> Asset -> Service Request -> Work Order -> Job Report -> Reminder -> Notification Outbox.
-- Rule: do not flatten assets into jobs.

create extension if not exists "pgcrypto";

do $$ begin create type public.customer_type as enum ('homeowner','landlord','property_manager','estate_hoa','body_corporate','holiday_home','commercial'); exception when duplicate_object then null; end $$;
do $$ begin create type public.property_type as enum ('residential','holiday_home','rental','estate_unit','commercial','agricultural'); exception when duplicate_object then null; end $$;
do $$ begin create type public.asset_category as enum ('electric_geyser','solar_geyser','heat_pump','pv_water_heating','pressure_pump','booster_pump','jojo_tank','filtration_unit','pressure_valve','float_valve','greywater_system','wastewater_system','septic_system','rainwater_harvest','water_meter','irrigation_system','drainage_line','iot_sensor','other'); exception when duplicate_object then null; end $$;
do $$ begin create type public.risk_rating as enum ('low','medium','high','critical'); exception when duplicate_object then null; end $$;
do $$ begin create type public.request_status as enum ('new','under_review','awaiting_schedule','scheduled','in_progress','awaiting_quote','awaiting_payment','completed','closed','cancelled'); exception when duplicate_object then null; end $$;
do $$ begin create type public.urgency_level as enum ('emergency','within_24h','within_48h','within_week','planned','general_enquiry'); exception when duplicate_object then null; end $$;
do $$ begin create type public.service_category as enum ('plumbing','geyser_hot_water','solar_water_heating','water_systems','drainage_wastewater','property_inspection','maintenance_plan','estate_support','projects_upgrades','ecomate_watercare','homepro_care','emergency_callout'); exception when duplicate_object then null; end $$;
do $$ begin create type public.work_order_status as enum ('draft','assigned','en_route','on_site','in_progress','paused','completed','report_pending','closed'); exception when duplicate_object then null; end $$;
do $$ begin create type public.plan_tier as enum ('homepro_essential','homepro_plus','estate_standard','estate_premium','ecomate_monitoring'); exception when duplicate_object then null; end $$;
do $$ begin create type public.plan_status as enum ('active','pending_renewal','expired','cancelled','suspended'); exception when duplicate_object then null; end $$;
do $$ begin create type public.notification_channel as enum ('whatsapp','email','sms','in_app'); exception when duplicate_object then null; end $$;
do $$ begin create type public.notification_status as enum ('pending','sent','failed','retrying'); exception when duplicate_object then null; end $$;
do $$ begin create type public.user_role as enum ('admin','technician','customer','estate_mgr'); exception when duplicate_object then null; end $$;

create table if not exists public.profiles (id uuid primary key default gen_random_uuid(), auth_user_id uuid unique not null references auth.users(id) on delete cascade, role public.user_role not null default 'customer', full_name text not null, phone text, email text, avatar_url text, is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.customers (id uuid primary key default gen_random_uuid(), profile_id uuid references public.profiles(id) on delete set null, type public.customer_type not null default 'homeowner', company_name text, contact_name text not null, email text, phone text not null, whatsapp text, address text, notes text, is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz);

create table if not exists public.estate_accounts (id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id) on delete cascade, estate_name text not null, unit_count int, manager_name text, manager_email text, manager_phone text, contract_start date, contract_end date, sla_hours int default 24, notes text, is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz);

create table if not exists public.properties (id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id) on delete cascade, estate_account_id uuid references public.estate_accounts(id) on delete set null, name text not null, type public.property_type not null default 'residential', address_line1 text not null, address_line2 text, suburb text, town text not null default 'Plettenberg Bay', province text not null default 'Western Cape', postal_code text, gps_lat numeric(10,7), gps_lng numeric(10,7), access_notes text, notes text, risk_rating public.risk_rating not null default 'low', is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz);

create table if not exists public.assets (id uuid primary key default gen_random_uuid(), property_id uuid not null references public.properties(id) on delete cascade, category public.asset_category not null, name text not null, make text, model text, serial_number text, supplier text, installed_by text, installation_date date, warranty_expiry date, location_in_property text, risk_rating public.risk_rating not null default 'low', next_service_date date, notes text, is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz);

create table if not exists public.technicians (id uuid primary key default gen_random_uuid(), profile_id uuid unique not null references public.profiles(id) on delete cascade, employee_id text, skills text[], is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz);

create table if not exists public.service_requests (id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id), property_id uuid references public.properties(id), service_category public.service_category not null, urgency public.urgency_level not null default 'within_48h', status public.request_status not null default 'new', description text not null, customer_photos text[], source text default 'website', internal_notes text, assigned_to uuid references public.technicians(id), converted_to_wo uuid, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz);

create table if not exists public.work_orders (id uuid primary key default gen_random_uuid(), request_id uuid references public.service_requests(id) on delete set null, customer_id uuid not null references public.customers(id), property_id uuid references public.properties(id), technician_id uuid references public.technicians(id), service_category public.service_category not null, status public.work_order_status not null default 'draft', urgency public.urgency_level not null default 'within_48h', title text not null, description text, internal_notes text, scheduled_start timestamptz, scheduled_end timestamptz, actual_start timestamptz, actual_end timestamptz, travel_notes text, checklist jsonb default '[]'::jsonb, parts_used jsonb default '[]'::jsonb, follow_up_required boolean default false, follow_up_notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz, constraint check_wo_scheduled_range check (scheduled_start is null or scheduled_end is null or scheduled_end > scheduled_start), constraint check_wo_actual_range check (actual_start is null or actual_end is null or actual_end >= actual_start));

do $$ begin alter table public.service_requests add constraint fk_sr_converted_to_wo foreign key (converted_to_wo) references public.work_orders(id) on delete set null; exception when duplicate_object then null; end $$;

create table if not exists public.work_order_assets (id uuid primary key default gen_random_uuid(), work_order_id uuid not null references public.work_orders(id) on delete cascade, asset_id uuid not null references public.assets(id) on delete cascade, action text not null, notes text, unique(work_order_id, asset_id));
create table if not exists public.asset_photos (id uuid primary key default gen_random_uuid(), asset_id uuid not null references public.assets(id) on delete cascade, storage_path text not null, caption text, taken_at timestamptz, uploaded_by uuid references public.profiles(id), created_at timestamptz not null default now());
create table if not exists public.service_request_photos (id uuid primary key default gen_random_uuid(), service_request_id uuid not null references public.service_requests(id) on delete cascade, storage_path text not null, caption text, photo_type text default 'customer_submitted', uploaded_by uuid references public.profiles(id), created_at timestamptz not null default now());
create table if not exists public.job_photos (id uuid primary key default gen_random_uuid(), work_order_id uuid not null references public.work_orders(id) on delete cascade, storage_path text not null, caption text, photo_type text default 'during', taken_at timestamptz, uploaded_by uuid references public.profiles(id), created_at timestamptz not null default now());

create table if not exists public.job_reports (id uuid primary key default gen_random_uuid(), work_order_id uuid unique not null references public.work_orders(id) on delete cascade, technician_id uuid not null references public.technicians(id), findings text not null, work_performed text not null, recommendations text, follow_up_required boolean default false, follow_up_notes text, customer_signature text, submitted_at timestamptz not null default now(), reviewed_by uuid references public.profiles(id), reviewed_at timestamptz, pdf_path text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz);

create table if not exists public.quotes (id uuid primary key default gen_random_uuid(), work_order_id uuid references public.work_orders(id) on delete set null, customer_id uuid not null references public.customers(id), quote_number text not null, line_items jsonb not null default '[]'::jsonb, subtotal numeric(10,2), vat_amount numeric(10,2), total numeric(10,2) not null, status text not null default 'draft', valid_until date, notes text, sent_at timestamptz, accepted_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz, constraint check_quotes_amounts_nonnegative check (total >= 0 and (subtotal is null or subtotal >= 0) and (vat_amount is null or vat_amount >= 0)));
create table if not exists public.invoices (id uuid primary key default gen_random_uuid(), quote_id uuid references public.quotes(id) on delete set null, work_order_id uuid references public.work_orders(id) on delete set null, customer_id uuid not null references public.customers(id), invoice_number text not null, line_items jsonb not null default '[]'::jsonb, subtotal numeric(10,2), vat_amount numeric(10,2), total numeric(10,2) not null, status text not null default 'unpaid', due_date date, paid_at timestamptz, payment_method text, payment_ref text, notes text, pdf_path text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz, constraint check_invoices_amounts_nonnegative check (total >= 0 and (subtotal is null or subtotal >= 0) and (vat_amount is null or vat_amount >= 0)));

create table if not exists public.maintenance_plans (id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.customers(id), property_id uuid references public.properties(id), estate_account_id uuid references public.estate_accounts(id), tier public.plan_tier not null, status public.plan_status not null default 'active', start_date date not null, renewal_date date not null, annual_fee numeric(10,2), included_visits int not null default 1, visits_used int not null default 0, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz, constraint check_plan_property_or_estate check (property_id is not null or estate_account_id is not null), constraint check_plan_dates check (renewal_date >= start_date));
create table if not exists public.reminders (id uuid primary key default gen_random_uuid(), customer_id uuid references public.customers(id) on delete cascade, property_id uuid references public.properties(id) on delete cascade, asset_id uuid references public.assets(id) on delete cascade, work_order_id uuid references public.work_orders(id) on delete set null, plan_id uuid references public.maintenance_plans(id) on delete set null, title text not null, description text, due_date date not null, priority public.urgency_level not null default 'planned', is_dismissed boolean not null default false, dismissed_at timestamptz, notification_sent boolean not null default false, sent_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz);

create table if not exists public.notification_outbox (id uuid primary key default gen_random_uuid(), channel public.notification_channel not null default 'whatsapp', recipient_phone text not null, recipient_name text, template_name text, body text not null, variables jsonb default '{}'::jsonb, entity_type text, entity_id uuid, customer_id uuid references public.customers(id) on delete set null, status public.notification_status not null default 'pending', attempt_count int not null default 0, max_attempts int not null default 3, next_attempt_at timestamptz not null default now(), sent_at timestamptz, provider_ref text, error_message text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz);
create table if not exists public.whatsapp_inbox (id uuid primary key default gen_random_uuid(), whatsapp_message_id text unique not null, conversation_id text, ticket_id text, from_phone text not null, from_name text, customer_id uuid references public.customers(id) on delete set null, work_order_id uuid references public.work_orders(id) on delete set null, service_request_id uuid references public.service_requests(id) on delete set null, message_type text, body text, media_url text, timestamp timestamptz not null, raw_payload jsonb, status text default 'received', processed_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz);
create table if not exists public.activity_log (id uuid primary key default gen_random_uuid(), actor_profile_id uuid references public.profiles(id) on delete set null, actor_role text, entity_type text not null, entity_id uuid, action text not null, before_data jsonb, after_data jsonb, created_at timestamptz not null default now());

create or replace function public.current_app_role() returns text language sql stable security definer set search_path = public, auth as $$ select coalesce((auth.jwt() -> 'app_metadata' ->> 'role'), 'customer'); $$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public, auth as $$ select public.current_app_role() = 'admin'; $$;
create or replace function public.is_technician() returns boolean language sql stable security definer set search_path = public, auth as $$ select public.current_app_role() = 'technician'; $$;
create or replace function public.is_customer() returns boolean language sql stable security definer set search_path = public, auth as $$ select public.current_app_role() = 'customer'; $$;
create or replace function public.is_estate_mgr() returns boolean language sql stable security definer set search_path = public, auth as $$ select public.current_app_role() = 'estate_mgr'; $$;
create or replace function public.current_profile_id() returns uuid language sql stable security definer set search_path = public, auth as $$ select id from public.profiles where auth_user_id = auth.uid() limit 1; $$;
create or replace function public.current_customer_id() returns uuid language sql stable security definer set search_path = public, auth as $$ select id from public.customers where profile_id = public.current_profile_id() and deleted_at is null limit 1; $$;
create or replace function public.current_technician_id() returns uuid language sql stable security definer set search_path = public, auth as $$ select id from public.technicians where profile_id = public.current_profile_id() and deleted_at is null limit 1; $$;

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
do $$ declare t text; begin foreach t in array array['profiles','customers','estate_accounts','properties','assets','technicians','service_requests','work_orders','job_reports','quotes','invoices','maintenance_plans','reminders','notification_outbox','whatsapp_inbox'] loop execute format('drop trigger if exists trg_%I_updated_at on public.%I', t, t); execute format('create trigger trg_%I_updated_at before update on public.%I for each row execute function public.set_updated_at()', t, t); end loop; end $$;

create or replace function public.enqueue_wo_status_notification() returns trigger language plpgsql security definer set search_path = public as $$
declare c record; p record; msg text; tmpl text;
begin
  if old.status = new.status or new.deleted_at is not null then return new; end if;
  select contact_name, coalesce(nullif(whatsapp,''), nullif(phone,'')) phone into c from public.customers where id = new.customer_id and deleted_at is null;
  if c.phone is null then return new; end if;
  select name into p from public.properties where id = new.property_id and deleted_at is null;
  case new.status
    when 'assigned' then tmpl := 'wo_assigned'; msg := format('Hi %s, your service request has been scheduled. Job ref: %s. Property: %s. - Prestige Property Solutions', c.contact_name, new.id, coalesce(p.name,'your property'));
    when 'en_route' then tmpl := 'wo_en_route'; msg := format('Hi %s, your Prestige technician is on the way to %s. Job ref: %s. - Prestige Property Solutions', c.contact_name, coalesce(p.name,'your property'), new.id);
    when 'on_site' then tmpl := 'wo_on_site'; msg := format('Hi %s, your Prestige technician has arrived at %s. Job ref: %s. - Prestige Property Solutions', c.contact_name, coalesce(p.name,'your property'), new.id);
    when 'completed' then tmpl := 'wo_completed'; msg := format('Hi %s, work has been completed at %s. Job ref: %s. Your service report will follow shortly. - Prestige Property Solutions', c.contact_name, coalesce(p.name,'your property'), new.id);
    else return new;
  end case;
  insert into public.notification_outbox(channel, recipient_phone, recipient_name, template_name, body, variables, entity_type, entity_id, customer_id) values ('whatsapp', c.phone, c.contact_name, tmpl, msg, jsonb_build_object('work_order_id',new.id,'status',new.status), 'work_order', new.id, new.customer_id);
  return new;
end; $$;
drop trigger if exists trg_wo_status_notification on public.work_orders;
create trigger trg_wo_status_notification after update of status on public.work_orders for each row execute function public.enqueue_wo_status_notification();

create or replace function public.auto_asset_reminder() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.deleted_at is not null or new.is_active = false or new.next_service_date is null then return new; end if;
  if tg_op = 'INSERT' or old.next_service_date is distinct from new.next_service_date or old.risk_rating is distinct from new.risk_rating then
    update public.reminders set is_dismissed = true, dismissed_at = now() where asset_id = new.id and is_dismissed = false and deleted_at is null;
    insert into public.reminders(customer_id, property_id, asset_id, title, description, due_date, priority)
    select p.customer_id, new.property_id, new.id, 'Service due: ' || new.name, 'Scheduled service for ' || new.name, new.next_service_date, case when new.risk_rating='critical' then 'emergency'::public.urgency_level when new.risk_rating='high' then 'within_48h'::public.urgency_level when new.risk_rating='medium' then 'within_week'::public.urgency_level else 'planned'::public.urgency_level end from public.properties p where p.id = new.property_id and p.deleted_at is null;
  end if;
  return new;
end; $$;
drop trigger if exists trg_asset_reminder on public.assets;
create trigger trg_asset_reminder after insert or update of next_service_date, risk_rating, deleted_at, is_active on public.assets for each row execute function public.auto_asset_reminder();

create index if not exists idx_profiles_auth_user on public.profiles(auth_user_id);
create index if not exists idx_customers_profile on public.customers(profile_id);
create index if not exists idx_properties_customer on public.properties(customer_id);
create index if not exists idx_properties_estate on public.properties(estate_account_id);
create index if not exists idx_assets_property on public.assets(property_id);
create index if not exists idx_assets_next_service on public.assets(next_service_date);
create index if not exists idx_sr_customer on public.service_requests(customer_id);
create index if not exists idx_wo_customer on public.work_orders(customer_id);
create index if not exists idx_wo_technician on public.work_orders(technician_id);
create index if not exists idx_reminders_due on public.reminders(due_date) where is_dismissed = false and deleted_at is null;
create index if not exists idx_outbox_pending on public.notification_outbox(next_attempt_at) where status in ('pending','retrying') and deleted_at is null;
create unique index if not exists uq_quotes_quote_number_active on public.quotes(quote_number) where deleted_at is null;
create unique index if not exists uq_invoices_invoice_number_active on public.invoices(invoice_number) where deleted_at is null;

do $$ declare t text; begin foreach t in array array['profiles','customers','estate_accounts','properties','assets','asset_photos','technicians','service_requests','work_orders','work_order_assets','service_request_photos','job_photos','job_reports','quotes','invoices','maintenance_plans','reminders','notification_outbox','whatsapp_inbox','activity_log'] loop execute format('alter table public.%I enable row level security', t); execute format('drop policy if exists admin_all on public.%I', t); execute format('create policy admin_all on public.%I for all using (public.is_admin()) with check (public.is_admin())', t); end loop; end $$;

drop policy if exists profiles_own on public.profiles;
create policy profiles_own on public.profiles for select using (auth.uid() = auth_user_id);
drop policy if exists profiles_own_update on public.profiles;
create policy profiles_own_update on public.profiles for update using (auth.uid() = auth_user_id) with check (auth.uid() = auth_user_id);

drop policy if exists customers_own_select on public.customers;
create policy customers_own_select on public.customers for select using (profile_id = public.current_profile_id() and deleted_at is null);
drop policy if exists properties_customer_select on public.properties;
create policy properties_customer_select on public.properties for select using (customer_id = public.current_customer_id() and deleted_at is null);
drop policy if exists assets_customer_select on public.assets;
create policy assets_customer_select on public.assets for select using (property_id in (select id from public.properties where customer_id = public.current_customer_id() and deleted_at is null) and deleted_at is null);
drop policy if exists wo_customer_select on public.work_orders;
create policy wo_customer_select on public.work_orders for select using (customer_id = public.current_customer_id() and deleted_at is null);
drop policy if exists sr_customer_select on public.service_requests;
create policy sr_customer_select on public.service_requests for select using (customer_id = public.current_customer_id() and deleted_at is null);
drop policy if exists jr_customer_select on public.job_reports;
create policy jr_customer_select on public.job_reports for select using (work_order_id in (select id from public.work_orders where customer_id = public.current_customer_id() and deleted_at is null) and deleted_at is null);
drop policy if exists reminders_customer_select on public.reminders;
create policy reminders_customer_select on public.reminders for select using (customer_id = public.current_customer_id() and deleted_at is null);

drop policy if exists wo_technician_select on public.work_orders;
create policy wo_technician_select on public.work_orders for select using (technician_id = public.current_technician_id() and deleted_at is null);
drop policy if exists wo_technician_update on public.work_orders;
create policy wo_technician_update on public.work_orders for update using (technician_id = public.current_technician_id() and deleted_at is null) with check (technician_id = public.current_technician_id());
drop policy if exists jr_technician_insert on public.job_reports;
create policy jr_technician_insert on public.job_reports for insert with check (technician_id = public.current_technician_id() and work_order_id in (select id from public.work_orders where technician_id = public.current_technician_id() and deleted_at is null));
drop policy if exists photos_technician_insert on public.job_photos;
create policy photos_technician_insert on public.job_photos for insert with check (work_order_id in (select id from public.work_orders where technician_id = public.current_technician_id() and deleted_at is null));

drop policy if exists estate_properties_select on public.properties;
create policy estate_properties_select on public.properties for select using (estate_account_id in (select ea.id from public.estate_accounts ea join public.customers c on c.id=ea.customer_id where c.profile_id = public.current_profile_id() and ea.deleted_at is null) and deleted_at is null);
drop policy if exists estate_assets_select on public.assets;
create policy estate_assets_select on public.assets for select using (property_id in (select id from public.properties where estate_account_id in (select ea.id from public.estate_accounts ea join public.customers c on c.id=ea.customer_id where c.profile_id = public.current_profile_id()) and deleted_at is null) and deleted_at is null);
drop policy if exists estate_wo_select on public.work_orders;
create policy estate_wo_select on public.work_orders for select using (property_id in (select id from public.properties where estate_account_id in (select ea.id from public.estate_accounts ea join public.customers c on c.id=ea.customer_id where c.profile_id = public.current_profile_id()) and deleted_at is null) and deleted_at is null);

insert into storage.buckets (id, name, public) values ('asset-photos','asset-photos',false), ('job-photos','job-photos',false), ('job-reports','job-reports',false), ('service-request-photos','service-request-photos',false) on conflict (id) do nothing;

select 'prestige_serviceos_v014_normalized_loaded' as migration_status;
