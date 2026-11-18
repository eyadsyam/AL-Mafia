-- Contract for 20261119000400_player_ratings. Rolled back.
begin;
do $$
declare
  owner uuid := gen_random_uuid();
  guest uuid := gen_random_uuid();
  other uuid := gen_random_uuid();
  answer jsonb;
  ratings jsonb;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
    (owner,'rating-owner@example.com',now(),false),(guest,null,null,true),(other,null,null,true);
  insert into public.commerce_admins(user_id,note) values(owner,'owner');
  delete from public.player_ratings;

  -- An anonymous account may rate; text is trimmed and kept.
  answer := public.submit_rating(guest,5,'  great game  ',25,'android');
  assert (answer->>'id') is not null, answer::text;
  assert (select body from public.player_ratings where user_id=guest)='great game';

  -- An empty or blank body is stored as null.
  perform public.submit_rating(guest,4,'   ',25,'web');
  perform public.submit_rating(other,3,null,25,'ios');
  assert (select count(*) from public.player_ratings where body is null)=2;

  -- Stars outside 1..5, a body over 500, a bad platform or a missing user: refused.
  begin perform public.submit_rating(other,0,null,25,'android'); raise exception 'stars 0 accepted';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin perform public.submit_rating(other,6,null,25,'android'); raise exception 'stars 6 accepted';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin perform public.submit_rating(other,3,repeat('x',501),25,'android'); raise exception 'long body accepted';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin perform public.submit_rating(other,3,null,25,'linux'); raise exception 'platform accepted';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;
  begin perform public.submit_rating(gen_random_uuid(),3,null,25,'android'); raise exception 'unknown user accepted';
  exception when others then assert sqlerrm='BAD_REQUEST', sqlerrm; end;

  -- The fourth rating in a day from one user is refused.
  perform public.submit_rating(guest,2,null,25,'android');
  begin perform public.submit_rating(guest,5,null,25,'android'); raise exception 'fourth rating accepted';
  exception when others then assert sqlerrm='RATE_LIMITED', sqlerrm; end;
  assert (select count(*) from public.player_ratings where user_id=guest)=3;

  -- The owner's view: counts, averages, latest lines with text; no user id.
  ratings := public.admin_feedback(owner)->'ratings';
  assert (ratings->>'count')::int=4, ratings::text;
  assert (ratings->>'avg7') is not null and (ratings->>'avg30') is not null;
  assert jsonb_array_length(ratings->'latest')=1, ratings::text;
  assert (ratings->'latest'->0->>'stars')::int=5;
  assert not (ratings->'latest'->0 ? 'user_id') and not (ratings->'latest'->0 ? 'userId');
  assert public.admin_feedback(owner) ? 'items';

  -- Only the service role may call it.
  assert not has_function_privilege('anon','public.submit_rating(uuid,int,text,int,text)','execute');
  assert not has_function_privilege('authenticated','public.submit_rating(uuid,int,text,int,text)','execute');
  assert has_function_privilege('service_role','public.submit_rating(uuid,int,text,int,text)','execute');
  assert not has_table_privilege('authenticated','public.player_ratings','select');
  assert not has_table_privilege('anon','public.player_ratings','insert');
end $$;
rollback;
