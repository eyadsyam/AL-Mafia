-- O8 — "client clock is 10 minutes off → timers render against
-- `phase_ends_at` with skew correction. Client clock is never trusted."
--
-- Skew correction needs two readings taken at the same moment: the server's
-- clock and the device's. The deadline itself gives the first only if the
-- client already knows the offset, so there has to be one call whose whole
-- answer is "what time is it where the deadlines are made".
--
-- PostgREST does not hand the response `Date` header to the Dart client, so
-- this is that call. It is deliberately the cheapest statement in the schema:
-- every full read makes it, and it touches nothing.

create or replace function public.server_now()
returns timestamptz
language sql
stable
as $$
  select now();
$$;

grant execute on function public.server_now() to anon, authenticated;
