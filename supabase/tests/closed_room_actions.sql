-- A deliberate host departure leaves the old phase row behind, but no move
-- may be accepted into a match that has ended without a result.
begin;
do $$
declare
  host uuid := gen_random_uuid(); guest uuid := gen_random_uuid(); rid uuid;
  ph text; refused boolean;
begin
  foreach ph in array array['night', 'vote'] loop
    rid := gen_random_uuid();
    insert into public.rooms(id, code, host_id, match_seed, status)
      values(rid, case when ph='night' then 'CLNAAA' else 'CLVAAA' end,
        host, 7, 'playing');
    insert into public.room_players(room_id, user_id, name, seat, status, connected)
      values(rid, host, 'host', 0, 'connected', true),
            (rid, guest, 'guest', 1, 'connected', true);
    insert into public.room_state(room_id, phase, phase_number, public_data)
      values(rid, ph, 1, '{}');
    assert public.leave_room(rid, host) = 'closed';
    refused := false;
    begin
      if ph = 'night' then
        insert into public.night_actions(room_id, night, actor_id, action)
          values(rid, 1, guest, 'skip');
      else
        insert into public.votes(room_id, day, voter_id, round)
          values(rid, 1, guest, 1);
      end if;
    exception when raise_exception then
      refused := sqlerrm = 'PHASE_CLOSED';
    end;
    assert refused, 'a ' || ph || ' move was accepted after the host closed the room';
    assert (select status from public.rooms where id = rid) = 'finished';
    assert (select public_data->>'outcome' from public.room_state where room_id = rid) is null;
    assert not exists(select 1 from public.wallet_ledger where source_room = rid);
  end loop;
  -- A decided night or ballot has an outcome before the result phase opens.
  -- A host departure in that gap must abort it, not expose a result or reward.
  foreach ph in array array['morning', 'verdict'] loop
    rid := gen_random_uuid();
    insert into public.rooms(id, code, host_id, match_seed, status, started_at)
      values(rid, case when ph='morning' then 'CLMAAA' else 'CLRAAA' end,
        host, 7, 'finished', now() - interval '5 minutes');
    insert into public.room_players(room_id, user_id, name, seat, status, connected, role)
      values(rid, host, 'host', 0, 'connected', true, 'mafia'),
            (rid, guest, 'guest', 1, 'connected', true, 'citizen');
    insert into public.room_state(room_id, phase, phase_number, public_data)
      values(rid, ph, 1, '{"outcome":"mafia"}');
    assert public.leave_room(rid, host) = 'closed';
    assert (select public_data->>'outcome' from public.room_state where room_id=rid)
      is null, 'a ' || ph || ' host leave kept a winner visible';
    assert not exists(select 1 from public.match_receipts where room_id=rid);
  end loop;
  foreach ph in array array['reveal', 'opening', 'confront', 'discuss', 'defense'] loop
    rid := gen_random_uuid();
    insert into public.rooms(id, code, host_id, match_seed, status)
      values(rid, case ph
        when 'reveal' then 'CLRAVA'
        when 'opening' then 'CLPPAA'
        when 'confront' then 'CLCXAA'
        when 'discuss' then 'CLDXAA'
        else 'CLDEAA' end, host, 7, 'playing');
    insert into public.room_players(room_id, user_id, name, seat, status, connected)
      values(rid, host, 'host', 0, 'connected', true),
            (rid, guest, 'guest', 1, 'connected', true);
    insert into public.room_state(room_id, phase, phase_number, public_data)
      values(rid, ph, 1, '{}');
    assert public.leave_room(rid, host)='closed', 'host could not close during '||ph;
    assert (select status from public.rooms where id=rid)='finished';
    assert (select public_data->>'outcome' from public.room_state where room_id=rid) is null;
    assert not exists(select 1 from public.match_receipts where room_id=rid);
  end loop;
end $$;
rollback;
