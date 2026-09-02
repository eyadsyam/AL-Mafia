-- Nobody plays this game without signing in, so nobody unsigned-in should
-- reach a policy at all (doc 10 §4.1; doc 11 §10, "get_advisors returns
-- clean").
--
-- ## What was actually wrong
--
-- Every policy in `20260901000800` and `20260902000700` was written without a
-- `to` clause, which in Postgres means `to public` — every role, including
-- `anon`. `anon` is the role a request carries when it presents the
-- publishable key and no session.
--
-- That was never *exploitable*: each policy's `using` clause funnels through
-- `auth.uid()`, which is null for `anon`, so `is_room_member(...)` is false and
-- the row set is empty. The database was returning nothing to an anonymous
-- caller by arithmetic rather than by rule.
--
-- Arithmetic is a bad place to keep a boundary. A policy added later that
-- happens not to mention `auth.uid()` — a lookup by room code, say, or a
-- public leaderboard — would inherit `to public` from the same silence and be
-- readable by anyone holding a key that ships inside the APK. Naming the role
-- makes the boundary a property of the grant instead of a property of every
-- future `where` clause.
--
-- ## Why `authenticated` and not `anon`
--
-- The app's one way in is `signInAnonymously`, and an anonymous sign-in still
-- produces a real session: the JWT carries `role: authenticated` and
-- `is_anonymous: true`. "Anonymous" in the product sense and `anon` in the
-- Postgres sense are unrelated, and conflating them is the usual way this gets
-- written backwards.

alter policy rooms_member_read        on public.rooms           to authenticated;
alter policy room_players_room_read   on public.room_players    to authenticated;
alter policy room_state_member_read   on public.room_state      to authenticated;
alter policy night_actions_own_read   on public.night_actions   to authenticated;
alter policy votes_read               on public.votes           to authenticated;
alter policy whisper_meta_room_read   on public.whisper_meta    to authenticated;
alter policy whisper_content_parties  on public.whisper_content to authenticated;
alter policy whisper_blocks_own       on public.whisper_blocks  to authenticated;
alter policy whisper_blocks_insert    on public.whisper_blocks  to authenticated;
alter policy whisper_blocks_delete    on public.whisper_blocks  to authenticated;
alter policy whisper_reports_own      on public.whisper_reports to authenticated;
alter policy signals_addressed_read   on public.signals         to authenticated;
alter policy signals_own_write        on public.signals         to authenticated;

-- ── the scheduler is not part of the client surface ──────────────────────
--
-- `pg_cron` creates `cron.job` and `cron.job_run_details` with policies of its
-- own, and those are `to public` for the same reason ours were. The schema is
-- not in PostgREST's exposed list, so this is not a hole either — but a client
-- role with no reason to know the schema exists should not hold `usage` on it.
--
-- `postgres` keeps everything; it is the role that owns the jobs.

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    revoke usage on schema cron from anon, authenticated;
  end if;
end
$$;

-- ── signalling rows are swept on their own clock ─────────────────────────
--
-- `purge_stale_signals()` arrived with the voice migration and was never given
-- a schedule, so the only thing sweeping `signals` was the nightly
-- `purge_finished_rooms`, at an hour's grain. An hour is three orders of
-- magnitude longer than an SDP offer is worth, and every stale row sits in the
-- RLS-filtered read path of a live match.

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    perform cron.unschedule('purge-stale-signals')
      where exists (select 1 from cron.job where jobname = 'purge-stale-signals');
    perform cron.schedule(
      'purge-stale-signals',
      '*/5 * * * *',
      $cron$ select public.purge_stale_signals(); $cron$
    );
  end if;
end
$$;
