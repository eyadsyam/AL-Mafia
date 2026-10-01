-- Thursday Night rooms sit in «أوض عامة» with everyone else's: an event room
-- is public and titled, so the second player of the night finds the first
-- one's table instead of opening a private room nobody can see. The browse
-- list marks an event room from its server-owned fingerprint, never from a
-- title a host can type.

create or replace function public.event_create_room(
  p_user uuid,p_event text,p_request uuid,p_code text,p_seed bigint,p_at timestamptz)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare replay record; state jsonb; wk date; made jsonb; rid uuid;
  chosen_name text; chosen_gender text;
begin
  if p_event<>'thursday' or p_request is null or p_at is null then
    raise exception 'BAD_REQUEST';
  end if;
  select r.room_id,rooms.code into replay from public.thursday_event_receipts r
    join public.rooms rooms on rooms.id=r.room_id
   where r.creator_id=p_user and r.request_id=p_request;
  if found then return jsonb_build_object('roomId',replay.room_id,'code',replay.code,
    'seat',0,'vacated',0,'replayed',true); end if;
  if not public.thursday_on() then raise exception 'DISABLED'; end if;
  state:=public.thursday_cairo_state(p_at);
  if not (state->>'isThursday')::boolean then raise exception 'NOT_THURSDAY'; end if;
  wk:=(state->>'eventWeek')::date;
  select name,gender into chosen_name,chosen_gender from public.council_identity
    where user_id=p_user;
  chosen_name:=coalesce(nullif(btrim(chosen_name),''),'Player');
  chosen_gender:=coalesce(chosen_gender,'unspecified');
  made:=public.create_room_atomic(p_code,p_user,chosen_name,chosen_gender,p_seed,
    jsonb_build_object('visibility','public','title','ليلة الخميس',
      'settings',public.thursday_preset()));
  rid:=(made->>'roomId')::uuid;
  update public.rooms set scenario_fingerprint=public.thursday_preset_fingerprint()
    where id=rid;
  perform public.thursday_ensure_event(wk);
  insert into public.thursday_event_receipts(
      room_id,event_week,creator_id,request_id,scenario_fingerprint)
    values(rid,wk,p_user,p_request,public.thursday_preset_fingerprint());
  return made||jsonb_build_object('event','thursday','replayed',false);
end $$;

revoke all on function public.event_create_room(uuid,text,uuid,text,bigint,timestamptz) from public,anon,authenticated;
grant execute on function public.event_create_room(uuid,text,uuid,text,bigint,timestamptz) to service_role;

-- v2's rows, unchanged and in v2's order, plus whether the room is a
-- Thursday Night table.
create function public.public_room_listing_v3(p_user uuid)
returns table (
  code text, title text, players int, capacity int, min_players int,
  voice boolean, waiting boolean, thursday boolean
)
language sql security definer set search_path=public,pg_temp stable as $$
  select l.code, l.title, l.players, l.capacity, l.min_players, l.voice, l.waiting,
    coalesce(r.scenario_fingerprint=public.thursday_preset_fingerprint(),false)
  from public.public_room_listing_v2(p_user) with ordinality as l(
    code, title, players, capacity, min_players, voice, waiting, ord)
  left join public.rooms r on r.code=l.code and r.status='lobby'
  order by l.ord
$$;

revoke all on function public.public_room_listing_v3(uuid) from public,anon,authenticated;
grant execute on function public.public_room_listing_v3(uuid) to service_role;
