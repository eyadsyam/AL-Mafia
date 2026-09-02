-- Rooms — one row per online match (doc 10 §4).
--
-- One migration per logical unit, never one giant file: the migration list is
-- the audit trail, and "add the whisper tables" is a thing a reviewer can read
-- and reason about in a way that "the schema" is not.

create table if not exists public.rooms (
  id          uuid primary key default gen_random_uuid(),

  -- Six characters from an unambiguous alphabet. Generated in `create_room`,
  -- not here, because the retry on collision (O13) belongs with the caller
  -- that can retry.
  code        text not null,

  host_id     uuid not null,

  -- lobby | playing | finished
  status      text not null default 'lobby',

  settings    jsonb not null default '{}'::jsonb,

  -- Drives ALL determinism, and is **never sent to a client** (doc 10 §10):
  -- with the seed in hand a player could predict every tie-break, including
  -- the Mafia's night tie-break and tomorrow's trace.
  match_seed  bigint not null,

  created_at  timestamptz not null default now(),
  ended_at    timestamptz,

  constraint rooms_status_valid
    check (status in ('lobby', 'playing', 'finished')),

  -- Doc 10 §10: "6 chars from an unambiguous alphabet". Enforced here as well
  -- as in the generator, because a hand-written insert is still an insert.
  constraint rooms_code_shape
    check (code ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$')
);

-- O13 — a duplicate code must be impossible rather than unlikely. The unique
-- index is what makes `create_room`'s retry loop correct: it does not check
-- first and then insert (which races), it inserts and handles 23505.
create unique index if not exists rooms_code_unique on public.rooms (code);

-- The purge job (doc 10 §3.1) scans on these two together.
create index if not exists rooms_finished_at
  on public.rooms (status, ended_at)
  where status = 'finished';

alter table public.rooms enable row level security;

comment on column public.rooms.match_seed is
  'Never expose to clients: it makes every tie-break predictable.';
