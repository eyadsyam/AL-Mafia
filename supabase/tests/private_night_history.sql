-- Run against a migrated database. All fixtures roll back, including on failure.
begin;
do $$
declare r uuid := gen_random_uuid(); u uuid := gen_random_uuid(); v jsonb;
begin
  perform set_config('test.room_id', r::text, true);
  perform set_config('request.jwt.claim.sub', u::text, true);
  insert into public.rooms(id, code, host_id, match_seed) values(r, 'ZXQ8K9', u, 1);
  insert into public.room_players(room_id, user_id, name, seat) values(r, u, 'privacy fixture', 0);
  insert into public.room_state(room_id) values(r);
  -- Legacy writer is protected during rolling deployment.
  perform public.set_public_path(r, array['resolvedNights','1'],
    '{"victimSeat":null,"savedSeat":3,"trace":"save"}'::jsonb);
  select public_data into v from public.room_state where room_id = r;
  if v #> '{resolvedNights,1,savedSeat}' is not null then
    raise exception 'legacy write leaked savedSeat';
  end if;
  if (select saved_seat from public.night_resolution_private where room_id=r and night=1) <> 3 then
    raise exception 'legacy private history lost';
  end if;
  -- New writer keeps safe public history and ignores extra public fields.
  perform public.record_night_resolution(r, 2, 4,
    '{"victimSeat":null,"trace":"save","savedSeat":4,"extra":"private"}'::jsonb);
  select public_data into v from public.room_state where room_id = r;
  if v #> '{resolvedNights,2}' <> '{"victimSeat":null,"trace":"save"}'::jsonb then
    raise exception 'public archive is not allowlisted';
  end if;
  if (select count(*) from public.night_resolution_private where room_id=r) <> 2 then
    raise exception 'previous night history lost';
  end if;
  if exists (select 1 from pg_publication_tables
    where schemaname='public' and tablename='night_resolution_private') then
    raise exception 'private table published';
  end if;
  if has_function_privilege('authenticated',
    'public.record_night_resolution(uuid,integer,integer,jsonb)', 'execute') then
    raise exception 'client can write resolution';
  end if;
end $$;
set local role authenticated;
do $$
declare v jsonb;
begin
  select public_data into v from public.room_state
    where room_id=current_setting('test.room_id')::uuid;
  if v is null then raise exception 'fixture member cannot read public row'; end if;
  if jsonb_path_exists(v, '$.resolvedNights.*.savedSeat') then
    raise exception 'member can read private target';
  end if;
  begin
    perform * from public.night_resolution_private;
    raise exception 'member read private table';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
select 'PASS private history retained; public/member access scrubbed; private SELECT refused; no publication' as result;
rollback;
