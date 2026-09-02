-- The client-facing surface, rebuilt so that `role` and `match_seed` are not
-- on it at all (doc 10 §4.1, §10) — and the function privileges that were
-- revoked but not actually removed.
--
-- ## Four findings from the first live database
--
-- **1. The views could not be read.** `rooms_public` and `room_players_public`
-- were `security_invoker = true` while the same migration revoked `select` on
-- their base tables, so every client read returned `permission denied for
-- table room_players`. Fixed once already, by making them run as owner; that
-- worked, and the linter is right that it is the wrong shape (`0010`). This
-- migration takes the third option instead.
--
-- **2. `revoke ... from anon, authenticated` does nothing to a function.**
-- `execute` on a new function is granted to `PUBLIC` by default, and `anon`
-- and `authenticated` inherit it from there; revoking their *named* grant
-- leaves the inherited one standing. Every helper was therefore callable by
-- any anonymous client over `/rest/v1/rpc/…`, and two of them are dangerous:
--
--   * `leave_room(room, user)` — disconnect anybody, or, in a lobby, delete
--     them and re-pack the seats;
--   * `migrate_host(room, claimant)` — take the room.
--
-- Both are `security definer`, so RLS would not have stopped either. The
-- revoke has to name `public`.
--
-- **3. `role` did not need to be on the wire.** The old view returned the
-- caller's own role and nulled everyone else's, which is correct but leaves
-- the column one policy mistake away from the room. It is not needed there:
-- `my_team` already runs as the service role and is already the one call that
-- may read somebody else's role, so it can answer "what am I, and who is with
-- me" in the same breath. With the column gone from the view, `role` is
-- reachable through **no** PostgREST route at all — the column grant below
-- does not include it, so it is not a redaction that has to be got right, it
-- is an absence.
--
-- Same argument, same shape, for `match_seed`.
--
-- **4. `is_room_member` has to stay `security definer`** — the policy on
-- `room_players` reads `room_players`, and only a definer function breaks the
-- recursion. What it does not have to be is *reachable*: moved to a schema
-- PostgREST does not expose, it is still callable from a policy and no longer
-- callable from the internet.

-- ── the private helper ───────────────────────────────────────────────────

create schema if not exists private;
revoke all on schema private from anon, authenticated;
grant usage on schema private to anon, authenticated, service_role;

create or replace function private.is_room_member(target_room uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.room_players
    where room_id = target_room and user_id = (select auth.uid())
  );
$$;

revoke all on function private.is_room_member(uuid) from public;
grant execute on function private.is_room_member(uuid)
  to anon, authenticated, service_role;

-- ── policies, rebuilt against it ─────────────────────────────────────────
--
-- Every `auth.uid()` is wrapped in a scalar sub-select. Postgres then treats
-- it as an InitPlan and evaluates it once per statement instead of once per
-- row (linter `0003`); on the roster read that is the difference between one
-- call and one per seat.

drop policy if exists rooms_member_read        on public.rooms;
drop policy if exists room_players_room_read   on public.room_players;
drop policy if exists room_state_member_read   on public.room_state;
drop policy if exists night_actions_own_read   on public.night_actions;
drop policy if exists votes_own_read           on public.votes;
drop policy if exists votes_resolved_read      on public.votes;
drop policy if exists whisper_meta_room_read   on public.whisper_meta;
drop policy if exists whisper_content_parties  on public.whisper_content;
drop policy if exists whisper_blocks_own       on public.whisper_blocks;
drop policy if exists whisper_blocks_insert    on public.whisper_blocks;
drop policy if exists whisper_blocks_delete    on public.whisper_blocks;
drop policy if exists whisper_reports_own      on public.whisper_reports;
drop policy if exists signals_addressed_read   on public.signals;
drop policy if exists signals_own_write        on public.signals;

drop view if exists public.rooms_public;
drop view if exists public.room_players_public;
drop function if exists public.is_room_member(uuid);

create policy rooms_member_read on public.rooms
  for select using (private.is_room_member(id));

create policy room_players_room_read on public.room_players
  for select using (private.is_room_member(room_id));

create policy room_state_member_read on public.room_state
  for select using (private.is_room_member(room_id));

create policy night_actions_own_read on public.night_actions
  for select using (actor_id = (select auth.uid()));

-- One policy where there were two. Permissive policies are OR-ed, so
-- `own OR resolved` is the same rule the pair expressed — and the linter's
-- `0006` is not a style note: each permissive policy is evaluated separately
-- for every row, so two of them cost twice.
create policy votes_read on public.votes
  for select using (
    voter_id = (select auth.uid())
    or (
      private.is_room_member(room_id)
      and exists (
        select 1 from public.room_state s
        where s.room_id = votes.room_id
          and (s.phase <> 'vote' or s.phase_number > votes.day)
      )
    )
  );

