-- Google Meet / Zoom / Teams integration token vault.
-- Run after meeting-provider-migration.sql. Browser users have no policies on this table;
-- only the server-side Edge Function uses the service-role client.
create table if not exists public.kip4_meeting_integrations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.kip4_organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('google_meet','zoom','microsoft_teams')),
  provider_account_email text,
  access_token_ciphertext text,
  refresh_token_ciphertext text,
  expires_at timestamptz,
  scopes text,
  status text not null default 'pending' check (status in ('pending','connected','error','disconnected')),
  oauth_state text,
  oauth_state_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id,provider)
);
alter table public.kip4_meeting_integrations enable row level security;
revoke all on public.kip4_meeting_integrations from anon, authenticated;
-- Intentionally no authenticated policies: only service-role Edge Function access.
create index if not exists kip4_meeting_integrations_org_idx
  on public.kip4_meeting_integrations(organization_id,provider);
