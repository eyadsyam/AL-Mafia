-- O3: server-made public rooms discuss 180 s; host rooms and Thursday rooms keep theirs.
begin;
do $$
declare
  u uuid := gen_random_uuid();
  preset jsonb := jsonb_build_object('maxPlayers',10,'speechSeconds',45,'discussionSeconds',300);
  got int;
begin
  insert into auth.users(id) values(u);

  -- quick-match shape
  insert into public.rooms(code,host_id,status,match_seed,visibility,title,settings)
    values('QPACEA',u,'lobby',1,'public','لعب سريع',preset);
  select (settings->>'discussionSeconds')::int into got from public.rooms where code='QPACEA';
  if got <> 180 then raise exception 'quick match room has %', got; end if;

  -- system waiting room shape
  insert into public.rooms(code,host_id,status,match_seed,visibility,title,settings,system_pool)
    values('QPACEB',null,'lobby',2,'public','',preset,'default');
  select (settings->>'discussionSeconds')::int into got from public.rooms where code='QPACEB';
  if got <> 180 then raise exception 'system room has %', got; end if;

  -- Thursday room keeps its preset
  insert into public.rooms(code,host_id,status,match_seed,visibility,title,settings)
    values('QPACEC',u,'lobby',3,'public','ليلة الخميس',public.thursday_preset());
  select (settings->>'discussionSeconds')::int into got from public.rooms where code='QPACEC';
  if got <> (public.thursday_preset()->>'discussionSeconds')::int then
    raise exception 'thursday room changed to %', got; end if;

  -- host-made public room keeps the host's choice
  insert into public.rooms(code,host_id,status,match_seed,visibility,title,settings)
    values('QPACED',u,'lobby',4,'public','أوضتي',jsonb_build_object('discussionSeconds',420));
  select (settings->>'discussionSeconds')::int into got from public.rooms where code='QPACED';
  if got <> 420 then raise exception 'host room changed to %', got; end if;

  -- private quick-titled room is not public: untouched
  insert into public.rooms(code,host_id,status,match_seed,visibility,title,settings)
    values('QPACEE',u,'lobby',5,'private','لعب سريع',preset);
  select (settings->>'discussionSeconds')::int into got from public.rooms where code='QPACEE';
  if got <> 300 then raise exception 'private room changed to %', got; end if;

  if has_function_privilege('anon','public.public_room_pace()','execute')
     or has_function_privilege('authenticated','public.public_room_pace()','execute') then
    raise exception 'pace trigger function is callable by clients'; end if;
  raise notice 'public_room_pace PASS';
end $$;
rollback;
