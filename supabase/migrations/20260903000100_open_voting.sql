-- Visible commitment (doc 12 §3.6).
--
-- ## What this changes, and what it deliberately does not
--
-- `votes_read` (20260902000700) lets a member read a ballot only once the day
-- has closed. That is doc 10 §4's rule and it is the right default: *"a running
-- count is a coordination channel the offline game does not have."*
--
-- Doc 12 §3.6 asks for the opposite, and — this is the part that matters — it
-- asks for it knowingly:
--
--   "vote intention is public and changeable until the timer ends, then
--    locked. Watching someone switch under pressure is real information, and it
--    is only possible online. This deliberately differs from offline (secret
--    ballot) — and that difference is a *feature* of online, not an
--    inconsistency. Make it a room setting."
--
-- So this is not an override of doc 10. It is doc 10's rule becoming the OFF
-- position of a switch. A room that does not set `openVoting` reads exactly as
-- it did before this file existed, because the new clause can only ever widen
-- and it is false unless the host chose otherwise.
--
-- ## Why a security-definer helper rather than a join
--
-- The setting lives in `rooms.settings`, and `rooms` has RLS of its own. A
-- policy on `votes` that joined `rooms` would evaluate that table's policy for
-- every candidate row, and `rooms_member_read` is itself a membership lookup —
-- so the ballot read would cost a nested policy evaluation per vote, and would
-- break outright the day somebody narrows `rooms` further. The helper below is
-- the same shape as `private.is_room_member`, for the same reasons, and is
-- revoked from `public` and granted by name.
--
-- ## What is still never readable early
--
-- Night actions. `night_actions_own_read` is untouched and this file adds
-- nothing beside it. A night that could be watched forming is the leak doc 05
-- exists to prevent, and **no room setting may switch it on**.

create or replace function private.room_has_open_voting(target_room uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    (select (r.settings ->> 'openVoting')::boolean
       from public.rooms r
      where r.id = target_room),
    false
  );
$$;

revoke all on function private.room_has_open_voting(uuid) from public;
grant execute on function private.room_has_open_voting(uuid)
  to anon, authenticated, service_role;

comment on function private.room_has_open_voting(uuid) is
  'Whether this room shows ballots while the day is open (doc 12 §3.6). '
  'Read from rooms.settings, never from the request.';

drop policy if exists votes_read on public.votes;

create policy votes_read on public.votes
  for select
  to authenticated
  using (
    voter_id = (select auth.uid())
    or (
      private.is_room_member(room_id)
      and (
        private.room_has_open_voting(room_id)
        or exists (
          select 1 from public.room_state s
          where s.room_id = votes.room_id
            and (s.phase <> 'vote' or s.phase_number > votes.day)
        )
      )
    )
  );

comment on policy votes_read on public.votes is
  'Own ballot always; the room''s ballots once the day closes, or while it is '
  'open when rooms.settings.openVoting is true (doc 12 §3.6).';
