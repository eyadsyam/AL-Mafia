-- D2 — a Daily Case pick is recorded once per request.
--
-- A pick that was recorded and lost its response on a weak network used to be
-- retried as a new pick: a wrong answer sent twice cost two of the three
-- attempts, and a player could fail the case after two real tries. The pick
-- now carries a request id. The first arrival records it and keeps the verdict
-- as a receipt; any later arrival of the same id gets that verdict back, with
-- today's state, and records nothing.
--
-- Only accepted picks leave a receipt. A refusal (disabled, day changed, no
-- attempts left, already solved) changed nothing, so asking again is already
-- safe and must be allowed to get a different answer once things change.

create table public.case_puzzle_receipts (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  request_id uuid not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key(user_id,day,request_id)
);
alter table public.case_puzzle_receipts enable row level security;
revoke all on public.case_puzzle_receipts from public,anon,authenticated;
grant all on public.case_puzzle_receipts to service_role;

-- The five-argument form stays as it was, for any caller without an id.
create function public.case_puzzle_record(
  p_user uuid,p_day date,p_pick text,p_correct boolean,p_answer_hash text,p_request uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare stored jsonb; result jsonb; today date:=(now() at time zone 'utc')::date;
begin
  if p_request is null then
    return public.case_puzzle_record(p_user,p_day,p_pick,p_correct,p_answer_hash);
  end if;
  -- The same lock the recording takes, so a retry racing its original waits
  -- for it and then finds its receipt.
  perform pg_advisory_xact_lock(hashtextextended('wallet:'||p_user::text,91));
  select r.result into stored from public.case_puzzle_receipts r
   where r.user_id=p_user and r.day=p_day and r.request_id=p_request;
  if found then
    return stored || jsonb_build_object(
      'state',public.case_puzzle_status(p_user),'replayed',true);
  end if;
  result:=public.case_puzzle_record(p_user,p_day,p_pick,p_correct,p_answer_hash);
  if coalesce((result->>'ok')::boolean,false) then
    insert into public.case_puzzle_receipts(user_id,day,request_id,result)
      values(p_user,today,p_request,result);
  end if;
  return result;
end $$;
revoke all on function public.case_puzzle_record(uuid,date,text,boolean,text,uuid)
  from public, anon, authenticated;
grant execute on function public.case_puzzle_record(uuid,date,text,boolean,text,uuid)
  to service_role;
