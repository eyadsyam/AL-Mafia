-- Contract for 20260928001300_witness_whispers (F21a). Rolled back by the SQL harness.
begin;
do $$
declare
  r uuid := gen_random_uuid(); other uuid := gen_random_uuid();
  dead uuid := '00000000-0000-4000-8000-0000000000f1';
  a uuid := '00000000-0000-4000-8000-0000000000f2';
  b uuid := '00000000-0000-4000-8000-0000000000f3';
  c uuid := '00000000-0000-4000-8000-0000000000f4';
  w1 uuid; w2 uuid; wv uuid; res jsonb; t text; rep jsonb;
begin
  insert into public.rooms(id,code,host_id,match_seed,status) values(r,'WTNSAA',a,1,'playing');
  insert into public.rooms(id,code,host_id,match_seed,status) values(other,'WTNSBB',c,2,'playing');
  insert into public.room_players(room_id,user_id,name,seat,role,alive) values
    (r,dead,'Dead',0,'citizen',false),(r,a,'Aa',1,'mafia',true),(r,b,'Bb',2,'doctor',true),
    (other,c,'Cc',0,'citizen',false);
  insert into public.whisper_meta(id,room_id,day,from_id,to_id) values
    (gen_random_uuid(),r,1,a,b) returning id into w1;
  insert into public.whisper_content(whisper_id,body) values(w1,'<b>هو ده المحقق</b> 🕵️');
  insert into public.whisper_meta(id,room_id,day,from_id,to_id) values
    (gen_random_uuid(),r,2,b,a) returning id into w2;
  insert into public.whisper_content(whisper_id,body) values(w2,repeat('ا',120));
  insert into public.whisper_meta(id,room_id,day,from_id,to_id,voided) values
    (gen_random_uuid(),r,2,dead,a,true) returning id into wv;
  insert into public.whisper_content(whisper_id,body) values(wv,'never delivered');

  -- Off by default: nothing, even for the dead.
  assert public.witness_whispers(r,dead) is null, 'whispers served with the flag off';
  update public.economy_config set witness_whispers_enabled=true;

  -- The living, strangers and other rooms' dead get nothing.
  assert public.witness_whispers(r,a) is null, 'a living member saw whispers';
  assert public.witness_whispers(r,gen_random_uuid()) is null, 'a stranger saw whispers';
  assert public.witness_whispers(r,c) is null, 'another room''s dead saw whispers';

  -- The dead see every delivered whisper, between anyone, in order; voided never.
  res := public.witness_whispers(r,dead);
  assert jsonb_array_length(res)=2, res::text;
  assert res->0->>'id'=w1::text and (res->0->>'fromSeat')::int=1 and (res->0->>'toSeat')::int=2, res::text;
  assert res->0->>'text'='<b>هو ده المحقق</b> 🕵️', 'text altered: '||(res->0->>'text');
  assert char_length(res->1->>'text')=120;
  t := res::text;
  assert position('never delivered' in t)=0, 'a voided whisper was shown';
  assert t !~ '"(role|mafia|doctor|citizen|userId|fromId|toId)"', 'identity or role in whispers: '||t;

  -- A room whose witness setting is off shows none.
  update public.rooms set settings=jsonb_build_object('witnessKnowledge',false) where id=r;
  assert public.witness_whispers(r,dead) is null, 'witness setting off still served whispers';
  update public.rooms set settings='{}'::jsonb where id=r;

  -- A sender the viewer blocked is masked for that viewer only.
  insert into public.player_blocks(blocker_id,blocked_id) values(dead,a);
  res := public.witness_whispers(r,dead);
  assert (res->0->>'masked')::boolean and res->0->'text'='null'::jsonb, res::text;
  assert not (res->1->>'masked')::boolean and res->1->>'text' is not null;
  delete from public.player_blocks where blocker_id=dead;

  -- A death by committed row only: revive the seat and the view closes.
  update public.room_players set alive=true where room_id=r and user_id=dead;
  assert public.witness_whispers(r,dead) is null;
  update public.room_players set alive=false where room_id=r and user_id=dead;

  -- Report by id: the text is kept as evidence; replay and dedup hold.
  rep := public.witness_report(dead,r,w1,'threat','40000000-0000-4000-8000-000000000001');
  assert exists(select 1 from public.whisper_reports where whisper_id=w1 and reporter_id=dead);
  assert (select evidence->>'whisperText' from public.safety_reports where id=(rep->>'receipt')::uuid)
    = '<b>هو ده المحقق</b> 🕵️', 'evidence lost the text';
  assert (select target_id from public.safety_reports where id=(rep->>'receipt')::uuid)=a;
  assert (public.witness_report(dead,r,w1,'threat','40000000-0000-4000-8000-000000000001')->>'replayed')::boolean;
  assert (public.witness_report(dead,r,w1,'spam','40000000-0000-4000-8000-000000000002')->>'receipt')
    = rep->>'receipt', 'second report of one whisper not deduplicated';
  begin
    perform public.witness_report(a,r,w2,'other','40000000-0000-4000-8000-000000000003');
    raise exception 'a living player reported a witnessed whisper';
  exception when raise_exception then assert sqlerrm='WITNESS_ONLY', sqlerrm; end;
  begin
    perform public.witness_report(dead,r,wv,'other','40000000-0000-4000-8000-000000000004');
    raise exception 'a voided whisper was reportable';
  exception when raise_exception then assert sqlerrm='BAD_REQUEST', sqlerrm; end;

  -- Direct reads stay denied; the functions are service-role only.
  assert not has_function_privilege('authenticated','public.witness_whispers(uuid,uuid)','execute');
  assert not has_function_privilege('authenticated','public.witness_report(uuid,uuid,uuid,text,uuid)','execute');
  assert not exists (select 1 from pg_publication_tables
    where pubname='supabase_realtime' and tablename='whisper_content'), 'whisper text is published';
  perform set_config('request.jwt.claim.sub', dead::text, true);
  set local role authenticated;
  assert not exists(select 1 from public.whisper_content where whisper_id in (w1,w2)), 'the dead read others'' whisper text directly';
  reset role;
  assert (public.economy_capabilities(dead)->'witness'->>'whispers')='true';
end $$;
rollback;
