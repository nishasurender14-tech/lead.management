-- Lead Management CRM - Supabase schema
create extension if not exists pgcrypto;

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  company text,
  phone text,
  email text,
  city text,
  source text default 'Website',
  service text,
  status text not null default 'New' check (status in ('New','Contacted','Follow-up','Converted','Not Interested','Lost')),
  assigned_to text,
  followup date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists leads_owner_id_idx on public.leads(owner_id);
create index if not exists leads_status_idx on public.leads(status);
create index if not exists leads_followup_idx on public.leads(followup);

alter table public.leads enable row level security;

drop policy if exists "Users can read own leads" on public.leads;
drop policy if exists "Users can insert own leads" on public.leads;
drop policy if exists "Users can update own leads" on public.leads;
drop policy if exists "Users can delete own leads" on public.leads;

create policy "Users can read own leads" on public.leads for select using (auth.uid() = owner_id);
create policy "Users can insert own leads" on public.leads for insert with check (auth.uid() = owner_id);
create policy "Users can update own leads" on public.leads for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "Users can delete own leads" on public.leads for delete using (auth.uid() = owner_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists leads_updated_at on public.leads;
create trigger leads_updated_at before update on public.leads for each row execute function public.set_updated_at();
