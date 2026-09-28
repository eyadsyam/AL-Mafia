-- F10: titles and the core Partner. Dark by default; exact-once grants from
-- claimed Season levels and the invite unlock; equip/replay/refusals; titles
-- visible only pre-deal and on the result; Partner free outside a live match.
begin;
do $$
declare
  u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); season bigint; rid uuid:=gen_random_uuid();
  req uuid:=gen_random_uuid(); r jsonb; again jsonb; i int; mates uuid[]:='{}';
begin
  insert into auth.users(id) values(u),(v);
  for i in 1..3 loop mates:=mates||gen_random_uuid(); insert into auth.users(id) values(mates[i]); end loop;

  -- Dark by default: reads say disabled, writes refuse, capability false.
  assert public.title_hub(u)='{"enabled":false}'::jsonb;
  assert public.partner_get(u)='{"enabled":false}'::jsonb;
  assert (public.title_equip(u,null,gen_random_uuid()))->>'code'='DISABLED';
  assert (public.partner_set(u,'doctor',gen_random_uuid()))->>'code'='DISABLED';
  assert public.economy_capabilities(u)->'titles'='false'::jsonb;
  assert public.economy_capabilities(u)->'partner'='false'::jsonb;
  -- Partner needs character bonds too (§6 dependency).
  update public.economy_config set partner_enabled=true;
  assert public.economy_capabilities(u)->'partner'='false'::jsonb,'partner without bonds';
  update public.economy_config set character_bonds_enabled=true,titles_enabled=true;
  assert public.economy_capabilities(u)->'partner'='true'::jsonb;
  assert public.economy_capabilities(u)->'titles'='true'::jsonb;

  -- No titles owned yet; equipping one not owned is refused.
  r:=public.title_hub(u);
  assert (r->>'enabled')::boolean and r->'equipped'='null'::jsonb,r::text;
  assert not exists(select 1 from jsonb_array_elements(r->'titles') t where (t->>'owned')::boolean);
  assert (public.title_equip(u,'season_zero_night_scribe',gen_random_uuid()))->>'code'='NOT_READY';

  -- Claimed Season level 10 carries a title: granted once, by sync.
  select id into season from public.mission_seasons where code='season_zero';
  insert into public.season_reward_claims(user_id,season_id,level) values(u,season,10);
  perform public.titles_sync(u);
  perform public.titles_sync(u);
  assert (select count(*) from public.player_titles where user_id=u)=1,'exact once';
  assert (select source_key from public.player_titles where user_id=u)='season:season_zero:10';
  -- The invite unlock grants «كبير الشلة».
  insert into public.invite_unlocks(user_id,code) values(u,'title_kabir_elshella');
  perform public.titles_sync(u);
  assert exists(select 1 from public.player_titles where user_id=u and code='kabir_elshella');

  -- Equip, replay by request id, unequip.
  r:=public.title_equip(u,'kabir_elshella',req);
  assert (r->>'ok')::boolean and r->>'requestId'=req::text,r::text;
  assert r->'grant'='{"coins":0,"xp":0}'::jsonb,'titles grant nothing';
  assert r->'state'->>'equipped'='kabir_elshella',r::text;
  again:=public.title_equip(u,'season_zero_night_scribe',req);
  assert again=r,'a replay returns the first answer, not a second equip';
  assert (select equipped_title from public.player_showcase where user_id=u)='kabir_elshella';
  r:=public.title_equip(u,null,gen_random_uuid());
  assert r->'state'->'equipped'='null'::jsonb,'unequipped';
  perform public.title_equip(u,'kabir_elshella',gen_random_uuid());

  -- Room titles: lobby and finished answer; a live room answers nothing.
  insert into public.rooms(id,code,host_id,match_seed) values(rid,'TTLPRT',u,1);
  insert into public.room_state(room_id,phase) values(rid,'lobby');
  insert into public.room_players(room_id,user_id,name,seat) values(rid,u,'U',0),(rid,v,'V',1);
  r:=public.room_titles(v,rid);
  assert r->'seats'->'0'->>'code'='kabir_elshella',r::text;
  assert not (r->'seats' ? '1'),'no title equipped, no entry';
  assert not (r::text like '%'||u::text||'%'),'seats, never user ids';
  update public.rooms set status='playing' where id=rid;
  assert public.room_titles(v,rid)->'seats'='{}'::jsonb,'no titles while the room is played';
  update public.rooms set status='finished',ended_at=now() where id=rid;
  assert public.room_titles(v,rid)->'seats'->'0'->>'code'='kabir_elshella','result shows it';
  begin
    perform public.room_titles(mates[1],rid);
    raise exception 'a non-member read titles';
  exception when others then assert sqlerrm='NOT_MEMBER',sqlerrm;
  end;

  -- Partner: set, replay, free switch, refused inside a live match.
  r:=public.partner_set(v,'detective',req);
  assert (r->>'ok')::boolean and r->'state'->>'side'='detective',r::text;
  assert public.partner_set(v,'mafia',req)=r,'replay';
  r:=public.partner_set(v,'mafia',gen_random_uuid());
  assert r->'state'->>'side'='mafia','free switch';
  assert (public.partner_set(v,'jester',gen_random_uuid()))->>'code'='BAD_REQUEST';
  update public.rooms set status='playing',ended_at=null where id=rid;
  r:=public.partner_set(v,'doctor',gen_random_uuid());
  assert r->>'code'='IN_MATCH',r::text;
  assert not (r::text like '%'||rid::text||'%'),'the refusal names no room';
  assert public.partner_get(v)->>'side'='mafia','unchanged during a live match';
  update public.room_players set status='left' where room_id=rid and user_id=v;
  assert (public.partner_set(v,'doctor',gen_random_uuid()))->>'ok'='true','left the match';

  -- Switches off again: reads disabled, stored choices kept.
  update public.economy_config set titles_enabled=false,partner_enabled=false;
  assert public.title_hub(u)='{"enabled":false}'::jsonb;
  assert public.partner_get(v)='{"enabled":false}'::jsonb;
  assert exists(select 1 from public.player_partner where user_id=v);

  -- Deletion.
  insert into public.data_deletion_requests(user_id) values(u);
  update public.rooms set status='finished' where id=rid;
  perform public.complete_data_deletion((select id from public.data_deletion_requests where user_id=u));
  assert not exists(select 1 from public.player_titles where user_id=u);
  assert not exists(select 1 from public.player_showcase where user_id=u);
  assert not exists(select 1 from public.profile_request_receipts where user_id=u);

  assert not has_function_privilege('authenticated','public.title_equip(uuid,text,uuid)','execute');
  assert not has_function_privilege('anon','public.partner_set(uuid,text,uuid)','execute');
  assert has_function_privilege('service_role','public.room_titles(uuid,uuid)','execute');
end $$;
rollback;
