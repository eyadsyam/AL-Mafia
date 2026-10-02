-- The whisper graph moves between phases, so it must be published.
--
-- `whisper_meta` is the public half of a whisper (doc 09 §3.1: everybody sees
-- the light, nobody sees the words), and the client redraws it only on a full
-- read, which it performs once per phase (doc 10 §3.1). A whisper sent in the
-- middle of a discussion therefore reached its recipient at the *next* phase
-- — a chime and a card during the ballot for words written during the talk.
-- Publishing the graph lets a member's client learn of a whisper when it is
-- written and read the room again; the body still lives behind
-- `whisper_content`, which only the two parties can select, and the row
-- itself is delivered only to room members (`whisper_meta_room_read` is
-- enforced on the Realtime stream as it is on a query).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='whisper_meta'
  ) then
    alter publication supabase_realtime add table public.whisper_meta;
  end if;
end $$;
