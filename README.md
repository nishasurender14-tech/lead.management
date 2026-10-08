# KIP Financial CRM V4

Client-ready CRM foundation for KIP Financial with public demo mode, authenticated live mode, business modules, analytics and AI Meeting Agent.

## Live application

https://nishasurender14-tech.github.io/lead.management/

## Included

- Public Demo Mode with sample data
- Supabase Team Login
- Automatic first-user KIP Financial organization/profile bootstrap
- Contacts, Companies, Leads, Deals, Tickets
- Activities, Tasks and Projects
- Tenders, Applications, Schemes & Subsidies, Registrations
- Documents, Services, Quotes, Invoices and Payments
- Campaigns, Reports and Forecast
- Users & Teams and Settings foundation
- AI Meeting Agent for recording → transcription → summary → decisions → action items → closure
- Private meeting recording storage
- RLS-protected CRM data

## Production setup

### 1. Database

Run the complete file below once in the client's Supabase SQL Editor:

`supabase/kip-financial-v4-schema.sql`

This single deployment file creates the CRM tables, RLS policies, first-login bootstrap function, AI meeting tables and private recording bucket.

### 2. Authentication

Create at least one confirmed Supabase Auth user in Authentication → Users.

The CRM no longer asks the user for their full name or organization name after login.

### 3. AI Meeting Agent

Deploy `supabase/functions/meeting-agent/index.ts` and configure:

- `OPENAI_API_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_ANON_KEY`
- `SUPABASE_URL`

Never put service-role or OpenAI secrets in GitHub Pages.

## Architecture

Objects → Records → Properties → Associations → Activities

Core CRM: Contacts, Companies, Leads, Deals, Tickets, Activities.

KIP business objects: Projects, Tenders, Applications, Schemes & Subsidies, Registrations, Documents, Services.

Revenue: Quotes, Invoices, Payments.

Marketing & Analytics: Campaigns, Reports, Forecast.

Administration: Users & Teams, Settings.

## Delivery note

The GitHub repository contains the application and deployment assets. Account-level Supabase actions (running SQL, creating Auth users and deploying the Edge Function) must be completed in the client's Supabase project.