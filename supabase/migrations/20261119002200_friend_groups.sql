-- Improvement 1 «الشلة» (owner 2026-11-19): named groups of friends, invited to
-- a lobby in one tap.
--
-- friend_groups: at most 10 per owner, a name of 1-20 characters. Members must
-- be the owner's accepted friends (not blocked), at most 15 per group. A member
-- who stops being a friend (or blocks the owner) silently drops out of the
-- listing and is never invited; nothing is deleted for them.
-- friend_group_invite: the same room_invite_send, member by member, with the
-- same rules (a member who cannot be invited is skipped); answers
-- {invited, inviteIds} where inviteIds are the FRESH invites the edge function
-- rings a phone for. Counts friend/group_invite through the metric_record
-- below (body of 20261119001100 plus that one prop).
-- Doc 05: nothing here reads a role, a team or a match.

create table if not exists public.friend_groups (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references auth.users on delete cascade,
  name text not null check (char_length(name) between 1 and 20),
  created_at timestamptz not null default now()
);
create index if not exists friend_groups_owner on public.friend_groups(owner, created_at);
create table if not exists public.friend_group_members (
  group_id uuid not null references public.friend_groups(id) on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  primary key (group_id, user_id)
);
create index if not exists friend_group_members_user on public.friend_group_members(user_id);
alter table public.friend_groups enable row level security;
alter table public.friend_group_members enable row level security;
revoke all on table public.friend_groups, public.friend_group_members from public, anon, authenticated;
grant all on table public.friend_groups, public.friend_group_members to service_role;

