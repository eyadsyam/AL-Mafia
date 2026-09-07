alter table public.room_players add column if not exists gender text not null default 'unspecified'
  check (gender in ('unspecified', 'male', 'female'));
create or replace view public.room_players_public
with (security_invoker = true) as
select room_id, user_id, name, seat, alive, connected, last_seen, gender
from public.room_players;
grant select (gender) on public.room_players to authenticated;
grant select on public.room_players_public to authenticated;
