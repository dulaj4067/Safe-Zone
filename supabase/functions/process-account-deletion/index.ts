import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Carries out an account-deletion request. Called from the app by an
// authority (Settings → Account deletion requests).
//
// Deploy with verify_jwt ENABLED: the caller's JWT is checked here and must
// belong to an authority/admin account. Uses the service role (built-in
// SUPABASE_SERVICE_ROLE_KEY secret) for the steps users can't do themselves.
//
// Order matters, and each step is safe to repeat if a later one fails:
//   1. mark the request 'processing'
//   2. remove the user's uploaded incident media (Storage API)
//   3. purge_user_data(): delete/detach rows that would block step 4
//   4. delete the auth user (cascades profile, family links, shares, ...)
//   5. mark the request 'completed' (its user_id is set null by step 4)

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const AUTHORITY_ROLES = ["authority", "admin"];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  // Who is asking? Resolve the caller from their own JWT.
  const authHeader = req.headers.get("Authorization") ?? "";
  const asCaller = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: callerData, error: callerErr } = await asCaller.auth.getUser();
  if (callerErr || !callerData.user) return json({ error: "Sign in again." }, 401);
  const callerId = callerData.user.id;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: callerProfile } = await admin
    .from("profiles")
    .select("role")
    .eq("id", callerId)
    .maybeSingle();
  if (!callerProfile || !AUTHORITY_ROLES.includes(callerProfile.role)) {
    return json({ error: "Only an authority can process deletion requests." }, 403);
  }

  let requestId: string | undefined;
  try {
    requestId = (await req.json()).request_id;
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  if (!requestId) return json({ error: "missing request_id" }, 400);

  const { data: request } = await admin
    .from("account_deletion_requests")
    .select("id, user_id, status")
    .eq("id", requestId)
    .maybeSingle();
  if (!request) return json({ error: "Request not found." }, 404);
  if (request.status === "completed") return json({ status: "completed" });
  if (request.status === "cancelled") return json({ error: "That request was cancelled." }, 409);
  if (!request.user_id) return json({ error: "Request has no account attached." }, 409);
  if (request.user_id === callerId) {
    return json({ error: "Another authority must process your own deletion." }, 409);
  }
  const target = request.user_id as string;

  const fail = (step: string, message: string) => {
    console.error(`process-account-deletion ${requestId} failed at ${step}: ${message}`);
    return json({ error: `Deletion stopped at "${step}". It can be retried safely.` }, 500);
  };

  // 1. processing
  await admin
    .from("account_deletion_requests")
    .update({ status: "processing", updated_at: new Date().toISOString(), processed_by: callerId })
    .eq("id", requestId);

  // 2. media files
  const { data: media, error: mediaErr } = await admin.rpc("user_media_paths", { target });
  if (mediaErr) return fail("list media", mediaErr.message);
  const byBucket = new Map<string, string[]>();
  for (const m of (media ?? []) as { bucket: string; path: string }[]) {
    byBucket.set(m.bucket, [...(byBucket.get(m.bucket) ?? []), m.path]);
  }
  for (const [bucket, paths] of byBucket) {
    for (let i = 0; i < paths.length; i += 100) {
      const { error } = await admin.storage.from(bucket).remove(paths.slice(i, i + 100));
      if (error) return fail("remove media", error.message);
    }
  }

  // 3. rows that would block deleting the user
  const { error: purgeErr } = await admin.rpc("purge_user_data", { target });
  if (purgeErr) return fail("purge data", purgeErr.message);

  // 4. the account itself
  const { error: delErr } = await admin.auth.admin.deleteUser(target);
  if (delErr && !/not found/i.test(delErr.message)) return fail("delete account", delErr.message);

  // 5. completed (user_id is now null via ON DELETE SET NULL)
  const now = new Date().toISOString();
  await admin
    .from("account_deletion_requests")
    .update({ status: "completed", completed_at: now, updated_at: now })
    .eq("id", requestId);

  return json({ status: "completed" });
});
