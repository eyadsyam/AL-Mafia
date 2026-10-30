begin;
do $$
declare r uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
        id1 uuid:=gen_random_uuid(); n integer;
begin
  insert into public.rooms(id,code,host_id,match_seed,status,settings)
    values(r,'SPKGRD',a,1,'playing','{"discussionMode":"free","discussionSeconds":30}');
  insert into public.room_players(room_id,user_id,name,seat,role) values
    (r,a,'A',0,'citizen'),(r,b,'B',1,'citizen');
  insert into public.room_state(room_id,phase,phase_number,phase_ends_at)
    values(r,'night',1,now()+interval '30 seconds');
  begin
    perform public.add_speaking_seconds(r,1,0,5,a,id1);
    raise exception 'night accepted';
  exception when raise_exception then if sqlerrm<>'PHASE_CLOSED' then raise; end if; end;
  update public.room_state set phase='discuss' where room_id=r;
  begin
    perform public.add_speaking_seconds(r,1,1,5,a,id1);
    raise exception 'another seat accepted';
  exception when raise_exception then if sqlerrm<>'NOT_A_MEMBER' then raise; end if; end;
  perform public.add_speaking_seconds(r,1,0,5,a,id1);
  perform public.add_speaking_seconds(r,1,0,5,a,id1);
  assert (select (public_data #>> '{speakingSeconds,1,0}')::integer from public.room_state where room_id=r)=5,
    'report id counted twice';
  perform public.add_speaking_seconds(r,1,0,500,a,gen_random_uuid());
  assert (select (public_data #>> '{speakingSeconds,1,0}')::integer from public.room_state where room_id=r)=35,
    'phase duration cap failed';
  perform public.add_speaking_seconds(r,1,0,3,a,null);
  perform public.add_speaking_seconds(r,1,0,3,a,null);
  assert (select (public_data #>> '{speakingSeconds,1,0}')::integer from public.room_state where room_id=r)=38,
    'legacy bucket counted twice';
  assert not has_function_privilege('service_role',
    'public.add_speaking_seconds(uuid,integer,integer,integer)','execute'),
    'unsafe legacy RPC remains callable';
end $$;
rollback;
select 'PASS speaking guard: phase, seat, duplicate, cap, legacy bucket' as result;