create policy whisper_meta_room_read on public.whisper_meta
  for select using (private.is_room_member(room_id));

create policy whisper_content_parties on public.whisper_content
  for select using (
    exists (
      select 1 from public.whisper_meta m
      where m.id = whisper_content.whisper_id
        and (select auth.uid()) in (m.from_id, m.to_id)
    )
  );

create policy whisper_blocks_own on public.whisper_blocks
  for select using (blocker_id = (select auth.uid()));

create policy whisper_blocks_insert on public.whisper_blocks
  for insert with check (
    blocker_id = (select auth.uid()) and private.is_room_member(room_id)
  );

create policy whisper_blocks_delete on public.whisper_blocks
  for delete using (blocker_id = (select auth.uid()));

create policy whisper_reports_own on public.whisper_reports
  for insert with check (reporter_id = (select auth.uid()));

create policy signals_addressed_read on public.signals
  for select using (
    to_id = (select auth.uid()) and private.is_room_member(room_id)
  );

create policy signals_own_write on public.signals
  for insert with check (
    from_id = (select auth.uid()) and private.is_room_member(room_id)
  );

-- ── the views, as ordinary invoker views ─────────────────────────────────
--
-- They are now a convenience — a stable name and a fixed column list — rather
-- than a security boundary. The boundary moved into the grants below, where a
-- future migration cannot weaken it by editing a `case` expression.

create view public.rooms_public
with (security_invoker = true)
as
  select id, code, host_id, status, settings, created_at, ended_at
  from public.rooms;

create view public.room_players_public
with (security_invoker = true)
as
  select room_id, user_id, name, seat, alive, connected, last_seen
  from public.room_players;

-- ── the grants that are the boundary ─────────────────────────────────────
--
-- Column privileges, not table privileges. `select *` on either base table
-- fails for every client role, because the two columns that matter are not in
-- the list and never will be.

revoke all on public.rooms        from anon, authenticated;
revoke all on public.room_players from anon, authenticated;

grant select (id, code, host_id, status, settings, created_at, ended_at)
  on public.rooms to anon, authenticated;

grant select (room_id, user_id, name, seat, alive, connected, last_seen)
  on public.room_players to anon, authenticated;

grant select on public.rooms_public        to anon, authenticated;
grant select on public.room_players_public to anon, authenticated;

comment on column public.room_players.role is
  'SECRET, and not on the client surface at all: no client role holds a '
  'column privilege for it, so no view, policy or PostgREST route can return '
  'it. A player learns their own role from the my_team function, which runs '
  'as the service role.';

comment on column public.rooms.match_seed is
  'SECRET. Same treatment as room_players.role: no client column privilege, '
  'so it cannot be selected by anybody but an Edge Function.';

-- ── function privileges ──────────────────────────────────────────────────
--
-- `from public` is the operative word. These bypass RLS by construction and
-- exist to be called by an Edge Function holding the service key; none of them
-- should have a REST route.

revoke all on function public.merge_public_data(uuid, jsonb)              from public, anon, authenticated;
revoke all on function public.set_public_path(uuid, text[], jsonb)        from public, anon, authenticated;
revoke all on function public.add_speaking_seconds(uuid, int, int, int)   from public, anon, authenticated;
revoke all on function public.migrate_host(uuid, uuid, interval)          from public, anon, authenticated;
revoke all on function public.leave_room(uuid, uuid)                      from public, anon, authenticated;
revoke all on function public.purge_finished_rooms()                      from public, anon, authenticated;
revoke all on function public.archive_abandoned_rooms(interval)           from public, anon, authenticated;

grant execute on function public.merge_public_data(uuid, jsonb)            to service_role;
grant execute on function public.set_public_path(uuid, text[], jsonb)      to service_role;
grant execute on function public.add_speaking_seconds(uuid, int, int, int) to service_role;
grant execute on function public.migrate_host(uuid, uuid, interval)        to service_role;
grant execute on function public.leave_room(uuid, uuid)                    to service_role;

-- The two housekeeping functions are for `pg_cron` alone. Not even the service
-- role needs them: nothing in the app purges or archives on demand.

-- `server_now` is the one function every client may call, so it is the one
-- that most needs a pinned search_path (linter `0011`): without it the name
-- `now()` is resolved through the caller's, and a caller controls that.
create or replace function public.server_now()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select pg_catalog.now();
$$;

revoke all on function public.server_now() from public;
grant execute on function public.server_now() to anon, authenticated, service_role;
