-- KIP FINANCIAL CRM V4 + AI MEETING AGENT
-- CLIENT DEPLOYMENT: run this complete file once in the Supabase SQL Editor.
-- Project: bjmmjqdraxqxbhapbtgt
-- Safe to re-run.

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
  role text not null default 'user' check (role in ('admin','manager','user')),
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

-- AI Meeting Agent
create table if not exists public.meetings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Untitled Meeting',
  meeting_date timestamptz not null default now(),
  duration_seconds integer,
  language text,
  recording_path text,
  transcript text,
  summary text,
  closure text,
  decisions jsonb not null default '[]'::jsonb,
  customer_requirements jsonb not null default '[]'::jsonb,
  risks jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.meeting_action_items (
  id uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  task text not null,
  owner text,
  deadline text,
  priority text not null default 'Medium',
  status text not null default 'Pending',
  created_at timestamptz not null default now()
);

-- Organization lookup for the signed-in user.
create or replace function public.kip4_my_org()
returns uuid
language sql stable security definer set search_path=public
as $$ select organization_id from public.kip4_profiles where id=auth.uid() limit 1 $$;

-- First-login bootstrap. The frontend does not ask the client for name/org.
create or replace function public.kip4_create_org(org_name text, user_name text)
returns uuid
language plpgsql security definer set search_path=public
as $$
declare
  oid uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select organization_id into oid from public.kip4_profiles where id=auth.uid();
  if oid is not null then return oid; end if;

  insert into public.kip4_organizations(name)
  values(coalesce(nullif(trim(org_name),''),'KIP Financial'))
  returning id into oid;

  insert into public.kip4_profiles(id,organization_id,full_name,role)
  values(auth.uid(),oid,coalesce(nullif(trim(user_name),''),'Team Member'),'admin');

  insert into public.kip4_pipelines(organization_id,object_type,name,stages) values
    (oid,'deals','Sales Pipeline','["New","Qualification","Needs Analysis","Proposal","Negotiation","Closed Won","Closed Lost"]'::jsonb),
    (oid,'tickets','Support Pipeline','["New","Open","Pending","Resolved","Closed"]'::jsonb)
  on conflict (organization_id,object_type,name) do nothing;

  return oid;
end
$$;

-- Keep record timestamps reliable.
create or replace function public.kip4_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end $$;
drop trigger if exists kip4_records_touch on public.kip4_records;
create trigger kip4_records_touch before update on public.kip4_records
for each row execute function public.kip4_touch_updated_at();

-- RLS
alter table public.kip4_organizations enable row level security;
alter table public.kip4_profiles enable row level security;
alter table public.kip4_records enable row level security;
alter table public.kip4_associations enable row level security;
alter table public.kip4_activities enable row level security;
alter table public.kip4_pipelines enable row level security;
alter table public.kip4_properties enable row level security;
alter table public.kip4_tasks enable row level security;
alter table public.meetings enable row level security;
alter table public.meeting_action_items enable row level security;

drop policy if exists kip4_org on public.kip4_organizations;
create policy kip4_org on public.kip4_organizations for all to authenticated
using(id=public.kip4_my_org()) with check(id=public.kip4_my_org());

drop policy if exists kip4_profile on public.kip4_profiles;
create policy kip4_profile on public.kip4_profiles for all to authenticated
using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());

drop policy if exists kip4_records on public.kip4_records;
create policy kip4_records on public.kip4_records for all to authenticated
using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());

drop policy if exists kip4_associations on public.kip4_associations;
create policy kip4_associations on public.kip4_associations for all to authenticated
using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());

drop policy if exists kip4_activities on public.kip4_activities;
create policy kip4_activities on public.kip4_activities for all to authenticated
using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());

drop policy if exists kip4_pipelines on public.kip4_pipelines;
create policy kip4_pipelines on public.kip4_pipelines for all to authenticated
using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());

drop policy if exists kip4_properties on public.kip4_properties;
create policy kip4_properties on public.kip4_properties for all to authenticated
using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());

drop policy if exists kip4_tasks on public.kip4_tasks;
create policy kip4_tasks on public.kip4_tasks for all to authenticated
using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());

drop policy if exists meetings_owner_all on public.meetings;
create policy meetings_owner_all on public.meetings for all to authenticated
using(auth.uid()=user_id) with check(auth.uid()=user_id);

drop policy if exists meeting_actions_owner_all on public.meeting_action_items;
create policy meeting_actions_owner_all on public.meeting_action_items for all to authenticated
using(exists(select 1 from public.meetings m where m.id=meeting_action_items.meeting_id and m.user_id=auth.uid()))
with check(exists(select 1 from public.meetings m where m.id=meeting_action_items.meeting_id and m.user_id=auth.uid()));

-- Private recording storage. Files must live under <user-id>/...
insert into storage.buckets(id,name,public)
values('meeting-recordings','meeting-recordings',false)
on conflict(id) do update set public=false;

drop policy if exists meeting_recordings_insert on storage.objects;
create policy meeting_recordings_insert on storage.objects for insert to authenticated
with check(bucket_id='meeting-recordings' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists meeting_recordings_select on storage.objects;
create policy meeting_recordings_select on storage.objects for select to authenticated
using(bucket_id='meeting-recordings' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists meeting_recordings_update on storage.objects;
create policy meeting_recordings_update on storage.objects for update to authenticated
using(bucket_id='meeting-recordings' and (storage.foldername(name))[1]=auth.uid()::text)
with check(bucket_id='meeting-recordings' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists meeting_recordings_delete on storage.objects;
create policy meeting_recordings_delete on storage.objects for delete to authenticated
using(bucket_id='meeting-recordings' and (storage.foldername(name))[1]=auth.uid()::text);

grant execute on function public.kip4_my_org() to authenticated;
grant execute on function public.kip4_create_org(text,text) to authenticated;
