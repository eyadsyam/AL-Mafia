-- Contract for 20260928000700_case_puzzle_receipts (D2). Rolled back by the SQL harness.
begin;
do $$
declare
  u uuid:=gen_random_uuid(); today date:=(now() at time zone 'utc')::date;
  h text:='0123456789abcdef';
  r1 uuid:=gen_random_uuid(); r2 uuid:=gen_random_uuid(); r3 uuid:=gen_random_uuid();
  first jsonb; again jsonb; balance bigint;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u,u::text||'@receipt.test',now(),false);
  update economy_config set case_of_day_enabled=true;

  -- A wrong pick, then the same request again: one attempt, the same verdict.
  first:=public.case_puzzle_record(u,today,'s1',false,h,r1);
  assert (first->>'ok')::boolean and not (first->>'correct')::boolean, first::text;
  again:=public.case_puzzle_record(u,today,'s1',false,h,r1);
  assert (again->>'replayed')::boolean, again::text;
  assert again->>'correct'=first->>'correct', again::text;
  assert (select attempts from case_puzzle_attempts where user_id=u and day=today)=1,
    'a replayed pick consumed an attempt';

  -- A new request is a new attempt.
  perform public.case_puzzle_record(u,today,'s2',false,h,r2);
  assert (select attempts from case_puzzle_attempts where user_id=u and day=today)=2;

  -- A correct pick replayed grants once and says the same thing.
  first:=public.case_puzzle_record(u,today,'s3',true,h,r3);
  assert (first->>'correct')::boolean, first::text;
  balance:=coalesce((select w.balance from wallet_accounts w where w.user_id=u),0);
  again:=public.case_puzzle_record(u,today,'s3',true,h,r3);
  assert (again->>'correct')::boolean and (again->>'replayed')::boolean, again::text;
  assert coalesce((select w.balance from wallet_accounts w where w.user_id=u),0)=balance,
    'a replayed solve granted twice';
  assert (select attempts from case_puzzle_attempts where user_id=u and day=today)=3;

  -- A refusal leaves no receipt: a new id after solving is refused, not replayed.
  again:=public.case_puzzle_record(u,today,'s3',true,h,gen_random_uuid());
  assert again->>'code'='ALREADY_SOLVED', again::text;
  assert (select count(*) from case_puzzle_receipts where user_id=u)=3;

  -- No id keeps the old behaviour.
  again:=public.case_puzzle_record(u,today,'s3',true,h,null);
  assert again->>'code'='ALREADY_SOLVED', again::text;

  -- Service role only.
  assert not has_function_privilege('authenticated',
    'public.case_puzzle_record(uuid,date,text,boolean,text,uuid)','execute');
  assert not has_table_privilege('authenticated','public.case_puzzle_receipts','select');
end $$;
rollback;
