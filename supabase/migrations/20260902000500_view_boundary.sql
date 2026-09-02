-- The two client-facing views, repaired (doc 10 §4.1, §10).
--
-- ## What was wrong
--
-- `rooms_public` and `room_players_public` were declared `security_invoker =
-- true` **and** the same migration revoked `select` on their base tables from
-- `anon` and `authenticated`. Those two facts cannot both hold: an invoker
-- view checks the base table's privileges as the *caller*, so every read a
-- client makes through either view returned
--
--     permission denied for table room_players
--
-- The roster, the room code and every player's own role were unreachable.
-- Online mode could not have worked at all; nothing caught it because no
-- client had ever spoken to a real Postgres.
--
-- ## Why the fix is a definer view rather than a grant
--
-- The obvious repair — grant `select` back and let RLS do the filtering — is
-- right for `rooms` (a column grant that omits `match_seed` keeps the seed
-- unreachable while the view's own column list still resolves) but cannot work
-- for `room_players`. The rule there is *"your own role, nobody else's"*, and a
-- grant is per column for every row: there is no column privilege that means
-- "this column, but only on the row where `user_id = auth.uid()`". Granting
-- `role` at all would hand every player the whole role table for their room,
-- because the row policy deliberately admits the whole room.
--
-- So both views run as their owner and carry their own row filter:
--
--   * the base tables stay revoked from `anon` and `authenticated`, which makes
--     them **unreachable** rather than merely policy-guarded — there is no
--     `select * from room_players` for anybody to get right or wrong;
--   * `where public.is_room_member(...)` is the row boundary, evaluated in one
--     place instead of once per policy;
--   * the `case` is the column boundary, and it is the only path by which the
--     `role` column can leave the database.
--
-- The comment on the previous migration worried that a definer view makes the
-- redaction "the only thing standing between a client and the role table".
-- That is exactly what it is — and with the base table's privileges revoked it
-- is also the only *door*, which is a stronger position than a redaction
-- standing beside an open one.
--
-- `security_barrier` keeps a caller from pushing a cheap, leaky predicate
-- underneath the filter and reading rows out through an error message.

create or replace view public.rooms_public
with (security_invoker = false, security_barrier = true)
as
  select id, code, host_id, status, settings, created_at, ended_at
  from public.rooms
  where public.is_room_member(id);

create or replace view public.room_players_public
with (security_invoker = false, security_barrier = true)
as
  select
    room_id,
    user_id,
    name,
    seat,
    alive,
    connected,
    last_seen,
    case when user_id = auth.uid() then role else null end as role
  from public.room_players
  where public.is_room_member(room_id);

-- `join_room` needs to resolve a code before the caller is a member of
-- anything, so the lookup cannot go through `rooms_public` — and it does not:
-- it runs in an Edge Function as the service role. Nothing here widens that.

grant select on public.rooms_public         to anon, authenticated;
grant select on public.room_players_public  to anon, authenticated;

-- Restated rather than assumed. A future migration that adds a column to
-- either base table must not be able to make it readable by forgetting this.
revoke all on public.rooms        from anon, authenticated;
revoke all on public.room_players from anon, authenticated;

comment on view public.room_players_public is
  'The only path by which room_players.role may leave the database. Runs as '
  'owner because "your own role, nobody else''s" is not expressible as a '
  'column privilege; the base table is revoked from all client roles.';
