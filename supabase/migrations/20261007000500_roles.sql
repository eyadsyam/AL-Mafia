-- Three owner-approved roles: Silencer, Elder and Sniper.
alter table public.room_players
  drop constraint if exists room_players_role_valid;
alter table public.room_players
  add constraint room_players_role_valid check (
    role is null or role in (
      'mafia','silencer','doctor','detective','elder','sniper','citizen'
    )
  );

alter table public.night_actions
  drop constraint if exists night_actions_action_valid;
alter table public.night_actions
  add constraint night_actions_action_valid check (
    action in ('kill','silence','protect','investigate','suspect','skip')
  );

-- A sniper shot is distinguished from an ordinary private suspicion by the
-- irreversible bullet bit, so it must participate in the atomic fingerprint.
create or replace function public.night_fingerprint(p_room uuid, p_night integer)
returns text language sql stable security definer
set search_path=public,pg_temp as $$
  select coalesce(string_agg(
    actor_id::text||'|'||action||'|'||coalesce(target_id::text,'-')||'|'||
    case when used_bullet then '1' else '0' end,
    ';' order by actor_id
  ), '') || '#roster:' || public.roster_fingerprint(p_room)
  from public.night_actions where room_id=p_room and night=p_night;
$$;
revoke all on function public.night_fingerprint(uuid,integer)
  from public,anon,authenticated;
grant execute on function public.night_fingerprint(uuid,integer) to service_role;

-- Night resolution can now eliminate two seats. The whole set is applied under
-- the same room/state lock and the same action fingerprint as the tally.
create function public.commit_night_roles_resolution(
  p_room uuid, p_number integer, p_victims uuid[], p_saved_seat integer,
  p_archive jsonb, p_patch jsonb, p_next text, p_deadline timestamptz,
  p_fingerprint text
) returns boolean language plpgsql security definer
set search_path=public,pg_temp as $$
declare
  s public.room_state;
  victim uuid;
  victim_seat integer;
begin
  perform 1 from public.rooms where id=p_room and status='playing' for update;
  if not found then return false; end if;
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase<>'night' or s.phase_number<>p_number or p_next<>'morning' then
    return false;
  end if;
  if p_fingerprint is distinct from public.night_fingerprint(p_room,p_number) then
    return false;
  end if;

  foreach victim in array coalesce(p_victims, array[]::uuid[]) loop
    update public.room_players set alive=false
      where room_id=p_room and user_id=victim and alive
      returning seat into victim_seat;
    if not found then raise exception 'resolution victim unavailable'; end if;
    perform public.set_public_path(
      p_room, array['eliminations',victim_seat::text],
      jsonb_build_object('phase','night','number',p_number)
    );
    update public.whisper_meta set voided=true
      where room_id=p_room and to_id=victim and not voided;
  end loop;

  perform public.record_night_resolution(
    p_room,p_number,p_saved_seat,p_archive
  );
  update public.room_state set
    public_data=public_data||p_patch,
    phase='morning',phase_ends_at=p_deadline,active_speaker=null,updated_at=now()
    where room_id=p_room;
  if p_patch->>'outcome' is not null then
    update public.rooms set status='finished',ended_at=now() where id=p_room;
  end if;
  return true;
end;
$$;
revoke all on function public.commit_night_roles_resolution(
  uuid,integer,uuid[],integer,jsonb,jsonb,text,timestamptz,text
) from public,anon,authenticated;
grant execute on function public.commit_night_roles_resolution(
  uuid,integer,uuid[],integer,jsonb,jsonb,text,timestamptz,text
) to service_role;

create function public.reveal_elder_role(p_room uuid, p_user uuid)
returns boolean language plpgsql security definer
set search_path=public,pg_temp as $$
declare
  s public.room_state;
  elder_seat integer;
  seats jsonb;
begin
  select * into s from public.room_state where room_id=p_room for update;
  if not found or s.phase not in ('morning','opening','confront','discuss','vote','verdict') then
    return false;
  end if;
  select seat into elder_seat from public.room_players
    where room_id=p_room and user_id=p_user and alive and role='elder';
  if not found then return false; end if;
  seats := coalesce(s.public_data->'elderRevealedSeats','[]'::jsonb);
  if not seats @> jsonb_build_array(elder_seat) then
    seats := seats || jsonb_build_array(elder_seat);
    update public.room_state set
      public_data=jsonb_set(public_data,'{elderRevealedSeats}',seats,true),
      updated_at=now()
      where room_id=p_room;
  end if;
  return true;
end;
$$;
revoke all on function public.reveal_elder_role(uuid,uuid)
  from public,anon,authenticated;
grant execute on function public.reveal_elder_role(uuid,uuid) to service_role;
