# CRM v2 backend

Run `supabase/crm_v2.sql` in the Supabase SQL Editor after the existing `supabase/schema.sql`.

This adds server-backed tables for Accounts, Contacts, Deals, Activities, Campaigns and Audit Logs, all scoped by `organization_id` with RLS.

The existing `crm.html` remains the UI foundation. The next frontend wiring step should replace browser `localStorage` with Supabase Auth + the tables in `crm_v2.sql`.
