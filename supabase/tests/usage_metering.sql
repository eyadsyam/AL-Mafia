begin;

do $$ declare h uuid:=gen_random_uuid(); r uuid; report record;
begin
  insert into public.rooms(code,host_id,match_seed) values('USAGE2',h,7) returning id into r;
  insert into public.room_players(room_id,user_id,name,seat,role,kicked) values
    (r,h,'Host',0,'mafia',false),(r,gen_random_uuid(),'Guest',1,'citizen',false);
  update public.rooms set status='playing' where id=r;
  if (select started_at is null from public.rooms where id=r) then raise exception 'started_at missing'; end if;
  update public.rooms set status='finished',ended_at=now()+interval '2 minutes' where id=r;
  select * into report from public.usage_month_report(date_trunc('month',now() at time zone 'utc')::date);
  if report.matches_started<1 or report.matches_finished<1 or report.player_matches<2 then raise exception 'usage not counted'; end if;

  update public.operations_control set new_rooms_enabled=false where singleton=true;
  begin
    perform public.create_room_atomic('PAUSE2',gen_random_uuid(),'Host','male',8,'{}');
    raise exception 'gate did not close';
  exception when others then
    if sqlerrm<>'NEW_ROOMS_PAUSED' then raise; end if;
  end;

  insert into public.usage_thresholds(metric,monthly_limit) values('matches_started',1)
    on conflict(metric) do update set monthly_limit=excluded.monthly_limit;
  if public.refresh_usage_alerts()<4 then raise exception 'threshold alerts missing'; end if;
end $$;

rollback;
