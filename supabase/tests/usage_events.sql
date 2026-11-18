-- Contract for 20261119000100_usage_events and 20261119000200_first_run_events. Rolled back by the harness.
begin;
do $$
declare
  u uuid:='00000000-0000-4000-8000-0000000b2001';
  d date:=(now() at time zone 'utc')::date;
  ev text;
  pr text;
  pairs text[][]:=array[
    ['app_open',''],
    ['store_open',''],
    ['mode_pick','local'],['mode_pick','online'],
    ['match_local_started','p4_6'],['match_local_started','p7_9'],
    ['match_local_started','p10_12'],['match_local_started','p13_plus'],
    ['online_action','quick'],['online_action','create'],
    ['online_action','join_code'],['online_action','join_public'],
    ['online_action','home_line'],
    ['match_local_finished','p4_6'],
    ['first_run','terms'],['first_run','account'],['first_run','kind'],
    ['first_run','name'],['first_run','done']
  ];
  bad text[][]:=array[
    ['app_open','x'],['mode_pick',''],['mode_pick','stories'],
    ['match_local_started',''],['match_local_started','p3'],
    ['online_action',''],['online_action','host'],['online_action','ABCD'],
    ['first_run',''],['first_run','gender'],['first_run','Terms']
  ];
  i int;
  result jsonb;
  before int;
begin
  for i in 1..array_length(pairs,1) loop
    ev:=pairs[i][1]; pr:=pairs[i][2];
    -- A live database already holds today's counts: the call adds one.
    before:=coalesce((select total from public.product_metric_daily
      where day=d and event=ev and prop=pr),0);
    result:=public.metric_record(u,ev,pr,gen_random_uuid());
    assert not (result->>'replayed')::boolean,ev||':'||pr;
    assert (select total from public.product_metric_daily
      where day=d and event=ev and prop=pr)=before+1,'not counted '||ev||':'||pr;
  end loop;
  for i in 1..array_length(bad,1) loop
    ev:=bad[i][1]; pr:=bad[i][2];
    begin
      perform public.metric_record(u,ev,pr,gen_random_uuid());
      raise exception 'accepted %:%',ev,pr;
    exception when raise_exception then assert sqlerrm='BAD_REQUEST',sqlerrm; end;
  end loop;
end $$;
select 'PASS usage_events';
rollback;
