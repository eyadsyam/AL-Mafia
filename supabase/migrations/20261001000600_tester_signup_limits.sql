-- Tester sign-up limits that count every attempt, atomically, and keep no
-- address beyond the hour it is needed for (review of 20261001000500).
--
-- `tester_signup_attempt` is called by the `tester_signup` edge function
-- (service role) before anything else, including duplicate and honeypot
-- requests. One upsert per bucket increments a per-hour counter: the caller's
-- address HMAC, and one global bucket. Rows older than two hours are removed on
-- the way, so the address HMAC lives at most two hours. The sign-up table no
-- longer stores it at all.
create table if not exists public.tester_signup_attempts (
  bucket text not null check (char_length(bucket) between 3 and 70),
  hour timestamptz not null,
  n integer not null default 0,
  primary key (bucket, hour)
);
alter table public.tester_signup_attempts enable row level security;
revoke all on table public.tester_signup_attempts from public, anon, authenticated;
grant select, insert, update, delete on table public.tester_signup_attempts to service_role;

create or replace function public.tester_signup_attempt(p_address text)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare
  this_hour timestamptz := date_trunc('hour', now());
  mine integer;
  everyone integer;
begin
  if p_address is null or char_length(p_address) <> 64 then
    raise exception 'BAD_ADDRESS';
  end if;
  delete from public.tester_signup_attempts where hour < this_hour - interval '1 hour';
  insert into public.tester_signup_attempts as a (bucket, hour, n)
    values ('ip:' || p_address, this_hour, 1)
    on conflict (bucket, hour) do update set n = a.n + 1
    returning n into mine;
  insert into public.tester_signup_attempts as a (bucket, hour, n)
    values ('all', this_hour, 1)
    on conflict (bucket, hour) do update set n = a.n + 1
    returning n into everyone;
  return mine <= 5 and everyone <= 300;
end $$;
revoke all on function public.tester_signup_attempt(text) from public, anon, authenticated;
grant execute on function public.tester_signup_attempt(text) to service_role;

drop index if exists public.tester_signups_ip_recent;
alter table public.tester_signups drop column if exists ip_hash;
