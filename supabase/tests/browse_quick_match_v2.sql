-- M7: the rewritten browse list and quick-match candidate choose exactly what
-- the correlated-subquery versions chose, over a randomized population, and
-- the partial active-seat index exists.
begin;
do $$
declare
  users uuid[]:='{}'; viewers uuid[]; rid uuid; i int; j int; v uuid; n int;
  listed_total int:=0; picks int:=0; old_rows jsonb; new_rows jsonb; old_pick text; new_pick text; cap int; st text; vis text;
begin
  perform setseed(0.42);
  for i in 1..80 loop
    users:=users||gen_random_uuid();
    insert into auth.users(id) values(users[i]);
  end loop;
  viewers:=users[71:80];
  -- 40 rooms: mixed status, visibility, capacity, scenario, bans, waiting.
  for i in 1..40 loop
    rid:=gen_random_uuid();
    cap:=(array[5,8,10,15,12])[1+floor(random()*5)::int];
    st:=(array['lobby','lobby','lobby','playing','finished'])[1+floor(random()*5)::int];
    vis:=(array['public','public','private'])[1+floor(random()*3)::int];
    insert into public.rooms(id,code,host_id,status,match_seed,visibility,title,settings,
        created_at,banned_user_ids,system_pool)
      values(rid,substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',1+i%32,1)
          ||substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',1+(i/32)%32,1)||'MQMQ',
        case when i=11 then null else users[i] end,
        case when i=11 then 'lobby' else st end,i,
        case when i=11 then 'public' else vis end,'t'||i,
        jsonb_build_object('maxPlayers',cap,
          'scenarioCode',case when i%7=0 then 'thursday' else 'classic' end),
        now()-make_interval(mins=>i*3),
        case when i%5=0 then array[viewers[1+i%10]] else '{}'::uuid[] end,
        case when i=11 then 'default' else null end);
    n:=case when i=11 then 0 else floor(random()*least(cap,12))::int end;
    for j in 1..n loop
      insert into public.room_players(room_id,user_id,seat,name,kicked,status)
        values(rid,users[1+((i*7+j*3)%70)],j-1,'P'||j,random()<0.15,
          case when random()<0.1 then 'left' else 'connected' end)
      on conflict do nothing;
    end loop;
  end loop;
  -- Blocks between some viewers and seated players.
  for i in 1..10 loop
    insert into public.player_blocks(blocker_id,blocked_id)
      values(viewers[i],users[1+(i*13)%70]) on conflict do nothing;
    insert into public.player_blocks(blocker_id,blocked_id)
      values(users[1+(i*17)%70],viewers[i]) on conflict do nothing;
  end loop;

  foreach v in array viewers loop
    select coalesce(jsonb_agg(to_jsonb(o)),'[]') into old_rows
      from public.public_room_listing_v2_pre_m7(v) o;
    select coalesce(jsonb_agg(to_jsonb(o)),'[]') into new_rows
      from public.public_room_listing_v2(v) o;
    if old_rows is distinct from new_rows then
      raise exception 'listing differs for %: old % new %', v, old_rows, new_rows;
    end if;

    -- The quick-match choice of the pre-M7 query (without the row lock).
    select r.code into old_pick from public.rooms r
     where r.status='lobby' and r.visibility='public'
       and coalesce(r.settings->>'scenarioCode','classic')='classic'
       and (select count(*) from public.room_players p where p.room_id=r.id and not p.kicked)
         < case when coalesce((r.settings->>'maxPlayers')::integer,10) in (5,8,10,15)
           then coalesce((r.settings->>'maxPlayers')::integer,10) else 10 end
       and not (v=any(coalesce(r.banned_user_ids,'{}'::uuid[])))
       and public.safety_room_compatible(r.id, v)
     order by (select count(*) from public.room_players p where p.room_id=r.id and not p.kicked) desc,
       r.created_at,r.id
     limit 1;
    listed_total:=listed_total+jsonb_array_length(new_rows);
    select c.code into new_pick from public.quick_match_candidates(v) c
     where public.safety_room_compatible(c.room_id,v) limit 1;
    if old_pick is distinct from new_pick then
      raise exception 'quick-match pick differs for %: % vs %', v, old_pick, new_pick;
    end if;
    if new_pick is not null then picks:=picks+1; end if;
  end loop;
  assert listed_total>=20 and picks>=5,
    format('population too thin to compare: %s rows, %s picks',listed_total,picks);

  -- A restricted player still sees nothing.
  insert into public.safety_restrictions(user_id,kind,ends_at)
    values(viewers[1],'public_rooms',now()+interval '1 day');
  assert not exists(select 1 from public.public_room_listing_v2(viewers[1])),'restricted';

  assert exists(select 1 from pg_indexes where indexname='room_players_active_seat'
    and indexdef like '%WHERE (NOT kicked)%'),'partial active-seat index';
  assert exists(select 1 from pg_indexes where indexname='rooms_public_lobby'),'lobby index';
end $$;
rollback;
