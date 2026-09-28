-- Contract for 20260928000800_season_operator_start (D3). Rolled back by the SQL harness.
begin;
do $$
declare r jsonb; at timestamptz:=date_trunc('second',now())+interval '2 days'; s public.mission_seasons;
begin
  -- Asleep after migrations: no season is current, so nothing earns into it.
  select * into s from mission_seasons where code='season_zero';
  assert not s.active, 'Season Zero started at migration time';
  assert not exists(select 1 from mission_seasons
    where active and now()>=starts_at and now()<ends_at), 'a season is running before the operator';

  r:=public.operator_start_season('season_zero',at);
  assert r->>'code'='STARTED', r::text;
  select * into s from mission_seasons where code='season_zero';
  assert s.active and s.starts_at=at and s.ends_at=at+interval '28 days', row_to_json(s)::text;

  -- The same call again is a no-op; a different moment is refused.
  r:=public.operator_start_season('season_zero',at);
  assert (r->>'ok')::boolean and r->>'code'='ALREADY_STARTED', r::text;
  r:=public.operator_start_season('season_zero',at+interval '1 day');
  assert not (r->>'ok')::boolean and r->>'code'='ALREADY_STARTED_ELSEWHEN', r::text;
  assert (select starts_at from mission_seasons where code='season_zero')=at;

  assert public.operator_start_season('no_such_season',at)->>'code'='NOT_FOUND';
  assert public.operator_start_season('season_zero',null)->>'code'='BAD_REQUEST';
  assert not has_function_privilege('authenticated',
    'public.operator_start_season(text,timestamptz)','execute');
end $$;
rollback;
