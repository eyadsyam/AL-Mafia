-- D7 (§7 row 7): `resultSummary{roomId,requestId}`.
--
-- The one result-screen call now names the room it is for and a request id.
-- It returns what the older summary returned plus the deltas this room
-- produced (coins, Council XP, Season XP, Council levels) so the client no
-- longer diffs two reads, and the receipt summary when Economy v3 is on. The
-- first answer is kept under the request id and replayed, so a retry after a
-- lost response shows the same lines instead of zeros.
--
-- Doc 05: only the caller's own rows are read, only after the room finished
-- with a public outcome; nothing about another seat is returned.

create table public.result_summary_receipts(
  user_id uuid not null,
  request_id uuid not null,
  room_id uuid not null,
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key(user_id,request_id)
);
create index result_summary_receipts_age on public.result_summary_receipts(created_at);
alter table public.result_summary_receipts enable row level security;
revoke all on public.result_summary_receipts from public,anon,authenticated;
grant select,insert,delete on public.result_summary_receipts to service_role;

create function public.result_summary_room(p_user uuid,p_room uuid,p_request uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare kept jsonb; base jsonb; before_xp bigint; after_xp bigint; season bigint;
  before_season bigint; after_season bigint; before_coins bigint; after_coins bigint;
  rec public.match_receipts; body jsonb;
begin
  if p_user is null or p_room is null or p_request is null then raise exception 'BAD_REQUEST'; end if;
  select response into kept from public.result_summary_receipts
   where user_id=p_user and request_id=p_request;
  if found then
    -- A request id belongs to the room it was first sent for.
    if kept->>'roomId' is distinct from p_room::text then raise exception 'BAD_REQUEST'; end if;
    return kept||jsonb_build_object('replayed',true);
  end if;
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select response into kept from public.result_summary_receipts
   where user_id=p_user and request_id=p_request;
  if found then return kept||jsonb_build_object('replayed',true); end if;

  select id into season from public.mission_seasons
   where active and now()>=starts_at and now()<ends_at order by starts_at desc limit 1;
  select coalesce(sum(xp),0) into before_xp from public.council_xp_events where user_id=p_user;
  select coalesce(sum(xp),0) into before_season from public.season_xp_events
   where user_id=p_user and season_id=season;
  select coalesce(balance,0) into before_coins from public.wallet_accounts where user_id=p_user;
  before_coins:=coalesce(before_coins,0);

  base:=public.result_summary(p_user);

  select coalesce(sum(xp),0) into after_xp from public.council_xp_events where user_id=p_user;
  select coalesce(sum(xp),0) into after_season from public.season_xp_events
   where user_id=p_user and season_id=season;
  select coalesce(balance,0) into after_coins from public.wallet_accounts where user_id=p_user;
  after_coins:=coalesce(after_coins,0);
  select * into rec from public.match_receipts where user_id=p_user and room_id=p_room;

  body:=base||jsonb_build_object(
    'roomId',p_room,
    'requestId',p_request,
    'deltas',jsonb_build_object(
      'coins',greatest(after_coins-before_coins,0),
      'councilXp',greatest(after_xp-before_xp,0),
      'seasonXp',greatest(after_season-before_season,0),
      'councilLevelFrom',public.council_level_for(before_xp),
      'councilLevelTo',public.council_level_for(after_xp)),
    'match',jsonb_build_object(
      -- A receipt's first-of-day coins are keyed by day, not room: count them.
      'coins',case when rec.user_id is not null
        then rec.completion_coins+rec.win_coins+rec.first_day_coins
        else coalesce((select sum(amount) from public.wallet_ledger where user_id=p_user
          and source_room=p_room and amount>0),0) end,
      'councilXp',coalesce((select xp from public.council_xp_events where user_id=p_user
        and source_key='match:'||p_room),0),
      'seasonXp',coalesce((select sum(xp) from public.season_xp_events where user_id=p_user
        and source_key in ('match:'||p_room,'thursday:'||p_room)),0)),
    'receipt',case when rec.user_id is null then null else jsonb_build_object(
      'version',rec.economy_version,'completion',rec.completion_coins,'win',rec.win_coins,
      'firstOfDay',rec.first_day_coins,'seasonXp',rec.season_xp,'councilXp',rec.council_xp,
      'dayOrdinal',rec.day_ordinal) end);
  insert into public.result_summary_receipts(user_id,request_id,room_id,response)
    values(p_user,p_request,p_room,body);
  delete from public.result_summary_receipts
   where user_id=p_user and created_at<now()-interval '48 hours';
  return body;
end $$;
revoke all on function public.result_summary_room(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.result_summary_room(uuid,uuid,uuid) to service_role;

create function public.purge_result_summary_receipts() returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare n integer;
begin
  delete from public.result_summary_receipts where created_at<now()-interval '48 hours';
  get diagnostics n=row_count;
  return n;
end $$;
revoke all on function public.purge_result_summary_receipts() from public,anon,authenticated;
grant execute on function public.purge_result_summary_receipts() to service_role;

alter function public.complete_data_deletion(uuid) rename to complete_data_deletion_pre_result_v2;
create function public.complete_data_deletion(p_request uuid)
returns void language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare who uuid;
begin
  select user_id into who from public.data_deletion_requests
   where id=p_request and completed_at is null;
  perform public.complete_data_deletion_pre_result_v2(p_request);
  if who is not null then
    delete from public.result_summary_receipts where user_id=who;
  end if;
end $$;
revoke all on function public.complete_data_deletion_pre_result_v2(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion_pre_result_v2(uuid) to service_role;
revoke all on function public.complete_data_deletion(uuid) from public,anon,authenticated;
grant execute on function public.complete_data_deletion(uuid) to service_role;
