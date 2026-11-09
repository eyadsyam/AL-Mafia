-- Feedback only from a signed-in player with a real message, and a username
-- that is fixed once chosen (owner, 2026-11-09).
--
-- 1. submit_feedback refuses anonymous users (SIGN_IN_REQUIRED) and bodies
--    under 3 words or 10 non-space characters (TOO_SHORT). The ten-minute and
--    daily limits stay.
-- 2. admin_feedback also returns the sender's @handle (and the directory
--    display name when the council identity has none).
-- 3. directory_set_handle refuses HANDLE_LOCKED once the player chose a handle
--    (handle_changed_at is not null). The auto-assigned handle may be replaced
--    exactly once. directory_me tells the client whether the handle is locked.

create or replace function public.submit_feedback(p_user uuid, p_kind text, p_body text, p_build int, p_platform text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid; v_body text := btrim(coalesce(p_body,''));
begin
  if p_user is null or not exists(select 1 from auth.users where id=p_user)
    or p_kind not in ('roles','online','store','look','idea','problem')
    or p_kind is null or p_body is null or char_length(v_body) not between 2 and 500
    or p_platform not in ('android','web','ios') or p_platform is null
    or (p_build is not null and p_build < 0) then
    raise exception 'BAD_REQUEST';
  end if;
  if exists(select 1 from auth.users u where u.id=p_user
      and (coalesce(u.is_anonymous,false) or u.email is null)) then
    raise exception 'SIGN_IN_REQUIRED';
  end if;
  if coalesce(array_length(regexp_split_to_array(v_body, '\s+'),1),0) < 3
    or char_length(regexp_replace(v_body, '\s', '', 'g')) < 10 then
    raise exception 'TOO_SHORT';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user::text, 0));
  if exists(select 1 from public.player_feedback where user_id=p_user
      and created_at > now()-interval '10 minutes')
    or (select count(*) from public.player_feedback where user_id=p_user
      and (created_at at time zone 'Africa/Cairo')::date =
          (now() at time zone 'Africa/Cairo')::date) >= 5 then
    raise exception 'RATE_LIMITED';
  end if;
  insert into public.player_feedback(user_id,kind,body,app_build,platform)
    values(p_user,p_kind,v_body,p_build,p_platform) returning id into v_id;
  perform public.push_owner('owner_feedback','feedback:'||v_id);
  return v_id;
end $$;
revoke all on function public.submit_feedback(uuid,text,text,int,text) from public,anon,authenticated;
grant execute on function public.submit_feedback(uuid,text,text,int,text) to service_role;

create or replace function public.admin_feedback(p_admin uuid, p_status text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_rows jsonb;
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
  return jsonb_build_object('items',v_rows);
end $$;
revoke all on function public.admin_feedback(uuid,text) from public,anon,authenticated;
grant execute on function public.admin_feedback(uuid,text) to service_role;

create or replace function public.directory_me(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select jsonb_build_object('handle',d.handle,'name',d.display_name,
      'gender',d.gender,
      'searchable',d.searchable,'strangerInvites',d.stranger_invites,
      'handleLocked',d.handle_changed_at is not null,
      'handleChangeAt',case when d.handle_changed_at is null then null
        else d.handle_changed_at + make_interval(days => c.handle_change_days) end)
    from public.player_directory d, public.economy_config c where d.user_id=p_user),
    jsonb_build_object('handle',null))
$$;
revoke all on function public.directory_me(uuid) from public, anon, authenticated;
grant execute on function public.directory_me(uuid) to service_role;

create or replace function public.directory_set_handle(p_user uuid, p_handle text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare cur public.player_directory; h text := btrim(coalesce(p_handle,''));
begin
  perform public.directory_guard(p_user);
  if h !~ '^[A-Za-z0-9_ء-ي٠-٩]{3,20}$' or length(public.directory_norm(h)) < 3 then
    raise exception 'BAD_REQUEST';
  end if;
  if not public.safety_name_allowed(h,'name') then raise exception 'NAME_NOT_ALLOWED'; end if;
  select * into cur from public.player_directory where user_id=p_user for update;
  if cur.user_id is null then raise exception 'BAD_REQUEST'; end if;
  if cur.handle = h then return public.directory_me(p_user); end if;
  -- A handle the player chose stays. The one assigned at first hello may be
  -- replaced exactly once (that replacement sets handle_changed_at).
  if cur.handle_changed_at is not null then raise exception 'HANDLE_LOCKED'; end if;
  perform pg_advisory_xact_lock(hashtextextended('directory:handles', 23));
  if exists(select 1 from public.player_directory
      where handle_norm=public.directory_norm(h) and user_id<>p_user) then
    raise exception 'HANDLE_TAKEN';
  end if;
  update public.player_directory set handle=h, handle_norm=public.directory_norm(h),
    handle_changed_at=now() where user_id=p_user;
  return public.directory_me(p_user);
end $$;
revoke all on function public.directory_set_handle(uuid,text) from public, anon, authenticated;
grant execute on function public.directory_set_handle(uuid,text) to service_role;
