"""Live suite controller. Credentials and refreshed sessions stay in memory.

Usage: python supabase/tests/run_live_suite.py
Reads dart_defines.json without logging it. Imports any existing bot_pool once.
Only bot-owned rooms may be mutated; service/admin HTTP and DELETE are disabled.
Results contain assertion labels and error codes, never response payloads.
"""
import contextlib
import http.client
import importlib
import io
import json
import os
from pathlib import Path
import socket
import time
import sys
import urllib.error

ROOT = Path(__file__).resolve().parents[2]
config = json.loads((ROOT / 'dart_defines.json').read_text(encoding='utf-8-sig'))
for name in ('SUPABASE_URL', 'SUPABASE_ANON_KEY'):
    os.environ[name] = config.get(name, config.get('SUPABASE_KEY', config.get('SUPABASE_PUBLISHABLE_KEY', '')))
assert os.environ['SUPABASE_URL'].rstrip('/') == 'https://hezjbrnveajypfqmjfnh.supabase.co'
os.environ.pop('SUPABASE_SERVICE_KEY', None)
os.environ['SIGNUP_RETRIES'] = '2'
os.environ['SIGNUP_WAIT_SECONDS'] = '30'
import e2e_match as h

owned, codes, errors, reports = set(), set(), [], {}
original = h._request
TRANSPORT = (TimeoutError, socket.timeout, ConnectionError, http.client.IncompleteRead,
             http.client.RemoteDisconnected, urllib.error.URLError)


members = {}  # roomId -> tokens that acted in it (never logged)
credited = set()  # (roomId, phase_number) whose ready-opened ballot a driver was credited with


def room_phase(room_id, token):
    with contextlib.suppress(*TRANSPORT):
        status, rows = original('/rest/v1/room_state?select=phase,phase_number,phase_ends_at&room_id=eq.' + room_id,
                                None, token, 'GET')
        if status == 200 and isinstance(rows, list) and rows:
            return rows[0]
    return None


_AHEAD = []


def clock_ahead():
    """Seconds this machine's clock runs ahead of the server's (measured once
    from the HTTP Date header; this laptop drifted 5.4 s on 2026-11-10, which
    made every «the clock ran out» call land before the server's clock had)."""
    if not _AHEAD:
        import email.utils
        import urllib.request
        try:
            with urllib.request.urlopen(os.environ['SUPABASE_URL'].rstrip('/') + '/auth/v1/health', timeout=10) as r:
                server = email.utils.parsedate_to_datetime(r.headers['Date']).timestamp()
            _AHEAD.append(max(0.0, time.time() - server) + 1.0)
        except Exception:  # noqa: BLE001
            _AHEAD.append(8.0)
    return _AHEAD[0]


def wait_until(iso, room_id=None):
    """Waits until a server deadline has passed (at most two minutes). The
    seats keep beating meanwhile, as open apps do: a silent host would be
    taken for gone and the room closed under the suite."""
    import calendar
    try:
        deadline = calendar.timegm(time.strptime(iso[:19], '%Y-%m-%dT%H:%M:%S'))
    except ValueError:
        return
    end = deadline + 1.5 + clock_ahead()
    if not 0 < end - time.time() <= 130:
        return
    while time.time() < end:
        for token in list(members.get(room_id, ())) if room_id else ():
            with contextlib.suppress(*TRANSPORT):
                original('/functions/v1/heartbeat', {'roomId': room_id}, token, 'POST')
        time.sleep(max(0, min(8, end - time.time())))


def ready_everyone(room_id):
    """The server opens the ballot only once every living player said
    «جاهزين للتصويت» (or the discussion clock ran out); the harness says it
    for every bot it has seen in the room, quietly — the dead are refused."""
    for token in list(members.get(room_id, ())):
        with contextlib.suppress(*TRANSPORT):
            status, data = original('/functions/v1/ready_to_vote', {'roomId': room_id, 'ready': True}, token, 'POST')
            if status >= 400:
                err = data.get('error', data.get('code', 'HTTP_ERROR')) if isinstance(data, dict) else 'HTTP_ERROR'
                errors.append({'endpoint': 'harness:ready_to_vote', 'status': status, 'code': err})


def request(path, payload, token=None, method='POST'):
    if method == 'DELETE' or '/admin/' in path:
        raise RuntimeError('privileged HTTP disabled')
    if path.endswith('/join_room') and payload.get('code') not in codes:
        return 403, {'error': 'TEST_OWNED_ROOMS_ONLY'}
    if path.startswith('/functions/') and payload and payload.get('roomId'):
        if payload['roomId'] not in owned:
            return 403, {'error': 'TEST_OWNED_ROOMS_ONLY'}
        if token:
            members.setdefault(payload['roomId'], set()).add(token)
        if path.endswith('/open_phase') and payload.get('phase') == 'vote':
            ready_everyone(payload['roomId'])
            # The last «جاهزين» opens the ballot by itself (atomic_ready_open),
            # exactly as in the app; the host's tap then has nothing left to do.
            # Only the first driver is credited with the move, so a race of
            # drivers still sees exactly one winner and the rest refused.
            row = room_phase(payload['roomId'], token)
            if row and row.get('phase') == 'vote':
                key = (payload['roomId'], row.get('phase_number'))
                if key not in credited:
                    credited.add(key)
                    return 200, {'ok': True, 'phase': 'vote', 'openedBy': 'ready'}
        if path.endswith('/resolve_vote'):
            # The ballot closes when every living player has voted or its clock
            # runs out, not on the host's word (owner, 2026-10-30). A suite
            # that leaves a seat silent waits for the clock, as a table would.
            row = room_phase(payload['roomId'], token)
            if row and row.get('phase') == 'vote' and row.get('phase_ends_at'):
                wait_until(row['phase_ends_at'], payload['roomId'])
    for wait in (2, 5, None):  # Dropped connections are local; the server never failed these calls.
        try:
            status, data = original(path, payload, token, method)
            break
        except urllib.error.HTTPError:
            raise
        except TRANSPORT as e:
            if wait is None:
                raise
            errors.append({'endpoint': path.split('?')[0], 'status': 0, 'code': 'TRANSPORT_' + type(e).__name__})
            time.sleep(wait)
    if path.endswith('/create_room') and status == 200 and data.get('roomId'):
        owned.add(data['roomId'])
        codes.add(data['code'])
    if (path.endswith('/create_room') or path.endswith('/join_room')) and token \
            and status == 200 and isinstance(data, dict) and data.get('roomId'):
        members.setdefault(data['roomId'], set()).add(token)
    if status >= 400:
        err = data.get('error', data.get('code', 'HTTP_ERROR')) if isinstance(data, dict) else 'HTTP_ERROR'
        errors.append({'endpoint': path.split('?')[0], 'status': status, 'code': err})
    return status, data


