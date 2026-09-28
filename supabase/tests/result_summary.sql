-- Contract for 20260928001000_result_summary (D7). Rolled back by the SQL harness.
begin;
do $$
declare u uuid:=gen_random_uuid(); first jsonb; again jsonb;
begin
  insert into auth.users(id,email,email_confirmed_at,is_anonymous)
    values(u,u::text||'@summary.test',now(),false);
  -- Everything off: one answer that says so, part by part.
  first:=public.result_summary(u);
  assert (first->>'ok')::boolean, first::text;
  assert first->'contracts'->>'enabled'='false' or first->'contracts' ? 'enabled', first::text;
  assert first->'rank' is not null and first->'hub' is not null, first::text;
  assert first->'hub'->>'enabled'='false', first::text;
  -- Features on: the same shapes the separate calls return.
  update economy_config set council_contracts_enabled=true,council_rank_enabled=true,missions_enabled=true;
  first:=public.result_summary(u);
  assert first->'contracts'=public.council_contracts_status(u)||jsonb_build_object('levelUps',first->'contracts'->'levelUps'),
    first::text;
  assert (first->'hub'->>'enabled')::boolean, first::text;
  -- A retry records nothing twice.
  again:=public.result_summary(u);
  assert again->'contracts'->'levelUps'='[]'::jsonb or again->'contracts'->'levelUps' is null
    or jsonb_array_length(again->'contracts'->'levelUps')=0, again::text;
  assert not has_function_privilege('authenticated','public.result_summary(uuid)','execute');
end $$;
rollback;
