-- The anti-cheat boundary (doc 10 §4.1, §10).
--
-- Read this file as the answer to one question: *what can a client with a
-- valid anonymous token, and a willingness to craft its own PostgREST
-- requests, actually select?*
--
--   rooms                — the room it is in, minus the seed (via a view)
--   room_players_public  — everyone's public fields; its own role, nobody else's
--   room_state           — the phase and the public payload
--   night_actions        — its own rows only
--   votes                — its own rows, plus everyone's once the day closed
--   whisper_meta         — the graph for its room
--   whisper_content      — only whispers it sent or received
--   signals              — only signals addressed to it
--
-- Writes: **none**, to any game table. Every mutation goes through an Edge
-- Function running as the service role, which is what makes O17 and O18
-- ("post a vote for someone else", "submit an action for a role you do not
-- have") unreachable rather than merely validated.

-- ── helpers ──────────────────────────────────────────────────────────────
--
-- `security definer` and a pinned `search_path`: a helper that resolved
-- `room_players` through the caller's search_path would be a way to feed it a
-- different table.

create or replace function public.is_room_member(target_room uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.room_players
    where room_id = target_room and user_id = auth.uid()
  );
$$;

revoke all on function public.is_room_member(uuid) from public;
grant execute on function public.is_room_member(uuid) to authenticated, anon;

-- ── rooms ────────────────────────────────────────────────────────────────
--
-- The seed is the reason clients never touch `rooms` directly. Doc 10 §10:
-- "`match_seed` is never sent to clients (it would let them predict
-- tie-breaks)". A column-level grant would still leak it through `select *`
-- from a future migration, so the client-facing surface is a view.

create or replace view public.rooms_public
with (security_invoker = true)
as
  select id, code, host_id, status, settings, created_at, ended_at
  from public.rooms;

drop policy if exists rooms_member_read on public.rooms;
create policy rooms_member_read on public.rooms
  for select
  using (public.is_room_member(id));

-- No insert/update/delete policy anywhere on `rooms`. With RLS enabled and no
-- policy, a client write is refused; the Edge Functions bypass RLS as the
-- service role.

grant select on public.rooms_public to authenticated, anon;

-- ── room_players ─────────────────────────────────────────────────────────
--
-- Clients read this view and never the base table (doc 10 §4.1). `role` is
-- returned only for the caller's own row.
--
-- `security_invoker = true` matters: without it the view would run as its
-- owner and RLS on the base table would not apply, which would turn the
-- redaction below into the *only* thing standing between a client and the role
-- table. With it, both apply.

create or replace view public.room_players_public
with (security_invoker = true)
as
  select
    room_id,
    user_id,
    name,
    seat,
    alive,
    connected,
    last_seen,
    case when user_id = auth.uid() then role else null end as role
  from public.room_players;

drop policy if exists room_players_room_read on public.room_players;
create policy room_players_room_read on public.room_players
  for select
  using (public.is_room_member(room_id));

grant select on public.room_players_public to authenticated, anon;

-- ── room_state ───────────────────────────────────────────────────────────

drop policy if exists room_state_member_read on public.room_state;
create policy room_state_member_read on public.room_state
  for select
  using (public.is_room_member(room_id));

-- ── night_actions ────────────────────────────────────────────────────────
--
-- O16's sibling: an action row names a role by naming what it did, so "read
-- only your own, ever" is the same rule as "you may not read another player's
-- role".

drop policy if exists night_actions_own_read on public.night_actions;
create policy night_actions_own_read on public.night_actions
  for select
  using (actor_id = auth.uid());

-- No write policy. Doc 10 §4.1 writes this as an explicit `with check (false)`;
-- the effect is the same and the absence is harder to weaken by accident, so
-- the intent is stated here instead of in a policy that could be dropped and
-- replaced with a permissive one.

-- ── votes ────────────────────────────────────────────────────────────────
--
-- Own ballots always; everyone's once the day has been resolved and the tally
-- is public anyway. A running count during an open ballot is a coordination
-- channel the table game does not have.

drop policy if exists votes_own_read on public.votes;
create policy votes_own_read on public.votes
  for select
  using (voter_id = auth.uid());

drop policy if exists votes_resolved_read on public.votes;
create policy votes_resolved_read on public.votes
  for select
  using (
    public.is_room_member(room_id)
    and exists (
      select 1 from public.room_state s
      where s.room_id = votes.room_id
        and (s.phase <> 'vote' or s.phase_number > votes.day)
    )
  );

-- ── whispers ─────────────────────────────────────────────────────────────

drop policy if exists whisper_meta_room_read on public.whisper_meta;
create policy whisper_meta_room_read on public.whisper_meta
  for select
  using (public.is_room_member(room_id));

drop policy if exists whisper_content_parties on public.whisper_content;
create policy whisper_content_parties on public.whisper_content
  for select
  using (
    exists (
      select 1 from public.whisper_meta m
      where m.id = whisper_content.whisper_id
        and (m.from_id = auth.uid() or m.to_id = auth.uid())
    )
  );

-- A block is the one row a client may write for itself. It is private to the
-- blocker: no policy lets the blocked party see it, which is H-E9's "the
-- sender is not told" expressed as an access rule rather than as restraint.
drop policy if exists whisper_blocks_own on public.whisper_blocks;
create policy whisper_blocks_own on public.whisper_blocks
  for select
  using (blocker_id = auth.uid());

drop policy if exists whisper_blocks_insert on public.whisper_blocks;
create policy whisper_blocks_insert on public.whisper_blocks
  for insert
  with check (blocker_id = auth.uid() and public.is_room_member(room_id));

drop policy if exists whisper_blocks_delete on public.whisper_blocks;
create policy whisper_blocks_delete on public.whisper_blocks
  for delete
  using (blocker_id = auth.uid());

drop policy if exists whisper_reports_own on public.whisper_reports;
create policy whisper_reports_own on public.whisper_reports
  for insert
  with check (reporter_id = auth.uid());

-- ── signals ──────────────────────────────────────────────────────────────
--
-- Peer-to-peer by nature, so this is the one table clients write to directly.
-- The payload is opaque SDP/ICE and carries nothing about the game.

drop policy if exists signals_addressed_read on public.signals;
create policy signals_addressed_read on public.signals
  for select
  using (to_id = auth.uid() and public.is_room_member(room_id));

drop policy if exists signals_own_write on public.signals;
create policy signals_own_write on public.signals
  for insert
  with check (from_id = auth.uid() and public.is_room_member(room_id));

-- ── grants ───────────────────────────────────────────────────────────────
--
-- Belt and braces. RLS decides *which rows*; these decide *whether a verb
-- exists at all*, and a missing grant survives a policy being replaced by a
-- permissive one during a hurried migration.

revoke all on public.rooms           from anon, authenticated;
revoke all on public.room_players    from anon, authenticated;
revoke all on public.room_state      from anon, authenticated;
revoke all on public.night_actions   from anon, authenticated;
revoke all on public.votes           from anon, authenticated;
revoke all on public.whisper_meta    from anon, authenticated;
revoke all on public.whisper_content from anon, authenticated;
revoke all on public.signals         from anon, authenticated;

grant select on public.room_state      to anon, authenticated;
grant select on public.night_actions   to anon, authenticated;
grant select on public.votes           to anon, authenticated;
grant select on public.whisper_meta    to anon, authenticated;
grant select on public.whisper_content to anon, authenticated;
grant select, insert on public.signals to anon, authenticated;
grant select, insert, delete on public.whisper_blocks to anon, authenticated;
grant insert on public.whisper_reports to anon, authenticated;
