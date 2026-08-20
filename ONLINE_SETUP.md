# KIP Financial CRM V4 — Online Setup

## 1. Database

Open your Supabase project → SQL Editor → New Query.

Run the complete file:

`supabase/kip-financial-v4-schema.sql`

This creates the fresh V4 CRM tables with the `kip4_` prefix and enables Row Level Security.

## 2. Web app

Open:

https://nishasurender14-tech.github.io/lead.management/

The root URL is now the only main CRM entry point.

## 3. First account

Click Create account. The first successful session asks for your name and organization. The default organization is KIP Financial.

## 4. CRM model

Contacts, Companies, Leads, Deals and Tickets are first-class CRM objects. KIP-specific objects include Projects, Tenders, Applications, Schemes & Subsidies, Registrations and Documents. Revenue includes Services, Quotes, Invoices and Payments. Records use JSON properties, two-way association records, activities and pipelines.

## 5. Important

Do not use the old CRM HTML pages. They were removed from the main application. The V4 database is isolated from the previous CRM schema so the old data is not silently mixed into the new system.
