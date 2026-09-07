-- Task 1 — the deal does not end until every player has looked at their card.
--
-- The gate has to be a column rather than a client's word for it. Offline the
-- phone is physically handed on, so "everyone has seen theirs" is something the
-- room witnesses; online it is a claim, and a claim from a client is exactly
-- what doc 10 §10 says never to trust. So the fact lives here, one boolean per
-- seat, written only by the `saw_role` Edge Function and read by `open_phase`
-- before it will let a room out of `reveal`.
--
-- It is on the public surface on purpose. The waiting list — «مستنيين: …» — is
-- a list of *names*, and names are already table-visible. Whether a seat has
-- dismissed a card says nothing about what was on it.

alter table public.room_players
  add column if not exists saw_role boolean not null default false;

create or replace view public.room_players_public
with (security_invoker = true) as
select room_id, user_id, name, seat, alive, connected, last_seen, gender, saw_role
from public.room_players;

grant select (saw_role) on public.room_players to authenticated;
grant select on public.room_players_public to authenticated;

comment on column public.room_players.saw_role is
  'Set by the saw_role Edge Function when this player dismisses their card. '
  'open_phase refuses reveal -> night until every seat has it.';
