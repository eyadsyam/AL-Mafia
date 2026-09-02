-- The anti-cheat boundary, asserted against a real database.
--
-- Doc 11 §6 asks whether a player "can post a vote for someone else" or
-- "submit an action for a role they do not have". Those are not questions a
-- Dart test can answer: the transport tests prove the *client* never tries,
-- which is a different claim from the server never allowing it. The only thing
-- that can answer them is Postgres, holding a token, being asked rudely.
--
-- So this is the gate. Run it against any project the migrations have been
-- applied to; it seeds a room, asks every forbidden question as three
-- different identities, and raises on the first wrong answer.
--
--   psql "$DATABASE_URL" -f supabase/tests/anticheat.sql
--
-- It cleans up after itself, and it is safe to run against a project with live
-- rooms in it: everything it touches hangs off one room id that no generator
-- can produce.
--
-- The identities:
--   …01  seat 0, mafia, host
--   …02  seat 1, doctor
--   …03  seat 2, citizen
--   …09  not in the room at all

begin;

create schema if not exists private;

-- Runs `p_sql` as `authenticated`, with `p_sub` as the JWT subject, and
-- returns its single value — or the refusal. `security invoker` matters: a
-- definer probe would run as its owner and prove nothing.
create or replace function private.__probe(p_sub text, p_sql text)
returns text language plpgsql as $probe$
declare r text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_sub, 'role', 'authenticated')::text, true);
  begin
    execute p_sql into r;
  exception when others then
    r := 'DENIED: ' || sqlerrm;
  end;
  perform set_config('role', 'none', true);
  return coalesce(r, '(null)');
end $probe$;

-- The same, for statements that write. Reports the row count so that a policy
-- which silently matches nothing is not mistaken for one that refused.
create or replace function private.__write(p_sub text, p_sql text)
returns text language plpgsql as $probe$
declare n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_sub, 'role', 'authenticated')::text, true);
  begin
    execute p_sql;
    get diagnostics n = row_count;
    perform set_config('role', 'none', true);
    return 'ALLOWED(' || n || ')';
  exception when others then
    perform set_config('role', 'none', true);
    return 'DENIED: ' || sqlerrm;
  end;
end $probe$;

create or replace function private.__expect(
  p_case text, p_got text, p_want text
) returns void language plpgsql as $expect$
begin
  if p_got is distinct from p_want then
    raise exception 'anticheat % FAILED: wanted %, got %', p_case, p_want, p_got;
  end if;
  raise notice 'anticheat % ok', p_case;
end $expect$;

create or replace function private.__expect_denied(
  p_case text, p_got text
) returns void language plpgsql as $expect$
begin
  if p_got not like 'DENIED:%' then
    raise exception 'anticheat % FAILED: expected a refusal, got %', p_case, p_got;
  end if;
  raise notice 'anticheat % ok (%)', p_case, left(p_got, 60);
end $expect$;

-- ── the fixture ──────────────────────────────────────────────────────────

delete from public.rooms where id = '11111111-1111-1111-1111-111111111111';

insert into public.rooms (id, code, host_id, status, match_seed)
values ('11111111-1111-1111-1111-111111111111', 'ABCDEF',
        'aaaaaaaa-0000-0000-0000-000000000001', 'playing', 987654321);

insert into public.room_state (room_id, phase, phase_number)
values ('11111111-1111-1111-1111-111111111111', 'vote', 1);

insert into public.room_players (room_id, user_id, name, seat, role) values
  ('11111111-1111-1111-1111-111111111111','aaaaaaaa-0000-0000-0000-000000000001','A',0,'mafia'),
  ('11111111-1111-1111-1111-111111111111','aaaaaaaa-0000-0000-0000-000000000002','B',1,'doctor'),
  ('11111111-1111-1111-1111-111111111111','aaaaaaaa-0000-0000-0000-000000000003','C',2,'citizen');

insert into public.night_actions (room_id, night, actor_id, action, target_id) values
  ('11111111-1111-1111-1111-111111111111',1,'aaaaaaaa-0000-0000-0000-000000000001','kill','aaaaaaaa-0000-0000-0000-000000000003'),
  ('11111111-1111-1111-1111-111111111111',1,'aaaaaaaa-0000-0000-0000-000000000002','protect','aaaaaaaa-0000-0000-0000-000000000003');

