-- Zoho-style CRM backend expansion
-- Run after the existing supabase/schema.sql

create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null, industry text, phone text, email text, website text, city text, owner_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.contacts (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  account_id uuid references public.accounts(id) on delete set null, first_name text not null, last_name text, phone text, email text,
  designation text, city text, owner_id uuid references auth.users(id) on delete set null, created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.deals (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  account_id uuid references public.accounts(id) on delete set null, contact_id uuid references public.contacts(id) on delete set null,
  name text not null, amount numeric(14,2) not null default 0, stage text not null default 'Qualification' check(stage in ('Qualification','Needs Analysis','Proposal','Negotiation','Won','Lost')),
  probability integer not null default 10 check(probability between 0 and 100), expected_close date, owner_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  type text not null check(type in ('Task','Call','Meeting','Email','Note')), subject text not null, due_at timestamptz, completed boolean not null default false,
  lead_id uuid references public.leads(id) on delete cascade, contact_id uuid references public.contacts(id) on delete cascade, account_id uuid references public.accounts(id) on delete cascade,
  deal_id uuid references public.deals(id) on delete cascade, assigned_to uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null, description text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null, type text default 'Digital', status text default 'Planning' check(status in ('Planning','Active','Paused','Completed')),
  budget numeric(14,2) default 0, start_date date, end_date date, notes text, created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key, organization_id uuid references public.organizations(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null, entity_type text not null, entity_id uuid, action text not null,
  details jsonb default '{}'::jsonb, created_at timestamptz not null default now()
);

create index if not exists accounts_org_idx on public.accounts(organization_id);
create index if not exists contacts_org_idx on public.contacts(organization_id);
create index if not exists deals_org_idx on public.deals(organization_id);
create index if not exists activities_org_idx on public.activities(organization_id);
create index if not exists activities_due_idx on public.activities(due_at);
create index if not exists campaigns_org_idx on public.campaigns(organization_id);
create index if not exists audit_org_idx on public.audit_logs(organization_id);

alter table public.accounts enable row level security;
alter table public.contacts enable row level security;
alter table public.deals enable row level security;
alter table public.activities enable row level security;
alter table public.campaigns enable row level security;
alter table public.audit_logs enable row level security;

create policy "org members read accounts" on public.accounts for select using (organization_id=public.my_org_id());
create policy "org members insert accounts" on public.accounts for insert with check (organization_id=public.my_org_id());
create policy "org members update accounts" on public.accounts for update using (organization_id=public.my_org_id()) with check (organization_id=public.my_org_id());
create policy "org members delete accounts" on public.accounts for delete using (organization_id=public.my_org_id());
create policy "org members read contacts" on public.contacts for select using (organization_id=public.my_org_id());
create policy "org members insert contacts" on public.contacts for insert with check (organization_id=public.my_org_id());
create policy "org members update contacts" on public.contacts for update using (organization_id=public.my_org_id()) with check (organization_id=public.my_org_id());
create policy "org members delete contacts" on public.contacts for delete using (organization_id=public.my_org_id());
create policy "org members read deals" on public.deals for select using (organization_id=public.my_org_id());
create policy "org members insert deals" on public.deals for insert with check (organization_id=public.my_org_id());
create policy "org members update deals" on public.deals for update using (organization_id=public.my_org_id()) with check (organization_id=public.my_org_id());
create policy "org members delete deals" on public.deals for delete using (organization_id=public.my_org_id());
create policy "org members read activities" on public.activities for select using (organization_id=public.my_org_id());
create policy "org members insert activities" on public.activities for insert with check (organization_id=public.my_org_id());
create policy "org members update activities" on public.activities for update using (organization_id=public.my_org_id()) with check (organization_id=public.my_org_id());
create policy "org members delete activities" on public.activities for delete using (organization_id=public.my_org_id());
create policy "org members read campaigns" on public.campaigns for select using (organization_id=public.my_org_id());
create policy "org members insert campaigns" on public.campaigns for insert with check (organization_id=public.my_org_id());
create policy "org members update campaigns" on public.campaigns for update using (organization_id=public.my_org_id()) with check (organization_id=public.my_org_id());
create policy "org members delete campaigns" on public.campaigns for delete using (organization_id=public.my_org_id());
create policy "org members read audit" on public.audit_logs for select using (organization_id=public.my_org_id());
create policy "org members insert audit" on public.audit_logs for insert with check (organization_id=public.my_org_id() and actor_id=auth.uid());

do $$ begin
  if not exists (select 1 from pg_trigger where tgname='accounts_updated_at') then create trigger accounts_updated_at before update on public.accounts for each row execute function public.set_updated_at(); end if;
  if not exists (select 1 from pg_trigger where tgname='contacts_updated_at') then create trigger contacts_updated_at before update on public.contacts for each row execute function public.set_updated_at(); end if;
  if not exists (select 1 from pg_trigger where tgname='deals_updated_at') then create trigger deals_updated_at before update on public.deals for each row execute function public.set_updated_at(); end if;
  if not exists (select 1 from pg_trigger where tgname='activities_updated_at') then create trigger activities_updated_at before update on public.activities for each row execute function public.set_updated_at(); end if;
  if not exists (select 1 from pg_trigger where tgname='campaigns_updated_at') then create trigger campaigns_updated_at before update on public.campaigns for each row execute function public.set_updated_at(); end if;
end $$;
