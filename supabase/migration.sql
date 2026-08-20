-- Organization CRM migration for existing installations
-- Run this file in Supabase SQL Editor AFTER the original schema.

create extension if not exists pgcrypto;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  join_code text unique,
  created_by uuid references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists organization_id uuid;
alter table public.profiles add column if not exists role text;
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists created_at timestamptz default now();
alter table public.profiles add column if not exists updated_at timestamptz default now();

alter table public.leads add column if not exists organization_id uuid;
alter table public.leads add column if not exists assigned_to uuid;
alter table public.leads add column if not exists service text;
alter table public.leads add column if not exists followup date;
alter table public.leads add column if not exists notes text;
alter table public.leads add column if not exists updated_at timestamptz default now();

-- Existing users become members of one default organization.
do $$
declare
  o_id uuid;
  first_user uuid;
begin
  select id into o_id from public.organizations order by created_at limit 1;
  select id into first_user from auth.users order by created_at limit 1;
  if o_id is null and first_user is not null then
    insert into public.organizations(name, created_by, join_code)
    values ('My Organization', first_user, upper(substr(encode(gen_random_bytes(6),'hex'),1,8)))
    returning id into o_id;
  end if;
  if o_id is not null then
    update public.profiles set organization_id=o_id where organization_id is null;
    update public.leads l set organization_id=o_id where l.organization_id is null;
    update public.profiles set role=coalesce(role,'employee') where role is null;
    update public.profiles p set role='admin'
      where p.id=(select created_by from public.organizations where id=o_id limit 1);
  end if;
end $$;

-- Safe foreign keys after columns exist.
do $$
begin
  if not exists (select 1 from pg_constraint where conname='profiles_organization_id_fkey') then
    alter table public.profiles add constraint profiles_organization_id_fkey foreign key (organization_id) references public.organizations(id) on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname='leads_organization_id_fkey') then
    alter table public.leads add constraint leads_organization_id_fkey foreign key (organization_id) references public.organizations(id) on delete cascade;
  end if;
end $$;

create index if not exists profiles_org_idx on public.profiles(organization_id);
create index if not exists leads_org_idx on public.leads(organization_id);
create index if not exists leads_assigned_idx on public.leads(assigned_to);

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.leads enable row level security;

create or replace function public.my_org_id()
returns uuid language sql stable security definer set search_path=public
as $$ select organization_id from public.profiles where id=auth.uid() $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin') $$;

drop policy if exists "org members can view organization" on public.organizations;
create policy "org members can view organization" on public.organizations for select using (id=public.my_org_id() or created_by=auth.uid());

drop policy if exists "users can view own profile" on public.profiles;
drop policy if exists "admins can view org profiles" on public.profiles;
drop policy if exists "users can update own profile" on public.profiles;
create policy "users can view own profile" on public.profiles for select using (id=auth.uid());
create policy "admins can view org profiles" on public.profiles for select using (organization_id=public.my_org_id() and public.is_admin());
create policy "users can update own profile" on public.profiles for update using (id=auth.uid()) with check (id=auth.uid());

drop policy if exists "org members can read leads" on public.leads;
drop policy if exists "org members can insert leads" on public.leads;
drop policy if exists "org members can update leads" on public.leads;
drop policy if exists "org members can delete leads" on public.leads;
create policy "org members can read leads" on public.leads for select using (organization_id=public.my_org_id());
create policy "org members can insert leads" on public.leads for insert with check (organization_id=public.my_org_id() and created_by=auth.uid());
create policy "org members can update leads" on public.leads for update using (organization_id=public.my_org_id()) with check (organization_id=public.my_org_id());
create policy "org members can delete leads" on public.leads for delete using (organization_id=public.my_org_id() and (created_by=auth.uid() or public.is_admin()));

grant execute on function public.my_org_id() to authenticated;
grant execute on function public.is_admin() to authenticated;
