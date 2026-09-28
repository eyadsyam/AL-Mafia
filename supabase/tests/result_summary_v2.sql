-- D7: resultSummary{roomId,requestId}: one call, deltas for this room, the
-- first answer replayed on retry, request ids bound to their room.
begin;
create function pg_temp.rs_user() returns uuid language plpgsql as $$
declare u uuid:=gen_random_uuid();
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u,u::text||'@rs.test',now(),false);
  return u;
end $$;
do $$
declare u uuid; mates uuid[]:='{}'; rid uuid:=gen_random_uuid(); other uuid:=gen_random_uuid();
  req uuid:=gen_random_uuid(); first jsonb; again jsonb; i int; season bigint;
begin
  u:=pg_temp.rs_user();
  for i in 1..4 loop mates:=mates||pg_temp.rs_user(); end loop;
  select id into season from public.mission_seasons where code='season_zero';
  update public.mission_seasons set active=true,starts_at=now()-interval '1 day',
    ends_at=now()+interval '27 days' where id=season;
  update public.economy_config set council_rank_enabled=true,missions_enabled=true,
    economy_v11_enabled=true;
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(rid,'RSUM22',u,'finished',1,now()-interval '20 minutes',now()-interval '1 minute');
  insert into public.room_players(room_id,user_id,seat,name,role) values(rid,u,0,'Me','citizen');
  for i in 1..4 loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(rid,mates[i],i,'P'||i,case when i=1 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,public_data) values(rid,'result','{"outcome":"town"}');

  first:=public.result_summary_room(u,rid,req);
  assert first->>'roomId'=rid::text and first->>'requestId'=req::text,first::text;
  assert first ? 'contracts' and first ? 'rank' and first ? 'hub','older keys kept';
  -- Win, first of the day: 25 + 10 + 25 = 60 coins; 50 Council XP; 10 Season XP.
  assert (first->'deltas'->>'coins')::int=60,first->'deltas'::text;
  assert (first->'deltas'->>'councilXp')::int=50,first->'deltas'::text;
  assert (first->'deltas'->>'seasonXp')::int=10,first->'deltas'::text;
  assert (first->'match'->>'coins')::int=60 and (first->'match'->>'councilXp')::int=50,
    'match: '||(first->'match')::text;
  assert (first->'receipt'->>'firstOfDay')::int=25 and (first->'receipt'->>'version')::int=3,
    'receipt: '||(first->'receipt')::text;
  -- Nothing about another seat.
  for i in 1..4 loop
    assert not (first::text like '%'||mates[i]::text||'%'),'another seat id leaked';
  end loop;
  -- The Casebook hub names mission *voices* (flavour); no seat's role or team.
  assert not ((first-'hub')::text ~ '"role"|"team"'),'no role facts';

  -- Retry after a lost response: the same lines, not zeros.
  again:=public.result_summary_room(u,rid,req);
  assert (again->>'replayed')::boolean,'replayed';
  assert again-'replayed'=first,'replay equals the first answer';
  -- A fresh request id reads zero deltas for the already-recorded room.
  again:=public.result_summary_room(u,rid,gen_random_uuid());
  assert (again->'deltas'->>'coins')::int=0 and (again->'match'->>'coins')::int=60,again::text;
  -- A request id is bound to its room.
  begin
    perform public.result_summary_room(u,other,req);
    raise exception 'request id reused for another room';
  exception when others then assert sqlerrm='BAD_REQUEST',sqlerrm;
  end;
  begin
    perform public.result_summary_room(u,rid,null);
    raise exception 'null request id accepted';
  exception when others then assert sqlerrm='BAD_REQUEST',sqlerrm;
  end;

  -- Economy v3 off: no receipt block, older amounts drive the deltas.
  update public.economy_config set economy_v11_enabled=false;
  u:=pg_temp.rs_user();
  rid:=gen_random_uuid();
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(rid,'RSUM33',u,'finished',1,now()-interval '20 minutes',now()-interval '1 minute');
  insert into public.room_players(room_id,user_id,seat,name,role) values(rid,u,0,'Me','citizen');
  for i in 1..4 loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(rid,mates[i],i,'P'||i,case when i=1 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,public_data) values(rid,'result','{"outcome":"town"}');
  first:=public.result_summary_room(u,rid,gen_random_uuid());
  assert first->'receipt'='null'::jsonb,first::text;
  assert (first->'deltas'->>'coins')::int=125,'v1 amounts: '||(first->'deltas')::text;
end $$;
rollback;
