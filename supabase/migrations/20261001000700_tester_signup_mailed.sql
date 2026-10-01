-- When the welcome email (Apps Script web app, see tool/tester_mail/Code.gs)
-- answered "sent" for this sign-up. Null: not sent (duplicate, hook not
-- configured, quota, or the hook failed); the operator can resend.
alter table public.tester_signups add column if not exists mailed_at timestamptz;
