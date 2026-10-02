-- Fill existing compatible public lobbies before creating another. The global
-- quick-match lock prevents simultaneous demand from fragmenting into empty
-- rooms, while ordinary join/create functions retain their per-user/room
-- locks and all existing capacity rules.
create or replace function public.quick_match_atomic(
  p_user uuid,p_name text,p_gender text
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare candidate text; result jsonb; new_code text; seed bigint; attempt integer;
begin
  if length(btrim(p_name)) not between 1 and 20 then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtext('quick_match:classic'));

  select r.code into candidate
  from public.rooms r
  where r.status='lobby' and r.visibility='public'
    and coalesce(r.settings->>'scenarioCode','classic')='classic'
    and (select count(*) from public.room_players p where p.room_id=r.id and not p.kicked)
      < case when coalesce((r.settings->>'maxPlayers')::integer,10) in (5,8,10,15)
        then coalesce((r.settings->>'maxPlayers')::integer,10) else 10 end
    and not (p_user=any(coalesce(r.banned_user_ids,'{}'::uuid[])))
  order by (select count(*) from public.room_players p where p.room_id=r.id and not p.kicked) desc,
    r.created_at,r.id
  limit 1 for update skip locked;

  if candidate is not null then
    result:=public.join_room_atomic(candidate,p_user,p_name,p_gender);
    return result||jsonb_build_object('code',candidate,'created',false);
  end if;

  for attempt in 1..8 loop
    new_code:=upper(substr(encode(gen_random_bytes(4),'hex'),1,6));
    seed:=(get_byte(gen_random_bytes(4),0)::bigint<<24)
      +(get_byte(gen_random_bytes(4),0)::bigint<<16)
      +(get_byte(gen_random_bytes(4),0)::bigint<<8)
      +get_byte(gen_random_bytes(4),0)::bigint;
    begin
      result:=public.create_room_atomic(
        new_code,p_user,p_name,p_gender,seed,
        jsonb_build_object(
          'visibility','public','title','لعب سريع',
          'settings',jsonb_build_object(
            'maxPlayers',10,'voice',true,'muteAllAtNight',true,
            'speechSeconds',45,'discussionSeconds',300,
            'openVoting',false,'traceEnabled',true,
            'discussionMode','structured','confrontationEnabled',true,
            'whisperEnabled',true,'scenarioCode','classic'
          )
        )
      );
      return result||jsonb_build_object('created',true);
    exception when unique_violation then
      -- Try another six-character code under the same demand lock.
    end;
  end loop;
  raise exception 'BAD_REQUEST';
end $$;
revoke all on function public.quick_match_atomic(uuid,text,text) from public,anon,authenticated;
grant execute on function public.quick_match_atomic(uuid,text,text) to service_role;