h._request = request
def check(name, condition, detail=''):
    (h.PASS if condition else h.FAIL).append(name)
    return condition
h.check = check


def save():
    (ROOT / 'build').mkdir(exist_ok=True)
    (ROOT / 'build/live_suite_results.json').write_text(json.dumps(reports, indent=2), encoding='utf-8')


def run(name):
    h.PASS.clear()
    h.FAIL.clear()
    h._POOL_TAKEN[0] = 0
    errors.clear()
    problem = None
    print('RUN ' + name, flush=True)
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            module = importlib.import_module(name)
            module.main()
    except SystemExit as e:
        if e.code:
            problem = 'SystemExit'  # auth exception text may contain credentials
    except Exception as e:
        problem = type(e).__name__
    reports[name] = {'passed': len(h.PASS), 'failed': list(h.FAIL), 'exception': problem,
                     'errors': list(errors)}
    save()
    print(json.dumps({'suite': name, 'passed': len(h.PASS), 'failed': h.FAIL, 'exception': problem}), flush=True)


if __name__ == '__main__':
    if ('--confront-timer' in sys.argv or '--timers-only' in sys.argv or
            '--dead-night-tools' in sys.argv):
        h._POOL_TAKEN[0] = 1  # Cached seats 1-5; seat 0's refresh was consumed by a read-only probe.
        def no_new_account(_label):
            raise SystemExit('CACHE_REFRESH_FAILED')
        h._anon_session_new = no_new_account
        for i in range(5):
            h.anon_session('CachedBot%d' % i)
        print('5 cached bot sessions ready in memory', flush=True)
        run('confront_expiry_match' if '--confront-timer' in sys.argv else
            'dead_night_tools_match' if '--dead-night-tools' in sys.argv else
            'timer_expiry_match')
        raise SystemExit(0)
    count = (0 if '--insufficient' in sys.argv else
             5 if '--revote-only' in sys.argv else
             6 if '--kick-only' in sys.argv or '--affected-baselines' in sys.argv else
             10 if '--affected-roles' in sys.argv else
             5 if ('--conflicts' in sys.argv or '--conflicts-one' in sys.argv) else 12)
    # Every session is minted before creating a lobby, then reused throughout.
    for i in range(count):
        h.anon_session('LiveBot%d' % i)
    print(str(count) + ' bot sessions ready in memory', flush=True)
    if '--insufficient' in sys.argv:
        run('insufficient_coins_match')
        raise SystemExit(0)
    if '--affected-baselines' in sys.argv:
        run('revote_match')
        run('kick_flow_match')
        raise SystemExit(0)
    if '--revote-only' in sys.argv or '--kick-only' in sys.argv:
        run('revote_match' if '--revote-only' in sys.argv else 'kick_flow_match')
        raise SystemExit(0)
    if '--affected-roles' in sys.argv:
        os.environ['LIVE_AFFECTED'] = '1'
        run('new_roles_tools_match')
        raise SystemExit(0)
    if '--conflicts-one' in sys.argv:
        os.environ['LIVE_ONLY_INTERACTION'] = '1'
        run('remaining_conflicts_match')
        raise SystemExit(0)
    if '--conflicts' in sys.argv:
        run('remaining_conflicts_match')
        raise SystemExit(0)
    if '--remaining' in sys.argv:
        run('new_roles_tools_match')
        raise SystemExit(0)
    if '--roles-timers' in sys.argv:
        os.environ['LIVE_ROLES_TIMERS_ONLY'] = '1'
        run('new_roles_tools_match')
        raise SystemExit(0)
    only = next((a.split('=', 1)[1] for a in sys.argv if a.startswith('--only=')), None)
    if only:
        for name in only.split(','):
            run(name)
        raise SystemExit(0)
    for name in ('e2e_match', 'ready_match', 'revote_match', 'recovery_match',
                 'kick_flow_match', 'kick_timing_match', 'roster_match',
                 'witness_match', 'concurrency_match'):
        run(name)
    print('BASELINES_DONE; holding sessions for new scenario module', flush=True)
    trigger = ROOT / 'build/run_new_roles.trigger'
    while not trigger.exists():
        time.sleep(2)
    run('new_roles_tools_match')
