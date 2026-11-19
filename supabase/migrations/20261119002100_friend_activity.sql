-- Improvement 3 «أخبار الأصحاب» + the weekly board (owner 2026-11-19, S5).
--
-- friend_activity: two kinds only, both written by triggers, both only when
-- the player shares activity (player_directory.share_activity, default on):
--   * win_streak {count:3}  when a finished-match record makes the last 3
--     records all wins (once per streak: not again until a loss has come between);
--   * rank_up {title,tier}  when a new XP grant lifts the player into a higher
--     rank tier (titles from council_rank_tiers).
-- Both fire from rows that exist only once a match is over (council_match_records,
-- council_xp_events), so nothing here can say anything about a match being
-- played, a role or a team (doc 05). room_open is not produced (public room
-- presence already shows in the friends list).
-- friend_feed answers my friends' last 7 days, newest first, with the three
-- reaction counts and my own reaction, plus my Saturday-start (Africa/Cairo)
-- week and a friends board of wins. A friend who switches sharing off
-- disappears from all of it at once (read-time check). Blocks hide both ways.

alter table public.player_directory
  add column if not exists share_activity boolean not null default true;

create table if not exists public.friend_activity (
  id bigserial primary key,
  user_id uuid not null references auth.users on delete cascade,
  kind text not null check (kind in ('win_streak','rank_up')),
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists friend_activity_user on public.friend_activity(user_id, created_at desc);
create index if not exists friend_activity_recent on public.friend_activity(created_at);

create table if not exists public.friend_activity_reactions (
  activity_id bigint not null references public.friend_activity(id) on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  emoji text not null check (emoji in ('👏','🔥','😂')),
  created_at timestamptz not null default now(),
  primary key (activity_id, user_id)
);
alter table public.friend_activity enable row level security;
alter table public.friend_activity_reactions enable row level security;
revoke all on table public.friend_activity, public.friend_activity_reactions from public, anon, authenticated;
grant all on table public.friend_activity, public.friend_activity_reactions to service_role;
grant usage, select on sequence public.friend_activity_id_seq to service_role;

-- ── S6: the privacy row gains «أخباري تظهر لأصحابي» ──────────────────────────
-- Body of directory_privacy from 20261119001000 plus p_share_activity. The old
-- 4-argument form keeps working and calls this one.
create or replace function public.directory_privacy(
  p_user uuid, p_who_can_add text, p_show_online boolean, p_searchable boolean,
  p_share_activity boolean
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare d public.player_directory;
begin
  perform public.directory_guard(p_user);
  if p_who_can_add is not null
     and p_who_can_add not in ('everyone','tablemates','nobody') then
    raise exception 'BAD_REQUEST';
  end if;
  update public.player_directory set
    who_can_add = coalesce(p_who_can_add, who_can_add),
    show_online = coalesce(p_show_online, show_online),
    searchable = coalesce(p_searchable, searchable),
    share_activity = coalesce(p_share_activity, share_activity)
   where user_id=p_user
  returning * into d;
  if d.user_id is null then raise exception 'NOT_ALLOWED'; end if;
  return jsonb_build_object('whoCanAdd',d.who_can_add,'showOnline',d.show_online,
    'searchable',d.searchable,'strangerInvites',d.stranger_invites,
    'shareActivity',d.share_activity);
end $$;
revoke all on function public.directory_privacy(uuid,text,boolean,boolean,boolean) from public, anon, authenticated;
grant execute on function public.directory_privacy(uuid,text,boolean,boolean,boolean) to service_role;

create or replace function public.directory_privacy(
  p_user uuid, p_who_can_add text, p_show_online boolean, p_searchable boolean
) returns jsonb language sql security definer set search_path=public,pg_temp as $$
  select public.directory_privacy(p_user, p_who_can_add, p_show_online, p_searchable, null::boolean)
$$;
revoke all on function public.directory_privacy(uuid,text,boolean,boolean) from public, anon, authenticated;
grant execute on function public.directory_privacy(uuid,text,boolean,boolean) to service_role;

-- ── Producers ───────────────────────────────────────────────────────────────
create or replace function public.friend_activity_on_record()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare streak int; last_loss timestamptz;
begin
  if not new.won then return new; end if;
  if not coalesce((select share_activity from public.player_directory
                    where user_id=new.user_id), false) then
    return new;
  end if;
  -- Wins in a row, newest first, up to the first loss.
  select coalesce(min(r.rn) filter (where not r.won) - 1, count(*))::int into streak
    from (select won, row_number() over (order by ended_at desc, created_at desc) rn
            from public.council_match_records where user_id=new.user_id) r;
  if streak <> 3 then return new; end if;
  select max(created_at) into last_loss
    from public.council_match_records where user_id=new.user_id and not won;
  -- Once per streak: nothing since the last loss has been announced.
  if exists(select 1 from public.friend_activity a
             where a.user_id=new.user_id and a.kind='win_streak'
               and (last_loss is null or a.created_at > last_loss)) then
    return new;
  end if;
  insert into public.friend_activity(user_id,kind,data)
    values(new.user_id,'win_streak',jsonb_build_object('count',3));
  return new;
-- News is never worth failing a match record or an XP grant.
exception when others then
  return new;
end $$;
revoke all on function public.friend_activity_on_record() from public, anon, authenticated;
drop trigger if exists friend_activity_record on public.council_match_records;
create trigger friend_activity_record after insert on public.council_match_records
  for each row execute function public.friend_activity_on_record();

create or replace function public.friend_activity_on_xp()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare after_total bigint; t_before smallint; t_after public.council_rank_tiers;
begin
  if not coalesce((select share_activity from public.player_directory
                    where user_id=new.user_id), false) then
    return new;
  end if;
  select coalesce(sum(xp),0) into after_total
    from public.council_xp_events where user_id=new.user_id;
  select tier into t_before from public.council_rank_tiers
   where min_level <= public.council_level_for(after_total - new.xp)
   order by min_level desc limit 1;
  select * into t_after from public.council_rank_tiers
   where min_level <= public.council_level_for(after_total)
   order by min_level desc limit 1;
  if t_after.tier is not null and t_after.tier > coalesce(t_before,0) then
    insert into public.friend_activity(user_id,kind,data)
      values(new.user_id,'rank_up',
        jsonb_build_object('title',t_after.title_ar,'tier',t_after.tier));
  end if;
  return new;
-- News is never worth failing a match record or an XP grant.
exception when others then
  return new;
end $$;
revoke all on function public.friend_activity_on_xp() from public, anon, authenticated;
drop trigger if exists friend_activity_xp on public.council_xp_events;
create trigger friend_activity_xp after insert on public.council_xp_events
  for each row execute function public.friend_activity_on_xp();

-- ── Reading ─────────────────────────────────────────────────────────────────
-- Whether p_viewer may see p_user's activity: an accepted friend, no block,
-- sharing on.
create or replace function public.friend_activity_visible(p_viewer uuid, p_user uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select p_viewer<>p_user
     and public.directory_is_friend(p_viewer,p_user)
     and not public.friends_blocked(p_viewer,p_user)
     and exists(select 1 from public.player_directory d
                 where d.user_id=p_user and d.share_activity)
$$;
revoke all on function public.friend_activity_visible(uuid,uuid) from public, anon, authenticated;
grant execute on function public.friend_activity_visible(uuid,uuid) to service_role;

create or replace function public.friend_feed(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare
  items jsonb; weekly jsonb; board jsonb;
  wk_day date := (now() at time zone 'Africa/Cairo')::date
    - ((extract(isodow from (now() at time zone 'Africa/Cairo'))::int + 1) % 7);
  wk_start timestamptz := (wk_day::timestamp) at time zone 'Africa/Cairo';
  m int; w int; mafia int; top jsonb;
begin
  perform public.directory_guard(p_user);

  select coalesce(jsonb_agg(jsonb_build_object(
      'id',a.id,'userId',a.user_id,'name',coalesce(d.display_name,'?'),'kind',a.kind,
      'data',a.data,'at',a.created_at,
      'reactions',jsonb_build_object(
        '👏',(select count(*) from public.friend_activity_reactions r where r.activity_id=a.id and r.emoji='👏'),
        '🔥',(select count(*) from public.friend_activity_reactions r where r.activity_id=a.id and r.emoji='🔥'),
        '😂',(select count(*) from public.friend_activity_reactions r where r.activity_id=a.id and r.emoji='😂')),
      'mine',(select r.emoji from public.friend_activity_reactions r
               where r.activity_id=a.id and r.user_id=p_user))
      order by a.created_at desc, a.id desc),'[]'::jsonb)
    into items
    from (select * from public.friend_activity x
           where x.created_at > now() - interval '7 days'
             and public.friend_activity_visible(p_user, x.user_id)
           order by x.created_at desc, x.id desc limit 50) a
    left join public.player_directory d on d.user_id=a.user_id;

  -- My week: finished online matches only.
  select count(*), count(*) filter (where won), count(*) filter (where team='mafia')
    into m, w, mafia
    from public.council_match_records
   where user_id=p_user and ended_at >= wk_start;
  select jsonb_build_object('name',coalesce(d.display_name,'?'),'count',t.n) into top
    from (select o.user_id, count(*)::int n
            from public.council_match_records me
            join public.council_match_records o on o.room_id=me.room_id and o.user_id<>p_user
           where me.user_id=p_user and me.ended_at >= wk_start
             and public.directory_is_friend(p_user,o.user_id)
             and not public.friends_blocked(p_user,o.user_id)
           group by o.user_id order by count(*) desc, o.user_id limit 1) t
    left join public.player_directory d on d.user_id=t.user_id;
  weekly := jsonb_build_object('matches',m,'wins',w,'mafia',mafia,'topFriend',top);

  -- Wins this week: me and the friends who share, top 10.
  select coalesce(jsonb_agg(jsonb_build_object('userId',b.user_id,'name',b.name,
      'wins',b.wins,'me',b.is_me) order by b.wins desc, b.is_me desc, b.name),'[]'::jsonb)
    into board
    from (
      select x.user_id, coalesce(d.display_name,'?') as name, x.wins, x.user_id=p_user as is_me
        from (
          select c.user_id, count(*) filter (where c.won)::int as wins
            from public.council_match_records c
           where c.ended_at >= wk_start
             and (c.user_id=p_user or public.friend_activity_visible(p_user,c.user_id))
           group by c.user_id
        ) x
        left join public.player_directory d on d.user_id=x.user_id
       where x.wins > 0 or x.user_id=p_user
       order by x.wins desc, (x.user_id=p_user) desc, d.display_name
       limit 10) b;
  -- I am on my own board even with no match this week.
  if not exists(select 1 from jsonb_array_elements(board) e where (e->>'me')::boolean) then
    board := board || jsonb_build_array(jsonb_build_object('userId',p_user,
      'name',coalesce((select display_name from public.player_directory where user_id=p_user),'?'),
      'wins',0,'me',true));
  end if;

  return jsonb_build_object('items',items,'weekly',weekly,'board',board);
end $$;
revoke all on function public.friend_feed(uuid) from public, anon, authenticated;
grant execute on function public.friend_feed(uuid) to service_role;

-- One of the three emojis, or null (take mine back), on an activity I may see.
create or replace function public.friend_react(p_user uuid, p_activity bigint, p_emoji text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare who uuid;
begin
  perform public.directory_guard(p_user);
  if p_activity is null or (p_emoji is not null and p_emoji not in ('👏','🔥','😂')) then
    raise exception 'BAD_REQUEST';
  end if;
  select user_id into who from public.friend_activity
   where id=p_activity and created_at > now() - interval '7 days';
  if who is null or not public.friend_activity_visible(p_user, who) then
    raise exception 'NOT_ALLOWED';
  end if;
  if p_emoji is null then
    delete from public.friend_activity_reactions where activity_id=p_activity and user_id=p_user;
  else
    insert into public.friend_activity_reactions(activity_id,user_id,emoji)
      values(p_activity,p_user,p_emoji)
      on conflict (activity_id,user_id) do update set emoji=excluded.emoji, created_at=now();
  end if;
  return jsonb_build_object('ok',true);
end $$;
revoke all on function public.friend_react(uuid,bigint,text) from public, anon, authenticated;
grant execute on function public.friend_react(uuid,bigint,text) to service_role;

-- Nightly: activity older than 14 days goes (the feed shows 7).
create or replace function public.friend_activity_purge()
returns integer language sql security definer set search_path=public,pg_temp as $$
  with gone as (delete from public.friend_activity
                 where created_at < now() - interval '14 days' returning 1)
  select count(*)::int from gone
$$;
revoke all on function public.friend_activity_purge() from public, anon, authenticated;
grant execute on function public.friend_activity_purge() to service_role;
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('friend_activity_purge', '57 4 * * *',
      $cron$select public.friend_activity_purge()$cron$);
  end if;
end $$;
