"""Four real server players for a room an app created: play_with_app.py with
the hosted URL and public key read from dart_defines.json (never printed).

    python supabase/tests/bots_for_app.py ROOMCODE
"""
import json
import os
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
config = json.loads((ROOT / 'dart_defines.json').read_text(encoding='utf-8-sig'))
os.environ['SUPABASE_URL'] = config.get('SUPABASE_URL', '')
os.environ['SUPABASE_ANON_KEY'] = config.get('SUPABASE_ANON_KEY', config.get('SUPABASE_KEY', config.get('SUPABASE_PUBLISHABLE_KEY', '')))
os.environ.pop('SUPABASE_SERVICE_KEY', None)
sys.path.insert(0, str(Path(__file__).resolve().parent))
os.chdir(ROOT)
sys.argv = [str(Path(__file__).with_name('play_with_app.py'))] + sys.argv[1:]
runpy.run_path(sys.argv[0], run_name='__main__')
