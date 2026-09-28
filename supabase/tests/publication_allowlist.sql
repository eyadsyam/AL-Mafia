-- S4 — the exact columns every client can receive over Realtime.
--
-- The replication stream is the one payload no Edge Function shapes: whatever
-- a published table holds, subscribers are sent. Each table's column list is
-- pinned here. A new column, a new table, or a republish without a column list
-- fails this file until someone decides — in review, against Doc 05 — that the
-- column is safe for every seat to see.
begin;
do $$
declare
  expected jsonb := jsonb_build_object(
    'ghost_messages', 'author_id,body,created_at,id,room_id',
    'room_players',   'alive,connected,cosmetics,gender,kicked,last_seen,muted,name,room_id,saw_role,seat,status,user_id',
    'room_reactions', 'created_at,id,kind,room_id,seat,user_id',
    'room_state',     'active_speaker,phase,phase_ends_at,phase_number,public_data,room_id,speaker_until,updated_at',
    'rooms',          'code,created_at,ended_at,host_id,id,settings,status,title,visibility',
    'whisper_meta',   'created_at,day,from_id,id,room_id,to_id,voided');
  actual jsonb;
  forbidden text[] := array['role','team','faction','target','target_id','seed','match_seed',
    'action','note','answer','answer_hash','used_bullet','night_action','vote','ballot','token','email'];
  bad text;
begin
  select jsonb_object_agg(p.tablename,
           (select string_agg(a,',' order by a) from unnest(p.attnames) a))
    into actual
    from pg_publication_tables p
   where p.pubname='supabase_realtime' and p.schemaname='public';
  if actual is distinct from expected then
    raise exception 'publication drift: expected % got %', expected, actual;
  end if;
  select string_agg(p.tablename||'.'||a,', ') into bad
    from pg_publication_tables p, unnest(p.attnames) a
   where p.pubname='supabase_realtime' and a = any(forbidden);
  if bad is not null then raise exception 'forbidden column published: %', bad; end if;
  if exists (select 1 from pg_publication_tables
              where pubname='supabase_realtime' and schemaname<>'public') then
    raise exception 'a non-public schema is published';
  end if;
end $$;
rollback;
