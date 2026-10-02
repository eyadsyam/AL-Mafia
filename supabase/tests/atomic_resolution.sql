begin;
do $$
declare r uuid := gen_random_uuid(); u uuid := gen_random_uuid(); v uuid := gen_random_uuid(); committed boolean;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'ZXQ8K9',u,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat) values(r,u,'host',0),(r,v,'victim',1);
  insert into public.room_state(room_id,phase,phase_number) values(r,'night',1);
  -- Fail AFTER the victim write and private archive write. Neither may survive.
  begin
    perform public.commit_resolution(r,'night',1,1,v,null,'{}',
      '{"resolvedNights":{"bad":{"savedSeat":3}}}', 'morning',now(),'#roster:'||public.roster_fingerprint(r));
    raise exception 'expected invalid archive failure';
  exception when invalid_text_representation then null;
  end;
  if not (select alive from public.room_players where room_id=r and user_id=v) then
    raise exception 'failed transaction killed player';
  end if;
  if exists(select 1 from public.night_resolution_private where room_id=r) then
    raise exception 'failed transaction retained private archive';
  end if;
  committed := public.commit_resolution(r,'night',1,1,v,null,'{"victimSeat":1}',
    '{"morning":{"victimSeat":1}}','morning',now(),'#roster:'||public.roster_fingerprint(r));
  if not committed then raise exception 'first resolution failed'; end if;
  committed := public.commit_resolution(r,'night',1,1,u,null,'{}','{}','morning',now(),'#roster:'||public.roster_fingerprint(r));
  if committed then raise exception 'second driver committed'; end if;
  if not (select alive from public.room_players where room_id=r and user_id=u) then
    raise exception 'stale driver changed roster';
  end if;
  update public.room_state set phase='vote',public_data='{}' where room_id=r;
  if not public.commit_resolution(r,'vote',1,1,null,null,'{}','{"revote":{"round":2}}','vote',now(),'#roster:'||public.roster_fingerprint(r)) then
    raise exception 'revote failed';
  end if;
  if public.commit_resolution(r,'vote',1,1,u,null,'{}','{}','verdict',now(),'#roster:'||public.roster_fingerprint(r)) then
    raise exception 'stale first-round driver closed revote';
  end if;
  if has_function_privilege('authenticated',
    'public.commit_resolution(uuid,text,integer,integer,uuid,integer,jsonb,jsonb,text,timestamptz,text)','execute') then
    raise exception 'client can commit resolution';
  end if;
end $$;
select 'PASS rollback, stale-driver rejection, revote epoch and service-only grant' as result;
rollback;
