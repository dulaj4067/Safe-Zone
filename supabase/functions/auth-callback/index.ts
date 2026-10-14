// Where Supabase Auth sends people after they click the link in a sign-up
// confirmation or password-reset email:
//   https://<project>.supabase.co/functions/v1/auth-callback?code=...
//
// By the time the browser lands here, Supabase has already verified the
// link. On Android this hands the one-time code to the SafeZone app
// (safezone://login-callback), which signs the person in — or, for a reset
// link, asks for a new password. The code only works on the phone that
// started the flow (PKCE), so other devices get instructions instead.
//
// Like family-invite, it never touches the database. Deploy with verify_jwt
// disabled (the person clicking the email link has no session). Add this URL
// to Authentication → URL Configuration → Redirect URLs, and set it as the
// Site URL.

const ANDROID_PACKAGE = "com.example.focus_app";
const CODE_PATTERN = /^[A-Za-z0-9-]{8,128}$/;

const text = (body: string, status = 200) =>
  new Response(body, {
    status,
    headers: { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" },
  });

Deno.serve((req: Request) => {
  const params = new URL(req.url).searchParams;

  const error = params.get("error_description") ?? params.get("error");
  if (error) {
    return text(
      `SafeZone couldn't confirm this link: ${error.slice(0, 200)}\n\n` +
        "The link may have expired or already been used. Open the SafeZone app: " +
        "use 'Resend confirmation email' on the sign-in screen, or 'Forgot password?' " +
        "to get a new reset link.",
      400,
    );
  }

  const code = params.get("code") ?? "";
  const isAndroid = /android/i.test(req.headers.get("user-agent") ?? "");

  if (isAndroid && CODE_PATTERN.test(code)) {
    return new Response("Opening SafeZone...", {
      status: 302,
      headers: {
        Location:
          `intent://login-callback?code=${code}#Intent;scheme=safezone;` +
          `package=${ANDROID_PACKAGE};end`,
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-store",
      },
    });
  }

  return text(
    "Your email link worked.\n\n" +
      "Signing up? Your email is confirmed - open the SafeZone app and sign in.\n\n" +
      "Resetting your password? Open the reset link from the email on the phone " +
      "where you asked for it, so SafeZone can let you choose a new password.",
  );
});
