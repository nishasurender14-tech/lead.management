# KIP Financial CRM

Fresh CRM V4 rebuild for KIP Financial.

## Architecture

Objects → Records → Properties → Associations → Activities

Core CRM: Contacts, Companies, Leads, Deals, Tickets, Activities.
KIP business objects: Projects, Tenders, Applications, Schemes & Subsidies, Registrations, Documents, Services.
Revenue: Quotes, Invoices, Payments.
Marketing & Analytics: Campaigns, Reports, Forecast.
Administration: Users & Teams, Settings.

## Setup

1. Open the GitHub Pages site: https://nishasurender14-tech.github.io/lead.management/
2. In Supabase SQL Editor, run `supabase/kip-financial-v4-schema.sql` once.
3. Open the site and create the first account.
4. The first account creates the KIP Financial organization and administrator profile.

The V4 schema uses isolated `kip4_` tables. It does not depend on the previous CRM tables.
