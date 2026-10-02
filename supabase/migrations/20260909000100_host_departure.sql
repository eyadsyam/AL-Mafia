-- Presence ageing and explicit departure use the same server-owned handover.
create or replace function public.handover_departed_host()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
declare
  target_room uuid := old.room_id;
  owner_id uuid;
  room_status text;
  heir uuid;
begin
  if tg_op = 'UPDATE' and new.status <> 'left' then return new; end if;
  select host_id, status into owner_id, room_status from public.rooms
    where id = target_room for update;
  if not found or room_status = 'finished' then return null; end if;
  if tg_op = 'DELETE' and room_status = 'lobby' and not exists
      (select 1 from public.room_players where room_id = target_room) then
    delete from public.rooms where id = target_room;
    return null;
  end if;
  if owner_id = old.user_id then
    select user_id into heir from public.room_players
      where room_id = target_room and user_id <> old.user_id
        and status = 'connected' and connected
        and last_seen > now() - interval '30 seconds'
      order by seat limit 1;
    if heir is not null then
      update public.rooms set host_id = heir where id = target_room;
    end if;
  end if;
  return null;
end;
$$;
revoke all on function public.handover_departed_host() from public, anon, authenticated;
drop trigger if exists room_player_host_departure on public.room_players;
create trigger room_player_host_departure
after update of status or delete on public.room_players
for each row execute function public.handover_departed_host();
