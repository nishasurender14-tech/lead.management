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
## Online meeting provider integration (Google Meet first)

### Provider integration assets
- `supabase/meeting-provider-migration.sql`: meetings table.
- `supabase/meeting-integrations-security-migration.sql`: private integration/token table. Run both in Supabase SQL Editor, in that order.
- `supabase/functions/meeting-provider/index.ts`: server-side OAuth, encrypted token storage, Google Meet event creation, and staged Zoom/Teams support.
- `meeting-oauth-callback.html`: GitHub Pages OAuth callback. Its redirect URI must exactly match the OAuth client configuration.

### Google OAuth setup
1. In Google Cloud Console, select/create the project that owns your OAuth client.
2. Enable **Google Calendar API**.
3. Configure the OAuth consent screen. Add the Google account(s) that will connect the CRM as test users while the app is in Testing.
4. Create/select an OAuth client of type **Web application**.
5. Add this exact Authorized redirect URI (no trailing slash):
   `https://nishasurender14-tech.github.io/lead.management/meeting-oauth-callback.html`
6. In Supabase Dashboard → Edge Functions → Secrets, set:
   - `GOOGLE_CLIENT_ID` = OAuth client ID
   - `GOOGLE_CLIENT_SECRET` = OAuth client secret
   - `GOOGLE_REDIRECT_URI` = the exact URI above
   - `OAUTH_TOKEN_ENCRYPTION_KEY` = a long random private value generated locally (never commit or send it in chat)
   - `APP_ORIGIN` = `https://nishasurender14-tech.github.io`
7. Supabase provides `SUPABASE_URL`, `SUPABASE_ANON_KEY` / publishable key and `SUPABASE_SERVICE_ROLE_KEY` / secret key in the Edge Function runtime. Do not put service-role keys in the website or GitHub.
8. Deploy `meeting-provider` Edge Function. See the repository README setup steps below.

Google OAuth may need the consent screen published/verified for external production use. Until then, only listed test users may connect. Creating a Google Meet link uses Google Calendar event creation and requires Calendar permissions.

### Deploy the Edge Function
From a local clone of this repository, with Supabase CLI installed:
```sh
supabase login
supabase link --project-ref bjmmjqdraxqxbhapbtgt
supabase functions deploy meeting-provider
```
Set secrets from the Supabase Dashboard or use a local ignored env file. Never commit real secrets. Verify function deployment in Supabase → Edge Functions → meeting-provider.

### Test Google Meet
1. Sign in to the live CRM using the same browser/profile that opens the callback page.
2. Open Meetings & AI → Connect Google Meet.
3. Approve Calendar access and return to CRM.
4. Create a test meeting 10–15 minutes in the future with a test attendee.
5. Confirm the meeting row has a real `meeting_url` and opens a Google Meet URL. Check the Google Calendar event too.

Zoom and Microsoft Teams UI/actions are staged for later; their client credentials, redirect URIs and provider consent/app setup are required before enabling those connections. Keep their credentials unset until ready.
