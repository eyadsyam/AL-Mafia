"""One hosted match where the seat holding the opening round stays silent: the
floor must move on its clock. Prints every refusal with its message.

    python supabase/tests/silent_opening_probe.py
"""
import calendar
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
from e2e_match import aid, fn  # noqa: E402

AHEAD = 7.5  # this laptop's clock runs ~5.4 s ahead of the server's


def say(*a):
    print(time.strftime('%H:%M:%S'), *a, flush=True)


def call(name, body, p):
    status, data = fn(name, body, p)
    say(name, json.dumps({k: v for k, v in body.items() if k not in ('roomId', 'actionId')}), '->', status,
        json.dumps(data, ensure_ascii=False)[:220])
    return status, data


players, room, code = make_room(['Host', 'Bina', 'Cyra', 'Dina', 'Ezra'])
stop = threading.Event()
threading.Thread(target=lambda: [fn('heartbeat', {'roomId': room}, p) for _ in iter(lambda: stop.wait(8), True) for p in players],
                 daemon=True).start()
deal(players, room)
call('open_phase', {'roomId': room, 'phase': 'night'}, players[0])
for p in players:
    call('submit_night_action', {'roomId': room, 'action': 'suspect', 'targetSeat': (p['seat'] + 1) % 5, 'actionId': aid()}, p)
call('resolve_night', {'roomId': room}, players[0])
call('open_phase', {'roomId': room, 'phase': 'opening'}, players[0])
seen_opening = False
for round_ in range(14):
    s = state_of(room, players[0])
    pd = s.get('public_data') or {}
    say('state', s.get('phase'), 'openingSeat', pd.get('openingSeat'), 'ends', s.get('phase_ends_at'))
    if s.get('phase') == 'opening':
        seen_opening = True
    elif seen_opening:
        break
    elif s.get('phase') == 'morning':
        call('open_phase', {'roomId': room, 'phase': 'opening'}, players[0])
        continue
    ends = calendar.timegm(time.strptime(s['phase_ends_at'][:19], '%Y-%m-%dT%H:%M:%S'))
    time.sleep(max(0, ends - time.time() + AHEAD))
    call('advance_phase', {'roomId': room}, players[1])
    if s.get('phase') == 'night':
        call('resolve_night', {'roomId': room}, players[1])
stop.set()
