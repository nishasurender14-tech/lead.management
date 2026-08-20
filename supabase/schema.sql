-- Lead Management CRM Organization Edition
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

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete restrict,
  assigned_to uuid references auth.users(id) on delete set null,
  name text not null,
  company text,
  phone text,
  email text,
  city text,
  source text default 'Website',
  service text,
  status text not null default 'New' check (status in ('New','Contacted','Follow-up','Converted','Not Interested','Lost')),
  followup date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_org_idx on public.profiles(organization_id);
create index if not exists leads_org_idx on public.leads(organization_id);
create index if not exists leads_assigned_idx on public.leads(assigned_to);
create index if not exists leads_status_idx on public.leads(status);
create index if not exists leads_followup_idx on public.leads(followup);

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.leads enable row level security;

create or replace function public.my_org_id()
returns uuid language sql stable security definer set search_path=public
as $$ select organization_id from public.profiles where id=auth.uid() $$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin') $$;

create or replace function public.create_organization(org_name text, user_name text)
returns public.organizations language plpgsql security definer set search_path=public
as $$
declare o public.organizations;
begin
  if exists(select 1 from public.profiles where id=auth.uid() and organization_id is not null) then
    raise exception 'User already belongs to an organization';
  end if;
  insert into public.organizations(name,created_by) values(trim(org_name),auth.uid()) returning * into o;
  insert into public.profiles(id,full_name,role,organization_id) values(auth.uid(),nullif(trim(user_name),''),'admin',o.id)
  on conflict (id) do update set full_name=excluded.full_name,role='admin',organization_id=o.id;
  return o;
end; $$;

create or replace function public.join_organization(code text, user_name text)
returns public.organizations language plpgsql security definer set search_path=public
as $$
declare o public.organizations;
begin
  select * into o from public.organizations where upper(join_code)=upper(trim(code));
  if o.id is null then raise exception 'Invalid organization code'; end if;
  insert into public.profiles(id,full_name,role,organization_id) values(auth.uid(),nullif(trim(user_name),''),'employee',o.id)
  on conflict (id) do update set full_name=excluded.full_name,organization_id=o.id;
  return o;
end; $$;

grant execute on function public.create_organization(text,text) to authenticated;
grant execute on function public.join_organization(text,text) to authenticated;
grant execute on function public.my_org_id() to authenticated;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "org members can view organization" on public.organizations;
create policy "org members can view organization" on public.organizations for select using (id=public.my_org_id() or created_by=auth.uid());

drop policy if exists "users can view own profile" on public.profiles;
drop policy if exists "admins can view org profiles" on public.profiles;
drop policy if exists "users can update own profile" on public.profiles;
create policy "users can view own profile" on public.profiles for select using (id=auth.uid());
create policy "admins can view org profiles" on public.profiles for select using (organization_id=public.my_org_id() and public.is_admin());
create policy "users can update own profile" on public.profiles for update using (id=auth.uid()) with check (id=auth.uid());

-- Employees can work with every lead in their organization; admins can manage all organization leads.
drop policy if exists "org members can read leads" on public.leads;
drop policy if exists "org members can insert leads" on public.leads;
drop policy if exists "org members can update leads" on public.leads;
drop policy if exists "org members can delete leads" on public.leads;
create policy "org members can read leads" on public.leads for select using (organization_id=public.my_org_id());
create policy "org members can insert leads" on public.leads for insert with check (organization_id=public.my_org_id() and created_by=auth.uid());
create policy "org members can update leads" on public.leads for update using (organization_id=public.my_org_id()) with check (organization_id=public.my_org_id());
create policy "org members can delete leads" on public.leads for delete using (organization_id=public.my_org_id() and (created_by=auth.uid() or public.is_admin()));

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists leads_updated_at on public.leads;
create trigger leads_updated_at before update on public.leads for each row execute function public.set_updated_at();