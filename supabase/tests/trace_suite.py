"""Runs one live suite through run_live_suite with a phase trace.

Every open_phase / resolve_* / ready / vote call is written to
build/trace_<suite>.log with the room's phase before and after, so a failing
step shows what the server had already done. Tokens are never written.

    python supabase/tests/trace_suite.py roster_match
"""
import json
import sys
import time
from pathlib import Path

sys.argv = [sys.argv[0]] + ['--only=__none__'] + sys.argv[1:]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_live_suite as live  # noqa: E402

suite = sys.argv[-1]
log = open(live.ROOT / 'build' / ('trace_%s.log' % suite), 'w', encoding='utf-8')
inner = live.h._request
WATCH = ('open_phase', 'resolve_vote', 'resolve_night', 'submit_vote', 'ready_to_vote', 'advance_phase',
         'submit_accusation', 'kick_player', 'start_match')


def phase(room, token):
    try:
        status, rows = live.original('/rest/v1/room_state?select=phase,phase_number,phase_ends_at,public_data&room_id=eq.' + room,
                                     None, token, 'GET')
        if status == 200 and rows:
            r = rows[0]
            pd = r.get('public_data') or {}
            st, rr = live.original('/rest/v1/rooms_public?select=status&id=eq.' + room, None, token, 'GET')
            status_txt = rr[0].get('status') if st == 200 and rr else '?'
            return '[%s] %s#%s ends=%s ready=%s outcome=%s' % (status_txt, r['phase'], r['phase_number'], (r.get('phase_ends_at') or '')[11:19],
                                                       (pd.get('readyToVote') or {}).get('seats'), pd.get('outcome'))
    except Exception as e:  # noqa: BLE001
        return 'read failed ' + type(e).__name__
    return '?'


def traced(path, payload, token=None, method='POST'):
    name = path.rsplit('/', 1)[-1].split('?')[0]
    room = (payload or {}).get('roomId') if isinstance(payload, dict) else None
    if name not in WATCH or not room:
        return inner(path, payload, token, method)
    before = phase(room, token)
    status, data = inner(path, payload, token, method)
    after = phase(room, token)
    brief = {k: v for k, v in (payload or {}).items() if k not in ('roomId', 'actionId')}
    code = ('%s %s' % (data.get('error'), data.get('message'))) if isinstance(data, dict) and data.get('error') else None
    log.write('%s %-18s %s -> %s %s | %s => %s\n' % (time.strftime('%H:%M:%S'), name, json.dumps(brief), status,
                                                  code or '', before, after))
    log.flush()
    return status, data


live.h._request = traced
live.run(suite)
log.close()
