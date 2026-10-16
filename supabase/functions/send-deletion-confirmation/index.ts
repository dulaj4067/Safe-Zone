import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Emails the signed-in citizen a 6-digit code that confirms their account-
// deletion request. Called from the app right after request_account_deletion()
// and again when they tap "Resend". They type the code into the app, where the
// confirm_account_deletion() function checks it.
//
// Deploy with verify_jwt ENABLED: the caller is whoever's JWT arrives, and
// they can only ever trigger the email for their OWN pending request.
//
// Required Edge Function secrets (already set for notify-im-safe):
//   BREVO_API_KEY, BREVO_SENDER_EMAIL
//
// The code is random and never stored: only sha256(request_id + ":" + code)
// is saved on the request row, with a 30-minute expiry.

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY")!;
const BREVO_SENDER_EMAIL = Deno.env.get("BREVO_SENDER_EMAIL")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const RESEND_COOLDOWN_MS = 60_000;
const CODE_LIFETIME_MS = 30 * 60 * 1000;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

// Uniform 6-digit code from the OS random source (rejection sampling, so no
// modulo bias).
function sixDigitCode() {
  const limit = Math.floor(0xffffffff / 1_000_000) * 1_000_000;
  const buf = new Uint32Array(1);
  do {
    crypto.getRandomValues(buf);
  } while (buf[0] >= limit);
  return String(buf[0] % 1_000_000).padStart(6, "0");
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

  const code = sixDigitCode();
  const now = new Date();

  const { error: saveError } = await admin
    .from("account_deletion_requests")
    .update({
      confirm_code_hash: await sha256Hex(`${request.id}:${code}`),
      confirm_expires_at: new Date(now.getTime() + CODE_LIFETIME_MS).toISOString(),
      confirm_email_sent_at: now.toISOString(),
      confirm_attempts: 0,
      updated_at: now.toISOString(),
    })
    .eq("id", request.id)
    .eq("status", "awaiting_email");
  if (saveError) return json({ error: "Could not prepare the confirmation email." }, 500);

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
      subject: `Your SafeZone confirmation code: ${code}`,
      htmlContent: `
        <p>Someone, hopefully you, asked to delete this SafeZone account and the
        personal data linked to it.</p>
        <p>Your confirmation code is:</p>
        <p style="font-size:28px;letter-spacing:6px;font-weight:bold">${code}</p>
        <p>Type it into the SafeZone app (Settings → Privacy &amp; data) to confirm.
        It works for 30 minutes.</p>
        <p>After you confirm, an administrator will review the request and delete
        the account. Nothing is deleted until then, and you can cancel in the app.</p>
        <p>If you did not ask for this, ignore this email: no request reaches an
        administrator unless the code is entered in the app.</p>
      `,
    }),
  });
  if (!resp.ok) {
    return json({ error: "The email could not be sent. Please try again." }, 502);
  }
  return json({ sent: true });
});
