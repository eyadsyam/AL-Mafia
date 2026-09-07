-- Least privilege on the client-facing surface, and two grants that were missing.
--
-- ## What the audit found
--
-- Every policy in this schema is written for the `authenticated` role and every
-- one of them is scoped to `auth.uid()` or to `private.is_room_member(...)`.
-- The policies were right. The **grants underneath them** were not, in two
-- opposite directions at once.
--
-- ### Too much: the two public views
--
-- `room_players_public` and `rooms_public` had been granted `arwdDxtm` — every
-- privilege there is — to both `anon` and `authenticated`. Both views are
-- `security_invoker = true`, so a read still runs against the base table's RLS
-- as the caller, and both base tables carry SELECT-only policies, so nothing was
-- actually readable or writable that should not have been.
--
-- It was still wrong, and specifically it was wrong in a way that would have
-- gone off later rather than now. A simple view over a single table is
-- auto-updatable: PostgREST will happily accept a PATCH to `room_players_public`
-- and Postgres will turn it into an UPDATE on `room_players`. Today RLS refuses
-- that, because `room_players` has no UPDATE policy. The day somebody adds one
-- — for presence, say, which is exactly the kind of thing that gets added —
-- the write path exists, is granted to the public, and reaches a table whose
-- `role` column is the entire secret of the game.
--
-- So: SELECT, to `authenticated`, and nothing else.
--
-- ### Too little: ghost_messages and predictions
--
-- Both tables had a correct RLS policy for `authenticated`
-- (`private.is_dead_member(room_id)` and `user_id = auth.uid()`) and **no grant
-- at all**. A policy without a grant is not a locked door, it is a wall: the
-- client calls `.from('ghost_messages').select(...)` and
-- `.from('predictions').select(...)` directly, and both were failing on
-- privilege before RLS ever got a say.
--
-- That is the eliminated players' channel and the prediction read-back, both
-- broken online and neither with a test that would have said so. The policies
-- were written for a grant that was never issued.
--
-- ### anon
--
-- Removed everywhere. Every player signs in anonymously *before* the first
-- query — that is what `SupabaseBackend.connect` does — so a live client is
-- `authenticated` with `is_anonymous = true`, never the `anon` role. Nothing
-- the app does needs a grant to a caller holding no JWT at all, and the
-- policies would have returned nothing to one anyway. This turns "silently
-- empty" into "refused", which is the honest answer to a request that arrived
-- without a session.

-- ── the two reads the client makes and could not ────────────────────────────
grant select on public.ghost_messages to authenticated;
grant select on public.predictions    to authenticated;

-- ── no privilege at all without a session ───────────────────────────────────
revoke all on public.ghost_messages, public.night_actions, public.predictions,
              public.room_players_public, public.room_state, public.rooms_public,
              public.signals, public.votes, public.whisper_blocks,
              public.whisper_content, public.whisper_meta, public.whisper_reports
  from anon;

-- ── exactly the verbs the policies permit, and no others ────────────────────
revoke all on public.room_players_public from authenticated;
grant select on public.room_players_public to authenticated;

revoke all on public.rooms_public from authenticated;
grant select on public.rooms_public to authenticated;

-- whisper_blocks_own (select), whisper_blocks_insert, whisper_blocks_delete.
-- No UPDATE policy exists, so UPDATE was already refused; the grant is going
-- anyway, because a privilege nobody can use is a privilege nobody audits.
revoke all on public.whisper_blocks from authenticated;
grant select, insert, delete on public.whisper_blocks to authenticated;

-- whisper_reports_own is INSERT-only by design: a report is written and never
-- read back by the reporter (doc 10 §9). The grant now says the same thing.
revoke all on public.whisper_reports from authenticated;
grant insert on public.whisper_reports to authenticated;
