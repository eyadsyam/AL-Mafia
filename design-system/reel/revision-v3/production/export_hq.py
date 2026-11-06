"""Package the native lossless picture with the approved mastered soundtrack."""
from pathlib import Path
import hashlib
import json
import subprocess

R = Path(__file__).resolve().parent
picture = R / 'exports/MAFIA_V3_LOSSLESS_RENDER.mp4'
approved = R / 'exports/MAFIA_V3_صاحبك_اللي_بريء.mp4'
output = R / 'exports/MAFIA_V3_HIGHEST_QUALITY.mp4'

def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          encoding='utf-8', errors='replace')

run(['ffmpeg', '-v', 'error', '-y', '-i', str(picture), '-i', str(approved),
     '-map', '0:v:0', '-map', '1:a:0', '-c', 'copy', '-t', '57.5',
     '-movflags', '+faststart', '-metadata',
     'title=Mafia V3 - Native Lossless Picture Master', str(output)])
probe = json.loads(run(['ffprobe', '-v', 'error', '-count_frames',
                       '-show_streams', '-show_format', '-of', 'json',
                       str(output)]).stdout)
v = next(s for s in probe['streams'] if s['codec_type'] == 'video')
assert (v['width'], v['height'], v['r_frame_rate'], v['nb_read_frames']) == (1080, 1920, '30/1', '1725')
assert abs(float(probe['format']['duration']) - 57.5) < .05
run(['ffmpeg', '-v', 'error', '-xerror', '-i', str(output), '-f', 'null', 'NUL'])
headers = run(['ffmpeg', '-hide_banner', '-i', str(output), '-map', '0:v:0',
               '-c:v', 'copy', '-bsf:v', 'trace_headers', '-frames:v', '1',
               '-f', 'null', 'NUL']).stderr
assert any('qpprime_y_zero_transform_bypass_flag' in line and '= 1' in line
           for line in headers.splitlines()), 'Encoder did not produce a lossless H.264 stream'

def audio_hash(file):
    return run(['ffmpeg', '-v', 'error', '-i', str(file), '-map', '0:a:0',
                '-c:a', 'copy', '-f', 'hash', '-hash', 'sha256', '-']).stdout.strip()
assert audio_hash(output) == audio_hash(approved), 'Mastered soundtrack changed'
report = {'file': str(output), 'bytes': output.stat().st_size,
          'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
          'probe': probe, 'picture': 'Native 1080x1920 H.264 lossless CRF 0; PNG video extraction',
          'lossless_transform_bypass_verified': True,
          'approved_audio_bitstream_unchanged': True, 'all_frames_decoded': True,
          'note': 'Lossless refers to this final picture encoding. Original source clips remain at their original fidelity.'}
(R / 'qa/highest-quality.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
state_path = R.parent.parent / 'STATE.json'
state = json.loads(state_path.read_text(encoding='utf-8-sig'))
state['active_runs'].pop('hq_export', None)
state['outputs']['highest_quality_video'] = str(output)
state['outputs']['highest_quality_qa'] = str(R / 'qa/highest-quality.json')
state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'file': str(output), 'bytes': output.stat().st_size,
                  'frames': 1725, 'lossless_picture_verified': True,
                  'approved_audio_unchanged': True}, ensure_ascii=False))
