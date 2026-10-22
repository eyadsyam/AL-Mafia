-- LOCAL ONLY: node tool/test_sql_without_docker.mjs tools_gaps.sql
-- One transaction per matrix proof; PGlite does not simulate concurrent clients.
begin;
do $$
declare
  t record; seats int; r uuid; actor uuid; outsider uuid; u uuid;
  phase_name text; bad_phase text; targets int[]; note_text text;
  seat_no int; before_count int; expected_error text; actual_error text;
begin
  -- M1-1/8/14/20/27/33/40/47/54/60/67/74/81/88/95/102/109:
  -- every tool's valid use and SQL guards at both supported table sizes.
  for t in select * from public.table_tools where active order by sort_order loop
    foreach seats in array array[4,20] loop
      r := gen_random_uuid(); actor := gen_random_uuid(); outsider := gen_random_uuid();
      insert into auth.users(id,is_anonymous) values(actor,true),(outsider,true);
      insert into public.rooms(id,code,host_id,match_seed,status,started_at)
        values(r,'TGAA'||substr('ABCDEFGHJKLMNPQRSTUVWXYZ',t.sort_order/10,1)||
          case when seats=4 then 'A' else 'B' end,actor,1,'playing',now());
      for seat_no in 0..seats-1 loop
        if seat_no=0 then u:=actor; else
          u:=gen_random_uuid();
          insert into auth.users(id,is_anonymous) values(u,true);
        end if;
        insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
          values(r,u,'Seat '||seat_no,seat_no,'citizen',seat_no<>0 or t.phase<>'dead','connected');
      end loop;
      phase_name := case t.phase when 'night' then 'night' when 'vote' then 'vote'
        when 'dead' then case when t.code='grave_vote' then 'vote' else 'discuss' end
        else 'discuss' end;
      bad_phase := case when t.phase='night' then 'vote' else 'night' end;
      targets := array(select generate_series(1,t.targets));
      note_text := case when t.code in ('anon_note','last_will') then 'proof'
        when t.code='impersonate' then 'citizen' else null end;
      insert into public.room_state(room_id,phase,phase_number,public_data)
        values(r,phase_name,1,'{"morning":{"silencedSeat":null}}');
      insert into public.player_tool_charges(user_id,tool_code,charges)
        values(actor,t.code,3);

      -- The service function refuses a caller with no seat, even with inventory.
      insert into public.player_tool_charges(user_id,tool_code,charges)
        values(outsider,t.code,3);
      begin
        perform public.use_table_tool(outsider,r,t.code,targets,note_text);
        raise exception 'accepted nonmember: %',t.code;
      exception when others then
        if sqlerrm<>'NOT_A_MEMBER' then raise; end if;
      end;
      assert (select charges from public.player_tool_charges where user_id=outsider and tool_code=t.code)=3;
      update public.room_state set phase=bad_phase where room_id=r;
      begin
        perform public.use_table_tool(actor,r,t.code,targets,note_text);
        raise exception 'accepted wrong phase: %',t.code;
      exception when others then
        if sqlerrm<>'WRONG_PHASE' then raise; end if;
      end;
      update public.room_state set phase=phase_name where room_id=r;
      update public.room_players set alive=(t.phase='dead') where room_id=r and user_id=actor;
      begin
        perform public.use_table_tool(actor,r,t.code,targets,note_text);
        raise exception 'accepted wrong life status: %',t.code;
      exception when others then
        if sqlerrm<>(case when t.phase='dead' then 'ALIVE' else 'NOT_ALIVE' end) then raise; end if;
      end;
      update public.room_players set alive=(t.phase<>'dead') where room_id=r and user_id=actor;
      if t.targets=0 then
        begin
          perform public.use_table_tool(actor,r,t.code,array[1],note_text);
          raise exception 'accepted unexpected target: %',t.code;
        exception when others then
          if sqlerrm<>'BAD_TARGETS' then raise; end if;
        end;
      else
        begin
          perform public.use_table_tool(actor,r,t.code,'{}',note_text);
          raise exception 'accepted missing targets: %',t.code;
        exception when others then
          if sqlerrm<>'BAD_TARGETS' then raise; end if;
        end;
        begin
          perform public.use_table_tool(actor,r,t.code,
            case when t.targets=1 then array[0] else array_fill(1,array[t.targets]) end,note_text);
          raise exception 'accepted duplicate/self target: %',t.code;
        exception when others then
          if sqlerrm<>'BAD_TARGETS' then raise; end if;
        end;
        begin
          perform public.use_table_tool(actor,r,t.code,
            array[seats]||targets[2:t.targets],note_text);
          raise exception 'accepted out-of-range target: %',t.code;
        exception when others then
          if sqlerrm<>'BAD_TARGETS' then raise; end if;
        end;
      end if;
      assert (select charges from public.player_tool_charges where user_id=actor and tool_code=t.code)=3,
        'refusal charged '||t.code;
      assert (select count(*) from public.room_tool_uses where room_id=r)=0,
        'refusal logged '||t.code;

      perform public.use_table_tool(actor,r,t.code,targets,note_text);
      assert (select charges from public.player_tool_charges where user_id=actor and tool_code=t.code)=2,
        'valid use not charged exactly once: '||t.code;
      assert (select count(*) from public.room_tool_uses where room_id=r)=1,
        'valid use not logged exactly once: '||t.code;
      assert (select jsonb_array_length(public_data->'toolLog') from public.room_state where room_id=r)=1,
        'valid use missing public log: '||t.code;

      expected_error := case when t.per_match=1 then 'LIMIT_TOOL' else 'LIMIT_PHASE' end;
      begin
        perform public.use_table_tool(actor,r,t.code,targets,note_text);
        raise exception 'accepted repeat: %',t.code;
      exception when others then
        if sqlerrm<>expected_error then raise; end if;
      end;
      update public.room_state set phase_number=2 where room_id=r;
      insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number)
        select r,actor,0,'anon_note','discuss',100+i from generate_series(1,3) i;
      begin
        perform public.use_table_tool(actor,r,t.code,targets,note_text);
        raise exception 'accepted fifth tool: %',t.code;
      exception when others then
        if sqlerrm<>'LIMIT_MATCH' then raise; end if;
      end;
      delete from public.room_tool_uses where room_id=r and phase_number>99;
      if t.tier='heavy' then
        insert into public.room_tool_uses(room_id,user_id,seat,tool_code,phase,phase_number)
          values(r,actor,0,'lock_door','night',101);
        begin
          perform public.use_table_tool(actor,r,t.code,targets,note_text);
          raise exception 'accepted third heavy tool: %',t.code;
        exception when others then
          if sqlerrm<>'LIMIT_HEAVY' then raise; end if;
        end;
      end if;
      assert (select charges from public.player_tool_charges where user_id=actor and tool_code=t.code)=2,
        'rejected limit charged '||t.code;
    end loop;
  end loop;
