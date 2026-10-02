# Accounts — owner setup at release (1.1)

The app code is done (lib/transport/account_auth.dart, lib/ui/account/*).
These switches live in consoles and are flipped **only when the big update
ships** (nothing is published before the owner says so).

## 1. Google sign-in
1. Google Cloud Console → the project that owns Play → APIs & Services →
   OAuth consent screen: External, app name «سيد المافيا / Mafia Master»,
   support email, privacy URL https://almafia.vercel.app/privacy/, scopes:
   email, profile, openid. Publish the consent screen.
2. Credentials → Create OAuth client ID → **Web application** (Supabase does
   the exchange). Authorized redirect URI:
   `https://hezjbrnveajypfqmjfnh.supabase.co/auth/v1/callback`.
3. Supabase → Authentication → Sign In / Providers → Google: enable, paste
   the client ID and secret (owner pastes the secret; never in chat).

## 2. Supabase auth settings
- Authentication → Sign In / Providers → **Allow manual linking: ON** (a
  guest links Google to the identity that already holds their coins).
- Email: minimum password length 8; OTP length 6 (already 6); confirm email ON.
- URL Configuration → Redirect URLs: add `mafiamaster://login-callback` and
  `https://almafia.vercel.app/**`.
- Email Templates → Reset password: subject «كلمة سر جديدة لحسابك · مافيا ماستر»,
  body = `supabase/templates/recovery.html` (carries `{{ .Token }}`).

## 3. Verify on a phone (Alpha)
Guest → Profile → «خلّي حسابك معاك» → Google → back in the app, the card
shows the Gmail and coins unchanged. Create with email → 6-digit code →
password. Sign out → sign in with password. Forgot password → code → new
password. «تذكرني» off → relaunch → signed out; guests stay.
