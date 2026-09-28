-- D3 — Season Zero starts when the operator starts it, not when this lands.
--
-- The casebook migration inserted Season Zero with `starts_at = now()`, so a
-- dark deploy would have started the 28-day clock on the day the schema went
-- out: by launch the season would be half gone, or over. The season now waits,
-- inactive, until the operator names the moment (spec §6: "Season Zero
-- operator active — explicit L timestamp").
--
-- Only a season nobody has earned in yet is put back to sleep: if XP already
-- exists the season really did run, and stopping it would take progress away.

update public.mission_seasons s set active=false
 where s.code='season_zero'
   and not exists (select 1 from public.season_xp_events e where e.season_id=s.id);

-- Starts a sleeping season at [p_starts_at] for its fixed 28 days. Asking again
-- with the same moment is a no-op; a different moment for a live season is
-- refused, so a retried or mistaken call cannot move a running season.
create function public.operator_start_season(p_code text,p_starts_at timestamptz)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.mission_seasons;
begin
  if p_code is null or p_starts_at is null or p_starts_at='infinity'::timestamptz then
    return jsonb_build_object('ok',false,'code','BAD_REQUEST');
  end if;
  select * into s from public.mission_seasons where code=p_code for update;
  if not found then return jsonb_build_object('ok',false,'code','NOT_FOUND'); end if;
  if s.active then
    if s.starts_at=p_starts_at then
      return jsonb_build_object('ok',true,'code','ALREADY_STARTED',
        'startsAt',s.starts_at,'endsAt',s.ends_at);
    end if;
    return jsonb_build_object('ok',false,'code','ALREADY_STARTED_ELSEWHEN',
      'startsAt',s.starts_at,'endsAt',s.ends_at);
  end if;
  update public.mission_seasons
     set starts_at=p_starts_at,ends_at=p_starts_at+interval '28 days',active=true
   where id=s.id;
  return jsonb_build_object('ok',true,'code','STARTED',
    'startsAt',p_starts_at,'endsAt',p_starts_at+interval '28 days');
end $$;
revoke all on function public.operator_start_season(text,timestamptz) from public,anon,authenticated;
grant execute on function public.operator_start_season(text,timestamptz) to service_role;
