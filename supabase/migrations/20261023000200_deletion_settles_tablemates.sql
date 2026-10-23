-- Preserve other members' earned match rewards before account deletion cascades
-- through their finished rooms. Both self-service and operator deletion use
-- complete_data_deletion, so the wrapper covers both entry paths.
alter function public.complete_data_deletion(uuid)
  rename to complete_data_deletion_pre_settle;

create function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare
  who uuid;
  member uuid;
  match record;
  rec public.match_receipts;
begin
  select user_id into who from public.data_deletion_requests
   where id=p_request and completed_at is null;

  if who is not null and public.economy_v3_on() then
    -- sync_player_rewards takes invite_v3_lock before its own wallet lock.
    -- We do not run invite_v3_settle: it pays referral rewards unrelated to
    -- these rooms, and the receipt pair touches only the member's wallet.
    -- Take every affected wallet once, in UUID order, before any receipt or
    -- row lock — the departing player's own included, so two deletions that
    -- shared a room queue behind each other instead of each settling the
    -- other while deleting the same rooms. Concurrent reward syncs never
    -- acquire these wallet advisory locks in an opposite order.
    for member in
      select p.user_id from public.rooms r
        join public.room_players departing on departing.room_id=r.id
        join public.room_players p on p.room_id=r.id
        join public.room_state s on s.room_id=r.id
       where departing.user_id=who and p.user_id<>who
         and not p.kicked and p.role is not null
         and r.status='finished' and r.ended_at is not null
         and s.public_data->>'outcome' in ('mafia','town')
      union
      select who
       order by 1
    loop
      perform pg_advisory_xact_lock(hashtextextended('wallet:'||member::text,91));
    end loop;

    -- Group by player so daily and roster receipt caps see rooms in the same
    -- order as sync_player_rewards. Its old-amounts skip is kept verbatim.
    for match in
      select p.user_id, r.id as room_id from public.rooms r
        join public.room_players departing on departing.room_id=r.id
        join public.room_players p on p.room_id=r.id
        join public.room_state s on s.room_id=r.id
       where departing.user_id=who and p.user_id<>who
         and not p.kicked and p.role is not null
         and r.status='finished' and r.ended_at is not null
         and s.public_data->>'outcome' in ('mafia','town')
       order by p.user_id,r.ended_at,r.id
    loop
      continue when not exists(select 1 from public.match_receipts
          where user_id=match.user_id and room_id=match.room_id)
        and exists(select 1 from public.wallet_ledger
          where user_id=match.user_id and source_room=match.room_id
            and kind='match_completion');
      rec:=public.economy_v3_issue_receipt(match.user_id,match.room_id);
      if rec.user_id is not null then
        perform public.economy_v3_settle_receipt(match.user_id,match.room_id);
      end if;
    end loop;
  end if;

  perform public.complete_data_deletion_pre_settle(p_request);
end $$;

revoke all on function public.complete_data_deletion_pre_settle(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion_pre_settle(uuid) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
