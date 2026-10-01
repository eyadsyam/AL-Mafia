-- Closed-test sign-ups from saidalmafia.com/beta: a name and the Google
-- account email to add to the Play tester list, nothing else. Written only by
-- the `tester_signup` edge function with the service role; no client role can
-- read or write it. `ip_hash` is a salted SHA-256 of the caller's address, kept
-- only to rate-limit; the address itself is never stored. `added_at` is set
-- when the email has been added to the Play list.
create table if not exists public.tester_signups (
  id bigint generated always as identity primary key,
  name text not null check (char_length(name) between 2 and 40),
  email text not null unique
    check (char_length(email) between 6 and 120 and email = lower(email)),
  ip_hash text not null check (char_length(ip_hash) = 64),
  source text check (source is null or char_length(source) <= 40),
  created_at timestamptz not null default now(),
  added_at timestamptz
);

create index if not exists tester_signups_ip_recent
  on public.tester_signups (ip_hash, created_at desc);
create index if not exists tester_signups_pending
  on public.tester_signups (created_at) where added_at is null;

alter table public.tester_signups enable row level security;
revoke all on table public.tester_signups from public, anon, authenticated;
grant select, insert, update, delete on table public.tester_signups to service_role;
