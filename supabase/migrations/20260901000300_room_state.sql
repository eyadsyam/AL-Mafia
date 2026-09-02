-- The phase, and the clock the whole room reads (doc 10 §4).

create table if not exists public.room_state (
  room_id        uuid primary key
                   references public.rooms (id) on delete cascade,

  -- lobby|reveal|night|morning|confront|discuss|defense|vote|result
  phase          text not null default 'lobby',
  phase_number   int  not null default 0,

  -- **Server clock, never the client's.** Doc 10 §8.2: a client with a wrong
  -- clock must never be able to act early or block a phase, so the deadline is
  -- a server timestamp and the client renders a countdown against it with skew
  -- correction (O8).
  phase_ends_at  timestamptz,

  -- Whose mic is live. The client hard-mutes itself unless it holds this;
  -- the server also ignores anyone else's track (V4, doc 10 §6.1).
  active_speaker uuid,

  -- The public payload for this phase: the trace, the confrontation, the
  -- tally. Everything in here is table-visible by definition — nothing secret
  -- may be written to it, which is why the resolve functions build it
  -- explicitly rather than dumping their working state.
  public_data    jsonb not null default '{}'::jsonb,

  updated_at     timestamptz not null default now(),

  constraint room_state_phase_valid check (phase in (
    'lobby', 'reveal', 'night', 'morning', 'confront',
    'discuss', 'defense', 'vote', 'result'
  ))
);

alter table public.room_state enable row level security;

comment on column public.room_state.public_data is
  'Table-visible by construction. Never write a role, a night action, a '
  'whisper body or the match seed here.';
