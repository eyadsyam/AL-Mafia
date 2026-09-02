-- Day ballots (doc 10 §4).
--
-- Unlike a night action a ballot is public once the day resolves — the tally
-- is announced — but it is *not* public while the day is open, because a
-- running count is a coordination channel the offline game does not have. So
-- reads are restricted until the phase closes, and `resolve_vote` publishes
-- the tally into `room_state.public_data`.

create table if not exists public.votes (
  room_id   uuid not null references public.rooms (id) on delete cascade,
  day       int  not null,
  voter_id  uuid not null,

  -- Null is an abstention (D1), which is a recorded choice and not an absence.
  target_id uuid,

  -- Revote rounds (FR-020, D2/D3). The tally must filter on this or a revote
  -- would be counted on top of the ballot that tied.
  round     int not null default 1,

  action_id uuid,

  created_at timestamptz not null default now(),

  -- D10 — "last write per (day, voter, round) wins". The primary key makes
  -- that an upsert rather than a duplicate.
  primary key (room_id, day, voter_id, round),

  constraint votes_round_positive check (round >= 1)
);

alter table public.votes enable row level security;
