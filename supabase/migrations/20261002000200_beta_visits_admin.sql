-- Who opened saidalmafia.com/beta and who signed up, for the owner only.
--
-- `beta_visits`: one row per visitor per day (the first source wins), with a
-- hit counter. A visitor is a hash of the address's HMAC and the day, so it
-- changes daily and cannot be matched to the limit counter or the address;
-- rows go after 60 days. Written only by `tester_signup` with the service role.
--
-- `admin_testers` / `admin_tester_mark`: the `/admin/testers` page. Both refuse
-- anyone outside `commerce_admins`.

create table if not exists public.beta_visits (
  day date not null default (now() at time zone 'Africa/Cairo')::date,
  visitor text not null check (char_length(visitor) = 64),
  source text check (source is null or source ~ '^[a-z0-9_-]{1,20}$'),
  hits integer not null default 1 check (hits >= 1),
  first_at timestamptz not null default now(),
  last_at timestamptz not null default now(),
  primary key (day, visitor)
);

alter table public.beta_visits enable row level security;
revoke all on table public.beta_visits from public, anon, authenticated;
grant select, insert, update, delete on table public.beta_visits to service_role;

create or replace function public.beta_visit_record(p_visitor text, p_source text)
returns void language sql security definer set search_path = public, pg_temp as $$
  delete from public.beta_visits where day < (now() at time zone 'Africa/Cairo')::date - 60;
  insert into public.beta_visits (visitor, source)
  values (p_visitor, case when p_source ~ '^[a-z0-9_-]{1,20}$' then p_source end)
  on conflict (day, visitor) do update
    set hits = least(public.beta_visits.hits + 1, 1000), last_at = now();
$$;
revoke all on function public.beta_visit_record(text, text) from public, anon, authenticated;
grant execute on function public.beta_visit_record(text, text) to service_role;

create or replace function public.admin_testers(p_admin uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  today date := (now() at time zone 'Africa/Cairo')::date;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  return jsonb_build_object(
    'visits', jsonb_build_object(
      'total', (select count(*) from public.beta_visits),
      'today', (select count(*) from public.beta_visits where day = today),
      'hits', (select coalesce(sum(hits), 0) from public.beta_visits),
      'bySource', coalesce((
        select jsonb_agg(jsonb_build_object('source', coalesce(source, ''), 'visitors', n) order by n desc)
        from (select source, count(*) n from public.beta_visits group by source) s), '[]'::jsonb),
      'byDay', coalesce((
        select jsonb_agg(jsonb_build_object('day', day, 'visitors', n) order by day desc)
        from (select day, count(*) n from public.beta_visits
              where day > today - 14 group by day) d), '[]'::jsonb)
    ),
    'signups', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', id, 'name', name, 'email', email, 'source', coalesce(source, ''),
        'createdAt', created_at, 'mailed', mailed_at is not null, 'added', added_at is not null)
        order by created_at desc)
      from public.tester_signups), '[]'::jsonb)
  );
end $$;
revoke all on function public.admin_testers(uuid) from public, anon, authenticated;
grant execute on function public.admin_testers(uuid) to service_role;

create or replace function public.admin_tester_mark(p_admin uuid, p_id bigint, p_added boolean)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  update public.tester_signups
     set added_at = case when p_added then coalesce(added_at, now()) end
   where id = p_id;
end $$;
revoke all on function public.admin_tester_mark(uuid, bigint, boolean) from public, anon, authenticated;
grant execute on function public.admin_tester_mark(uuid, bigint, boolean) to service_role;
