-- Night actions — the second secret table (doc 10 §4).
--
-- A night action names both the actor and what they did, so a client that
-- could read another player's row would learn their role from the `action`
-- column alone. RLS restricts reads to the actor, and writes to the service
-- role: doc 10 §10 — "`night_actions` and `votes` are insert-only via Edge
-- Functions".

create table if not exists public.night_actions (
  room_id    uuid not null references public.rooms (id) on delete cascade,
  night      int  not null,
  actor_id   uuid not null,

  -- kill | protect | investigate | suspect | skip
  --
  -- `skip` is a first-class action, not a missing row. Doc 11 N10 needs "the
  -- Citizen chose nobody" to be distinguishable from "the Citizen has not
  -- acted yet" — `T6` and `C10` both read the difference — and doc 10 §8.2's
  -- expiry defaults write it for a player who never answered.
  action     text not null,

  target_id  uuid,

  -- ≤40 chars (N11). Truncation is refused, not applied.
  note       text,

  -- Doc 10 §8.3. The primary key is already (room, night, actor), so a retry
  -- is idempotent by construction; this column exists so a *different* second
  -- action from the same actor can be told apart from a replayed first one
  -- (O19).
  action_id  uuid,

  created_at timestamptz not null default now(),

  primary key (room_id, night, actor_id),

  constraint night_actions_action_valid
    check (action in ('kill', 'protect', 'investigate', 'suspect', 'skip')),

  constraint night_actions_note_length
    check (note is null or char_length(note) <= 40),

  -- A skip has no target, and every other action must have one.
  constraint night_actions_target_matches_action
    check ((action = 'skip') = (target_id is null))
);

alter table public.night_actions enable row level security;
