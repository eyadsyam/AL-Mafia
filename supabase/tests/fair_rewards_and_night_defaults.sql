-- Local regression: receipt participation, award eligibility, and kick voiding.
begin;
alter table public.votes disable trigger vote_phase_guard;
alter table public.night_actions disable trigger night_action_phase_guard;
do $$
declare
  people uuid[]; r uuid:=gen_random_uuid(); r2 uuid:=gen_random_uuid();
  r3 uuid:=gen_random_uuid(); r4 uuid:=gen_random_uuid(); i int; answer jsonb; before_balance bigint;
begin
  select array_agg(gen_random_uuid()) into people from generate_series(1,5);
  insert into auth.users(id) select unnest(people);
  update public.economy_config set economy_v11_enabled=true,awards_enabled=true;

  -- Four actors and one Citizen killed before their first turn make five humans.
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(r,'ABCDEF',people[1],'finished',1,now()-interval '10 minutes',now());
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role,alive)
      values(r,people[i],i-1,'Seat'||i,case when i=1 then 'mafia' else 'citizen' end,i<>5);
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(r,'result','{"outcome":"town"}');
  insert into public.votes(room_id,day,voter_id,action_id)
    select r,1,unnest(people[1:4]),gen_random_uuid();
  insert into public.night_actions(room_id,night,actor_id,action,target_id)
    values(r,1,people[1],'kill',people[5]);
  assert public.economy_took_part(r,people[5]),'night victim did not participate';
  for i in 1..5 loop
    assert (public.economy_v3_issue_receipt(people[i],r)).user_id=people[i],
      'eligible human missing receipt: '||i;
  end loop;
  assert (select count(*) from public.match_receipts where room_id=r)=5,
    'the victim or an actor missed their receipt';

  -- The award list is public to members; receipt holders alone get the bonus.
  select coalesce(balance,0) into before_balance from public.wallet_accounts where user_id=people[2];
  answer:=public.match_awards_get(people[2],r);
  assert answer->>'ready'='true' and jsonb_array_length(answer->'awards')>0,
    'eligible awards hidden';
  assert (answer->>'granted')::int>0,'receipt holder did not earn award coins';
  assert coalesce((select balance from public.wallet_accounts where user_id=people[2]),0)
    = coalesce(before_balance,0)+(answer->>'granted')::int,
    'award credit did not reach the wallet';
  assert (select count(*) from public.wallet_ledger where user_id=people[2]
    and source_room=r and kind='match_award')=1,'award ledger missing';
  assert (public.match_awards_get(people[2],r)->>'granted')::int=0,
    'award replay credited twice';

  -- An idle living fifth seat still fails the floor; titles remain visible.
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(r2,'ABCDEG',people[1],'finished',1,now()-interval '10 minutes',now());
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(r2,people[i],i-1,'Seat'||i,case when i=1 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(r2,'result','{"outcome":"town"}');
  insert into public.votes(room_id,day,voter_id,action_id)
    select r2,1,unnest(people[1:4]),gen_random_uuid();
  assert not public.economy_took_part(r2,people[5]),'idle living seat took part';
  assert (public.economy_v3_issue_receipt(people[2],r2)).user_id is null,
    'four humans paid';
  answer:=public.match_awards_get(people[2],r2);
  assert answer->>'ready'='true' and jsonb_array_length(answer->'awards')>0
    and (answer->>'granted')::int=0,'ineligible awards were hidden or paid';
  assert not exists(select 1 from public.wallet_ledger where source_room=r2 and kind='match_award'),
    'award ledger bypassed receipts';

  -- A later town win does not turn a nondeciding kick into a reward void.
  update public.room_players set kicked=true,status='left',alive=false
    where room_id=r2 and user_id=people[1];
  assert not public.economy_kick_voided(r2),'new room used the legacy fallback';
  insert into public.economy_void_rooms(room_id) values(r2);
  assert public.economy_kick_voided(r2),'deciding marker was ignored';
  delete from public.economy_void_rooms where room_id=r2;
  update public.rooms set started_at=timestamptz '2026-10-08 23:00:00+00' where id=r2;
  assert public.economy_kick_voided(r2),'legacy fallback was lost';

  -- A finished room refuses kick before touching the seat or its ban list.
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(r3,'ABCDEH',people[1],'finished',1,now()-interval '10 minutes',now());
  insert into public.room_players(room_id,user_id,seat,name,role)
    values(r3,people[1],0,'Host','citizen'),(r3,people[2],1,'Guest','mafia');
  insert into public.room_state(room_id,phase,public_data)
    values(r3,'result','{"outcome":"town"}');
  begin
    perform public.kick_member(r3,people[1],1);
    raise exception 'finished room accepted kick';
  exception when raise_exception then
    if sqlerrm<>'PHASE_CLOSED' then raise; end if;
  end;
  assert exists(select 1 from public.room_players where room_id=r3
    and user_id=people[2] and not kicked),'finished kick mutated the seat';

  -- A stale tally cannot overwrite a decision that landed before its commit.
  insert into public.rooms(id,code,host_id,status,match_seed,started_at)
    values(r4,'ABCDEJ',people[1],'playing',1,now()-interval '10 minutes');
  insert into public.room_players(room_id,user_id,seat,name,role)
    values(r4,people[1],0,'Host','citizen'),(r4,people[2],1,'Guest','mafia');
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(r4,'vote',1,'{"outcome":"town"}');
  assert not public.commit_resolution(r4,'vote',1,1,people[2],null,'{}','{"outcome":null}',
    'verdict',now(),public.vote_fingerprint(r4,1,1)),
    'stale vote tally eliminated after a decision';
  update public.room_state set phase='night' where room_id=r4;
  assert not public.commit_night_roles_resolution(r4,1,array[people[2]],null,'{}',
    '{"outcome":null}','morning',now(),public.night_fingerprint(r4,1)),
    'stale night tally killed after a decision';
  assert exists(select 1 from public.room_players where room_id=r4
    and user_id=people[2] and alive),'stale tally changed the roster';
end $$;
select 'PASS fair rewards and night defaults' as result;
rollback;
