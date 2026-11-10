"""One hosted match where a living player never votes: the ballot must close
on its clock. Prints every refusal with its message.

    python supabase/tests/silent_ballot_probe.py
"""
import json
import os
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
cfg = json.loads((ROOT / 'dart_defines.json').read_text(encoding='utf-8-sig'))
os.environ['SUPABASE_URL'] = cfg.get('SUPABASE_URL', '')
os.environ['SUPABASE_ANON_KEY'] = cfg.get('SUPABASE_ANON_KEY', cfg.get('SUPABASE_KEY', cfg.get('SUPABASE_PUBLISHABLE_KEY', '')))
os.environ.pop('SUPABASE_SERVICE_KEY', None)
sys.path.insert(0, str(Path(__file__).resolve().parent))
os.chdir(ROOT)
from concurrency_match import deal, make_room, state_of  # noqa: E402
from e2e_match import aid, fn, rest  # noqa: E402


def say(*a):
    print(time.strftime('%H:%M:%S'), *a, flush=True)


def call(name, body, p):
    status, data = fn(name, body, p)
    say(name, json.dumps({k: v for k, v in body.items() if k not in ('roomId', 'actionId')}), '->', status,
        json.dumps(data)[:200] if status != 200 else '')
    return status, data


players, room, code = make_room(['Host', 'Bina', 'Cyra', 'Dina', 'Ezra'])
stop = threading.Event()


def beats():
    while not stop.wait(8):
        for p in players:
            fn('heartbeat', {'roomId': room}, p)


threading.Thread(target=beats, daemon=True).start()
deal(players, room)
by = {}
for p in players:
    by.setdefault(p['role'], []).append(p)
mafia = by['mafia'][0]
call('open_phase', {'roomId': room, 'phase': 'night'}, players[0])
for p in players:
    target = next(o for o in players if o is not p and o is not mafia)
    action = {'mafia': 'kill', 'doctor': 'protect', 'detective': 'investigate'}.get(p['role'], 'suspect')
    if p['role'] == 'doctor':
        target = p if False else next(o for o in players if o is not p and o is not mafia)
    call('submit_night_action', {'roomId': room, 'action': action, 'targetSeat': target['seat'], 'actionId': aid()}, p)
call('resolve_night', {'roomId': room}, players[0])
say('state', state_of(room, players[0]).get('phase'))
call('open_phase', {'roomId': room, 'phase': 'opening'}, players[0])
alive = lambda: sorted(r['seat'] for r in rest('room_players_public?select=seat,alive&room_id=eq.' + room, players[0])[1] if r['alive'])
living = alive()
for seat in living:
    p = next(x for x in players if x['seat'] == seat)
    call('submit_accusation', {'roomId': room, 'targetSeat': next(s for s in living if s != seat)}, p)
say('state', state_of(room, players[0]).get('phase'))
for seat in living:
    p = next(x for x in players if x['seat'] == seat)
    call('ready_to_vote', {'roomId': room, 'ready': True}, p)
s = state_of(room, players[0])
say('state', s.get('phase'), s.get('phase_ends_at'))
for seat in living:
    p = next(x for x in players if x['seat'] == seat)
    if p is mafia:
        continue
    call('submit_vote', {'roomId': room, 'targetSeat': mafia['seat'], 'round': 1, 'actionId': aid()}, p)
s = state_of(room, players[0])
say('waiting for the ballot clock', s.get('phase_ends_at'))
while True:
    s = state_of(room, players[0])
    if s.get('phase') != 'vote':
        say('room moved on by itself to', s.get('phase'))
        break
    import calendar
    ends = calendar.timegm(time.strptime(s['phase_ends_at'][:19], '%Y-%m-%dT%H:%M:%S'))
    if time.time() > ends + 1:
        call('resolve_vote', {'roomId': room}, players[1])
        time.sleep(3)
        s = state_of(room, players[0])
        say('after resolve', s.get('phase'), (s.get('public_data') or {}).get('outcome'))
        if s.get('phase') != 'vote':
            break
    time.sleep(2)
stop.set()
