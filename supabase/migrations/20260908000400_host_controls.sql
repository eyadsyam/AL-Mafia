-- Task 6 — the two things a host may do to a person, and where they are
-- decided.
--
-- Both are enforced inside the Edge Functions, against the room's `host_id`,
-- and neither is reachable any other way: `muted` and `kicked` carry no client
-- write privilege, and `banned_user_ids` is not on the client surface at all.
-- A modified client can draw whatever sheet it likes and change nothing.
--
-- ## Why `kicked` is a column and not a lookup in the ban list
--
-- The player who was ejected has to be told, and the ban list is a fact about
-- the *room* — publishing it would hand every client the list of everybody the
-- host has ever thrown out. One boolean on the ejected player's own row says
-- the same thing to the only person entitled to hear it.

alter table public.room_players
  add column if not exists muted boolean not null default false;

alter table public.room_players
  add column if not exists kicked boolean not null default false;

alter table public.rooms
  add column if not exists banned_user_ids uuid[] not null default '{}';

create or replace view public.room_players_public
with (security_invoker = true) as
select room_id, user_id, name, seat, alive, connected, last_seen, gender,
       saw_role, status, muted, kicked
from public.room_players;

grant select (muted, kicked) on public.room_players to authenticated;
grant select on public.room_players_public to authenticated;

-- `banned_user_ids` stays off the client surface. `rooms_public` is the client's
-- whole view of a room and it does not list it; the column grant on `rooms`
-- below is the boundary, exactly as it is for `match_seed`.
comment on column public.rooms.banned_user_ids is
  'Not on the client surface. join_room reads it as the service role; a '
  'kicked player learns they were kicked from their own room_players row.';

-- The realtime column list, again: a column that is not in it arrives null and
-- overwrites what the client had.
alter publication supabase_realtime drop table public.room_players;
alter publication supabase_realtime add table public.room_players
  (room_id, user_id, name, seat, alive, connected, last_seen, gender,
   saw_role, status, muted, kicked);
