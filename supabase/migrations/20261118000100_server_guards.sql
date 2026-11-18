-- Retired bot play retains audit rows but no longer has a reward route.
drop function if exists public.claim_bot_win(uuid, uuid);
drop function if exists public.start_bot_match(uuid);
revoke all on public.bot_match_sessions, public.bot_wins from anon, authenticated;

-- A persisted outcome can only advance to the result, even if a client asks
-- for another phase after reading the old phase and deadline.
create or replace function public.commit_phase_open(
  p_room uuid, p_expected text, p_number integer, p_expected_deadline timestamptz,
  p_next text, p_next_number integer, p_deadline timestamptz, p_patch jsonb,
  p_require_all_seen boolean default false
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  if p_next <> 'result' and p_patch ? 'standings' then
    raise exception 'standings may only be published with the result';
  end if;
  perform 1 from public.rooms where id=p_room
    and (status='playing' or (p_next='result' and status='finished')) for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>p_expected or s.phase_number<>p_number or
    s.phase_ends_at is distinct from p_expected_deadline then return false; end if;
  if p_next <> 'result' and s.public_data->>'outcome' is not null then return false; end if;
  if p_next='result' and s.public_data->>'outcome' is null then return false; end if;
  if p_require_all_seen and p_expected='discuss' and p_next='vote' then
    if (s.public_data #>> '{readyToVote,number}')::integer is distinct from p_number
      or exists (
        select 1 from public.room_players p
        where p.room_id=p_room and p.alive and not p.kicked
          and not (coalesce(s.public_data #> '{readyToVote,seats}', '[]'::jsonb) @> to_jsonb(p.seat))
      ) then return false; end if;
  elsif p_require_all_seen and exists (
    select 1 from public.room_players where room_id=p_room and alive and not kicked and not saw_role
  ) then return false; end if;
  update public.room_state set phase=p_next,phase_number=p_next_number,
    phase_ends_at=p_deadline,public_data=public_data || p_patch,
    active_speaker=null,updated_at=now() where room_id=p_room;
  if p_next='result' then
    update public.rooms set status='finished',ended_at=coalesce(ended_at,now()) where id=p_room;
  end if;
  return true;
end;
$$;
revoke all on function public.commit_phase_open(uuid,text,integer,timestamptz,text,integer,timestamptz,jsonb,boolean)
  from public,anon,authenticated;
grant execute on function public.commit_phase_open(uuid,text,integer,timestamptz,text,integer,timestamptz,jsonb,boolean)
  to service_role;

-- Confrontations cannot publish after another operation decided the match.
create or replace function public.commit_confrontation(
  p_room uuid, p_number integer, p_expected_deadline timestamptz,
  p_confrontation jsonb, p_next text, p_deadline timestamptz
) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare s public.room_state;
begin
  if p_next not in ('confront','discuss') then
    raise exception 'a morning opens on a confrontation or a discussion';
  end if;
  if (p_next='confront') <> (p_confrontation is not null and jsonb_typeof(p_confrontation)='object') then
    raise exception 'confrontation payload does not match the phase';
  end if;
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>'morning' or s.phase_number<>p_number or
    s.phase_ends_at is distinct from p_expected_deadline then return false; end if;
  if s.public_data->>'outcome' is not null then return false; end if;
  if p_next='confront' then
    perform public.set_public_path(p_room, array['confrontations', p_number::text], p_confrontation);
  end if;
  update public.room_state set phase=p_next, phase_ends_at=p_deadline, active_speaker=null,
    public_data=public_data || jsonb_build_object('confrontation', case when p_next='confront' then p_confrontation else 'null'::jsonb end,
                                                  'confrontationSilent', null),
    updated_at=now() where room_id=p_room;
  return true;
end;
$$;
revoke all on function public.commit_confrontation(uuid,integer,timestamptz,jsonb,text,timestamptz)
  from public,anon,authenticated;
grant execute on function public.commit_confrontation(uuid,integer,timestamptz,jsonb,text,timestamptz)
  to service_role;

-- Push wakeups authenticate as the database scheduler before the outbox drains.
create or replace function public.push_wake()
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform net.http_post(
    url := 'https://hezjbrnveajypfqmjfnh.supabase.co/functions/v1/send_push',
    body := '{}'::jsonb,
    headers := jsonb_build_object('content-type','application/json','x-sync-secret',
                 (select decrypted_secret from vault.decrypted_secrets where name='play_sync_secret')),
    timeout_milliseconds := 5000);
exception when others then
  null;  -- the 30-second sweep below picks the rows up
end $$;
revoke all on function public.push_wake() from public, anon, authenticated;

-- Unrecorded uploads are safe to delete after a day; recorded proofs follow
-- the existing order retention clock instead.
create or replace function public.payment_proof_orphans(p_limit integer default 200)
returns table(path text) language sql stable security definer set search_path = public, storage, pg_temp as $$
  select o.name from storage.objects o
   where o.bucket_id = 'payment-proofs'
     and o.created_at < now() - interval '1 day'
     and not exists (select 1 from public.coin_orders c where c.proof_path = o.name)
   order by o.created_at
   limit greatest(1, least(coalesce(p_limit,200), 500))
$$;
revoke all on function public.payment_proof_orphans(integer) from public, anon, authenticated;
grant execute on function public.payment_proof_orphans(integer) to service_role;

-- Run proof cleanup once daily when pg_cron is available.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('proof-sweep', '29 4 * * *', $cron$ select net.http_post(url := 'https://hezjbrnveajypfqmjfnh.supabase.co/functions/v1/proof_sweep', headers := jsonb_build_object('x-sync-secret', (select decrypted_secret from vault.decrypted_secrets where name='play_sync_secret')), timeout_milliseconds := 20000); $cron$);
  end if;
end $$;

-- The five-second ready timer has work only while the feature is enabled.
create or replace function public.sync_lobby_ready_job_now() returns void
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then return; end if;
  if public.lobby_ready_on() then
    perform cron.schedule('expire-lobby-ready', '5 seconds', 'select public.expire_lobby_ready();');
  elsif exists (select 1 from cron.job where jobname = 'expire-lobby-ready') then
    perform cron.unschedule('expire-lobby-ready');
  end if;
end $$;
revoke all on function public.sync_lobby_ready_job_now() from public, anon, authenticated;

-- Reconcile the cron job after each feature toggle.
create or replace function public.sync_lobby_ready_job() returns trigger
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public.sync_lobby_ready_job_now();
  return new;
end $$;
revoke all on function public.sync_lobby_ready_job() from public, anon, authenticated;
drop trigger if exists sync_lobby_ready_job on public.economy_config;
create trigger sync_lobby_ready_job after insert or update of lobby_ready_enabled
  on public.economy_config for each row execute function public.sync_lobby_ready_job();
select public.sync_lobby_ready_job_now();
