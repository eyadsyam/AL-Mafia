# Launch gaps (release 1.1)

What was missing for launch, what was built, and what is left.

## Deploy steps (owner)

Migrations, in order, after `20260930000800`:

1. `20260930001100_delete_my_account.sql` (wraps `complete_data_deletion` with a per-player sweep, adds `delete_my_account`)
2. `20260930001200_min_app_build.sql` (new one-row table `public.app_config` with `min_build_android` / `min_build_web`, readable by any signed-in client, anonymous session included)

Edge function to deploy: `delete_account` (new). Nothing else changed on the server.

Both migrations are additive and change nothing for current builds: the minimum defaults to 0 (blocks nothing) and deletion only runs when a player asks.

## 1. Onboarding sign-in choice: done

- First launch has a new chapter after the language: «تحب تحفظ تقدمك؟». One button opens the existing account sheet (Google, create account with email + 6-digit code, sign in); the main button is «كمّل من غير تسجيل» (the install's anonymous session, untouched).
- Shown only in a build that has a server (`accountsAvailableProvider`, true when the Supabase keys are compiled in). An offline-only build keeps the original four chapters.
- Already signed in (for example after coming back from Google) the chapter says «متسجّل بـ …» and just continues.
- Later, from the profile: the account card opens the same sheet. A guest who links Google (`linkIdentity`) or an email (`updateUser`) keeps the same user id, so coins, items, rank and friends stay. Nothing new was needed server-side.
- Files: `lib/ui/account/onboarding_account_step.dart`, `lib/ui/screens/onboarding/first_run_screen.dart`, `lib/ui/account/profile_panels.dart`, test `test/widget/onboarding_account_test.dart`.
- Caveat: on the web, Google sign-in leaves the page and returns to it, so a player who chose Google on the first launch restarts the welcome chapters (language is kept); email sign-in does not leave the page.
- Not done: a capability flag that hides the Google button when the provider is off on Supabase. Today the button answers with «الخدمة مش متاحة» (`PROVIDER_OFF`) if Google is not configured. Console steps: Supabase → Authentication → Providers → Google (client id/secret), and add `mafiamaster://login-callback` plus the web origin to the allowed redirect URLs.

## 2a. In-app account deletion: done

- Account sheet (profile) and Settings → Privacy and data deletion → «احذف حسابي وبياناتي» → confirm sheet (tick box, red button, «مش دلوقتي»). Offered to guests too.
- Server: `delete_account` Edge Function → `delete_my_account(p_user)` (user id from the JWT only) → the same `complete_data_deletion` chain the operator uses, now with a sweep over every per-player table found in the catalog (push tokens, friends and requests, blocks, room invites, invite events, handle/directory, Council, Casebook, season, referral, terms, etc.) and the auth user.
- Kept on purpose: abuse reports and audit logs, payment orders and Play purchases (already detached from the person), the deletion receipt.
- Refused, with nothing deleted: while the player is in an unfinished room (`IN_MATCH`) or has a payment under review (`ORDER_OPEN`); the sheet says so in Arabic.
- The web `/delete-data` and `/privacy` pages now describe the immediate route; the sheet links to the website page (opens on the web, copies the link on Android because the app has no browser launcher).
- Tests: `supabase/tests/delete_my_account.sql` (includes a catalog sweep that fails if any user-keyed table still holds the deleted id), `test/widget/delete_account_test.dart`.
- Not done: the local match history on the phone is not erased (the sheet says so); deleting the Play-side account is Google's.

## 2b. Force update: done

- `public.app_config.min_build_android` / `min_build_web`, default 0. Set with `update public.app_config set min_build_android = 11;`. (A table, not a function: the server-surface test forbids client-callable security-definer functions.)
- The app reads that row (signing in anonymously first if needed) on start and every 30 minutes on resume, and blocks behind «حدّث التطبيق» when its build is lower. Android: «افتح Google Play»; web: «حدّث الصفحة». Any failure to read = no block.
- The app's own build number is `kAppBuildNumber` in `lib/app/app_build.dart` (no package-info plugin). A test compares it with the `+N` in `pubspec.yaml`: bump both together.
- Tests: `supabase/tests/min_app_build.sql`, `test/widget/update_gate_test.dart`.

## 2c. Offline / no network: done for the online door

- The online entry screen shows a clear offline state (Arabic sentence, what happens next, «جرّب تاني») when the room list has never loaded; once it has, the existing "may be stale" line stays. Create/join failures show the friendly sentence for their code.
- Not done: other online surfaces (vault, Council, friends) keep their own existing Arabic failure lines; none show an exception, but they do not all have a retry button.

## 2d. Friendly error copy: done for the shared path

- `lib/ui/friendly_error.dart` maps every server error code to Arabic (and English); a test reads the `ErrorCode` union in `supabase/functions/_shared/api.ts` and requires every code to land on a real sentence, so a code added later cannot reach a player raw. Rate limits now say «بتعمل حاجات كتير بسرعة» instead of a dead-connection line.
- Used by: the online entry screen, the deletion sheet. The economy/Council/daily-reward screens already map their own codes to Arabic with a generic Arabic fallback; they were not rewritten to use the shared mapper.
- Payment-order codes map to a generic sentence in the shared mapper; the payment screens keep their own copy (not touched).

## 2e. Privacy and terms: done

- Settings already had them (`LegalDocuments`, and the privacy and data screen). The account sheet now carries the same two rows, read in place, plus the deletion entry.

## Remaining / risks

- Hosted: apply the two migrations and deploy `delete_account` before shipping the build that has the sheet; before that the button answers with a friendly "try again" line.
- Android APK was not built here; the Play Store button uses `in_app_review`'s `openStoreListing`, unverified on a device.
- `kAppBuildNumber` is 10 (pubspec `1.1.0+10`).
