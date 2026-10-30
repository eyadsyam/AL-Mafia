begin;
do $$
declare r uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); p text;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'WHPHSE',a,1,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role) values
    (r,a,'A',0,'citizen'),(r,b,'B',1,'citizen');
  insert into public.room_state(room_id,phase,phase_number) values(r,'opening',1);
  foreach p in array array['opening','confront','defense','night','vote'] loop
    update public.room_state set phase=p where room_id=r;
    begin
      perform public.commit_whisper(r,a,1,1,'secret');
      raise exception 'whisper accepted in %',p;
    exception when raise_exception then if sqlerrm<>'PHASE_CLOSED' then raise; end if; end;
  end loop;
  update public.room_state set phase='discuss' where room_id=r;
  assert public.commit_whisper(r,a,1,1,'secret') is not null,
    'discussion whisper refused';
end $$;
rollback;
select 'PASS whisper phases: discussion only' as result;
