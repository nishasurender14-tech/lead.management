# KIP AI Meeting Agent — MVP

Built as a separate module inside the existing KIP Lead Management repository.

## Flow
Meeting recording -> Supabase Storage -> Edge Function -> Speech-to-text -> AI analysis -> Meeting + Action Items in Supabase -> Results dashboard.

## Setup
1. Run `supabase/meeting-agent-schema.sql` in the Supabase SQL Editor.
2. Deploy `supabase/functions/meeting-agent/index.ts` as a Supabase Edge Function named `meeting-agent`.
3. Add the Edge Function secret `OPENAI_API_KEY`.
4. Keep the OpenAI key out of browser code.
5. The UI is `meeting-agent/index.html`.

## Current AI output
- Meeting title
- Language
- Summary
- Key discussions
- Customer requirements
- Decisions
- Action items: task, owner, deadline, priority
- Risks
- Meeting closure
- Next follow-up

## Planned next
Email delivery, WhatsApp follow-up, speaker identification, Google Meet/Zoom/Teams integrations, and KIP CRM lead updates.
