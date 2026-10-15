begin;
do $$
declare u uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); fresh uuid:=gen_random_uuid();
  deal jsonb; s uuid;
  truth public.story_v2_suspects; picks text[]:='{}'; i int; failed boolean;
  coins int:=(select coins from public.story_rewards where story_id='qahwet_el_moallem');
begin
  insert into auth.users(id) values(u),(other),(fresh);
  assert (select count(*) from public.story_v2_suspects where story_id='qahwet_el_moallem')=10,
    'the pilot seeds ten suspects';

  -- Refusals: unknown story, bad table size, an oversized avoid list.
  failed:=false;
  begin perform public.start_story_session(u,'no_such_story',5); exception when others then
    failed:=sqlerrm='NOT_FOUND'; end;
  assert failed,'unknown story is NOT_FOUND';
  failed:=false;
  begin perform public.start_story_session(u,'qahwet_el_moallem',11); exception when others then
    failed:=sqlerrm='BAD_REQUEST'; end;
  assert failed,'eleven players is BAD_REQUEST';
  failed:=false;
  begin perform public.start_story_session(u,'qahwet_el_moallem',3,
    array['a01','a02','a03','a04','a05','a06','a07','a08','a09','a10','a11']); exception when others then
    failed:=sqlerrm='BAD_REQUEST'; end;
  assert failed,'eleven avoided ids is BAD_REQUEST';

  -- The deal: a known suspect, partners only at 5+, recent culprits skipped.
  for i in 1..4 loop
    deal:=public.start_story_session(u,'qahwet_el_moallem',3);
    assert deal->>'partner' is null,'no partner under five players';
    assert exists(select 1 from public.story_v2_suspects where story_id='qahwet_el_moallem'
      and suspect_id=deal->>'culprit'),'the culprit is a seeded suspect';
    assert not (deal->>'culprit' = any(picks[greatest(1,cardinality(picks)-2):cardinality(picks)])),
      'the last three culprits are skipped';
    picks:=picks||(deal->>'culprit');
  end loop;
  deal:=public.start_story_session(fresh,'qahwet_el_moallem',5,
    array['n03','n04','n05','n06','n07','n08','n09','n10']);
  assert deal->>'culprit' in ('n01','n02'),'the phone''s avoided culprits are skipped too';
  assert deal->>'partner' is null or deal->>'partner'=
    (select partner_id from public.story_v2_suspects where story_id='qahwet_el_moallem'
      and suspect_id=deal->>'culprit'),'a partner is the culprit''s own';
  deal:=public.start_story_session(u,'qahwet_el_moallem',2,
    array['n01','n02','n03','n04','n05','n06','n07','n08','n09','n10']);
  assert deal->>'culprit' is not null,'everyone avoided still deals someone';

  -- A group table: who only, at least a minute after the deal, once.
  deal:=public.start_story_session(u,'qahwet_el_moallem',6);
  s:=(deal->>'sessionId')::uuid;
  assert (public.claim_story_session(u,s,deal->>'culprit')->>'granted')::int=0,'one minute floor';
  update public.story_v2_sessions set answered_at=null,started_at=now()-interval '5 minutes' where id=s;
  assert (public.claim_story_session(other,s,deal->>'culprit')->>'granted')::int=0,
    'the session belongs to its caller';
  assert (public.claim_story_session(u,s,'n00')->>'solved')::boolean=false,'a wrong name';
  assert (public.claim_story_session(u,s,deal->>'culprit')->>'granted')::int=0,
    'a wrong answer closes the session';
  assert not exists(select 1 from public.story_solves where user_id=u),'nothing solved yet';

  deal:=public.start_story_session(u,'qahwet_el_moallem',6);
  s:=(deal->>'sessionId')::uuid;
  update public.story_v2_sessions set started_at=now()-interval '13 hours' where id=s;
  assert (public.claim_story_session(u,s,deal->>'culprit')->>'granted')::int=0,'twelve hour window';

  -- Solo: who, why and how. A right who with a wrong why pays nothing.
  deal:=public.start_story_session(u,'qahwet_el_moallem',1);
  s:=(deal->>'sessionId')::uuid;
  select * into truth from public.story_v2_suspects where story_id='qahwet_el_moallem'
    and suspect_id=deal->>'culprit';
  update public.story_v2_sessions set started_at=now()-interval '5 minutes' where id=s;
  assert (public.claim_story_session(u,s,truth.suspect_id,'wrong',truth.method_id)->>'solved')::boolean=false,
    'solo needs why';
  deal:=public.start_story_session(u,'qahwet_el_moallem',1);
  s:=(deal->>'sessionId')::uuid;
  select * into truth from public.story_v2_suspects where story_id='qahwet_el_moallem'
    and suspect_id=deal->>'culprit';
  update public.story_v2_sessions set started_at=now()-interval '5 minutes' where id=s;
  deal:=public.claim_story_session(u,s,truth.suspect_id,truth.motive_id,truth.method_id);
  assert (deal->>'solved')::boolean,'solo solved';
  assert (deal->>'granted')::int=coins,'the first solve pays the story''s coins';
  assert (public.claim_story_session(u,s,truth.suspect_id,truth.motive_id,truth.method_id)->>'granted')::int=0,
    'one answer per session';

  -- The first solve is paid once per account, across tables.
  deal:=public.start_story_session(u,'qahwet_el_moallem',4);
  s:=(deal->>'sessionId')::uuid;
  update public.story_v2_sessions set started_at=now()-interval '5 minutes' where id=s;
  deal:=public.claim_story_session(u,s,deal->>'culprit');
  assert (deal->>'solved')::boolean and (deal->>'granted')::int=0,'solved again pays nothing';
  assert (select count(*) from public.wallet_ledger where user_id=u and kind='story_first_solve')=1,
    'one ledger row';

  -- Thirty tables an hour.
  for i in 1..40 loop
    begin perform public.start_story_session(other,'qahwet_el_moallem',5);
    exception when others then
      assert sqlerrm='STORY_LIMIT','only the hourly limit refuses';
      assert i>30,'thirty tables are allowed';
      exit;
    end;
    assert i<=30,'the thirty-first table is refused';
  end loop;
  update public.story_v2_sessions set started_at=started_at-interval '2 hours' where user_id=other;
  perform public.start_story_session(other,'qahwet_el_moallem',5);
  assert (select count(*) from public.story_v2_sessions where user_id=other)=10,
    'ten tables of history per story once the hour has passed';

  assert not has_function_privilege('authenticated',
    'public.start_story_session(uuid,text,int,text[])','execute'),'service role only';
  assert not has_function_privilege('authenticated',
    'public.claim_story_session(uuid,uuid,text,text,text)','execute'),'service role only';
end $$;
rollback;
