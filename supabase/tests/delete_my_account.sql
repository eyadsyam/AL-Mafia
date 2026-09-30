-- Contract for 20260930001100_delete_my_account: in-app account deletion.
-- Rolled back by the harness.
--
-- The privacy page promises that the push token, friends, blocks, invites and
-- the handle go with the account. None of those tables has a foreign key to
-- auth.users, so nothing cascades: every one of them is asserted here by name,
-- and a catalog sweep at the end fails if ANY table that keys a row by a user
-- id column is left holding one (except the evidence and accounting tables
-- that are kept on purpose and listed below).
begin;
do $$
declare
  u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); w uuid:=gen_random_uuid();
  lo uuid; hi uuid; rid uuid:=gen_random_uuid(); report uuid:=gen_random_uuid();
  failed text; r jsonb; left_behind text; leftover bigint; t record;
begin
  insert into auth.users(id) values(u),(v),(w);
  lo:=least(u,v); hi:=greatest(u,v);

  -- Something of u's in the tables added after the last deletion wrapper.
  insert into public.wallet_accounts(user_id,balance) values(u,40),(v,7);
  insert into public.push_tokens(token,user_id,platform)
    values(repeat('a',30),u,'android'),(repeat('b',30),u,'web'),(repeat('c',30),v,'web');
  -- Friends: one accepted link and one pending request u sent to w.
  insert into public.friend_links(user_lo,user_hi,requested_by,accepted_at) values(lo,hi,u,now());
  insert into public.friend_links(user_lo,user_hi,requested_by)
    values(least(u,w),greatest(u,w),u);
  insert into public.council_preferences(user_id) values(u),(v);
  insert into public.terms_acceptances(user_id,terms_version,adult_confirmed,accepted_at)
    values(u,'2026-09-27',true,now()),(v,'2026-09-27',true,now());
  insert into public.player_blocks(blocker_id,blocked_id) values(u,v),(v,u),(v,w);
  -- The handle (the public username) and the invite trail, both directions.
  insert into public.player_directory(user_id,handle,handle_norm,display_name,name_norm)
    values(u,'u_handle','u_handle','U','u'),(v,'v_handle','v_handle','V','v');
  insert into public.invite_events(from_user,to_user,room_id,stranger)
    values(u,v,rid,false),(v,u,rid,false),(v,w,rid,true);

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
  insert into public.room_invites(room_id,to_user,from_user) values(rid,v,u),(rid,u,v),(rid,w,v);
  begin perform public.delete_my_account(u); failed:=null;
  exception when others then failed:=sqlerrm; end;
  assert failed='ACTIVE_ROOM',coalesce(failed,'null');
  assert exists(select 1 from auth.users where id=u),'still there after a refusal';
  assert exists(select 1 from public.wallet_accounts where user_id=u);
  assert exists(select 1 from public.push_tokens where user_id=u),'a refusal deletes nothing';

  -- Once the room is over, deletion goes through.
  update public.rooms set status='finished' where id=rid;
  r:=public.delete_my_account(u);
  assert r='{"deleted": true}'::jsonb,r::text;
  assert not exists(select 1 from auth.users where id=u),'auth user gone';
  assert not exists(select 1 from public.wallet_accounts where user_id=u);
  assert not exists(select 1 from public.push_tokens where user_id=u),'push tokens (both)';
  assert not exists(select 1 from public.friend_links where user_lo=u or user_hi=u or requested_by=u),
    'friends and friend requests';
  assert not exists(select 1 from public.player_blocks where blocker_id=u or blocked_id=u),'blocks';
  assert not exists(select 1 from public.room_invites where from_user=u or to_user=u),'room invites';
  assert not exists(select 1 from public.invite_events where from_user=u or to_user=u),'invite events';
  assert not exists(select 1 from public.player_directory where user_id=u),'the handle';
  assert not exists(select 1 from public.council_preferences where user_id=u);
  assert not exists(select 1 from public.terms_acceptances where user_id=u);
  assert not exists(select 1 from public.rooms where id=rid),'the finished room goes';

  -- Everyone else is untouched, including rows that merely mention u.
  assert exists(select 1 from auth.users where id=v);
  assert (select balance from public.wallet_accounts where user_id=v)=7;
  assert exists(select 1 from public.push_tokens where user_id=v);
  assert exists(select 1 from public.council_preferences where user_id=v);
  assert exists(select 1 from public.player_blocks where blocker_id=v and blocked_id=w);
  assert exists(select 1 from public.player_directory where user_id=v);
  assert exists(select 1 from public.invite_events where from_user=v and to_user=w);

  -- Evidence and the receipt stay; the request is marked done.
  assert exists(select 1 from public.safety_reports where id=report),'evidence kept';
  assert (select completed_at is not null from public.data_deletion_requests where user_id=u);

  -- The sweep, from the catalog: no table is left holding a row keyed by u,
  -- except the ones kept on purpose.
  for t in
    select c.table_name::text tbl, c.column_name::text col
      from information_schema.columns c
      join information_schema.tables x
        on x.table_schema=c.table_schema and x.table_name=c.table_name
     where c.table_schema='public' and x.table_type='BASE TABLE' and c.data_type='uuid'
       and c.column_name in ('user_id','blocker_id','blocked_id','from_user','to_user',
                             'inviter','invitee','user_lo','user_hi','requested_by',
                             'actor_id','author_id','voter_id','from_id','to_id','host_id')
       and c.table_name not in ('data_deletion_requests','safety_reports','whisper_reports',
                                'safety_audit','safety_audit_monthly','safety_admin_receipts',
                                'operator_audit_log','creator_entitlement_audit')
  loop
    execute format('select count(*) from public.%I where %I=$1',t.tbl,t.col) into leftover using u;
    assert leftover=0, format('%s.%s still holds %s row(s) of a deleted account',t.tbl,t.col,leftover);
  end loop;

  -- The operator path is the same chain and still works for a filed request.
  insert into public.data_deletion_requests(user_id) values(v);
  perform public.complete_data_deletion((select id from public.data_deletion_requests where user_id=v));
  assert not exists(select 1 from auth.users where id=v);
  assert not exists(select 1 from public.push_tokens where user_id=v);
  assert not exists(select 1 from public.player_directory where user_id=v);
  assert not exists(select 1 from public.invite_events where from_user=v or to_user=v);
  assert exists(select 1 from auth.users where id=w);
end $$;
rollback;
