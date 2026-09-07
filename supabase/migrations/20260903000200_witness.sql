-- «الشاهد» — Witness mode (doc 12 §4).
--
-- ## The problem this table solves
--
-- *"Offline, an eliminated player is still at the table, still talking, still
-- part of the evening. Online, they are alone in a room with a dead app. They
-- will close it, and they will not suggest the game next week."*
--
-- That is doc 12's biggest named retention risk, and it is a product problem
-- with a database shape. Two things give an eliminated player something to do
-- for the next half hour: somebody to talk to, and a stake in the ending.
--
-- ## The wall
--
-- Doc 12 §4.1, binding: ghost chat is *"hard-walled: no channel from dead to
-- living exists in the app."* The wall is not a screen that is not shown. It is
-- this, in two halves:
--
--   * a **read** policy that requires the caller to be a *dead* member of the
--     room, so a living player asking for the rows is refused by Postgres;
--   * **no insert, update or delete grant at all** for any client role, so the
--     only way a row appears is `ghost_say`, which checks the same thing again
--     with the service key.
--
-- A living player who patched their client, read their own JWT and called
-- PostgREST directly gets an empty array. That is what "hard-walled" has to
-- mean to be worth writing down.
--
-- ## And the thing the wall cannot do
--
-- A dead player can text a living friend on another app. Doc 12 §4.3 says so
-- plainly, and the answer is a line of social norm in the lobby rather than a
-- pretence of enforcement. Nothing below claims otherwise.

-- ── who is dead, as a policy can ask it ──────────────────────────────────
--
-- Same shape and same reasons as `private.is_room_member`: `security definer`
-- so the lookup does not re-enter `room_players`' own policy, in a schema
-- PostgREST does not expose, revoked from `public` and granted by name.

create or replace function private.is_dead_member(target_room uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.room_players
    where room_id = target_room
      and user_id = (select auth.uid())
      and not alive
  );
$$;

revoke all on function private.is_dead_member(uuid) from public;
grant execute on function private.is_dead_member(uuid)
  to anon, authenticated, service_role;

comment on function private.is_dead_member(uuid) is
  'Whether the caller is an eliminated member of this room. The whole of the '
  'ghost-chat wall rests on this returning false for the living (doc 12 §4.1).';

-- ── ghost chat ───────────────────────────────────────────────────────────

create table if not exists public.ghost_messages (
  id         uuid primary key default gen_random_uuid(),
  room_id    uuid not null references public.rooms (id) on delete cascade,
  author_id  uuid not null,

  -- Short on purpose. This is a side conversation running underneath a live
  -- match, not a second game; a paragraph would pull the reader out of the
  -- table they are meant to still be watching.
  body       text not null,

  created_at timestamptz not null default now(),

  constraint ghost_body_length check (char_length(body) between 1 and 240)
);

create index if not exists ghost_messages_room_time
  on public.ghost_messages (room_id, created_at);

alter table public.ghost_messages enable row level security;

drop policy if exists ghost_messages_dead_read on public.ghost_messages;
create policy ghost_messages_dead_read on public.ghost_messages
  for select
  to authenticated
  using (private.is_dead_member(room_id));

comment on policy ghost_messages_dead_read on public.ghost_messages is
  'The dead only. A living member of the same room reads nothing — this is the '
  'read half of doc 12 §4.1''s wall.';

-- ── the prediction panel ─────────────────────────────────────────────────
--
-- One row per player per room. Locked once submitted (doc 12 §4.1: "Locked
-- once submitted, scored in post-game") — enforced by the Edge Function, which
-- refuses a second write, rather than by a trigger, so the refusal can carry a
-- reason the screen can render.

create table if not exists public.predictions (
  room_id     uuid not null references public.rooms (id) on delete cascade,
  user_id     uuid not null,

  -- 'mafia' or 'town'. Text rather than an enum so a room created by an older
  -- client does not fail to insert against a type it has never seen.
  winner      text not null,

  -- The seats this player believes are Mafia. Order is not meaningful.
  mafia_seats int[] not null default '{}',

  locked_at   timestamptz not null default now(),

  primary key (room_id, user_id),

  constraint predictions_winner_known check (winner in ('mafia', 'town'))
);

alter table public.predictions enable row level security;

drop policy if exists predictions_own_read on public.predictions;
create policy predictions_own_read on public.predictions
  for select
  to authenticated
  using (user_id = (select auth.uid()));

comment on policy predictions_own_read on public.predictions is
  'Your own call and nobody else''s. Two dead players comparing predictions in '
  'ghost chat is a conversation; the app reading them off each other is a leak '
  'of what the room collectively suspects.';

-- ── the client surface ───────────────────────────────────────────────────
--
-- Select only, exactly like every other table on the wire. Writes go through
-- `ghost_say` and `submit_prediction`, which run with the service key and
-- check membership and vitality for themselves.

revoke all on public.ghost_messages from anon, authenticated;
revoke all on public.predictions    from anon, authenticated;

grant select (id, room_id, author_id, body, created_at)
  on public.ghost_messages to authenticated;
grant select (room_id, user_id, winner, mafia_seats, locked_at)
  on public.predictions to authenticated;

-- ── purge ────────────────────────────────────────────────────────────────
--
-- Both tables cascade from `rooms`, so the nightly purge of finished rooms
-- (20260901000900) already takes them with it. Nothing to schedule; this note
-- exists so the next person does not add a second job that deletes rows
-- something else already deleted.

-- ── realtime ─────────────────────────────────────────────────────────────
--
-- Ghost chat is a conversation, so it is the one place in this project where a
-- poll would be visibly wrong. Added to the publication; the read policy still
-- decides who receives anything, and a living client's subscription therefore
-- delivers nothing at all rather than delivering rows it then has to hide.

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'ghost_messages'
     )
  then
    execute 'alter publication supabase_realtime add table public.ghost_messages';
  end if;
end
$$;

alter table public.ghost_messages replica identity full;
