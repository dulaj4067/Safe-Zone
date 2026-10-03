// Public landing URL for family-circle invite links:
//   https://<project>.supabase.co/functions/v1/family-invite?code=ABC123DEF456
//
// Messaging apps only make https links tappable, not custom app schemes, so
// this is the link people share. It never touches the database or accepts
// anything itself; it just hands the code to the SafeZone app, which
// accepts the invite as the signed-in user (accept_family_invite RPC) and
// then asks them to confirm.
//
// Deploy with verify_jwt disabled: the person tapping the link has no
// Supabase session in their browser.

const ANDROID_PACKAGE = "com.example.focus_app";
const CODE_PATTERN = /^[A-Za-z0-9]{6,32}$/;

Deno.serve((req: Request) => {
  const code = new URL(req.url).searchParams.get("code") ?? "";
  if (!CODE_PATTERN.test(code)) {
    return new Response("This SafeZone invite link is not valid.", {
      status: 400,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }

  const appLink = `safezone://family-invite?code=${code}`;
  const isAndroid = /android/i.test(req.headers.get("user-agent") ?? "");

  // Chrome on Android opens apps reliably through intent:// URLs and falls
  // back to the Play Store if the app isn't installed.
  const location = isAndroid
    ? `intent://family-invite?code=${code}#Intent;scheme=safezone;package=${ANDROID_PACKAGE};end`
    : appLink;

  return new Response(
    `Opening SafeZone... If nothing happens, open the SafeZone app and go to ` +
      `Family circle > Join with a code, then enter: ${code}`,
    {
      status: 302,
      headers: {
        Location: location,
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-store",
      },
    },
  );
});
