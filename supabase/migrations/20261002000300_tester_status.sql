-- The standalone tester page (saidalmafia.com/admin/testers/): a status and a
-- private note per sign-up, changed in bulk, and deletion on request.
--
-- Status: new (not added yet), added (in the Google group), active (installed
-- and testing), problem (needs a follow-up), removed (taken off the test).
-- `added_at` stays the moment the person first reached added/active.

alter table public.tester_signups
  add column if not exists status text not null default 'new'
    check (status in ('new', 'added', 'active', 'problem', 'removed')),
  add column if not exists note text check (note is null or char_length(note) <= 300),
  add column if not exists updated_at timestamptz;

update public.tester_signups set status = 'added'
 where added_at is not null and status = 'new';

create index if not exists tester_signups_status on public.tester_signups (status);

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
        'createdAt', created_at, 'mailed', mailed_at is not null,
        'added', added_at is not null, 'addedAt', added_at,
        'status', status, 'note', coalesce(note, ''))
        order by created_at desc)
      from public.tester_signups), '[]'::jsonb)
  );
end $$;
revoke all on function public.admin_testers(uuid) from public, anon, authenticated;
grant execute on function public.admin_testers(uuid) to service_role;

create or replace function public.admin_tester_set(p_admin uuid, p_ids bigint[], p_status text)
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare
  changed integer;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if p_status not in ('new', 'added', 'active', 'problem', 'removed')
     or coalesce(cardinality(p_ids), 0) not between 1 and 5000 then
    raise exception 'BAD_REQUEST';
  end if;
  update public.tester_signups
     set status = p_status,
         added_at = case
           when p_status in ('added', 'active') then coalesce(added_at, now())
           when p_status = 'new' then null
           else added_at end,
         updated_at = now()
   where id = any(p_ids);
  get diagnostics changed = row_count;
  return changed;
end $$;
revoke all on function public.admin_tester_set(uuid, bigint[], text) from public, anon, authenticated;
grant execute on function public.admin_tester_set(uuid, bigint[], text) to service_role;

create or replace function public.admin_tester_note(p_admin uuid, p_id bigint, p_note text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  update public.tester_signups
     set note = nullif(left(trim(coalesce(p_note, '')), 300), ''), updated_at = now()
   where id = p_id;
end $$;
revoke all on function public.admin_tester_note(uuid, bigint, text) from public, anon, authenticated;
grant execute on function public.admin_tester_note(uuid, bigint, text) to service_role;

create or replace function public.admin_tester_delete(p_admin uuid, p_ids bigint[])
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare
  removed integer;
begin
  if not public.is_commerce_admin(p_admin) then raise exception 'NOT_ADMIN'; end if;
  if coalesce(cardinality(p_ids), 0) not between 1 and 5000 then raise exception 'BAD_REQUEST'; end if;
  delete from public.tester_signups where id = any(p_ids);
  get diagnostics removed = row_count;
  return removed;
end $$;
revoke all on function public.admin_tester_delete(uuid, bigint[]) from public, anon, authenticated;
grant execute on function public.admin_tester_delete(uuid, bigint[]) to service_role;

drop function if exists public.admin_tester_mark(uuid, bigint, boolean);
