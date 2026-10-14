import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APP_ORIGIN = Deno.env.get("APP_ORIGIN") ?? "https://nishasurender14-tech.github.io";
const CALLBACK_URL = Deno.env.get("GOOGLE_REDIRECT_URI") ?? "https://nishasurender14-tech.github.io/lead.management/meeting-oauth-callback.html";
const cors = {
  "Access-Control-Allow-Origin": APP_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
const b64 = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes));
const unb64 = (value: string) => Uint8Array.from(atob(value), c => c.charCodeAt(0));
async function cryptoKey() {
  const secret = Deno.env.get("OAUTH_TOKEN_ENCRYPTION_KEY");
  if (!secret) throw new Error("Missing OAUTH_TOKEN_ENCRYPTION_KEY Edge Function secret.");
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(secret));
  return crypto.subtle.importKey("raw", digest, "AES-GCM", false, ["encrypt", "decrypt"]);
}
async function encrypt(value?: string | null) {
  if (!value) return null;
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipher = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await cryptoKey(), new TextEncoder().encode(value));
  return b64(new Uint8Array([...iv, ...new Uint8Array(cipher)]));
}
async function decrypt(value?: string | null) {
  if (!value) return null;
  const bytes = unb64(value);
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: bytes.slice(0, 12) }, await cryptoKey(), bytes.slice(12));
  return new TextDecoder().decode(plain);
}
const providerEnv = (provider: string) => {
  if (provider === "google_meet") return {
    id: Deno.env.get("GOOGLE_CLIENT_ID"), secret: Deno.env.get("GOOGLE_CLIENT_SECRET"),
    redirect: Deno.env.get("GOOGLE_REDIRECT_URI") ?? CALLBACK_URL,
  };
  if (provider === "zoom") return {
    id: Deno.env.get("ZOOM_CLIENT_ID"), secret: Deno.env.get("ZOOM_CLIENT_SECRET"),
    redirect: Deno.env.get("ZOOM_REDIRECT_URI") ?? CALLBACK_URL,
  };
  if (provider === "microsoft_teams") return {
    id: Deno.env.get("MICROSOFT_CLIENT_ID"), secret: Deno.env.get("MICROSOFT_CLIENT_SECRET"),
    redirect: Deno.env.get("MICROSOFT_REDIRECT_URI") ?? CALLBACK_URL,
  };
  throw new Error("Unsupported meeting provider.");
};
const scopes: Record<string, string> = {
  google_meet: "openid email https://www.googleapis.com/auth/calendar.events",
  zoom: "meeting:write user:read",
  microsoft_teams: "openid profile email offline_access User.Read Calendars.ReadWrite",
};
async function tokenRequest(url: string, body: URLSearchParams, basic?: string) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", ...(basic ? { Authorization: "Basic " + btoa(basic) } : {}) },
    body,
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error_description ?? data.reason ?? data.message ?? data.error ?? "OAuth token request failed.");
  return data;
}
function isoForProvider(value: string) { return new Date(value).toISOString(); }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST required." }, 405);
  try {
    const authorization = req.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) return json({ error: "Sign in to KIP CRM first." }, 401);
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) return json({ error: "Your CRM session is invalid or expired." }, 401);
    const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: profile, error: profileError } = await admin.from("kip4_profiles").select("organization_id").eq("id", user.id).single();
    if (profileError || !profile?.organization_id) return json({ error: "Your CRM user is not assigned to an organization yet." }, 403);
    const input = await req.json();
    const action = String(input.action ?? "");
    const provider = String(input.provider ?? "google_meet");
    if (!["google_meet", "zoom", "microsoft_teams"].includes(provider)) return json({ error: "Unsupported provider." }, 400);
    const env = providerEnv(provider);
    const integrationKey = { organization_id: profile.organization_id, user_id: user.id, provider };
    if (action === "status") {
      const { data } = await admin.from("kip4_meeting_integrations")
        .select("provider,provider_account_email,status,expires_at,scopes")
        .eq("user_id", user.id).eq("provider", provider).maybeSingle();
      return json({ integration: data ?? { provider, status: "disconnected" } });
    }
    if (action === "connect") {
      if (!env.id || !env.secret) return json({ error: provider === "google_meet" ? "Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in Supabase Edge Function Secrets first." : "This provider's OAuth credentials have not been configured yet." }, 400);
      const state = b64(crypto.getRandomValues(new Uint8Array(32))).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
      const { error } = await admin.from("kip4_meeting_integrations").upsert({
        ...integrationKey, status: "pending", oauth_state: state,
        oauth_state_expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id,provider" });
      if (error) throw error;
      let url: URL;
      if (provider === "google_meet") {
        url = new URL("https://accounts.google.com/o/oauth2/v2/auth");
        url.search = new URLSearchParams({ client_id: env.id, redirect_uri: env.redirect, response_type: "code", scope: scopes[provider], access_type: "offline", prompt: "consent", include_granted_scopes: "true", state }).toString();
      } else if (provider === "zoom") {
        url = new URL("https://zoom.us/oauth/authorize");
        url.search = new URLSearchParams({ client_id: env.id, redirect_uri: env.redirect, response_type: "code", state }).toString();
      } else {
        url = new URL("https://login.microsoftonline.com/common/oauth2/v2.0/authorize");
        url.search = new URLSearchParams({ client_id: env.id, redirect_uri: env.redirect, response_type: "code", response_mode: "query", scope: scopes[provider], state }).toString();
      }
      return json({ authorization_url: url.toString() });
    }
    if (action === "callback") {
      const code = String(input.code ?? "");
      const state = String(input.state ?? "");
      if (!code || !state) return json({ error: "OAuth code or state is missing." }, 400);
      const { data: row, error } = await admin.from("kip4_meeting_integrations").select("*")
        .eq("user_id", user.id).eq("provider", provider).eq("oauth_state", state)
        .gt("oauth_state_expires_at", new Date().toISOString()).maybeSingle();
      if (error || !row || row.organization_id !== profile.organization_id) return json({ error: "OAuth state is invalid, expired, or belongs to another CRM user. Start Connect again." }, 400);
      if (!env.id || !env.secret) throw new Error("OAuth client credentials are not configured in Supabase Edge Function Secrets.");
      let token;
      if (provider === "google_meet") {
        token = await tokenRequest("https://oauth2.googleapis.com/token", new URLSearchParams({ code, client_id: env.id, client_secret: env.secret, redirect_uri: env.redirect, grant_type: "authorization_code" }));
      } else if (provider === "zoom") {
        token = await tokenRequest("https://zoom.us/oauth/token", new URLSearchParams({ code, redirect_uri: env.redirect, grant_type: "authorization_code" }), env.id + ":" + env.secret);
      } else {
        token = await tokenRequest("https://login.microsoftonline.com/common/oauth2/v2.0/token", new URLSearchParams({ code, client_id: env.id, client_secret: env.secret, redirect_uri: env.redirect, grant_type: "authorization_code", scope: scopes[provider] }));
      }
      let email = user.email ?? null;
      try {
        const who = provider === "google_meet" ? await fetch("https://www.googleapis.com/oauth2/v2/userinfo", { headers: { Authorization: "Bearer " + token.access_token } })
          : provider === "zoom" ? await fetch("https://api.zoom.us/v2/users/me", { headers: { Authorization: "Bearer " + token.access_token } })
          : await fetch("https://graph.microsoft.com/v1.0/me", { headers: { Authorization: "Bearer " + token.access_token } });
        if (who.ok) { const w = await who.json(); email = w.email ?? w.mail ?? w.userPrincipalName ?? email; }
      } catch (_) { /* account email is informational only */ }
      const update = {
        provider_account_email: email,
        access_token_ciphertext: await encrypt(token.access_token),
        refresh_token_ciphertext: await encrypt(token.refresh_token ?? await decrypt(row.refresh_token_ciphertext)),
        expires_at: new Date(Date.now() + Number(token.expires_in ?? 3600) * 1000).toISOString(),
        scopes: token.scope ?? scopes[provider], status: "connected",
        oauth_state: null, oauth_state_expires_at: null, updated_at: new Date().toISOString(),
      };
      const { error: saveError } = await admin.from("kip4_meeting_integrations").update(update).eq("id", row.id);
      if (saveError) throw saveError;
      return json({ connected: true, provider, account_email: email });
    }
    if (action === "disconnect") {
      const { error } = await admin.from("kip4_meeting_integrations").update({
        status: "disconnected", access_token_ciphertext: null, refresh_token_ciphertext: null,
        oauth_state: null, oauth_state_expires_at: null, updated_at: new Date().toISOString(),
      }).eq("user_id", user.id).eq("provider", provider);
      if (error) throw error;
      return json({ disconnected: true, provider });
    }
    if (action === "create_meeting") {
      const title = String(input.title ?? "").trim();
      const start = new Date(input.start_at);
      const end = new Date(input.end_at);
      if (!title || !Number.isFinite(start.getTime()) || !Number.isFinite(end.getTime()) || end <= start) return json({ error: "A title and valid start/end times are required." }, 400);
      const { data: row, error } = await admin.from("kip4_meeting_integrations").select("*")
        .eq("user_id", user.id).eq("provider", provider).eq("status", "connected").maybeSingle();
      if (error || !row) return json({ error: "Connect this provider before creating an online meeting." }, 400);
      let access = await decrypt(row.access_token_ciphertext);
      if (!access) throw new Error("Provider access token is missing. Reconnect the account.");
      if (!row.expires_at || new Date(row.expires_at).getTime() < Date.now() + 60_000) {
        const refresh = await decrypt(row.refresh_token_ciphertext);
        if (!refresh) throw new Error("Provider token expired and no refresh token is stored. Disconnect and connect again.");
        let refreshed;
        if (provider === "google_meet") refreshed = await tokenRequest("https://oauth2.googleapis.com/token", new URLSearchParams({ client_id: env.id!, client_secret: env.secret!, refresh_token: refresh, grant_type: "refresh_token" }));
        else if (provider === "zoom") refreshed = await tokenRequest("https://zoom.us/oauth/token", new URLSearchParams({ grant_type: "refresh_token", refresh_token: refresh }), env.id + ":" + env.secret);
        else refreshed = await tokenRequest("https://login.microsoftonline.com/common/oauth2/v2.0/token", new URLSearchParams({ client_id: env.id!, client_secret: env.secret!, refresh_token: refresh, grant_type: "refresh_token", scope: scopes[provider] }));
        access = refreshed.access_token;
        const { error: refreshSaveError } = await admin.from("kip4_meeting_integrations").update({
          access_token_ciphertext: await encrypt(access),
          refresh_token_ciphertext: await encrypt(refreshed.refresh_token ?? refresh),
          expires_at: new Date(Date.now() + Number(refreshed.expires_in ?? 3600) * 1000).toISOString(),
          updated_at: new Date().toISOString(),
        }).eq("id", row.id);
        if (refreshSaveError) throw refreshSaveError;
      }
      const attendees = Array.isArray(input.attendee_emails) ? input.attendee_emails.filter((e: unknown) => typeof e === "string" && e.includes("@")).map((email: string) => ({ email })) : [];
      let meetingUrl = "";
      let providerMeetingId = "";
      let calendarEventId: string | null = null;
      if (provider === "google_meet") {
        const event = {
          summary: title, description: String(input.notes ?? ""),
          start: { dateTime: isoForProvider(start.toISOString()), timeZone: "Asia/Kolkata" },
          end: { dateTime: isoForProvider(end.toISOString()), timeZone: "Asia/Kolkata" },
          attendees: attendees.map((a: {email:string}) => ({ email: a.email })),
          conferenceData: { createRequest: { requestId: crypto.randomUUID(), conferenceSolutionKey: { type: "hangoutsMeet" } } },
        };
        const response = await fetch("https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1&sendUpdates=all", {
          method: "POST", headers: { Authorization: "Bearer " + access, "Content-Type": "application/json" }, body: JSON.stringify(event),
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error?.message ?? "Google Calendar event creation failed.");
        let eventData = data;
        meetingUrl = eventData.hangoutLink ?? eventData.conferenceData?.entryPoints?.find((x: {entryPointType:string;uri:string}) => x.entryPointType === "video")?.uri ?? "";
        providerMeetingId = eventData.id ?? ""; calendarEventId = eventData.id ?? null;
        // Google can create conference details asynchronously; briefly re-read the event before reporting failure.
        for (let attempt = 0; !meetingUrl && attempt < 6 && calendarEventId; attempt++) {
          await new Promise(resolve => setTimeout(resolve, 1000));
          const check = await fetch("https://www.googleapis.com/calendar/v3/calendars/primary/events/" + encodeURIComponent(calendarEventId), {
            headers: { Authorization: "Bearer " + access },
          });
          if (!check.ok) continue;
          eventData = await check.json();
          meetingUrl = eventData.hangoutLink ?? eventData.conferenceData?.entryPoints?.find((x: {entryPointType:string;uri:string}) => x.entryPointType === "video")?.uri ?? "";
        }
        if (!meetingUrl) throw new Error("Google Calendar created the event, but Meet has not returned a join URL yet. Check Google Calendar/Workspace Meet settings before retrying to avoid creating a duplicate event.");
      } else if (provider === "zoom") {
        const duration = Math.max(1, Math.round((end.getTime() - start.getTime()) / 60000));
        const response = await fetch("https://api.zoom.us/v2/users/me/meetings", {
          method: "POST", headers: { Authorization: "Bearer " + access, "Content-Type": "application/json" },
          body: JSON.stringify({ topic: title, type: 2, start_time: start.toISOString(), duration, timezone: "Asia/Kolkata", agenda: String(input.notes ?? "") }),
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.message ?? "Zoom meeting creation failed.");
        meetingUrl = data.join_url ?? ""; providerMeetingId = String(data.id ?? "");
      } else {
        const event = {
          subject: title, body: { contentType: "text", content: String(input.notes ?? "") },
          start: { dateTime: start.toISOString().replace("Z", ""), timeZone: "India Standard Time" },
          end: { dateTime: end.toISOString().replace("Z", ""), timeZone: "India Standard Time" },
          attendees: attendees.map((a: {email:string}) => ({ emailAddress: { address: a.email }, type: "required" })),
          isOnlineMeeting: true, onlineMeetingProvider: "teamsForBusiness",
        };
        const response = await fetch("https://graph.microsoft.com/v1.0/me/events", {
          method: "POST", headers: { Authorization: "Bearer " + access, "Content-Type": "application/json", Prefer: 'outlook.timezone="India Standard Time"' }, body: JSON.stringify(event),
        });
        const data = await response.json();
        if (!response.ok) throw new Error(data.error?.message ?? "Microsoft Teams event creation failed.");
        meetingUrl = data.onlineMeeting?.joinUrl ?? data.onlineMeetingUrl ?? ""; providerMeetingId = data.id ?? ""; calendarEventId = data.id ?? null;
        if (!meetingUrl) throw new Error("Microsoft created a calendar event but did not return a Teams URL. Check the tenant's Teams meeting policy.");
      }
      const { data: saved, error: saveError } = await admin.from("kip4_meetings").insert({
        organization_id: profile.organization_id, owner_id: user.id, title, provider,
        start_at: start.toISOString(), end_at: end.toISOString(), timezone: "Asia/Kolkata",
        meeting_url: meetingUrl, provider_meeting_id: providerMeetingId || null, calendar_event_id: calendarEventId,
        attendee_emails: attendees.map((a: {email:string}) => a.email), notes: String(input.notes ?? ""), status: "Scheduled",
        crm_object_type: input.crm_object_type ?? null, crm_record_id: input.crm_record_id ?? null,
      }).select("id,title,provider,start_at,end_at,meeting_url,provider_meeting_id,calendar_event_id,status").single();
      if (saveError) throw saveError;
      return json({ meeting: saved });
    }
    return json({ error: "Unknown action." }, 400);
  } catch (error) {
    console.error("meeting-provider error", error);
    return json({ error: error instanceof Error ? error.message : "Unexpected meeting integration error." }, 500);
  }
});
