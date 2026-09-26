-- Reports are private moderation evidence, never room facts or Realtime data.
create table public.safety_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null,
  room_id uuid not null,
  target_id uuid,
  reason text not null check (reason in ('abuse','harassment','inappropriate','other')),
  details text not null default '' check (char_length(details) <= 1000),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index safety_reports_reporter_time on public.safety_reports(reporter_id, created_at);
create table public.data_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create table public.player_blocks (
  blocker_id uuid not null,
  blocked_id uuid not null,
  created_at timestamptz not null default now(),
  primary key(blocker_id, blocked_id),
  check(blocker_id <> blocked_id)
);
alter table public.safety_reports enable row level security;
alter table public.data_deletion_requests enable row level security;
alter table public.player_blocks enable row level security;
revoke all on public.safety_reports, public.data_deletion_requests, public.player_blocks from anon, authenticated;
grant all on public.safety_reports, public.data_deletion_requests, public.player_blocks to service_role;
grant select on public.player_blocks to authenticated;
create policy own_blocks on public.player_blocks for select to authenticated using (blocker_id = auth.uid());

create function public.submit_player_safety(p_user uuid, p_action text,
  p_room uuid default null, p_seat integer default null,
  p_reason text default 'other', p_details text default '')
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare target uuid; receipt uuid;
begin
  if p_user is null then raise exception 'BAD_REQUEST'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 73));
  if p_action = 'delete' then
    insert into public.data_deletion_requests(user_id) values(p_user)
      on conflict(user_id) do update set user_id=excluded.user_id
      returning id into receipt;
    return receipt;
  end if;
  if not exists(select 1 from public.room_players where room_id=p_room and user_id=p_user) then
    raise exception 'NOT_A_MEMBER';
  end if;
  if p_seat is not null then
    select user_id into target from public.room_players where room_id=p_room and seat=p_seat;
    if target is null or target=p_user then raise exception 'BAD_REQUEST'; end if;
  end if;
  if p_action = 'block' then
    if target is null then raise exception 'BAD_REQUEST'; end if;
    insert into public.player_blocks(blocker_id,blocked_id) values(p_user,target) on conflict do nothing;
    return target;
  elsif p_action = 'report' then
    if p_reason not in ('abuse','harassment','inappropriate','other') or
      char_length(coalesce(p_details,'')) > 1000 then raise exception 'BAD_REQUEST'; end if;
    if (select count(*) from public.safety_reports where reporter_id=p_user and created_at>now()-interval '1 day') >= 10 then
      raise exception 'RATE_LIMITED';
    end if;
    insert into public.safety_reports(reporter_id,room_id,target_id,reason,details)
      values(p_user,p_room,target,p_reason,coalesce(p_details,'')) returning id into receipt;
    return receipt;
  end if;
  raise exception 'BAD_REQUEST';
end $$;
revoke all on function public.submit_player_safety(uuid,text,uuid,integer,text,text) from public,anon,authenticated;
grant execute on function public.submit_player_safety(uuid,text,uuid,integer,text,text) to service_role;
