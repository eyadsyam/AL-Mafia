-- «ماتش كمان بنفس الترابيزة»: the host of a finished room opens the next room
-- with the same settings, and every player still on the result screen sees
-- its code appear in the old room's public data and joins with one tap.
--
-- Additive. The old room is only read and annotated (`public_data.rematch`),
-- after its outcome is public; nothing about the finished match changes.
-- Idempotent: a second call returns the room the first one opened.

create or replace function public.rematch_room_atomic(
  p_old uuid, p_host uuid, p_name text, p_gender text, p_code text, p_seed bigint
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare old public.rooms; existing jsonb; created jsonb;
begin
  select * into old from public.rooms where id=p_old for update;
  if old.id is null then raise exception 'ROOM_NOT_FOUND'; end if;
  if old.status<>'finished' then raise exception 'PHASE_CLOSED'; end if;
  if old.host_id is distinct from p_host then raise exception 'NOT_HOST'; end if;

  select public_data->'rematch' into existing from public.room_state where room_id=p_old;
  if existing is not null and exists(
      select 1 from public.rooms n where n.id=(existing->>'roomId')::uuid
        and n.status in ('lobby','playing')) then
    return jsonb_build_object('roomId',existing->>'roomId','code',existing->>'code',
      'seat',0,'vacated',0,'existing',true);
  end if;

  created := public.create_room_atomic(p_code, p_host, p_name, p_gender, p_seed,
    jsonb_build_object('settings',old.settings,'visibility',old.visibility,'title',old.title));

  update public.room_state
     set public_data = coalesce(public_data,'{}'::jsonb) || jsonb_build_object('rematch',
       jsonb_build_object('roomId',created->>'roomId','code',created->>'code'))
   where room_id=p_old;
  return created;
end $$;

revoke all on function public.rematch_room_atomic(uuid,uuid,text,text,text,bigint)
  from public, anon, authenticated;
grant execute on function public.rematch_room_atomic(uuid,uuid,text,text,text,bigint)
  to service_role;
