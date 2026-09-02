-- The floor: who may speak, decided by the server (doc 10 §6.1).
--
-- `room_state.active_speaker` has existed since the first migration and has
-- been written `null` by every handler that touches the row. This is the
-- migration that lets it hold somebody, and it adds the one column that makes
-- the token safe to hand out: a deadline.
--
-- ## Why a deadline and not a release
--
-- V5: *"active speaker disconnects → token passes to the next speaker at timer
-- expiry."* A floor that is only ever given back by the client that holds it
-- is a floor that a crashed phone keeps forever, and the phase after it is a
-- room of people who cannot speak. So the grant expires on its own, and
-- `release_floor` is an optimisation — the polite path — rather than the
-- mechanism.
--
-- ## Why the claim is one statement
--
-- Two clients tapping «اتكلم» in the same tenth of a second against a
-- read-modify-write both read `null`, both write themselves, and the second
-- one wins silently. The whole check is therefore in the `where` clause of a
-- single update: the row is the lock, and exactly one of the two updates
-- matches.

alter table public.room_state
  add column if not exists speaker_until timestamptz;

comment on column public.room_state.speaker_until is
  'When the current grant lapses. A floor nobody gave back is a floor the next '
  'claimant may take (V5).';

-- ── the claim ────────────────────────────────────────────────────────────
--
-- Returns true when this call is what granted the floor. False means somebody
-- else holds it and their grant has not lapsed — an ordinary answer, and the
-- one every client gets for most of a match.
--
-- Renewing your own grant counts as a claim: a speaker who is still talking at
-- the deadline should not lose the floor to the first person with a fast
-- thumb, and `active_speaker = p_user` in the predicate is what lets them
-- extend it.

create or replace function public.claim_speaking_floor(
  p_room    uuid,
  p_user    uuid,
  p_seconds int
) returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  granted int;
begin
  update public.room_state
     set active_speaker = p_user,
         speaker_until  = now() + make_interval(secs => greatest(p_seconds, 1)),
         updated_at     = now()
   where room_id = p_room
     and (active_speaker is null
          or active_speaker = p_user
          or speaker_until is null
          or speaker_until < now());

  get diagnostics granted = row_count;
  return granted > 0;
end;
$$;

-- ── what counts as giving it back ────────────────────────────────────────
--
-- Clearing `active_speaker`, and nothing else. Every phase transition already
-- writes it null, which is why none of the six handlers that open a phase
-- needed changing for this migration: a phase change *is* a release.
--
-- `speaker_until` is therefore only meaningful beside a holder. A deadline
-- left behind by a phase that ended early is read by nobody — the claim
-- predicate's first clause matches on the null holder before it ever looks at
-- the timestamp — and the next grant overwrites it.
--
-- Giving it back early is scoped to the holder. A client that has already lost the floor to an expiry
-- must not be able to clear the next speaker's grant by finishing its own
-- sentence a moment late.

create or replace function public.release_speaking_floor(
  p_room uuid,
  p_user uuid
) returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  update public.room_state
     set active_speaker = null,
         speaker_until  = null,
         updated_at     = now()
   where room_id = p_room
     and active_speaker = p_user;
$$;

-- `from public, anon, authenticated` and not just `from public`. The project
-- carries a default-privileges rule that grants EXECUTE on new functions in
-- this schema to both roles, so a function arrives with an inherited PUBLIC
-- grant *and* two explicit ones, and revoking the first leaves the others
-- standing. On `claim_speaking_floor` that is not a lint: it takes `p_user`,
-- so a client that could call it would hand the floor to anybody, in any
-- phase, with none of `micPolicyFor`'s refusals in the way.
revoke all on function public.claim_speaking_floor(uuid, uuid, int)
  from public, anon, authenticated;
revoke all on function public.release_speaking_floor(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.claim_speaking_floor(uuid, uuid, int)
  to service_role;
grant execute on function public.release_speaking_floor(uuid, uuid)
  to service_role;

-- ── signalling rows do not accumulate ────────────────────────────────────
--
-- An SDP offer is worthless thirty seconds after it is written and a room of
-- fifteen players produces a few hundred of them per connection attempt. The
-- table has no `on delete` story of its own — the rows outlive the negotiation
-- and nothing reads them again — so they are swept on the same schedule as
-- everything else that expires (doc 10 §3.1).

create or replace function public.purge_stale_signals()
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  delete from public.signals
   where created_at < now() - interval '2 minutes';
$$;

revoke all on function public.purge_stale_signals()
  from public, anon, authenticated;
grant execute on function public.purge_stale_signals() to service_role;
