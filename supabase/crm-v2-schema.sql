-- KIP CRM Pro V2
-- Run this entire file once in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.crm_organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.crm_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid not null references public.crm_organizations(id) on delete cascade,
  full_name text,
  role text not null default 'sales' check (role in ('admin','manager','sales','viewer')),
  created_at timestamptz not null default now()
);

create table if not exists public.crm_settings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null unique references public.crm_organizations(id) on delete cascade,
  lead_statuses jsonb not null default '["New","Contacted","Qualified","Follow-up","Converted","Lost","Not Interested"]'::jsonb,
  deal_stages jsonb not null default '["New","Qualification","Proposal","Negotiation","Won","Lost"]'::jsonb,
  lead_sources jsonb not null default '["Website","Facebook","Google","WhatsApp","Referral","Exhibition","Other"]'::jsonb,
  custom_lead_fields jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.crm_leads (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.crm_organizations(id) on delete cascade,
  owner_id uuid references auth.users(id),
  name text not null,
  company text,
  email text,
  phone text,
  source text,
  status text not null default 'New',
  notes text,
  custom_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.crm_contacts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.crm_organizations(id) on delete cascade,
  account_id uuid,
  lead_id uuid,
  owner_id uuid references auth.users(id),
  name text not null,
  designation text,
  email text,
  phone text,
  notes text,
  custom_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.crm_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.crm_organizations(id) on delete cascade,
  owner_id uuid references auth.users(id),
  name text not null,
  industry text,
  phone text,
  website text,
  gstin text,
  pan text,
  address text,
  notes text,
  custom_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.crm_contacts add constraint crm_contacts_account_fk foreign key (account_id) references public.crm_accounts(id) on delete set null;
alter table public.crm_contacts add constraint crm_contacts_lead_fk foreign key (lead_id) references public.crm_leads(id) on delete set null;

create table if not exists public.crm_deals (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.crm_organizations(id) on delete cascade,
  owner_id uuid references auth.users(id),
  lead_id uuid references public.crm_leads(id) on delete set null,
  contact_id uuid references public.crm_contacts(id) on delete set null,
  account_id uuid references public.crm_accounts(id) on delete set null,
  title text not null,
  amount numeric(14,2) default 0,
  stage text not null default 'New',
  probability integer default 0,
  expected_close date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.crm_activities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.crm_organizations(id) on delete cascade,
  owner_id uuid references auth.users(id),
  lead_id uuid references public.crm_leads(id) on delete set null,
  contact_id uuid references public.crm_contacts(id) on delete set null,
  account_id uuid references public.crm_accounts(id) on delete set null,
  deal_id uuid references public.crm_deals(id) on delete set null,
  subject text not null,
  type text not null default 'Task',
  status text not null default 'Pending',
  due_at timestamptz,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.crm_campaigns (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.crm_organizations(id) on delete cascade,
  owner_id uuid references auth.users(id),
  name text not null,
  channel text,
  status text not null default 'Draft',
  budget numeric(14,2) default 0,
  leads_count integer not null default 0,
  conversions integer not null default 0,
  notes text,
  created_at timestamptz not null default now()
);

create or replace function public.crm_create_organization(org_name text, user_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare org_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  insert into public.crm_organizations(name) values (trim(org_name)) returning id into org_id;
  insert into public.crm_profiles(id, organization_id, full_name, role)
    values (auth.uid(), org_id, nullif(trim(user_name),''), 'admin');
  insert into public.crm_settings(organization_id) values (org_id);
  return org_id;
end;
$$;

create or replace function public.crm_my_org()
returns uuid language sql stable security definer set search_path=public as $$
  select organization_id from public.crm_profiles where id=auth.uid() limit 1;
$$;

alter table public.crm_organizations enable row level security;
alter table public.crm_profiles enable row level security;
alter table public.crm_settings enable row level security;
alter table public.crm_leads enable row level security;
alter table public.crm_contacts enable row level security;
alter table public.crm_accounts enable row level security;
alter table public.crm_deals enable row level security;
alter table public.crm_activities enable row level security;
alter table public.crm_campaigns enable row level security;

create policy crm_org_select on public.crm_organizations for select using (id=public.crm_my_org());
create policy crm_profile_all on public.crm_profiles for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());
create policy crm_settings_all on public.crm_settings for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());
create policy crm_leads_all on public.crm_leads for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());
create policy crm_contacts_all on public.crm_contacts for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());
create policy crm_accounts_all on public.crm_accounts for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());
create policy crm_deals_all on public.crm_deals for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());
create policy crm_activities_all on public.crm_activities for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());
create policy crm_campaigns_all on public.crm_campaigns for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());

grant execute on function public.crm_create_organization(text,text) to authenticated;
grant execute on function public.crm_my_org() to authenticated;
