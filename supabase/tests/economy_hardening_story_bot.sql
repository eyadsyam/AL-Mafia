begin;
do $$
declare u uuid:=gen_random_uuid(); s uuid; old_session uuid; answer record; first jsonb; i int;
begin
  insert into auth.users(id) values(u);
  assert (select count(*) from public.story_solutions)=24,'all bundled stories loaded';
  select * into answer from public.story_solutions where story_id='el_arousa';
  first:=public.claim_story_reward(u,'el_arousa','wrong',answer.motive,answer.method);
  assert (first->>'granted')::int=0 and (first->>'xpGranted')::int=0,'wrong answer pays nothing';
  assert not exists(select 1 from public.story_solves where user_id=u),'wrong answer did not consume solve';
  first:=public.claim_story_reward(u,'el_arousa',answer.culprit,answer.motive,answer.method);
  assert (first->>'granted')::int>0,'correct answer pays';
  assert (public.claim_story_reward(u,'el_arousa',answer.culprit,answer.motive,answer.method)->>'granted')::int=0,
    'first solve only';

  s:=(public.start_bot_match(u)->>'sessionId')::uuid;
  old_session:=s;
  s:=(public.start_bot_match(u)->>'sessionId')::uuid;
  assert (public.claim_bot_win(u,old_session)->>'granted')::int=0,
    'starting a new match invalidates the old session';
  assert (public.claim_bot_win(u,s)->>'granted')::int=0,'one minute floor';
  update public.bot_match_sessions set started_at=now()-interval '2 minutes' where id=s;
  assert (public.claim_bot_win(u,gen_random_uuid())->>'granted')::int=0,'session belongs to caller';
  assert (public.claim_bot_win(u,s)->>'granted')::int=25,'valid session pays';
  assert (public.claim_bot_win(u,s)->>'granted')::int=0,'session consumed once';
  assert (select count(*) from public.bot_wins where user_id=u)=1,'one win row';
  for i in 1..5 loop
    s:=(public.start_bot_match(u)->>'sessionId')::uuid;
    update public.bot_match_sessions set started_at=now()-interval '2 minutes' where id=s;
    first:=public.claim_bot_win(u,s);
    assert (first->>'granted')::int=case when i<5 then 25 else 0 end,
      'daily cap remains five';
  end loop;
  assert (select count(*) from public.bot_wins where user_id=u)=5,'five paid wins';
end $$;
rollback;
