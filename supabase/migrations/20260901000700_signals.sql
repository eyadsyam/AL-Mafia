-- WebRTC signalling (doc 10 §4).
--
-- Ephemeral by design: SDP offers and ICE candidates are worthless thirty
-- seconds after they are written, and keeping them would be the one table in
-- the schema that grows without bound.
--
-- Nothing here is load-bearing. Doc 10 §1.2: an online match must be 100%
-- playable with voice completely broken, so a failure to read or write this
-- table degrades the call and touches nothing else.

create table if not exists public.signals (
  id         bigserial primary key,
  room_id    uuid not null references public.rooms (id) on delete cascade,
  from_id    uuid not null,
  to_id      uuid not null,
  payload    jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists signals_recipient
  on public.signals (room_id, to_id, id);

alter table public.signals enable row level security;
