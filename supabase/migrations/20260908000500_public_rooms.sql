-- Public rooms, a room title, and settings that change while people watch
-- (task 10).
--
-- ## Why `visibility` is a column and not a setting
--
-- Everything else the host can choose lives in `rooms.settings`, and that is
-- the right place for it: the jsonb is opaque to the database, every field in
-- it is a rule the *engine* reads, and adding one is not a migration.
--
-- Visibility is not a rule of the game. It decides whether a row is returned to
-- somebody who is not in the room, which makes it the input to a security
-- definer function — and a value a query plans on belongs in a column with an
-- index, not inside a jsonb the planner has to unwrap per row.
--
-- ## Why the browse list is a function
--
-- `rooms` has RLS, and `rooms_member_read` is exactly right: a room is not
-- readable by somebody who is not in it. A public room is the one deliberate
-- hole in that, and a hole cut by a `security definer` function is a hole whose
-- exact shape is written down here — four columns, lobby rooms only, capped at
-- fifty — rather than a policy that widens the table for every query that
-- touches it.
--
-- What it does not return: the room's id, its host, its seed, its settings
-- object, or the names of the people in it. A browser gets a title, a count and
-- whether voice is on, which is what a person choosing a room needs and is not
-- enough to do anything else with. Joining still goes through `join_room`,
-- which still checks the ban list.
--
-- ## Why `rooms` joins the realtime publication
--
-- The host can change the room's rules while nine people are looking at the
-- lobby, and doc 10 §9's rule is that a client never guesses what it missed. A
-- change to `rooms` therefore has to reach the other clients, and the column
-- list is the same boundary it is on `room_players`: `match_seed` and
-- `banned_user_ids` are not in it, so a delta cannot carry them.

alter table public.rooms
  add column if not exists visibility text not null default 'private';

alter table public.rooms
  add column if not exists title text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'rooms_visibility_valid'
  ) then
    alter table public.rooms
      add constraint rooms_visibility_valid
      check (visibility in ('private', 'public'));
  end if;
end
$$;

-- The browse list reads exactly this shape and nothing else does.
create index if not exists rooms_public_browse
  on public.rooms (visibility, status, created_at desc)
  where visibility = 'public';

-- ── the client surface ───────────────────────────────────────────────────

-- Dropped and recreated rather than replaced: the new columns land before
-- created_at, and `create or replace view` may not reorder a column list.
drop view if exists public.rooms_public;

create view public.rooms_public
with (security_invoker = true)
as
  select id, code, host_id, status, settings, visibility, title,
         created_at, ended_at
  from public.rooms;

grant select (visibility, title) on public.rooms to anon, authenticated;
grant select on public.rooms_public to anon, authenticated;

-- ── the one hole in `rooms_member_read` ──────────────────────────────────

create or replace function public.public_rooms()
returns table (code text, title text, players int, voice boolean)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select
    r.code,
    r.title,
    (select count(*) from public.room_players p where p.room_id = r.id)::int,
    coalesce((r.settings ->> 'voice')::boolean, true)
  from public.rooms r
  where r.visibility = 'public'
    and r.status = 'lobby'
  order by r.created_at desc
  limit 50;
$$;

-- Revoked from all three, by name. The default-privileges rule in
-- `20260902000700` grants EXECUTE on new functions in `public` to both client
-- roles, so `from public` alone would leave two explicit grants standing.
--
-- No client calls this. `browse_rooms` calls it as the service role, which is
-- what keeps the hole in `rooms_member_read` reachable through exactly one
-- audited path rather than through `/rest/v1/rpc` for anybody with a token.
revoke all on function public.public_rooms() from public, anon, authenticated;

comment on function public.public_rooms() is
  'The «أوض عامة» browse list. A deliberate hole in rooms_member_read, cut to '
  'four columns: a room that has started is not listed, and nothing here '
  'identifies a room beyond the code somebody would have been given anyway.';

-- ── realtime ─────────────────────────────────────────────────────────────

do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'rooms'
  ) then
    alter publication supabase_realtime drop table public.rooms;
  end if;
end
$$;

alter publication supabase_realtime add table public.rooms
  (id, code, host_id, status, settings, visibility, title, created_at, ended_at);
