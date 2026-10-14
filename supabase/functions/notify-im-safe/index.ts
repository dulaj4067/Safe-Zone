import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Called by the trg_notify_im_safe trigger (via pg_net) when someone presses
// "I'm Safe". Emails each confirmed family member. Same trust model as
// notify-safety-circle-request: verify_jwt is off (the trigger has no user
// session) and the shared x-webhook-secret header takes its place.
//
// Required Edge Function secrets (already set for notify-safety-circle-request):
//   BREVO_API_KEY, BREVO_SENDER_EMAIL, SAFETY_CIRCLE_WEBHOOK_SECRET
// Deploy with verify_jwt disabled.

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY")!;
const BREVO_SENDER_EMAIL = Deno.env.get("BREVO_SENDER_EMAIL")!;
const WEBHOOK_SECRET = Deno.env.get("SAFETY_CIRCLE_WEBHOOK_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

// Names are user-supplied: never interpolate them into HTML raw.
const escapeHtml = (s: string) =>
  s.replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!
  );

Deno.serve(async (req: Request) => {
  if (req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return json({ error: "unauthorized" }, 401);
  }

  let broadcastId: string | undefined;
  try {
    broadcastId = (await req.json()).broadcast_id;
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  if (!broadcastId) return json({ error: "missing broadcast_id" }, 400);

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: broadcast } = await supabase
    .from("safety_broadcasts")
    .select("id, user_id, sent_at")
    .eq("id", broadcastId)
    .maybeSingle();
  if (!broadcast) return json({ skipped: true, reason: "broadcast not found" });

  // Confirmed links in either direction.
  const { data: links, error: linkErr } = await supabase
    .from("safety_circle_contacts")
    .select("owner_id, contact_user_id")
    .eq("status", "confirmed")
    .or(`owner_id.eq.${broadcast.user_id},contact_user_id.eq.${broadcast.user_id}`);
  if (linkErr) return json({ error: linkErr.message }, 500);

  const familyIds = [
    ...new Set(
      (links ?? [])
        .map((l) => (l.owner_id === broadcast.user_id ? l.contact_user_id : l.owner_id))
        .filter((id): id is string => !!id && id !== broadcast.user_id),
    ),
  ];
  if (familyIds.length === 0) return json({ skipped: true, reason: "no confirmed family" });

  const { data: sender } = await supabase
    .from("profiles")
    .select("full_name")
    .eq("id", broadcast.user_id)
    .maybeSingle();
  const name = escapeHtml(sender?.full_name?.trim() || "A family member");
  const time = new Date(broadcast.sent_at).toLocaleString("en-GB", {
    timeZone: "Asia/Colombo",
    dateStyle: "medium",
    timeStyle: "short",
  });

  let sent = 0;
  const failures: string[] = [];
  // One email per recipient so family members don't see each other's addresses.
  for (const id of familyIds) {
    const { data: user } = await supabase.auth.admin.getUserById(id);
    const email = user?.user?.email;
    if (!email) continue;

    const resp = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "api-key": BREVO_API_KEY,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        sender: { name: "SafeZone", email: BREVO_SENDER_EMAIL },
        to: [{ email }],
        subject: `${sender?.full_name?.trim() || "A family member"} marked themselves safe`,
        htmlContent: `
          <p><strong>${name}</strong> marked themselves <strong>safe</strong> in SafeZone
          at ${escapeHtml(time)} (Sri Lanka time).</p>
          <p>Open the SafeZone app to see their latest status and location, if they're sharing it.</p>
          <p>You're receiving this because you're in ${name}'s SafeZone family circle.
          You can leave the circle at any time in the app.</p>
        `,
      }),
    });
    if (resp.ok) sent++;
    else failures.push(`${resp.status}`);
  }

  return json({ sent, failed: failures.length }, failures.length && !sent ? 502 : 200);
});