create or replace function public.friend_groups_list(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
  perform public.directory_guard(p_user);
  return jsonb_build_object('groups', coalesce((
    select jsonb_agg(jsonb_build_object('id',g.id,'name',g.name,'members',coalesce((
        select jsonb_agg(jsonb_build_object('userId',m.user_id,'name',coalesce(d.display_name,'?'))
                 order by d.display_name, m.user_id)
          from public.friend_group_members m
          left join public.player_directory d on d.user_id=m.user_id
         where m.group_id=g.id
           and public.directory_is_friend(p_user,m.user_id)
           and not public.friends_blocked(p_user,m.user_id)),'[]'::jsonb))
      order by g.created_at, g.id)
    from public.friend_groups g where g.owner=p_user),'[]'::jsonb));
end $$;
revoke all on function public.friend_groups_list(uuid) from public, anon, authenticated;
grant execute on function public.friend_groups_list(uuid) to service_role;

-- Create (p_id null) or replace one group's name and members. Limits answer
-- BAD_REQUEST; a group that is not mine, or a member who is not my friend,
-- answers NOT_ALLOWED.
create or replace function public.friend_group_save(
  p_user uuid, p_id uuid, p_name text, p_members uuid[]
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare nm text := btrim(coalesce(p_name,'')); gid uuid := p_id; uniq uuid[]; u uuid; n int;
begin
  perform public.directory_guard(p_user);
  if char_length(nm) not between 1 and 20 then raise exception 'BAD_REQUEST'; end if;
  uniq := coalesce(array(select distinct x from unnest(coalesce(p_members,'{}'::uuid[])) x
                          where x is not null),'{}'::uuid[]);
  if coalesce(array_length(uniq,1),0) > 15 then raise exception 'BAD_REQUEST'; end if;
  foreach u in array uniq loop
    if u=p_user or not public.directory_is_friend(p_user,u)
       or public.friends_blocked(p_user,u) then
      raise exception 'NOT_ALLOWED';
    end if;
  end loop;
  perform pg_advisory_xact_lock(hashtextextended('friend_groups:'||p_user::text, 37));
  if gid is null then
    select count(*) into n from public.friend_groups where owner=p_user;
    if n >= 10 then raise exception 'BAD_REQUEST'; end if;
    insert into public.friend_groups(owner,name) values(p_user,nm) returning id into gid;
  else
    update public.friend_groups set name=nm where id=gid and owner=p_user;
    if not found then raise exception 'NOT_ALLOWED'; end if;
    delete from public.friend_group_members where group_id=gid;
  end if;
  insert into public.friend_group_members(group_id,user_id)
    select gid, x from unnest(uniq) x;
  return public.friend_groups_list(p_user);
end $$;
revoke all on function public.friend_group_save(uuid,uuid,text,uuid[]) from public, anon, authenticated;
grant execute on function public.friend_group_save(uuid,uuid,text,uuid[]) to service_role;

create or replace function public.friend_group_delete(p_user uuid, p_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
  perform public.directory_guard(p_user);
  delete from public.friend_groups where id=p_id and owner=p_user;
  return public.friend_groups_list(p_user);
end $$;
revoke all on function public.friend_group_delete(uuid,uuid) from public, anon, authenticated;
grant execute on function public.friend_group_delete(uuid,uuid) to service_role;

-- One call, one invite per member through room_invite_send. A member who is
-- already in the room, who is no longer a friend, or whom the invite rules
-- refuse (a block, a restriction) is skipped; a rate limit, a closed feature or
-- my not sitting in the room stops the whole call.
create or replace function public.friend_group_invite(p_user uuid, p_group uuid, p_room uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare m record; r jsonb; ids uuid[] := '{}'; n int := 0;
begin
  perform public.directory_guard(p_user);
  if not exists(select 1 from public.friend_groups where id=p_group and owner=p_user) then
    raise exception 'NOT_ALLOWED';
  end if;
  for m in
    select gm.user_id from public.friend_group_members gm
     where gm.group_id=p_group
     order by gm.user_id
  loop
    continue when not public.directory_is_friend(p_user,m.user_id)
      or public.friends_blocked(p_user,m.user_id)
      or exists(select 1 from public.room_players p
                 where p.room_id=p_room and p.user_id=m.user_id
                   and not p.kicked and p.status is distinct from 'left');
    begin
      r := public.room_invite_send(p_user, null, m.user_id, p_room);
      n := n + 1;
      if (r->>'fresh')::boolean then ids := ids || (r->>'inviteId')::uuid; end if;
    exception when others then
      if sqlerrm in ('RATE_LIMITED','FEATURE_OFF','NOT_A_MEMBER') then raise; end if;
    end;
  end loop;
  return jsonb_build_object('invited',n,'inviteIds',to_jsonb(ids));
end $$;
revoke all on function public.friend_group_invite(uuid,uuid,uuid) from public, anon, authenticated;
grant execute on function public.friend_group_invite(uuid,uuid,uuid) to service_role;

-- metric_record: 20261119001100 plus friend/group_invite.
CREATE OR REPLACE FUNCTION public.metric_record(p_user uuid, p_event text, p_prop text, p_request uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  d date:=(now() at time zone 'utc')::date;
  s bytea;
  subject_hash bytea;
  inserted integer;
  no_prop constant text[]:=array[
    'eligible_app_open','case_open','case_attempt','case_solved','case_failed',
    'mission_hub_open','mission_claim','season_level_reached','chapter_started',
    'chapter_completed','academy_started','academy_passed','share_exported',
    'scenario_selected','house_rule_created','house_rule_imported','series_started',
    'series_completed','series_dropped','thursday_match','title_equipped','store_open',
    'product_view','purchase_started','purchase_succeeded','purchase_revoked','ad_offer',
    'ad_started','ad_completed','ad_no_fill','pass_view','pass_purchase',
    'invite_landing_open','invite_web_join','invite_first_match','case_share',
    'case_link_open','founder_grant','code_redeem','app_open'
  ];
  ad_offers constant text[]:=array['match','match_step','match_step_two','daily','extra'];
  ad_outcomes constant text[]:=array['earned','dismissed','unavailable','failed','not_consented'];
begin
  if p_user is null or p_request is null or p_event is null or p_prop is null then
    raise exception 'BAD_REQUEST';
  end if;
  if not (
    (p_event=any(no_prop) and p_prop='') or
    (p_event='invite_share' and p_prop=any(array['home','lobby','result','case'])) or
    (p_event='partner_pick' and p_prop=any(array['detective','doctor','mafia','citizen'])) or
    (p_event='attributed_first_open' and p_prop=any(array[
      'side_detective','side_doctor','side_mafia','side_citizen',
      'creator','case','invite','organic'
    ])) or
    (p_event='match_local_finished' and p_prop=any(array['p4_6','p7_9','p10_12','p13_plus'])) or
    (p_event='mode_pick' and p_prop=any(array['local','online'])) or
    (p_event='match_local_started' and p_prop=any(array['p4_6','p7_9','p10_12','p13_plus'])) or
    (p_event='first_run' and p_prop=any(array['terms','account','kind','name','done'])) or
    (p_event='online_action' and p_prop=any(array['quick','create','join_code','join_public','home_line'])) or
    (p_event='queue' and p_prop=any(array['join','matched','expired','ready_yes','ready_no'])) or
    (p_event='play_night' and p_prop=any(array['remind','push'])) or
    (p_event='friend' and p_prop=any(array['request','accept','ping','group_invite'])) or
    (p_event='ad_result' and split_part(p_prop,':',1)=any(ad_offers)
      and split_part(p_prop,':',2)=any(ad_outcomes)
      and p_prop=split_part(p_prop,':',1)||':'||split_part(p_prop,':',2))
  ) then
    raise exception 'BAD_REQUEST';
  end if;

  insert into public.metric_salts(day,salt)
    values(d,decode(replace(gen_random_uuid()::text,'-','')||replace(gen_random_uuid()::text,'-',''),'hex'))
    on conflict(day) do nothing;
  select salt into strict s from public.metric_salts where day=d;
  subject_hash:=public.metric_hmac_sha256(s,convert_to(p_user::text,'UTF8'));

  insert into public.metric_receipts(subject,request_id,day)
    values(subject_hash,p_request,d) on conflict do nothing;
  get diagnostics inserted=row_count;
  if inserted=0 then return jsonb_build_object('ok',true,'replayed',true); end if;

  insert into public.product_metric_daily(day,event,prop,total)
    values(d,p_event,p_prop,1)
    on conflict(day,event,prop) do update set total=public.product_metric_daily.total+1;
  return jsonb_build_object('ok',true,'replayed',false);
end $function$;
revoke all on function public.metric_record(uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function public.metric_record(uuid,text,text,uuid) to service_role;
