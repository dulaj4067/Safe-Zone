import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// The link in the deletion-confirmation email:
//   https://<project>.supabase.co/functions/v1/confirm-deletion?token=...
//
// Marks the matching request as confirmed ('awaiting_email' -> 'received'),
// which is what makes it appear for administrators. The token was emailed by
// send-deletion-confirmation; only its SHA-256 is stored.
//
// Deploy with verify_jwt DISABLED: the person opening the email link has no
// app session. The token is the credential: random, single use, 24 hours.
// (Supabase serves function responses as plain text, so this is a text page.)

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const TOKEN_PATTERN = /^[a-f0-9]{64}$/;

const text = (body: string, status = 200) =>
  new Response(body, {
    status,
    headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" },
  });

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method !== "GET") return text("Method not allowed.", 405);

  const token = new URL(req.url).searchParams.get("token") ?? "";
  if (!TOKEN_PATTERN.test(token)) {
    return text("This confirmation link is not valid.", 400);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const now = new Date().toISOString();

  const { data, error } = await admin
    .from("account_deletion_requests")
    .update({
      status: "received",
      email_confirmed_at: now,
      confirm_token_hash: null,
      confirm_expires_at: null,
      updated_at: now,
    })
    .eq("confirm_token_hash", await sha256Hex(token))
    .eq("status", "awaiting_email")
    .gt("confirm_expires_at", now)
    .select("id");

  if (error) {
    return text("Something went wrong confirming your request. Please try the link again.", 500);
  }
  if (!data || data.length === 0) {
    return text(
      "This link is invalid, has expired, or was already used.\n\n" +
        "Open SafeZone > Settings > Privacy & data to see the state of your request " +
        "or to ask for a new confirmation email.",
      400,
    );
  }

  return text(
    "Your email is confirmed.\n\n" +
      "Your account deletion request has been sent to a SafeZone administrator, who will " +
      "review it and delete your account. Nothing has been deleted yet, and you can still " +
      "cancel in the app under Settings > Privacy & data.",
  );
});
