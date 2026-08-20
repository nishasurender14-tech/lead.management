-- KIP FINANCIAL CRM V4 COMPLETE ADD-ON
-- Run after supabase/kip-financial-v4-schema.sql.
create extension if not exists pgcrypto;

create table if not exists public.kip4_workflows (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
 name text not null, object_type text not null, enabled boolean not null default true, trigger jsonb not null default '{}'::jsonb, actions jsonb not null default '[]'::jsonb,
 created_at timestamptz not null default now(), unique(organization_id,name)
);
create table if not exists public.kip4_notifications (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
 user_id uuid references auth.users(id) on delete cascade, title text not null, body text, type text not null default 'info', read_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.kip4_audit_logs (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
 user_id uuid references auth.users(id), action text not null, object_type text, record_id uuid, before_data jsonb, after_data jsonb, created_at timestamptz not null default now()
);
create table if not exists public.kip4_teams (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
 name text not null, description text, created_at timestamptz not null default now(), unique(organization_id,name)
);
create table if not exists public.kip4_team_members (
 team_id uuid not null references public.kip4_teams(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade,
 role text not null default 'member', primary key(team_id,user_id)
);
create table if not exists public.kip4_saved_views (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
 user_id uuid references auth.users(id), object_type text not null, name text not null, filters jsonb not null default '{}'::jsonb, columns jsonb not null default '[]'::jsonb, is_shared boolean not null default false,
 unique(organization_id,user_id,object_type,name)
);
create table if not exists public.kip4_forms (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
 name text not null, object_type text not null, enabled boolean not null default true, fields jsonb not null default '[]'::jsonb, created_at timestamptz not null default now(), unique(organization_id,name)
);
create index if not exists kip4_notifications_user_idx on public.kip4_notifications(organization_id,user_id,created_at desc);
create index if not exists kip4_audit_record_idx on public.kip4_audit_logs(organization_id,record_id,created_at desc);

alter table public.kip4_workflows enable row level security;
alter table public.kip4_notifications enable row level security;
alter table public.kip4_audit_logs enable row level security;
alter table public.kip4_teams enable row level security;
alter table public.kip4_team_members enable row level security;
alter table public.kip4_saved_views enable row level security;
alter table public.kip4_forms enable row level security;

drop policy if exists kip4_workflows_org on public.kip4_workflows;
create policy kip4_workflows_org on public.kip4_workflows for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_notifications_org on public.kip4_notifications;
create policy kip4_notifications_org on public.kip4_notifications for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_audit_org on public.kip4_audit_logs;
create policy kip4_audit_org on public.kip4_audit_logs for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_teams_org on public.kip4_teams;
create policy kip4_teams_org on public.kip4_teams for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_team_members_org on public.kip4_team_members;
create policy kip4_team_members_org on public.kip4_team_members for all using(team_id in(select id from public.kip4_teams where organization_id=public.kip4_my_org())) with check(team_id in(select id from public.kip4_teams where organization_id=public.kip4_my_org()));
drop policy if exists kip4_saved_views_org on public.kip4_saved_views;
create policy kip4_saved_views_org on public.kip4_saved_views for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());
drop policy if exists kip4_forms_org on public.kip4_forms;
create policy kip4_forms_org on public.kip4_forms for all using(organization_id=public.kip4_my_org()) with check(organization_id=public.kip4_my_org());

-- Seed default teams/workflows for each new organization through an explicit helper.
create or replace function public.kip4_seed_defaults(oid uuid)
returns void language plpgsql security definer set search_path=public
as $$ begin
 insert into public.kip4_teams(organization_id,name,description) values
  (oid,'Sales','Lead and deal management'),(oid,'Consulting','Projects, applications and schemes'),(oid,'Accounts','Quotes, invoices and payments'),(oid,'Support','Tickets and customer service') on conflict do nothing;
 insert into public.kip4_workflows(organization_id,name,object_type,trigger,actions) values
  (oid,'New Lead Follow-up','leads','{"event":"created"}'::jsonb,'[{"action":"notify_owner","message":"New lead received"}]'::jsonb),
  (oid,'Deal Won → Project','deals','{"property":"stage","equals":"Closed Won"}'::jsonb,'[{"action":"create_record","object":"projects"}]'::jsonb),
  (oid,'Tender Deadline Alert','tenders','{"property":"closing_date","window_days":3}'::jsonb,'[{"action":"notify_owner","message":"Tender deadline is approaching"}]'::jsonb)
  on conflict do nothing;
end $$;
grant execute on function public.kip4_seed_defaults(uuid) to authenticated;

-- Ensure newly-created organizations receive defaults by replacing the create function.
create or replace function public.kip4_create_org(org_name text, user_name text)
returns uuid language plpgsql security definer set search_path=public
as $$ declare oid uuid; begin
 insert into public.kip4_organizations(name) values(coalesce(nullif(trim(org_name),''),'KIP Financial')) returning id into oid;
 insert into public.kip4_profiles(id,organization_id,full_name,role) values(auth.uid(),oid,coalesce(nullif(trim(user_name),''),'Administrator'),'admin') on conflict(id) do update set organization_id=excluded.organization_id,full_name=excluded.full_name;
 insert into public.kip4_pipelines(organization_id,object_type,name,stages) values
  (oid,'deals','Sales Pipeline','["New","Qualification","Needs Analysis","Proposal","Negotiation","Closed Won","Closed Lost"]'::jsonb),
  (oid,'tickets','Support Pipeline','["New","Open","Pending","Resolved","Closed"]'::jsonb) on conflict do nothing;
 perform public.kip4_seed_defaults(oid); return oid;
end $$;
grant execute on function public.kip4_create_org(text,text) to authenticated;
