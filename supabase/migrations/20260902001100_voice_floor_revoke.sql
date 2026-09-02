-- The revoke that 20260902001000 should have written, applied to a database
-- that already had the functions.
--
-- `get_advisors(type: "security")` found all three of them callable over
-- `/rest/v1/rpc/…` by `anon` and by `authenticated`, which is the third time
-- this schema has met the same trap (see 20260902000700 §2): a `revoke ...
-- from public` removes the inherited grant and leaves the two explicit ones
-- that the project's default-privileges rule created.
--
-- On `claim_speaking_floor` it was a real hole rather than a lint. The
-- function takes `p_user`, so any signed-in client that knew a room id could
-- grant the floor to any player in any phase — the night included — with the
-- Edge Function and its whole policy table bypassed.
--
-- A no-op on a database built from scratch, where 20260902001000 now writes
-- the same revoke itself. Kept because it is what the live project actually
-- ran, and the migration list is the audit trail.

revoke all on function public.claim_speaking_floor(uuid, uuid, int)
  from public, anon, authenticated;
revoke all on function public.release_speaking_floor(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.purge_stale_signals()
  from public, anon, authenticated;

grant execute on function public.claim_speaking_floor(uuid, uuid, int)
  to service_role;
grant execute on function public.release_speaking_floor(uuid, uuid)
  to service_role;
grant execute on function public.purge_stale_signals()
  to service_role;
