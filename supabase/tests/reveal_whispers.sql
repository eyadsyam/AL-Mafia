-- Contract for 20260930000800_reveal_whispers (Doc 09 §7). Rolled back.
begin;
-- The list inside the answer (null = not revealed).
create function pg_temp.match_whispers_revealed_list(p_user uuid,p_room uuid) returns jsonb
language sql as $$ select nullif(public.match_whispers_revealed(p_user,p_room)->'whispers','null'::jsonb) $$;
do $$
declare
  r uuid := gen_random_uuid(); other uuid := gen_random_uuid();
  a uuid := '00000000-0000-4000-8000-0000000000a1';
  b uuid := '00000000-0000-4000-8000-0000000000a2';
  d uuid := '00000000-0000-4000-8000-0000000000a3';
  k uuid := '00000000-0000-4000-8000-0000000000a4';
  w1 uuid; w2 uuid; wv uuid; res jsonb; t text;
begin
  insert into public.rooms(id,code,host_id,match_seed,status,settings)
    values(r,'RVWHAA',a,1,'playing',jsonb_build_object('revealWhisperContent',true));
  insert into public.rooms(id,code,host_id,match_seed,status) values(other,'RVWHBB',k,2,'finished');
  insert into public.room_players(room_id,user_id,name,seat,role,alive,kicked) values
    (r,a,'Aa',0,'mafia',true,false),(r,b,'Bb',1,'doctor',true,false),
    (r,d,'Dd',2,'citizen',false,false),(r,k,'Kk',3,'citizen',true,true);
  insert into public.room_state(room_id,phase,public_data) values(r,'discuss','{}');
  insert into public.whisper_meta(id,room_id,day,from_id,to_id) values
    (gen_random_uuid(),r,1,a,b) returning id into w1;
  insert into public.whisper_content(whisper_id,body) values(w1,'<i>صدقني</i>');
  insert into public.whisper_meta(id,room_id,day,from_id,to_id) values
    (gen_random_uuid(),r,2,b,d) returning id into w2;
  insert into public.whisper_content(whisper_id,body) values(w2,'مين؟');
  insert into public.whisper_meta(id,room_id,day,from_id,to_id,voided) values
    (gen_random_uuid(),r,2,a,d,true) returning id into wv;
  insert into public.whisper_content(whisper_id,body) values(wv,'never read');

  -- During the match: nobody, not even the two parties, through this door.
  assert pg_temp.match_whispers_revealed_list(a,r) is null,'revealed before the end';
  assert pg_temp.match_whispers_revealed_list(d,r) is null,'the dead read it here before the end';

  -- The public end: every seated member, alive or dead at the end.
  update public.rooms set status='finished' where id=r;
  update public.room_state set phase='result',public_data='{"outcome":"town"}' where room_id=r;
  res := pg_temp.match_whispers_revealed_list(d,r);
  assert jsonb_array_length(res)=2, res::text;
  assert (res->0->>'fromSeat')::int=0 and (res->0->>'toSeat')::int=1 and res->0->>'text'='<i>صدقني</i>', res::text;
  assert res->1->>'text'='مين؟';
  t := res::text;
  assert position('never read' in t)=0,'a voided whisper was revealed';
  assert t !~ '"(role|mafia|doctor|citizen|userId|fromId|toId)"', 'identity or role leaked: '||t;
  assert jsonb_array_length(pg_temp.match_whispers_revealed_list(a,r))=2;

  -- Strangers, removed seats and other rooms' members get nothing.
  assert pg_temp.match_whispers_revealed_list(gen_random_uuid(),r) is null,'a stranger read them';
  assert pg_temp.match_whispers_revealed_list(k,r) is null,'a removed seat read them';
  assert pg_temp.match_whispers_revealed_list(k,other) is null;

  -- A sender the viewer blocked is masked for that viewer.
  insert into public.player_blocks(blocker_id,blocked_id) values(d,a);
  res := pg_temp.match_whispers_revealed_list(d,r);
  assert (res->0->>'masked')::boolean and res->0->'text'='null'::jsonb, res::text;
  delete from public.player_blocks where blocker_id=d;

  -- A room that did not switch it on (the default) reveals nothing.
  update public.rooms set settings='{}'::jsonb where id=r;
  assert pg_temp.match_whispers_revealed_list(a,r) is null,'default off still revealed';
  update public.rooms set settings=jsonb_build_object('revealWhisperContent','yes') where id=r;
  assert pg_temp.match_whispers_revealed_list(a,r) is null,'only a true boolean switches it on';

  -- An abandoned room (no public outcome) never reveals.
  update public.rooms set settings=jsonb_build_object('revealWhisperContent',true) where id=r;
  update public.room_state set public_data='{}' where room_id=r;
  assert pg_temp.match_whispers_revealed_list(a,r) is null,'no outcome, no reveal';
end $$;
rollback;
