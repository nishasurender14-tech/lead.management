# Online CRM Setup

The online version uses Supabase Auth + PostgreSQL with Row Level Security.

## 1. Create Supabase project

Create a project at https://supabase.com/.

## 2. Create the database

Open **SQL Editor** in Supabase and run the complete contents of:

`supabase/schema.sql`

This creates the `leads` table and policies so each signed-in user can only read/write their own leads.

## 3. Get browser credentials

In Supabase open **Project Settings → API** and copy:

- Project URL
- `anon` / `public` key

Do **not** put a `service_role` key in the website.

## 4. Open the CRM

Deploy this repository with GitHub Pages. When the CRM opens, click **Database Setup**, paste the Project URL and anon/public key, and connect.

The credentials are stored only in that browser's local storage. They are not committed to GitHub.

## 5. Create your account

Use **Create Account** with an email and password. If email confirmation is enabled in Supabase, confirm the email before signing in.

## 6. Team usage

Each team member creates their own login. The current security model isolates leads by user account. A later team-management version can add an organization/company table, roles, shared leads, assignments and admin controls.

## Current online features

- Secure email/password authentication
- PostgreSQL-backed leads
- Row Level Security
- Add/edit/delete leads
- Dashboard and pipeline
- Search and status filtering
- Follow-up dates
- Reports
- Multi-device persistence
- Sign out