insert into public.votes (room_id, day, voter_id, target_id) values
  ('11111111-1111-1111-1111-111111111111',1,'aaaaaaaa-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000003');

insert into public.whisper_meta (id, room_id, day, from_id, to_id) values
  ('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',1,
   'aaaaaaaa-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000003');
insert into public.whisper_content (whisper_id, body)
values ('22222222-2222-2222-2222-222222222222', 'secret');

-- ── reads ────────────────────────────────────────────────────────────────

do $$
declare R constant text := '11111111-1111-1111-1111-111111111111';
        A constant text := 'aaaaaaaa-0000-0000-0000-000000000001';
        B constant text := 'aaaaaaaa-0000-0000-0000-000000000002';
        C constant text := 'aaaaaaaa-0000-0000-0000-000000000003';
        X constant text := 'aaaaaaaa-0000-0000-0000-000000000009';
begin
  -- The roster is readable, and carries no role column at all: `role` holds no
  -- column privilege for any client role, so this is not a redaction that has
  -- to stay correct — there is nothing to redact.
  perform private.__expect('roster',
    private.__probe(B, format(
      $q$select string_agg(name, ',' order by seat)
           from public.room_players_public where room_id = %L$q$, R)),
    'A,B,C');

  perform private.__expect_denied('O16 role column, own row',
    private.__probe(B, format(
      $q$select role from public.room_players where user_id = %L$q$, B)));

  perform private.__expect_denied('O16 role column, another row',
    private.__probe(B, format(
      $q$select role from public.room_players where user_id = %L$q$, A)));

  perform private.__expect_denied('O16 select * on the role table',
    private.__probe(B, format(
      $q$select count(*)::text from (select * from public.room_players) x$q$)));

  -- The seed makes every tie-break predictable, including tonight's.
  perform private.__expect_denied('match_seed',
    private.__probe(B, $q$select match_seed::text from public.rooms$q$));

  perform private.__expect('room code',
    private.__probe(B, format(
      $q$select code from public.rooms_public where id = %L$q$, R)),
    'ABCDEF');

  -- A night action names a role by naming what it did.
  perform private.__expect('own night action',
    private.__probe(A, $q$select string_agg(action, ',') from public.night_actions$q$),
    'kill');
  perform private.__expect('night actions of others',
    private.__probe(C, $q$select string_agg(action, ',') from public.night_actions$q$),
    '(null)');

  -- A running tally during an open ballot is a coordination channel the table
  -- game does not have: own ballots only until the day resolves.
  perform private.__expect('open ballot, another voter',
    private.__probe(B, $q$select string_agg(voter_id::text, ',') from public.votes$q$),
    '(null)');
  perform private.__expect('open ballot, own',
    private.__probe(A, $q$select count(*)::text from public.votes$q$),
    '1');

  update public.room_state set phase = 'result'
   where room_id = '11111111-1111-1111-1111-111111111111';
  perform private.__expect('resolved ballot is public',
    private.__probe(B, $q$select count(*)::text from public.votes$q$),
    '1');
  update public.room_state set phase = 'vote'
   where room_id = '11111111-1111-1111-1111-111111111111';

  -- The graph is public; the body belongs to the two parties.
  perform private.__expect('whisper graph',
    private.__probe(B, $q$select count(*)::text from public.whisper_meta$q$),
    '1');
  perform private.__expect('whisper body, a third party',
    private.__probe(B, $q$select string_agg(body, ',') from public.whisper_content$q$),
    '(null)');
  perform private.__expect('whisper body, the recipient',
    private.__probe(C, $q$select string_agg(body, ',') from public.whisper_content$q$),
    'secret');

  -- Somebody who is not in the room sees a room that is not there.
  perform private.__expect('outsider roster',
    private.__probe(X, $q$select count(*)::text from public.room_players_public$q$),
    '0');
  perform private.__expect('outsider rooms',
    private.__probe(X, $q$select count(*)::text from public.rooms_public$q$),
    '0');
  perform private.__expect('outsider state',
    private.__probe(X, $q$select count(*)::text from public.room_state$q$),
    '0');
end $$;

-- ── writes ───────────────────────────────────────────────────────────────
--
-- Every mutation in this app goes through an Edge Function holding the service
-- key. A client's write surface is exactly one table: `signals`, whose payload
-- is opaque SDP and carries nothing about the game.

