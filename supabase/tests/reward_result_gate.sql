-- A resolved ballot can mark the room finished before the result opens.
-- A pending winner is not yet a rewardable completed match.
begin;
do $$
declare people uuid[]; rid uuid:=gen_random_uuid(); i int;
begin
  select array_agg(gen_random_uuid()) into people from generate_series(1,5);
  insert into auth.users(id) select unnest(people);
  update public.economy_config set economy_v11_enabled=true,awards_enabled=true;
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(rid,'RPRGAA',people[1],'finished',1,now()-interval '10 minutes',now());
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(rid,people[i],i-1,'Seat'||i,
        case when i=1 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(rid,'verdict',1,'{"outcome":"town"}');
  -- Prior votes are a legitimate participation record. They were written while
  -- the ballot was open; bypass only their phase guard for this fixture.
  alter table public.votes disable trigger vote_phase_guard;
  insert into public.votes(room_id,day,voter_id,action_id)
    select rid,1,unnest(people),gen_random_uuid();
  alter table public.votes enable trigger vote_phase_guard;
  assert (public.economy_v3_issue_receipt(people[2],rid)).user_id is null,
    'a pending verdict issued a reward receipt before the result';
  assert not exists(select 1 from public.match_receipts where room_id=rid);
  update public.room_state set phase='result' where room_id=rid;
  assert (public.economy_v3_issue_receipt(people[2],rid)).user_id=people[2],
    'the completed result did not issue its receipt';
end $$;
rollback;
