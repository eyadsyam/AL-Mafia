-- Players in a room, and the one secret column in the schema (doc 10 §4).
--
-- `role` is the whole product premise. Everything about how this table is
-- exposed exists to keep it from reaching anybody but its owner:
--
--   * RLS is on, and no policy grants a client a row it does not own;
--   * clients read `room_players_public` (next migration), never this table;
--   * the view returns `role` only for `auth.uid()` and NULL for everyone else.
--
-- A leaked role table destroys the game, so this is treated as the security
-- boundary it is rather than as a column with a rule attached.

create table if not exists public.room_players (
  room_id    uuid not null references public.rooms (id) on delete cascade,
  user_id    uuid not null,
  name       text not null,

  -- Ordering is "seating order" — the night pass, the «اسم واحد» round and the
  -- host-migration order all read it.
  seat       int  not null,

  -- SECRET. Assigned by `start_match` using the room's seed; null until then.
  role       text,

  alive      boolean not null default true,
  connected  boolean not null default true,
  last_seen  timestamptz not null default now(),

  primary key (room_id, user_id),

  constraint room_players_role_valid
    check (role is null or role in ('mafia', 'doctor', 'detective', 'citizen')),

  constraint room_players_name_present
    check (length(btrim(name)) > 0)
);

-- Seats are unique within a room, and the seat *is* the identity claim (O5):
-- a returning player is matched on `user_id`, and a new `user_id` cannot take
-- a seat that already exists.
create unique index if not exists room_players_seat_unique
  on public.room_players (room_id, seat);

-- Host migration walks this order: lowest connected seat wins (O1, O2).
create index if not exists room_players_connected
  on public.room_players (room_id, connected, seat);

alter table public.room_players enable row level security;

comment on column public.room_players.role is
  'SECRET. Clients must read room_players_public, which nulls this for '
  'everyone but its owner. No policy on this table grants another player''s row.';
