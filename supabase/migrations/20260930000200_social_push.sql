-- D: friend requests and accepted requests also reach the phone, on the
-- quieter `mafia_social` channel (default sound, short vibration). Same
-- tokens, same switch (`push_invites_enabled`), same generic rules: nothing
-- across a block, nothing while push is off.
--
-- The payload is the kind and the sender's display name. No id, no code, no
-- match fact (Doc 05).

-- What the Edge function needs right after friend_request / friend_respond:
-- a fresh request from p_from to p_to, or p_from just accepting p_to's
-- request (both within the last minute), else nothing.
create or replace function public.friend_push_targets(p_from uuid, p_to uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select coalesce((
    select jsonb_build_object('enabled',true,
        'kind',case when l.accepted_at is null then 'friend_request' else 'friend_accepted' end,
        'fromName',coalesce(d.display_name,i.name,'?'),
        'tokens',coalesce((select jsonb_agg(jsonb_build_object('token',t.token,'platform',t.platform)
          order by t.updated_at desc) from public.push_tokens t where t.user_id=p_to),'[]'::jsonb))
      from public.friend_links l
      left join public.player_directory d on d.user_id=p_from
      left join public.council_identity i on i.user_id=p_from
     where l.user_lo=least(p_from,p_to) and l.user_hi=greatest(p_from,p_to)
       and ((l.accepted_at is null and l.requested_by=p_from
              and l.created_at > now() - interval '1 minute')
         or (l.accepted_at is not null and l.requested_by=p_to
              and l.accepted_at > now() - interval '1 minute'))
       and public.safety_users_compatible(p_from,p_to)
       and public.friends_on()
       and coalesce((select push_invites_enabled from public.economy_config),false)),
    jsonb_build_object('enabled',false))
$$;
revoke all on function public.friend_push_targets(uuid,uuid) from public, anon, authenticated;
grant execute on function public.friend_push_targets(uuid,uuid) to service_role;
