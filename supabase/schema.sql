-- Lead Management CRM - production schema / migration
-- Safe to run on the existing Supabase project.
create extension if not exists pgcrypto;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text not null unique default upper(substr(encode(gen_random_bytes(6),'hex'),1,8)),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'employee' check (role in ('admin','employee')),
  organization_id uuid references public.organizations(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists role text default 'employee';
alter table public.profiles add column if not exists organization_id uuid;
alter table public.profiles add column if not exists created_at timestamptz default now();
alter table public.profiles add column if not exists updated_at timestamptz default now();

do $$ begin
  if not exists(select 1 from pg_constraint where conrelid='public.profiles'::regclass and conname='profiles_organization_id_fkey') then
    alter table public.profiles add constraint profiles_organization_id_fkey foreign key(organization_id) references public.organizations(id) on delete set null;
  end if;
end $$;

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(), organization_id uuid, created_by uuid, assigned_to uuid,
  name text not null, company text, phone text, email text, city text, source text default 'Website', service text,
  status text not null default 'New' check(status in ('New','Contacted','Follow-up','Converted','Not Interested','Lost')),
  followup date, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.leads add column if not exists organization_id uuid;
alter table public.leads add column if not exists created_by uuid;
alter table public.leads add column if not exists assigned_to uuid;
alter table public.leads add column if not exists updated_at timestamptz default now();
alter table public.leads add column if not exists source text default 'Website';
alter table public.leads add column if not exists service text;
alter table public.leads add column if not exists status text default 'New';
alter table public.leads add column if not exists followup date;
alter table public.leads add column if not exists notes text;

do $$ begin
  if not exists(select 1 from pg_constraint where conrelid='public.leads'::regclass and conname='leads_organization_id_fkey') then alter table public.leads add constraint leads_organization_id_fkey foreign key(organization_id) references public.organizations(id) on delete cascade; end if;
  if not exists(select 1 from pg_constraint where conrelid='public.leads'::regclass and conname='leads_created_by_fkey') then alter table public.leads add constraint leads_created_by_fkey foreign key(created_by) references auth.users(id) on delete set null; end if;
  if not exists(select 1 from pg_constraint where conrelid='public.leads'::regclass and conname='leads_assigned_to_fkey') then alter table public.leads add constraint leads_assigned_to_fkey foreign key(assigned_to) references auth.users(id) on delete set null; end if;
end $$;

create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null, industry text, phone text, email text, website text, city text, owner_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.contacts (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  account_id uuid references public.accounts(id) on delete set null, first_name text not null, last_name text, designation text,
  phone text, email text, city text, owner_id uuid references auth.users(id) on delete set null, created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.deals (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  account_id uuid references public.accounts(id) on delete set null, contact_id uuid references public.contacts(id) on delete set null,
  name text not null, amount numeric(14,2) default 0, stage text not null default 'Qualification' check(stage in ('Qualification','Needs Analysis','Proposal','Negotiation','Won','Lost')),
  probability integer default 10 check(probability between 0 and 100), expected_close date, owner_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  lead_id uuid references public.leads(id) on delete set null, contact_id uuid references public.contacts(id) on delete set null,
  subject text not null, type text not null default 'Task' check(type in ('Task','Call','Meeting','Email','Note')),
  due_at timestamptz, completed boolean not null default false, assigned_to uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null, description text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null, type text default 'Digital', status text not null default 'Planning' check(status in ('Planning','Active','Paused','Completed')),
  budget numeric(14,2) default 0, start_date date, end_date date, notes text, created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create index if not exists leads_org_idx on public.leads(organization_id);
create index if not exists contacts_org_idx on public.contacts(organization_id);
create index if not exists accounts_org_idx on public.accounts(organization_id);
create index if not exists deals_org_idx on public.deals(organization_id);
create index if not exists activities_org_idx on public.activities(organization_id);
create index if not exists campaigns_org_idx on public.campaigns(organization_id);

create or replace function public.my_org_id() returns uuid language sql stable security definer set search_path=public as $$ select organization_id from public.profiles where id=auth.uid() limit 1 $$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin') $$;

create or replace function public.create_organization(org_name text,user_name text) returns public.organizations language plpgsql security definer set search_path=public as $$
declare o public.organizations; begin
  if exists(select 1 from public.profiles where id=auth.uid() and organization_id is not null) then raise exception 'User already belongs to an organization'; end if;
  if nullif(trim(org_name),'') is null then raise exception 'Organization name is required'; end if;
  insert into public.organizations(name,created_by) values(trim(org_name),auth.uid()) returning * into o;
  insert into public.profiles(id,full_name,role,organization_id) values(auth.uid(),nullif(trim(user_name),''),'admin',o.id)
    on conflict(id) do update set full_name=excluded.full_name,role='admin',organization_id=o.id,updated_at=now();
  return o;
end $$;
create or replace function public.join_organization(code text,user_name text) returns public.organizations language plpgsql security definer set search_path=public as $$
declare o public.organizations; begin
  if exists(select 1 from public.profiles where id=auth.uid() and organization_id is not null) then raise exception 'User already belongs to an organization'; end if;
  select * into o from public.organizations where upper(join_code)=upper(trim(code));
  if o.id is null then raise exception 'Invalid organization code'; end if;
  insert into public.profiles(id,full_name,role,organization_id) values(auth.uid(),nullif(trim(user_name),''),'employee',o.id)
    on conflict(id) do update set full_name=excluded.full_name,organization_id=o.id,updated_at=now();
  return o;
end $$;
grant execute on function public.create_organization(text,text) to authenticated;
grant execute on function public.join_organization(text,text) to authenticated;
grant execute on function public.my_org_id() to authenticated;
grant execute on function public.is_admin() to authenticated;

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.leads enable row level security;
alter table public.accounts enable row level security;
alter table public.contacts enable row level security;
alter table public.deals enable row level security;
alter table public.activities enable row level security;
alter table public.campaigns enable row level security;

-- Organization/profile policies
 drop policy if exists org_select on public.organizations;
 create policy org_select on public.organizations for select using(id=public.my_org_id() or created_by=auth.uid());
 drop policy if exists profile_self on public.profiles;
 create policy profile_self on public.profiles for select using(id=auth.uid());
 drop policy if exists profile_admin_read on public.profiles;
 create policy profile_admin_read on public.profiles for select using(organization_id=public.my_org_id() and public.is_admin());
 drop policy if exists profile_self_update on public.profiles;
 create policy profile_self_update on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());

-- Organization-scoped CRUD policies
 do $$ declare t text; begin
  foreach t in array array['accounts','contacts','deals','activities','campaigns'] loop
    execute format('drop policy if exists %I_select on public.%I',t,t);
    execute format('create policy %I_select on public.%I for select using(organization_id=public.my_org_id())',t,t);
    execute format('drop policy if exists %I_insert on public.%I',t,t);
    execute format('create policy %I_insert on public.%I for insert with check(organization_id=public.my_org_id() and created_by=auth.uid())',t,t);
    execute format('drop policy if exists %I_update on public.%I',t,t);
    execute format('create policy %I_update on public.%I for update using(organization_id=public.my_org_id()) with check(organization_id=public.my_org_id())',t,t);
    execute format('drop policy if exists %I_delete on public.%I',t,t);
    execute format('create policy %I_delete on public.%I for delete using(organization_id=public.my_org_id() and (created_by=auth.uid() or public.is_admin()))',t,t);
  end loop;
 end $$;

-- Leads policies (replace old policies)
drop policy if exists "Users can view own leads" on public.leads;
drop policy if exists "Users can insert own leads" on public.leads;
drop policy if exists "Users can update own leads" on public.leads;
drop policy if exists "Users can delete own leads" on public.leads;
drop policy if exists org_read on public.leads;
drop policy if exists org_insert on public.leads;
drop policy if exists org_update on public.leads;
drop policy if exists org_delete on public.leads;
create policy org_read on public.leads for select using(organization_id=public.my_org_id());
create policy org_insert on public.leads for insert with check(organization_id=public.my_org_id() and created_by=auth.uid());
create policy org_update on public.leads for update using(organization_id=public.my_org_id()) with check(organization_id=public.my_org_id());
create policy org_delete on public.leads for delete using(organization_id=public.my_org_id() and (created_by=auth.uid() or public.is_admin()));

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;

do $$ declare t text; begin foreach t in array array['profiles','leads','accounts','contacts','deals','activities','campaigns'] loop
  execute format('drop trigger if exists %I_updated_at on public.%I',t,t);
  execute format('create trigger %I_updated_at before update on public.%I for each row execute function public.set_updated_at()',t,t);
end loop; end $$;
