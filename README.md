# Lead Management CRM

Responsive Lead Management CRM MVP for sales teams.

## Included

- Dashboard KPIs
- Lead database with add/edit/delete
- Search, status and executive filters
- Lead pipeline
- Follow-up tracking
- Browser reminders/due follow-ups
- WhatsApp contact button
- Email contact button
- CSV import/export
- Team and lead assignment view
- Conversion and source reports
- Responsive desktop/mobile UI
- Demo login

## Open the enhanced version

Open `pro.html` for the enhanced CRM interface.

**Demo login:** `admin` / `admin123`

## Current storage model

The application currently uses browser `localStorage`, so data is local to the browser/device. WhatsApp and email actions use the user's existing apps/services.

For a production multi-user deployment, connect the same UI to a secure backend/database (for example PostgreSQL/MySQL) and add server-side authentication, permissions, audit logs, and a WhatsApp Business API provider. Never put database passwords, API secrets, or service-account credentials in this public repository.
