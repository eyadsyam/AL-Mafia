begin;
do $$
declare u uuid:=gen_random_uuid(); answer record; first jsonb;
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

end $$;
rollback;
