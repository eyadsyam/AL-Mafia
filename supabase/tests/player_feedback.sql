begin;
do $$
declare
  owner uuid := gen_random_uuid();
  player uuid := gen_random_uuid();
  guest uuid := gen_random_uuid();
  stranger uuid := gen_random_uuid();
  first_id uuid;
  next_id uuid;
  rows jsonb;
  n int;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values
    (owner,'feedback-owner@example.com',now(),false),
    (player,'feedback-player@example.com',now(),false),
    (guest,null,null,true),(stranger,null,null,true);
  insert into public.commerce_admins(user_id,note) values(owner,'owner');
  insert into public.player_directory(user_id,handle,handle_norm,display_name,name_norm)
    values(player,'fb_player','fb_player','Sender','sender');
  update public.economy_config set push_invites_enabled=true, friends_enabled=true;
  perform public.push_token_register(owner,repeat('f',40),'android');

  -- A guest (anonymous session) is sent to sign in, whatever the body says.
  begin
    perform public.submit_feedback(guest,'idea','More scenes would be great',18,'android');
    raise exception 'anonymous feedback accepted';
  exception when others then assert sqlerrm='SIGN_IN_REQUIRED',sqlerrm; end;
  assert (select count(*) from public.player_feedback where user_id=guest)=0;

  -- Too short: under 3 words, or under 10 non-space characters.
  begin
    perform public.submit_feedback(player,'idea','More scenes',18,'android');
    raise exception 'two words accepted';
  exception when others then assert sqlerrm='TOO_SHORT',sqlerrm; end;
  begin
    perform public.submit_feedback(player,'idea','a b c d e',18,'android');
    raise exception 'nine characters accepted';
  exception when others then assert sqlerrm='TOO_SHORT',sqlerrm; end;

  first_id := public.submit_feedback(player,'idea','More scenes please',18,'android');
  assert first_id is not null;
  assert (select count(*) from public.player_feedback where id=first_id)=1;
  assert (select count(*) from public.push_outbox where kind='owner_feedback' and user_id=owner)=1;
  assert (select payload from public.push_outbox where kind='owner_feedback')='{}'::jsonb;

  begin
    perform public.submit_feedback(player,'invalid','More scenes please',18,'android');
    raise exception 'invalid kind accepted';
  exception when others then assert sqlerrm='BAD_REQUEST',sqlerrm; end;
  begin
    perform public.submit_feedback(player,'idea','  ',18,'android');
    raise exception 'empty body accepted';
  exception when others then assert sqlerrm='BAD_REQUEST',sqlerrm; end;
  begin
    perform public.submit_feedback(player,'idea','Another scene please',18,'android');
    raise exception 'ten-minute limit missed';
  exception when others then assert sqlerrm='RATE_LIMITED',sqlerrm; end;

  update public.player_feedback set created_at=now()-interval '11 minutes' where id=first_id;
  next_id := public.submit_feedback(player,'roles','New role please now',18,'web');
  assert next_id is not null;
  for n in 2..4 loop
    update public.player_feedback set created_at=now()-(n*interval '11 minutes') where id=next_id;
    next_id := public.submit_feedback(player,'look','More colors please now',18,'ios');
  end loop;
  update public.player_feedback set created_at=now()-interval '55 minutes' where id=next_id;
  assert (select count(*) from public.player_feedback where user_id=player)=5;
  begin
    perform public.submit_feedback(player,'idea','One more idea please',18,'android');
    raise exception 'daily limit missed';
  exception when others then assert sqlerrm='RATE_LIMITED',sqlerrm; end;

  begin
    perform public.admin_feedback(stranger,null);
    raise exception 'stranger read';
  exception when others then assert sqlerrm='NOT_ADMIN',sqlerrm; end;
  begin
    perform public.admin_feedback_mark(stranger,first_id,'read');
    raise exception 'stranger marked';
  exception when others then assert sqlerrm='NOT_ADMIN',sqlerrm; end;
  rows := public.admin_feedback(owner,null);
  assert jsonb_array_length(rows->'items')=5,rows::text;
  -- The owner sees who sent it: name and @handle, with build and platform.
  assert rows->'items'->0->>'handle'='fb_player',rows::text;
  assert rows->'items'->0->>'displayName'='Sender',rows::text;
  assert (rows->'items'->0->>'appBuild')::int=18 and rows->'items'->0->>'platform' is not null,rows::text;
  perform public.admin_feedback_mark(owner,first_id,'read');
  assert (select status from public.player_feedback where id=first_id)='read';
  assert jsonb_array_length(public.admin_feedback(owner,'read')->'items')=1;
  assert not has_function_privilege('authenticated','public.submit_feedback(uuid,text,text,int,text)','execute');
  assert not has_function_privilege('authenticated','public.admin_feedback(uuid,text)','execute');
  assert not has_table_privilege('authenticated','public.player_feedback','select');
end $$;
rollback;
