-- KIP CRM Pro V3 migration
-- Run after crm-v2-schema.sql

alter table public.crm_leads add column if not exists score integer not null default 0;
alter table public.crm_leads add column if not exists tags jsonb not null default '[]'::jsonb;
alter table public.crm_leads add column if not exists next_follow_up timestamptz;
alter table public.crm_leads add column if not exists converted_at timestamptz;
alter table public.crm_leads add column if not exists lost_reason text;

alter table public.crm_deals add column if not exists lost_reason text;
alter table public.crm_deals add column if not exists source text;

create table if not exists public.crm_notes (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.crm_organizations(id) on delete cascade,
 owner_id uuid references auth.users(id), lead_id uuid references public.crm_leads(id) on delete cascade,
 contact_id uuid references public.crm_contacts(id) on delete cascade, account_id uuid references public.crm_accounts(id) on delete cascade,
 deal_id uuid references public.crm_deals(id) on delete cascade, body text not null, created_at timestamptz not null default now()
);
create table if not exists public.crm_tags (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.crm_organizations(id) on delete cascade,
 name text not null, created_at timestamptz not null default now(), unique(organization_id,name)
);
create table if not exists public.crm_lead_events (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.crm_organizations(id) on delete cascade,
 lead_id uuid not null references public.crm_leads(id) on delete cascade, user_id uuid references auth.users(id), event_type text not null,
 description text, created_at timestamptz not null default now()
);

alter table public.crm_notes enable row level security;
alter table public.crm_tags enable row level security;
alter table public.crm_lead_events enable row level security;
create policy crm_notes_all on public.crm_notes for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());
create policy crm_tags_all on public.crm_tags for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());
create policy crm_lead_events_all on public.crm_lead_events for all using (organization_id=public.crm_my_org()) with check (organization_id=public.crm_my_org());

create or replace function public.crm_convert_lead(p_lead uuid, make_deal boolean default true)
returns jsonb language plpgsql security definer set search_path=public as $$
declare l crm_leads%rowtype; c uuid; a uuid; d uuid;
begin
 select * into l from crm_leads where id=p_lead and organization_id=crm_my_org();
 if l.id is null then raise exception 'Lead not found'; end if;
 insert into crm_accounts(organization_id,owner_id,name) values(l.organization_id,l.owner_id,coalesce(l.company,l.name)) returning id into a;
 insert into crm_contacts(organization_id,owner_id,lead_id,account_id,name,email,phone) values(l.organization_id,l.owner_id,l.id,a,l.name,l.email,l.phone) returning id into c;
 if make_deal then insert into crm_deals(organization_id,owner_id,lead_id,contact_id,account_id,title) values(l.organization_id,l.owner_id,l.id,c,a,coalesce(l.company,l.name)||' Deal') returning id into d; end if;
 update crm_leads set status='Converted',converted_at=now(),updated_at=now() where id=l.id;
 insert into crm_lead_events(organization_id,lead_id,user_id,event_type,description) values(l.organization_id,l.id,auth.uid(),'converted','Lead converted to Contact and Account');
 return jsonb_build_object('contact_id',c,'account_id',a,'deal_id',d);
end; $$;
grant execute on function public.crm_convert_lead(uuid,boolean) to authenticated;
