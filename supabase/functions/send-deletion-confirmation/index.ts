import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Emails the signed-in citizen a link to confirm their account-deletion
// request. Called from the app right after request_account_deletion().
//
// Deploy with verify_jwt ENABLED: the caller is whoever's JWT arrives, and
// they can only ever trigger the email for their OWN pending request.
//
// Required Edge Function secrets (already set for notify-im-safe):
//   BREVO_API_KEY, BREVO_SENDER_EMAIL
//
// The emailed token is random and never stored: only its SHA-256 is saved on
// the request row, with a 24-hour expiry. confirm-deletion checks it.

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY")!;
const BREVO_SENDER_EMAIL = Deno.env.get("BREVO_SENDER_EMAIL")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const RESEND_COOLDOWN_MS = 60_000;
const TOKEN_LIFETIME_MS = 24 * 60 * 60 * 1000;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const toHex = (bytes: Uint8Array) =>
  Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return toHex(new Uint8Array(digest));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  // Who is asking? Resolve the caller from their own JWT.
  const authHeader = req.headers.get("Authorization") ?? "";
  const asCaller = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user } } = await asCaller.auth.getUser();
  if (!user || !user.email) return json({ error: "not signed in" }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: request } = await admin
    .from("account_deletion_requests")
    .select("id, confirm_email_sent_at")
    .eq("user_id", user.id)
    .eq("status", "awaiting_email")
    .order("requested_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (!request) {
    return json({ error: "There is no deletion request waiting for email confirmation." }, 404);
  }

  const lastSent = request.confirm_email_sent_at
    ? new Date(request.confirm_email_sent_at).getTime()
    : 0;
  if (Date.now() - lastSent < RESEND_COOLDOWN_MS) {
    return json({ error: "Please wait a minute before asking for another email." }, 429);
  }

  const tokenBytes = crypto.getRandomValues(new Uint8Array(32));
  const token = toHex(tokenBytes);
  const now = new Date();

  const { error: saveError } = await admin
    .from("account_deletion_requests")
    .update({
      confirm_token_hash: await sha256Hex(token),
      confirm_expires_at: new Date(now.getTime() + TOKEN_LIFETIME_MS).toISOString(),
      confirm_email_sent_at: now.toISOString(),
      updated_at: now.toISOString(),
    })
    .eq("id", request.id)
    .eq("status", "awaiting_email");
  if (saveError) return json({ error: "Could not prepare the confirmation email." }, 500);

  const link = `${SUPABASE_URL}/functions/v1/confirm-deletion?token=${token}`;
  const resp = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": BREVO_API_KEY,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      sender: { name: "SafeZone", email: BREVO_SENDER_EMAIL },
      to: [{ email: user.email }],
      subject: "Confirm your SafeZone account deletion request",
      htmlContent: `
        <p>Someone, hopefully you, asked to delete this SafeZone account and the
        personal data linked to it.</p>
        <p><a href="${link}">Yes, I want to delete my account</a></p>
        <p>After you confirm, an administrator will review the request and delete
        the account. Nothing is deleted until then, and you can cancel in the app
        under Settings → Privacy &amp; data.</p>
        <p>This link works for 24 hours. If you did not ask for this, ignore this
        email: no request reaches an administrator unless you open the link.</p>
      `,
    }),
  });
  if (!resp.ok) {
    return json({ error: "The email could not be sent. Please try again." }, 502);
  }
  return json({ sent: true });
});
