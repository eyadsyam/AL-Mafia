begin;
do $$
declare r uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); outsider uuid:=gen_random_uuid(); receipt uuid;
begin
  insert into public.rooms(id,code,host_id,match_seed,status,settings) values(r,'SFTYQ7',a,1,'lobby','{}');
  insert into public.room_players(room_id,user_id,name,seat) values(r,a,'a',0),(r,b,'b',1);
  receipt:=public.submit_player_safety(a,'delete');
  if public.submit_player_safety(a,'delete') <> receipt then raise exception 'deletion not idempotent'; end if;
  perform public.submit_player_safety(a,'report',r,1,'abuse','reported text');
  perform public.submit_player_safety(a,'block',r,1);
  perform public.submit_player_safety(a,'block',r,1);
  if (select count(*) from public.player_blocks where blocker_id=a)<>1 then raise exception 'block not idempotent'; end if;
  begin
    perform public.submit_player_safety(outsider,'report',r,1);
    raise exception 'outsider report accepted';
  exception when raise_exception then if sqlerrm<>'NOT_A_MEMBER' then raise; end if; end;
  begin
    perform public.submit_player_safety(a,'block',r,0);
    raise exception 'self block accepted';
  exception when raise_exception then if sqlerrm<>'BAD_REQUEST' then raise; end if; end;
  update public.room_players set kicked=true where room_id=r and user_id=b;
  perform public.submit_player_safety(b,'report',r,0,'harassment','kicked players can report');
  if has_table_privilege('authenticated','public.safety_reports','select') or
     has_table_privilege('authenticated','public.data_deletion_requests','select') or
     has_function_privilege('authenticated','public.submit_player_safety(uuid,text,uuid,integer,text,text)','execute') then
    raise exception 'private evidence exposed';
  end if;
  perform set_config('request.jwt.claim.sub', a::text, true);
  set local role authenticated;
  if exists(select 1 from public.player_blocks where blocker_id<>a) then raise exception 'block list exposed'; end if;
  reset role;
end $$;
rollback;
