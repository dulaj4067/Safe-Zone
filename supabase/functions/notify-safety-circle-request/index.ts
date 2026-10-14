import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Called by a Postgres trigger (via pg_net) whenever a safety_circle_contacts
// row becomes 'pending' with a resolved contact_user_id - i.e. someone just
// added a real registered user to their circle and that person's consent is
// needed before any location is ever exposed to the owner. Not reachable by
// a browser/app client directly: verify_jwt is off (the trigger has no user
// session to attach) and a shared secret header takes its place instead.
//
// Required Edge Function secrets:
//   BREVO_API_KEY                 Brevo transactional email API key
//   BREVO_SENDER_EMAIL            a sender address verified in Brevo
//   SAFETY_CIRCLE_WEBHOOK_SECRET  must match the value in
//                                 sql/safety_circle_notify_trigger.sql
// Deploy with verify_jwt disabled.

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY")!;
const BREVO_SENDER_EMAIL = Deno.env.get("BREVO_SENDER_EMAIL")!;
const WEBHOOK_SECRET = Deno.env.get("SAFETY_CIRCLE_WEBHOOK_SECRET")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  if (req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }

  let contactId: string | undefined;
  try {
    const payload = await req.json();
    contactId = payload.contact_id;
  } catch {
    return new Response(JSON.stringify({ error: "invalid body" }), { status: 400 });
  }
  if (!contactId) {
    return new Response(JSON.stringify({ error: "missing contact_id" }), { status: 400 });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: contact, error: contactErr } = await supabase
    .from("safety_circle_contacts")
    .select("id, relationship, status, contact_user_id, owner_id")
    .eq("id", contactId)
    .single();

  if (contactErr || !contact || contact.status !== "pending" || !contact.contact_user_id) {
    // Not an error - the row may have already been confirmed/declined by the
    // time this runs, or isn't linked to a real user. Nothing to send.
    return new Response(JSON.stringify({ skipped: true }), { status: 200 });
  }

  const [{ data: ownerProfile }, { data: targetUser, error: userErr }] = await Promise.all([
    supabase.from("profiles").select("full_name").eq("id", contact.owner_id).single(),
    supabase.auth.admin.getUserById(contact.contact_user_id),
  ]);

  const targetEmail = targetUser?.user?.email;
  if (userErr || !targetEmail) {
    return new Response(JSON.stringify({ skipped: true, reason: "no email on file" }), { status: 200 });
  }

  const ownerName = ownerProfile?.full_name ?? "Someone";

  const emailResp = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": BREVO_API_KEY,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      sender: { name: "SafeZone", email: BREVO_SENDER_EMAIL },
      to: [{ email: targetEmail }],
      subject: `Confirm joining ${ownerName}'s SafeZone family circle`,
      htmlContent: `
        <p>You opened an invite to join <strong>${ownerName}</strong>'s SafeZone family circle.</p>
        <p>If you confirm, you and ${ownerName} will be able to see each other's location
        whenever either of you shares it. Open the SafeZone app to confirm or decline.</p>
        <p>If you didn't open this invite or don't recognize this person, decline it in the app -
        nothing is shared unless you confirm.</p>
      `,
    }),
  });

  if (!emailResp.ok) {
    const text = await emailResp.text();
    return new Response(JSON.stringify({ error: text }), { status: 502 });
  }

  return new Response(JSON.stringify({ sent: true }), { status: 200 });
});
