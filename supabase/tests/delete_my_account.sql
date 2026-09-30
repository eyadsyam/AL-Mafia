-- Contract for 20260930001100_delete_my_account: in-app account deletion.
-- Rolled back by the harness.
begin;
do $$
declare
  u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); w uuid:=gen_random_uuid();
  lo uuid; hi uuid; rid uuid:=gen_random_uuid(); report uuid:=gen_random_uuid();
  failed text; r jsonb;
begin
  insert into auth.users(id) values(u),(v),(w);
  lo:=least(u,v); hi:=greatest(u,v);

  -- Something of u's in the tables added after the last deletion wrapper.
  insert into public.wallet_accounts(user_id,balance) values(u,40),(v,7);
  insert into public.push_tokens(token,user_id,platform)
    values(repeat('a',30),u,'android'),(repeat('b',30),v,'web');
  insert into public.friend_links(user_lo,user_hi,requested_by) values(lo,hi,u);
  insert into public.council_preferences(user_id) values(u),(v);
  insert into public.terms_acceptances(user_id,terms_version,adult_confirmed,accepted_at)
    values(u,'2026-09-27',true,now()),(v,'2026-09-27',true,now());
  insert into public.player_blocks(blocker_id,blocked_id) values(u,v),(v,w);
  -- Abuse evidence that names u is kept: the moderation trail is not the
  -- player's to delete.
  insert into public.safety_reports(id,reporter_id,target_id,reason) values(report,v,u,'abuse');

  -- Only the service role can run it; nobody can name another account.
  assert not has_function_privilege('authenticated','public.delete_my_account(uuid)','execute');
  assert not has_function_privilege('anon','public.delete_my_account(uuid)','execute');
  assert has_function_privilege('service_role','public.delete_my_account(uuid)','execute');
  begin perform public.delete_my_account(null); failed:=null;
  exception when others then failed:=sqlerrm; end;
  assert failed='BAD_REQUEST',coalesce(failed,'null');

  -- In an unfinished room: refused, and nothing is deleted.
  insert into public.rooms(id,code,host_id,match_seed) values(rid,'DELACC',u,1);
  insert into public.room_players(room_id,user_id,name,seat) values(rid,u,'U',0),(rid,v,'V',1);
  begin perform public.delete_my_account(u); failed:=null;
  exception when others then failed:=sqlerrm; end;
  assert failed='ACTIVE_ROOM',coalesce(failed,'null');
  assert exists(select 1 from auth.users where id=u),'still there after a refusal';
  assert exists(select 1 from public.wallet_accounts where user_id=u);

  -- Once the room is over, deletion goes through.
  update public.rooms set status='finished' where id=rid;
  r:=public.delete_my_account(u);
  assert r='{"deleted": true}'::jsonb,r::text;
  assert not exists(select 1 from auth.users where id=u),'auth user gone';
  assert not exists(select 1 from public.wallet_accounts where user_id=u);
  assert not exists(select 1 from public.push_tokens where user_id=u);
  assert not exists(select 1 from public.friend_links where user_lo=u or user_hi=u);
  assert not exists(select 1 from public.council_preferences where user_id=u);
  assert not exists(select 1 from public.terms_acceptances where user_id=u);
  assert not exists(select 1 from public.player_blocks where blocker_id=u or blocked_id=u);
  assert not exists(select 1 from public.rooms where id=rid),'the finished room goes';

  -- Everyone else is untouched.
  assert exists(select 1 from auth.users where id=v);
  assert (select balance from public.wallet_accounts where user_id=v)=7;
  assert exists(select 1 from public.push_tokens where user_id=v);
  assert exists(select 1 from public.council_preferences where user_id=v);
  assert exists(select 1 from public.player_blocks where blocker_id=v and blocked_id=w);

  -- Evidence and the receipt stay; the request is marked done.
  assert exists(select 1 from public.safety_reports where id=report),'evidence kept';
  assert (select completed_at is not null from public.data_deletion_requests where user_id=u);

  -- The operator path is the same chain and still works for a filed request.
  insert into public.data_deletion_requests(user_id) values(v);
  perform public.complete_data_deletion((select id from public.data_deletion_requests where user_id=v));
  assert not exists(select 1 from auth.users where id=v);
  assert not exists(select 1 from public.push_tokens where user_id=v);
  assert exists(select 1 from auth.users where id=w);
end $$;
rollback;
