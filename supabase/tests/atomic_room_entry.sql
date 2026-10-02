begin;
do $$
declare u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); r uuid; result jsonb; original_seat integer;
begin
  begin
    perform public.create_room_atomic('ZXQ8K9',u,'host','invalid-gender',1,'{}');
    raise exception 'expected invalid member failure';
  exception when check_violation then null;
  end;
  if exists(select 1 from public.rooms where code='ZXQ8K9') then
    raise exception 'failed creation left an orphan room';
  end if;
  result:=public.create_room_atomic('ZXQ8K9',u,'host','male',1,'{"settings":{"maxPlayers":5}}');
  r:=(result->>'roomId')::uuid;
  if not exists(select 1 from public.room_state where room_id=r and phase='lobby') then
    raise exception 'missing initial state';
  end if;
  result:=public.join_room_atomic('zxq8k9',v,'guest','female');
  original_seat:=(result->>'seat')::integer;
  result:=public.join_room_atomic('ZXQ8K9',v,'guest','female');
  if (result->>'seat')::integer <> original_seat or not (result->>'rejoined')::boolean then
    raise exception 'rejoin duplicated seat';
  end if;
  update public.rooms set status='playing' where id=r;
  begin
    perform public.join_room_atomic('ZXQ8K9',gen_random_uuid(),'late','male');
    raise exception 'late join accepted';
  exception when raise_exception then
    if sqlerrm <> 'PHASE_CLOSED' then raise; end if;
  end;
  result:=public.join_room_atomic('ZXQ8K9',v,'guest','female');
  if not (result->>'rejoined')::boolean then raise exception 'active rejoin failed'; end if;
  if has_function_privilege('authenticated','public.create_room_atomic(text,uuid,text,text,bigint,jsonb)','execute')
    or has_function_privilege('authenticated','public.join_room_atomic(text,uuid,text,text)','execute') then
    raise exception 'client can bypass entry handlers';
  end if;
end $$;
select 'PASS creation rollback, complete lobby, seat reuse, playing-room exclusion, service-only entry' as result;
rollback;
