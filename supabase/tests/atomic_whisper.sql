begin;
-- Force a body-write failure after the graph insert, inside this rollback-only test.
create function pg_temp.reject_test_whisper() returns trigger language plpgsql as $$
begin
  if new.body='force-body-failure' then raise exception 'TEST_BODY_FAILURE'; end if;
  return new;
end $$;
create trigger test_whisper_failure before insert on public.whisper_content
for each row execute function pg_temp.reject_test_whisper();
do $$
declare r uuid:=gen_random_uuid(); h uuid:=gen_random_uuid(); a uuid:=gen_random_uuid();
        k uuid:=gen_random_uuid(); w uuid; p text;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'ATMWH7',h,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive) values
    (r,h,'host',0,'mafia',true),(r,a,'guest',1,'citizen',true),(r,k,'removed',2,'citizen',true);
  update public.room_players set kicked=true where room_id=r and user_id=k;
  insert into public.room_state(room_id,phase,phase_number) values(r,'discuss',1);
  begin
    perform public.commit_whisper(r,h,1,1,'force-body-failure');
    raise exception 'body failure did not fire';
  exception when raise_exception then if sqlerrm<>'TEST_BODY_FAILURE' then raise; end if; end;
  if exists(select 1 from public.whisper_meta where room_id=r) then raise exception 'orphan graph'; end if;
  foreach p in array array['night','vote','result'] loop
    update public.room_state set phase=p where room_id=r;
    begin
      perform public.commit_whisper(r,h,1,1,'closed');
      raise exception 'closed phase accepted';
    exception when raise_exception then if sqlerrm<>'PHASE_CLOSED' then raise; end if; end;
  end loop;
  update public.room_state set phase='discuss' where room_id=r;
  begin
    perform public.commit_whisper(r,k,1,1,'removed');
    raise exception 'removed sender accepted';
  exception when raise_exception then if sqlerrm<>'NOT_A_MEMBER' then raise; end if; end;
  begin
    perform public.commit_whisper(r,h,2,1,'removed target');
    raise exception 'removed target accepted';
  exception when raise_exception then if sqlerrm<>'BAD_REQUEST' then raise; end if; end;
  begin
    perform public.commit_whisper(r,h,1,0,'stale');
    raise exception 'stale day accepted';
  exception when raise_exception then if sqlerrm<>'PHASE_CLOSED' then raise; end if; end;
  w:=public.commit_whisper(r,h,1,1,'hello');
  if not exists(select 1 from public.whisper_content where whisper_id=w and body='hello') then raise exception 'missing body'; end if;
  begin
    perform public.commit_whisper(r,h,1,1,'duplicate');
    raise exception 'duplicate accepted';
  exception when unique_violation then null; end;
  if has_function_privilege('authenticated','public.commit_whisper(uuid,uuid,integer,integer,text)','execute')
     or has_function_privilege('anon','public.commit_whisper(uuid,uuid,integer,integer,text)','execute') then raise exception 'client can impersonate sender'; end if;
end $$;
select 'PASS atomic whisper: body rollback, phase/day guards, removed seats, complete delivery, daily limit, service-only grant' as result;
rollback;
