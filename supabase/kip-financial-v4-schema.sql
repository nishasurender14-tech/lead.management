-- KIP Financial CRM V4
-- Fresh schema. Run this entire file once in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.kip4_organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.kip4_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
  full_name text,
  role text not null default 'user',
  created_at timestamptz not null default now()
);

create table if not exists public.kip4_records (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
  object_type text not null,
  properties jsonb not null default '{}'::jsonb,
  owner_id uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists kip4_records_object_idx on public.kip4_records(organization_id, object_type);
create index if not exists kip4_records_properties_idx on public.kip4_records using gin(properties);

create table if not exists public.kip4_associations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
  from_record_id uuid not null references public.kip4_records(id) on delete cascade,
  to_record_id uuid not null references public.kip4_records(id) on delete cascade,
  label text,
  created_at timestamptz not null default now(),
  unique(from_record_id,to_record_id,label)
);
create index if not exists kip4_assoc_from_idx on public.kip4_associations(from_record_id);
create index if not exists kip4_assoc_to_idx on public.kip4_associations(to_record_id);

create table if not exists public.kip4_activities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
  activity_type text not null,
  subject text not null,
  body text,
  due_at timestamptz,
  status text not null default 'Open',
  owner_id uuid references auth.users(id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.kip4_pipelines (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
  object_type text not null,
  name text not null,
  stages jsonb not null default '[]'::jsonb,
  unique(organization_id,object_type,name)
);

create table if not exists public.kip4_properties (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
  object_type text not null,
  property_key text not null,
  label text not null,
  field_type text not null default 'text',
  options jsonb not null default '[]'::jsonb,
  required boolean not null default false,
  unique(organization_id,object_type,property_key)
);

create table if not exists public.kip4_tasks (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
  title text not null,
  status text not null default 'Open',
  priority text not null default 'Normal',
  due_at timestamptz,
  owner_id uuid references auth.users(id),
  related_record_id uuid references public.kip4_records(id) on delete set null,
  created_at timestamptz not null default now()
);

create or replace function public.kip4_my_org()
returns uuid language sql stable security definer set search_path=public
as $$ select organization_id from public.kip4_profiles where id=auth.uid() limit 1 $$;

create or replace function public.kip4_create_org(org_name text, user_name text)
returns uuid language plpgsql security definer set search_path=public
as $$ declare oid uuid; begin
  insert into public.kip4_organizations(name) values(coalesce(nullif(trim(org_name),''),'KIP Financial')) returning id into oid;
  insert into public.kip4_profiles(id,organization_id,full_name,role) values(auth.uid(),oid,coalesce(nullif(trim(user_name),''),'Administrator'),'admin') on conflict(id) do update set organization_id=excluded.organization_id;
  insert into public.kip4_pipelines(organization_id,object_type,name,stages) values
    (oid,'deals','Sales Pipeline','["New","Qualification","Needs Analysis","Proposal","Negotiation","Closed Won","Closed Lost"]'::jsonb),
    (oid,'tickets','Support Pipeline','["New","Open","Pending","Resolved","Closed"]'::jsonb);
  return oid;
end $$;

alter table public.kip4_organizations enable row level security;
alter table public.kip4_profiles enable row level security;
alter table public.kip4_records enable row level security;
alter table public.kip4_associations enable row level security;
alter table public.kip4_activities enable row level security;
alter table public.kip4_pipelines enable row level security;
alter table public.kip4_properties enable row level security;
alter table public.kip4_tasks enable row level security;

drop policy if exists kip4_org on public.kip4_organizations;
create policy kip4_org on public.kip4_organizations for all using(id=public.kip4_my_org()) with check(id=public.kip4_my_org());
drop policy if exists kip4_profile on public.kip4_profiles;
create policy kip4_profile on public.kip4_profiles for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_records on public.kip4_records;
create policy kip4_records on public.kip4_records for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_associations on public.kip4_associations;
create policy kip4_associations on public.kip4_associations for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_activities on public.kip4_activities;
create policy kip4_activities on public.kip4_activities for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_pipelines on public.kip4_pipelines;
create policy kip4_pipelines on public.kip4_pipelines for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_properties on public.kip4_properties;
create policy kip4_properties on public.kip4_properties for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_tasks on public.kip4_tasks;
create policy kip4_tasks on public.kip4_tasks for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());

grant execute on function public.kip4_my_org() to authenticated;
grant execute on function public.kip4_create_org(text,text) to authenticated;
