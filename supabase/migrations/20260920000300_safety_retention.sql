-- Operator-only completion, after the person's active rooms have closed.
create function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests where id=p_request and completed_at is null for update;
  if who is null then raise exception 'REQUEST_NOT_FOUND'; end if;
  if exists(select 1 from public.rooms r join public.room_players p on p.room_id=r.id
    where p.user_id=who and r.status<>'finished') then raise exception 'ACTIVE_ROOM'; end if;
  -- No live match is interrupted; child rows cascade with their finished room.
  delete from public.rooms where id in (select room_id from public.room_players where user_id=who);
  delete from public.player_blocks where blocker_id=who or blocked_id=who;
  delete from auth.users where id=who;
  update public.data_deletion_requests set completed_at=now() where id=p_request;
end $$;
revoke all on function public.complete_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;

create function public.purge_resolved_safety()
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  delete from public.safety_reports where resolved_at < now()-interval '90 days';
  delete from public.data_deletion_requests where completed_at < now()-interval '90 days';
end $$;
revoke all on function public.purge_resolved_safety() from public,anon,authenticated;
grant execute on function public.purge_resolved_safety() to service_role;
select cron.schedule('purge-resolved-safety','21 4 * * *','select public.purge_resolved_safety();');
