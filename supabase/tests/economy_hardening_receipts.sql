begin;
alter table public.votes disable trigger vote_phase_guard;
do $$
declare people uuid[]; rid uuid:=gen_random_uuid(); i int; rec public.match_receipts;
begin
  select array_agg(gen_random_uuid()) into people from generate_series(1,6);
  insert into auth.users(id) select unnest(people);
  update public.economy_config set economy_v11_enabled=true;
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(rid,'EHARD2',people[1],'finished',1,now()-interval '10 minutes',now());
  for i in 1..6 loop
    insert into public.room_players(room_id,user_id,seat,name,role,status)
      values(rid,people[i],i-1,'Seat'||i,case when i=2 then 'mafia' else 'citizen' end,
        case when i=6 then 'left' else 'connected' end);
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(rid,'result','{"outcome":"town"}');
  insert into public.votes(room_id,day,voter_id,action_id)
    select rid,1,unnest(people[1:4]),gen_random_uuid();
  assert (public.economy_v3_issue_receipt(people[1],rid)).user_id is null,
    'idle and left seats do not fill five';
  insert into public.votes(room_id,day,voter_id) values(rid,1,people[5]);
  assert (public.economy_v3_issue_receipt(people[1],rid)).user_id is null,
    'server default abstention is not participation';
  update public.votes set action_id=gen_random_uuid()
    where room_id=rid and voter_id=people[5];
  rec:=public.economy_v3_issue_receipt(people[1],rid);
  assert rec.user_id=people[1] and rec.human_count=5,'five participating seats pay';
  assert (public.economy_v3_issue_receipt(people[6],rid)).user_id is null,'left seat earns nothing';

  rid:=gen_random_uuid();
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(rid,'EHARD3',people[1],'finished',1,now()-interval '2 minutes',now());
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(rid,people[i],i-1,'Seat'||i,case when i=2 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(rid,'result','{"outcome":"town"}');
  insert into public.votes(room_id,day,voter_id,action_id)
    select rid,1,unnest(people[1:5]),gen_random_uuid();
  assert (public.economy_v3_issue_receipt(people[1],rid)).user_id is null,'short match earns nothing';
  update public.rooms set started_at=now()-interval '10 minutes' where id=rid;
  insert into public.economy_void_rooms(room_id) values(rid);
  assert (public.economy_v3_issue_receipt(people[1],rid)).user_id is null,'kick-decisive result void';

  rid:=gen_random_uuid();
  insert into public.rooms(id,code,host_id,status,match_seed,started_at)
    values(rid,'EHARD4',people[1],'playing',1,now()-interval '10 minutes');
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(rid,people[i],i-1,'Seat'||i,case when i<=2 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(rid,'vote',1,'{}');
  perform public.kick_member(rid,people[1],4);
  assert exists(select 1 from public.economy_void_rooms where room_id=rid),
    'kick that reaches parity voids rewards';
  update public.economy_config set awards_enabled=true;
  assert (public.match_awards_get(people[1],rid)->>'granted')::int=0,
    'kick-decisive match pays no award coins';
end $$;
rollback;
