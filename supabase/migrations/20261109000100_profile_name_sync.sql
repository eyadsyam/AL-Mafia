-- One name per account on every device: the caller's own entry also says the
-- gender, so a phone or browser signing in to an existing account takes the
-- account's name AND address instead of asking the player again.
-- Same signature and grants as 20260930000100_invites_push.sql; only the
-- `gender` key is new (older clients ignore it).

create or replace function public.directory_me(p_user uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((select jsonb_build_object('handle',d.handle,'name',d.display_name,
      'gender',d.gender,
      'searchable',d.searchable,'strangerInvites',d.stranger_invites,
      'handleChangeAt',case when d.handle_changed_at is null then null
        else d.handle_changed_at + make_interval(days => c.handle_change_days) end)
    from public.player_directory d, public.economy_config c where d.user_id=p_user),
    jsonb_build_object('handle',null))
$$;
