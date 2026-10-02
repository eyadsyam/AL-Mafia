create function public.create_room_atomic(
  p_code text,p_host uuid,p_name text,p_gender text,p_seed bigint,p_configuration jsonb
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r uuid;
begin
  if length(btrim(p_name)) not between 1 and 20 then raise exception 'BAD_REQUEST'; end if;
  insert into public.rooms(code,host_id,match_seed,settings,visibility,title)
    values(p_code,p_host,p_seed,coalesce(p_configuration->'settings','{}'),
      coalesce(p_configuration->>'visibility','private'),coalesce(p_configuration->>'title',''))
    returning id into r;
  insert into public.room_players(room_id,user_id,name,gender,seat)
    values(r,p_host,btrim(p_name),p_gender,0);
  insert into public.room_state(room_id,phase) values(r,'lobby');
  return jsonb_build_object('roomId',r,'code',p_code,'seat',0);
end;
$$;
revoke all on function public.create_room_atomic(text,uuid,text,text,bigint,jsonb) from public,anon,authenticated;
grant execute on function public.create_room_atomic(text,uuid,text,text,bigint,jsonb) to service_role;

create function public.join_room_atomic(p_code text,p_user uuid,p_name text,p_gender text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare r public.rooms; player public.room_players; n integer; cap integer; chosen text; suffix integer:=2;
begin
  if length(btrim(p_name)) not between 1 and 20 then raise exception 'BAD_REQUEST'; end if;
  select * into r from public.rooms where code=upper(btrim(p_code)) for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  if r.status='finished' then raise exception 'ROOM_FINISHED'; end if;
  if p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])) then raise exception 'NOT_A_MEMBER'; end if;
  select * into player from public.room_players where room_id=r.id and user_id=p_user;
  if found then
    if player.kicked then raise exception 'NOT_A_MEMBER'; end if;
    update public.room_players set status='connected',connected=true,last_seen=now()
      where room_id=r.id and user_id=p_user;
    return jsonb_build_object('roomId',r.id,'seat',player.seat,'rejoined',true);
  end if;
  if r.status <> 'lobby' then raise exception 'PHASE_CLOSED'; end if;
  select count(*) into n from public.room_players where room_id=r.id;
  cap := coalesce((r.settings->>'maxPlayers')::integer,10);
  if cap not in (5,8,10,15) then cap:=10; end if;
  if n>=cap then raise exception 'ROOM_FULL'; end if;
  chosen:=btrim(p_name);
  while exists(select 1 from public.room_players where room_id=r.id and name=chosen) loop
    chosen:=left(btrim(p_name),20-length(suffix::text)-1)||' '||suffix;
    suffix:=suffix+1;
  end loop;
  select coalesce(max(seat),-1)+1 into n from public.room_players where room_id=r.id;
  insert into public.room_players(room_id,user_id,name,gender,seat)
    values(r.id,p_user,chosen,p_gender,n);
  return jsonb_build_object('roomId',r.id,'seat',n,'name',chosen);
end;
$$;
revoke all on function public.join_room_atomic(text,uuid,text,text) from public,anon,authenticated;
grant execute on function public.join_room_atomic(text,uuid,text,text) to service_role;
