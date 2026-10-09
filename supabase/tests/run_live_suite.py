"""Live suite controller. Credentials and refreshed sessions stay in memory.

Usage: python supabase/tests/run_live_suite.py
Reads dart_defines.json without logging it. Imports any existing bot_pool once.
Only bot-owned rooms may be mutated; service/admin HTTP and DELETE are disabled.
Results contain assertion labels and error codes, never response payloads.
"""
import contextlib
import importlib
import io
import json
import os
from pathlib import Path
import time

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


def request(path, payload, token=None, method='POST'):
    if method == 'DELETE' or '/admin/' in path:
        raise RuntimeError('privileged HTTP disabled')
    if path.endswith('/join_room') and payload.get('code') not in codes:
        return 403, {'error': 'TEST_OWNED_ROOMS_ONLY'}
    if path.startswith('/functions/') and payload and payload.get('roomId'):
        if payload['roomId'] not in owned:
            return 403, {'error': 'TEST_OWNED_ROOMS_ONLY'}
    status, data = original(path, payload, token, method)
    if path.endswith('/create_room') and status == 200 and data.get('roomId'):
        owned.add(data['roomId'])
        codes.add(data['code'])
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
    # Maximum concurrent accounts needed by any baseline, before any lobby.
    for i in range(12):
        h.anon_session('LiveBot%d' % i)
    print('12 bot sessions ready in memory', flush=True)
    for name in ('e2e_match', 'ready_match', 'revote_match', 'recovery_match',
                 'kick_flow_match', 'kick_timing_match', 'roster_match',
                 'witness_match', 'concurrency_match'):
        run(name)
    print('BASELINES_DONE; holding sessions for new scenario module', flush=True)
    trigger = ROOT / 'build/run_new_roles.trigger'
    while not trigger.exists():
        time.sleep(2)
    run('new_roles_tools_match')
