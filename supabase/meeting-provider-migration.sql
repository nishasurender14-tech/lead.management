-- KIP Financial CRM meeting provider foundation
-- Run once after kip-financial-v4-schema.sql

create table if not exists public.kip4_meetings (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
  owner_id uuid references auth.users(id) on delete set null,
  title text not null,
  provider text not null default 'none' check (provider in ('google_meet','zoom','microsoft_teams','none')),
  start_at timestamptz not null,
  end_at timestamptz,
  timezone text not null default 'Asia/Kolkata',
  meeting_url text,
  provider_meeting_id text,
  calendar_event_id text,
  attendee_emails jsonb not null default '[]'::jsonb,
  notes text,
  status text not null default 'Scheduled' check (status in ('Scheduled','Completed','Cancelled')),
  crm_object_type text,
  crm_record_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists kip4_meetings_org_start_idx
  on public.kip4_meetings(organization_id, start_at desc);

create index if not exists kip4_meetings_record_idx
  on public.kip4_meetings(organization_id, crm_object_type, crm_record_id);

alter table public.kip4_meetings enable row level security;

drop policy if exists kip4_meetings_org on public.kip4_meetings;
create policy kip4_meetings_org on public.kip4_meetings
for all to authenticated
using (organization_id=public.kip4_my_org())
with check (organization_id=public.kip4_my_org());

drop trigger if exists kip4_meetings_touch on public.kip4_meetings;
create trigger kip4_meetings_touch
before update on public.kip4_meetings
for each row execute function public.kip4_touch_updated_at();

grant select, insert, update, delete on public.kip4_meetings to authenticated;
