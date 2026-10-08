-- KIP AI Meeting Agent MVP
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
  task text not null, owner text, deadline text,
  priority text not null default 'Medium',
  status text not null default 'Pending',
  created_at timestamptz not null default now()
);
alter table public.meetings enable row level security;
alter table public.meeting_action_items enable row level security;
drop policy if exists "meetings_owner_all" on public.meetings;
create policy "meetings_owner_all" on public.meetings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "meeting_actions_owner_all" on public.meeting_action_items;
create policy "meeting_actions_owner_all" on public.meeting_action_items for all using (exists (select 1 from public.meetings m where m.id = meeting_action_items.meeting_id and m.user_id = auth.uid())) with check (exists (select 1 from public.meetings m where m.id = meeting_action_items.meeting_id and m.user_id = auth.uid()));
insert into storage.buckets (id,name,public) values ('meeting-recordings','meeting-recordings',false) on conflict (id) do nothing;
drop policy if exists "meeting_recordings_insert" on storage.objects;
create policy "meeting_recordings_insert" on storage.objects for insert to authenticated with check (bucket_id='meeting-recordings' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "meeting_recordings_select" on storage.objects;
create policy "meeting_recordings_select" on storage.objects for select to authenticated using (bucket_id='meeting-recordings' and (storage.foldername(name))[1]=auth.uid()::text);