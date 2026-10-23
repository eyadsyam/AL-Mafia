-- Deleting a finished-room host pays each remaining member before room cleanup.
begin;
alter table public.votes disable trigger vote_phase_guard;
do $$
declare
  people uuid[];
  room uuid:=gen_random_uuid();
  i int;
  expected bigint;
  before_sync bigint;
begin
  select array_agg(gen_random_uuid()) into people from generate_series(1,5);
  insert into auth.users(id) select unnest(people);
  update public.economy_config set economy_v11_enabled=true,
    council_rank_enabled=true,missions_enabled=true;
  update public.mission_seasons set active=true,starts_at=now()-interval '1 day',
    ends_at=now()+interval '27 days' where code='season_zero';
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(room,'DELSTA',people[1],'finished',1,now()-interval '10 minutes',now());
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(room,people[i],i-1,'Seat'||i,
        case when i=2 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(room,'result','{"outcome":"town"}');
  insert into public.votes(room_id,day,voter_id,action_id)
    select room,1,unnest(people),gen_random_uuid();

  assert not exists(select 1 from public.match_receipts where room_id=room),
    'rewards must be pending before deletion';
  assert public.delete_my_account(people[1])='{"deleted":true}'::jsonb;
  assert not exists(select 1 from public.rooms where id=room),
    'the existing deletion chain must still remove the room';
  for i in 2..5 loop
    expected:=case when i=2 then 50 else 60 end;
    assert (select count(*) from public.match_receipts
      where user_id=people[i] and room_id=room)=1,
      'missing tablemate receipt for seat '||i;
    assert (select balance from public.wallet_accounts where user_id=people[i])=expected,
      'incorrect tablemate balance for seat '||i;
    assert (select coalesce(sum(amount),0) from public.wallet_ledger
      where user_id=people[i] and source_room=room
        and kind in ('match_completion','match_win'))
      =case when i=2 then 25 else 35 end,
      'missing per-room ledger credit for seat '||i;
    assert (select xp from public.season_xp_events
      where user_id=people[i] and source_key='match:'||room)
      =case when i=2 then 5 else 10 end,
      'incorrect season XP for seat '||i;
    assert (select xp from public.council_xp_events
      where user_id=people[i] and source_key='match:'||room)
      =case when i=2 then 30 else 50 end,
      'incorrect Council XP for seat '||i;
  end loop;

  before_sync:=(select balance from public.wallet_accounts where user_id=people[2]);
  perform public.sync_player_rewards(people[2]);
  assert (select balance from public.wallet_accounts where user_id=people[2])=before_sync,
    'later sync paid the deleted room again';
  assert (select count(*) from public.wallet_ledger
    where user_id=people[2] and source_room=room and kind='match_completion')=1,
    'later sync duplicated the completion credit';
end $$;
rollback;

-- With economy v3 disabled, deletion retains its old behavior: no new receipt.
begin;
alter table public.votes disable trigger vote_phase_guard;
do $$
declare people uuid[]; room uuid:=gen_random_uuid(); i int;
begin
  select array_agg(gen_random_uuid()) into people from generate_series(1,5);
  insert into auth.users(id) select unnest(people);
  update public.economy_config set economy_v11_enabled=false;
  insert into public.rooms(id,code,host_id,status,match_seed,started_at,ended_at)
    values(room,'DELSTB',people[1],'finished',1,now()-interval '10 minutes',now());
  for i in 1..5 loop
    insert into public.room_players(room_id,user_id,seat,name,role)
      values(room,people[i],i-1,'Seat'||i,
        case when i=2 then 'mafia' else 'citizen' end);
  end loop;
  insert into public.room_state(room_id,phase,public_data)
    values(room,'result','{"outcome":"town"}');
  insert into public.votes(room_id,day,voter_id,action_id)
    select room,1,unnest(people),gen_random_uuid();

  perform public.delete_my_account(people[1]);
  assert not exists(select 1 from public.rooms where id=room),
    'flag-off deletion did not remove the room';
  assert not exists(select 1 from public.match_receipts where room_id=room),
    'flag-off deletion issued v3 receipts';
  assert not exists(select 1 from public.wallet_ledger
    where user_id=any(people[2:5]) and source_room=room),
    'flag-off deletion paid a tablemate';
end $$;
rollback;