end $$;

do $$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); r uuid:=gen_random_uuid();
  before_charges int; entry jsonb;
begin
  -- M1-19: a kicked dead member and a finished room cannot post a will.
  insert into auth.users(id,is_anonymous) values(a,true),(b,true);
  insert into public.rooms(id,code,host_id,match_seed,status,started_at)
    values(r,'TGAWLL',a,1,'playing',now());
  insert into public.room_players(room_id,user_id,name,seat,role,alive,status)
    values(r,a,'A',0,'citizen',false,'connected'),(r,b,'B',1,'mafia',true,'connected');
  insert into public.room_state(room_id,phase,phase_number,public_data)
    values(r,'discuss',1,'{}');
  insert into public.player_tool_charges(user_id,tool_code,charges) values(a,'last_will',2);
  update public.room_players set kicked=true where room_id=r and user_id=a;
  begin
    perform public.use_table_tool(a,r,'last_will','{}','will');
    raise exception 'kicked member posted will';
  exception when others then if sqlerrm<>'NOT_A_MEMBER' then raise; end if; end;
  update public.room_players set kicked=false where room_id=r and user_id=a;
  update public.rooms set status='finished' where id=r;
  begin
    perform public.use_table_tool(a,r,'last_will','{}','will');
    raise exception 'finished match accepted will';
  exception when others then if sqlerrm<>'NOT_PLAYING' then raise; end if; end;
  assert (select charges from public.player_tool_charges where user_id=a and tool_code='last_will')=2;
  assert not exists(select 1 from public.room_tool_uses where room_id=r);
  assert not (select public_data ? 'toolLog' from public.room_state where room_id=r);

  -- M1-64/93: SQL's raw public log retains the secret code but no seat,
  -- targets or chosen face. Each tool is checked separately.
  update public.rooms set status='playing' where id=r;
  update public.room_players set alive=true where room_id=r and user_id=a;
  update public.room_state set phase='discuss' where room_id=r;
  insert into public.player_tool_charges(user_id,tool_code,charges)
    values(a,'camouflage',1),(a,'impersonate',1);
  perform public.use_table_tool(a,r,'camouflage','{}',null);
  perform public.use_table_tool(a,r,'impersonate','{}','mafia');
  select public_data->'toolLog'->0 into entry from public.room_state where room_id=r;
  assert entry->>'tool'='camouflage' and entry->>'seat' is null
    and entry->'targets'='[]'::jsonb and entry->>'note' is null,
    'camouflage raw public payload shape';
  select public_data->'toolLog'->1 into entry from public.room_state where room_id=r;
  assert entry->>'tool'='impersonate' and entry->>'seat' is null
    and entry->'targets'='[]'::jsonb and entry->>'note' is null,
    'impersonate raw public payload shape';
  -- M1-17: the living refusal above and an immediate public will for the dead.
  update public.room_players set alive=false where room_id=r and user_id=a;
  perform public.use_table_tool(a,r,'last_will','{}','will');
  select public_data->'toolLog'->2 into entry from public.room_state where room_id=r;
  assert entry->>'tool'='last_will' and entry->>'note'='will' and entry->>'seat'='0',
    'dead will was not posted immediately';
end $$;
rollback;
