"""Read-only Realtime transport diagnosis using an existing bot cache."""
import json
import os
import time
from pathlib import Path
import websocket

config = json.loads(Path('dart_defines.json').read_text(encoding='utf-8-sig'))
os.environ['SUPABASE_URL'] = config['SUPABASE_URL']
os.environ['SUPABASE_ANON_KEY'] = config['SUPABASE_KEY']
import e2e_match as h
p = json.loads(Path('build/bot_pool.json').read_text())[0]
status, rows = h.rest('room_players_public?select=room_id&user_id=eq.' + p['id'], p)
ids = ','.join(r['room_id'] for r in rows)
status, rooms = h.rest('rooms_public?select=id,status&id=in.(' + ids + ')&status=eq.playing', p)
if not rooms:
    raise SystemExit('No current bot room')
rid = rooms[-1]['id']
try:
    ws = websocket.create_connection(h.URL.replace('https:', 'wss:') +
        '/realtime/v1/websocket?apikey=' + h.KEY + '&vsn=1.0.0', timeout=5)
    ws.send(json.dumps(dict(topic='realtime:probe', event='phx_join', ref='1', payload={
        'access_token': p['token'], 'config': {'broadcast': {'self': False},
        'presence': {'key': ''}, 'postgres_changes': [dict(event='*', schema='public',
            table='room_state', filter='room_id=eq.' + rid)]}})))
    for _ in range(4):
        try:
            d = json.loads(ws.recv())
            body = d.get('payload', {})
            print(json.dumps({'event': d.get('event'), 'status': body.get('status'),
                  'responseKeys': list(body.get('response', {})),
                  'extension': body.get('extension'), 'message': body.get('message')
                    if d.get('event') == 'system' else None}), flush=True)
        except websocket.WebSocketTimeoutException:
            print('No payload in five-second window', flush=True)
    ws.close()
except Exception as e:
    print('Realtime error type: ' + type(e).__name__)
