-- Improvement 2 «ممكن تعرفهم» (owner 2026-11-19): up to 10 people worth asking.
--
-- A suggestion is either
--   * someone who sat in at least 2 FINISHED online matches with me in the last
--     60 days (council_match_records, same room; those rows only exist once a
--     match is over and are kept ~21 days, so in practice the window is that
--     long), or
--   * a friend of at least 2 of my friends.
-- Never someone I am already linked to (friend, pending either way), never a
-- block either way, never a player who hides from search, restricted, or whose
-- request rule would refuse me ('nobody'; 'tablemates' only when we really
-- played together). Each row carries {matchesTogether} or {mutualFriends}
-- (the other is null) and nothing about roles or teams (doc 05).
-- Read-only; clients cannot call it (service_role through the friends function).

create or replace function public.friend_suggestions(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
declare out jsonb;
begin
  perform public.directory_guard(p_user);
  with together as (
    select o.user_id as cand, count(*)::int as n
      from public.council_match_records m
      join public.council_match_records o on o.room_id=m.room_id and o.user_id<>m.user_id
     where m.user_id=p_user and m.ended_at > now() - interval '60 days'
     group by o.user_id
    having count(*) >= 2
  ), mine as (
    select case when l.user_lo=p_user then l.user_hi else l.user_lo end as f
      from public.friend_links l
     where p_user in (l.user_lo,l.user_hi) and l.accepted_at is not null
  ), mutual as (
    select case when l.user_lo=mf.f then l.user_hi else l.user_lo end as cand,
           count(*)::int as n
      from public.friend_links l
      join mine mf on mf.f in (l.user_lo,l.user_hi)
     where l.accepted_at is not null
     group by 1
    having count(*) >= 2
  ), cands as (
    select coalesce(t.cand,m.cand) as cand, t.n as together_n, m.n as mutual_n
      from together t full join mutual m on m.cand=t.cand
  ), shown as (
    select d.user_id, d.handle, d.display_name, d.gender, c.together_n, c.mutual_n
      from cands c
      join public.player_directory d on d.user_id=c.cand
     where c.cand<>p_user
       and not exists(select 1 from public.friend_links l
         where l.user_lo=least(p_user,c.cand) and l.user_hi=greatest(p_user,c.cand))
       and public.directory_visible(p_user,c.cand)
       and (d.who_can_add='everyone'
            or (d.who_can_add='tablemates' and c.together_n is not null))
     order by coalesce(c.together_n,0) desc, coalesce(c.mutual_n,0) desc, d.handle
     limit 10
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'userId',s.user_id,'handle',s.handle,'name',s.display_name,'gender',s.gender,
      'matchesTogether',s.together_n,'mutualFriends',s.mutual_n)
      order by coalesce(s.together_n,0) desc, coalesce(s.mutual_n,0) desc, s.handle),'[]'::jsonb)
    into out from shown s;
  return jsonb_build_object('rows',out);
end $$;
revoke all on function public.friend_suggestions(uuid) from public, anon, authenticated;
grant execute on function public.friend_suggestions(uuid) to service_role;