do $$
declare R constant text := '11111111-1111-1111-1111-111111111111';
        A constant text := 'aaaaaaaa-0000-0000-0000-000000000001';
        B constant text := 'aaaaaaaa-0000-0000-0000-000000000002';
        C constant text := 'aaaaaaaa-0000-0000-0000-000000000003';
begin
  perform private.__expect_denied('O17 a ballot in someone else''s name',
    private.__write(B, format(
      $q$insert into public.votes (room_id, day, voter_id, target_id)
         values (%L, 1, %L, null)$q$, R, C)));

  perform private.__expect_denied('O17 a ballot in one''s own name',
    private.__write(B, format(
      $q$insert into public.votes (room_id, day, voter_id, target_id)
         values (%L, 2, %L, null)$q$, R, B)));

  perform private.__expect_denied('O18 a kill from a Doctor',
    private.__write(B, format(
      $q$insert into public.night_actions (room_id, night, actor_id, action, target_id)
         values (%L, 2, %L, 'kill', %L)$q$, R, B, A)));

  perform private.__expect_denied('rewriting a role',
    private.__write(B, format(
      $q$update public.room_players set role = 'citizen' where user_id = %L$q$, A)));

  perform private.__expect_denied('killing a player',
    private.__write(B, format(
      $q$update public.room_players set alive = false where user_id = %L$q$, A)));

  perform private.__expect_denied('driving the phase',
    private.__write(B, format(
      $q$update public.room_state set phase = 'result' where room_id = %L$q$, R)));

  perform private.__expect_denied('taking the room',
    private.__write(B, format(
      $q$update public.rooms set host_id = %L where id = %L$q$, B, R)));

  perform private.__expect_denied('forging a whisper',
    private.__write(B, format(
      $q$insert into public.whisper_meta (room_id, day, from_id, to_id)
         values (%L, 1, %L, %L)$q$, R, A, C)));

  -- The two helpers a definer function would have handed to anybody who found
  -- the route: kick a player, or take the host seat.
  perform private.__expect_denied('rpc leave_room on another player',
    private.__probe(B, format(
      $q$select public.leave_room(%L, %L)$q$, R, A)));
  perform private.__expect_denied('rpc migrate_host',
    private.__probe(B, format(
      $q$select public.migrate_host(%L, %L)::text$q$, R, B)));
  perform private.__expect_denied('rpc purge_finished_rooms',
    private.__probe(B, $q$select public.purge_finished_rooms()::text$q$));
  perform private.__expect_denied('rpc merge_public_data',
    private.__probe(B, format(
      $q$select public.merge_public_data(%L, '{"x":1}'::jsonb)::text$q$, R)));

  -- The one write a client may make, and the one it may not.
  perform private.__expect('own signal',
    private.__write(B, format(
      $q$insert into public.signals (room_id, from_id, to_id, payload)
         values (%L, %L, %L, '{"sdp":"x"}')$q$, R, B, C)),
    'ALLOWED(1)');
  perform private.__expect_denied('a signal in someone else''s name',
    private.__write(B, format(
      $q$insert into public.signals (room_id, from_id, to_id, payload)
         values (%L, %L, %L, '{"sdp":"x"}')$q$, R, A, C)));
  perform private.__expect('a signal addressed elsewhere',
    private.__probe(A, $q$select count(*)::text from public.signals$q$),
    '0');

  -- The clock every countdown is drawn against is readable by everyone.
  perform private.__expect('server_now',
    private.__probe(B, $q$select (public.server_now() is not null)::text$q$),
    'true');
end $$;

-- ── the roster stays writable ────────────────────────────────────────────
--
-- Not an access rule: a regression guard. Publishing `room_players` with a
-- column list while it carried `replica identity full` made every update and
-- delete on it fail, which stopped the heartbeat and every elimination.

update public.room_players set connected = false, last_seen = now()
 where room_id = '11111111-1111-1111-1111-111111111111';
delete from public.room_players
 where room_id = '11111111-1111-1111-1111-111111111111'
   and seat = 2;

delete from public.rooms where id = '11111111-1111-1111-1111-111111111111';

drop function private.__probe(text, text);
drop function private.__write(text, text);
drop function private.__expect(text, text, text);
drop function private.__expect_denied(text, text);

commit;
