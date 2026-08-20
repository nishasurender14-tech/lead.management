# Organization CRM Setup

## 1. Supabase
Create/open your Supabase project and open **SQL Editor**.

Run the complete contents of `supabase/schema.sql`.

## 2. API credentials
In **Project Settings → API**, copy:
- Project URL
- `anon` / `public` key

Never put a `service_role` key in the browser.

## 3. Authentication URL
In **Authentication → URL Configuration** set:

Site URL:
`https://nishasurender14-tech.github.io/lead.management/`

Redirect URL:
`https://nishasurender14-tech.github.io/lead.management/**`

Keep the Email provider enabled. If email confirmation is enabled, users must confirm their email before signing in.

## 4. First organization admin
Open the CRM and create an account. After email confirmation/sign-in, the CRM asks for organization setup. Create your organization. The first creator becomes **Admin**.

## 5. Add employees
Admin → Team → copy the **Organization Code**.

Give the code to employees. Each employee creates their own account, confirms their email if required, then uses **Join Organization** and enters the code.

## 6. Organization model
The CRM now stores:
- organizations
- employee profiles and roles
- shared organization leads
- lead creator
- lead assignment
- organization-level Row Level Security

Employees can access the shared leads of their organization. Admins can view the organization team and all organization leads.

## 7. GitHub Pages
The `main` branch is the published branch. After changes are merged to `main`, GitHub Pages publishes the updated CRM.
