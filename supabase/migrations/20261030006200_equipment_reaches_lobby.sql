-- What a player wears was copied once, when they took the seat: a frame changed
-- from the lobby reached nobody. While the room is still a lobby the seat follows
-- the player's equipment; once the cards are out it stays fixed for the match
-- (Doc 05: nothing about a seat moves during play). The rank on the seat is kept.
create or replace function public.equipment_reaches_lobby()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare
  who uuid := coalesce(new.user_id, old.user_id);
  worn jsonb;
begin
  if coalesce(new.slot, old.slot) not in ('frame','nameplate') then return null; end if;
  worn := coalesce((select jsonb_object_agg(slot,item_code)
    from public.player_equipment where user_id=who and slot in ('frame','nameplate')),'{}');
  update public.room_players p
     set cosmetics = worn || case when p.cosmetics ? 'rank'
                                  then jsonb_build_object('rank',p.cosmetics->'rank')
                                  else '{}'::jsonb end
    from public.rooms r
   where r.id=p.room_id and r.status='lobby' and p.user_id=who and not p.kicked;
  return null;
end $$;
revoke all on function public.equipment_reaches_lobby() from public,anon,authenticated;

drop trigger if exists player_equipment_reaches_lobby on public.player_equipment;
create trigger player_equipment_reaches_lobby
  after insert or update or delete on public.player_equipment
  for each row execute function public.equipment_reaches_lobby();
