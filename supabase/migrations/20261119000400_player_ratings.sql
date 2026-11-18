-- B3: the star rating a player gives after a finished match (one to five stars,
-- an optional line of text). Anonymous accounts may rate; at most three a day.
-- The owner reads it beside the written suggestions (admin_feedback).
-- Idempotent.

create table if not exists public.player_ratings (
  id bigserial primary key,
  user_id uuid references auth.users(id) on delete set null,
  stars smallint not null check (stars between 1 and 5),
  body text check (body is null or char_length(body) between 1 and 500),
  build integer not null,
  platform text not null check (platform in ('android','web','ios')),
  created_at timestamptz not null default now()
);
create index if not exists player_ratings_user_created on public.player_ratings(user_id, created_at desc);
alter table public.player_ratings enable row level security;
revoke all on public.player_ratings from anon, authenticated;
grant select, insert on public.player_ratings to service_role;
grant usage, select on sequence public.player_ratings_id_seq to service_role;

create or replace function public.submit_rating(p_user uuid, p_stars int, p_body text, p_build int, p_platform text)
returns jsonb language plpgsql security definer set search_path to 'public','pg_temp' as $$
declare v_id bigint; v_body text := nullif(btrim(coalesce(p_body,'')), '');
begin
  if p_user is null or not exists (select 1 from auth.users where id = p_user)
     or p_stars is null or p_stars not between 1 and 5
     or (v_body is not null and char_length(v_body) > 500)
     or p_build is null or p_build < 0
     or p_platform is null or p_platform not in ('android','web','ios') then
    raise exception 'BAD_REQUEST';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('rating:' || p_user::text, 0));
  if (select count(*) from public.player_ratings where user_id = p_user
        and (created_at at time zone 'Africa/Cairo')::date = (now() at time zone 'Africa/Cairo')::date) >= 3 then
    raise exception 'RATE_LIMITED';
  end if;
  insert into public.player_ratings(user_id, stars, body, build, platform)
    values (p_user, p_stars::smallint, v_body, p_build, p_platform) returning id into v_id;
  return jsonb_build_object('id', v_id);
end $$;
revoke all on function public.submit_rating(uuid,int,text,int,text) from public, anon, authenticated;
grant execute on function public.submit_rating(uuid,int,text,int,text) to service_role;

-- The owner's feedback view: the same rows as before, plus the ratings (count,
-- average over the last 7 and 30 days, the latest 30 that have a line of text;
-- never a user id).
create or replace function public.admin_feedback(p_admin uuid, p_status text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_rows jsonb; v_ratings jsonb;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_status is not null and p_status not in ('new','read','planned') then raise exception 'BAD_REQUEST'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',f.id,'kind',f.kind,'body',f.body,
      'status',f.status,'createdAt',f.created_at,'appBuild',f.app_build,
      'platform',f.platform,'displayName',coalesce(i.name,d.display_name),
      'handle',d.handle) order by f.created_at desc),'[]'::jsonb)
    into v_rows from (select * from public.player_feedback
      where p_status is null or status=p_status order by created_at desc limit 100) f
    left join public.council_identity i on i.user_id=f.user_id
    left join public.player_directory d on d.user_id=f.user_id;
  select jsonb_build_object(
      'count', (select count(*) from public.player_ratings),
      'avg7', (select round(avg(stars)::numeric, 2) from public.player_ratings
                where created_at > now() - interval '7 days'),
      'avg30', (select round(avg(stars)::numeric, 2) from public.player_ratings
                 where created_at > now() - interval '30 days'),
      'latest', coalesce((select jsonb_agg(jsonb_build_object('stars', r.stars, 'body', r.body,
            'build', r.build, 'platform', r.platform, 'createdAt', r.created_at)
          order by r.created_at desc)
        from (select * from public.player_ratings where body is not null
               order by created_at desc, id desc limit 30) r), '[]'::jsonb))
    into v_ratings;
  return jsonb_build_object('items',v_rows,'ratings',v_ratings);
end $$;
revoke all on function public.admin_feedback(uuid,text) from public,anon,authenticated;
grant execute on function public.admin_feedback(uuid,text) to service_role;
