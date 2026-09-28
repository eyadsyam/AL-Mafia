-- Contract for 20260928000900_unpublished_presence (M3). Rolled back by the SQL harness.
begin;
do $$
declare
  r uuid := gen_random_uuid();
  h uuid := '00000000-0000-4000-8000-0000000000e1';
  a uuid := '00000000-0000-4000-8000-0000000000e2';
  b uuid := '00000000-0000-4000-8000-0000000000e3';
  k uuid := '00000000-0000-4000-8000-0000000000e4';
  before xid; res jsonb;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'PRSN33',h,9,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,connected,status,last_seen) values
    (r,h,'H',0,'mafia',true,true,'connected',now()),
    (r,a,'A',1,'citizen',true,true,'connected',now()),
    (r,b,'B',2,'doctor',true,true,'away',now()-interval '40 seconds'),
    (r,k,'K',3,'citizen',true,true,'connected',now());
  update public.room_players set kicked=true where room_id=r and user_id=k;
  insert into public.room_state(room_id,phase,phase_number) values(r,'discuss',1);

  perform public.presence_beat(r,h);

  -- A beat from a connected seat does not touch the published row.
  select xmin into before from public.room_players where room_id=r and user_id=a;
  assert public.presence_beat(r,a), 'a seated player was refused';
  assert (select xmin from public.room_players where room_id=r and user_id=a)=before,
    'a plain beat rewrote the published roster row';
  assert exists(select 1 from public.room_presence where room_id=r and user_id=a);

  -- A beat from an away seat is a transition, and the room hears it once.
  assert public.presence_beat(r,b);
  assert (select status from public.room_players where room_id=r and user_id=b)='connected';
  select xmin into before from public.room_players where room_id=r and user_id=b;
  perform public.presence_beat(r,b);
  assert (select xmin from public.room_players where room_id=r and user_id=b)=before,
    'the second beat after returning was published again';

  -- Removed and absent seats have no beat.
  assert not public.presence_beat(r,k), 'a removed seat was heard';
  assert not public.presence_beat(r,gen_random_uuid()), 'a stranger was heard';

  -- Ageing reads the beat, not the stale published timestamp.
  update public.room_players set last_seen=now()-interval '10 minutes' where room_id=r;
  update public.room_presence set heard_at=now() where room_id=r;
  perform public.age_presence();
  assert (select status from public.room_players where room_id=r and user_id=a)='connected',
    'a beating seat was aged away';
  update public.room_presence set heard_at=now()-interval '40 seconds' where room_id=r and user_id=a;
  perform public.age_presence();
  assert (select status from public.room_players where room_id=r and user_id=a)='away';
  update public.room_presence set heard_at=now()-interval '100 seconds' where room_id=r and user_id=a;
  perform public.age_presence();
  assert (select status from public.room_players where room_id=r and user_id=a)='left';

  -- The host who still beats keeps the room; strike and archive agree.
  update public.room_presence set heard_at=now() where room_id=r and user_id=h;
  assert public.migrate_host(r,b)=h, 'a beating host lost the room';
  begin
    res := public.strike_absent_member(r,h,2);
    raise exception 'a beating seat was struck';
  exception when raise_exception then
    if sqlerrm<>'STILL_HERE' then raise; end if;
  end;
  assert public.archive_abandoned_rooms()=0, 'a beating room was archived';
  assert (select status from public.rooms where id=r)='playing';

  -- A silent host gives the room to the lowest beating seat.
  update public.room_presence set heard_at=now()-interval '2 minutes' where room_id=r and user_id=h;
  update public.room_players set status='connected' where room_id=r and user_id=b;
  assert public.migrate_host(r,b)=b, 'the room did not move to the beating heir';

  -- Nobody outside the service role reaches the beat.
  assert not has_table_privilege('authenticated','public.room_presence','select');
  assert not has_function_privilege('authenticated','public.presence_beat(uuid,uuid)','execute');
  assert not exists (select 1 from pg_publication_tables
                      where pubname='supabase_realtime' and tablename='room_presence'),
    'the beat table is published';
end $$;
rollback;
