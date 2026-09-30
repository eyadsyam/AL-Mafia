"""Gives every store narrator pack the full line bank, in its own voice.

tool/voice/pack_voices.mjs renders each pack's five signature lines. On their
own they leave a paid pack poorer than the free narrator: no line at the vote
result, no morning variant for "someone died" / "nobody died", one line per
beat. This runs every Kratos clip (the same voice the packs are rendered
from) through the pack's own room treatment (the same ffmpeg effect as
pack_voices.mjs) and appends them to the pack's manifest after its signature
lines, keeping each clip's beat, condition and family flag.

    python tool/voice/pack_full_lines.py

Writes assets/voice/<pack>/full_<clip>.ogg + .mp3 (Safari twin) and rewrites
the manifest. Idempotent: earlier full_ rows are replaced.
"""
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
VOICE = ROOT / 'assets' / 'voice'

# Keep in step with the `effect` of each pack in pack_voices.mjs.
EFFECTS = {
    'narrator_storyteller': 'atempo=0.93,bass=g=3:f=180,aecho=0.8:0.5:45:0.18',
    'narrator_keeper': 'atempo=0.97,aecho=0.8:0.75:110|230:0.32|0.18',
    'narrator_noir': 'asetrate=44100*0.9,aresample=44100,atempo=1.08,'
                     'highpass=f=220,lowpass=f=3600,'
                     'acompressor=threshold=0.1:ratio=4',
}
LOUDNESS = 'loudnorm=I=-16:TP=-1.5:LRA=7'


def ffmpeg(src, af, dst, codec):
    subprocess.run(
        ['ffmpeg', '-y', '-loglevel', 'error', '-i', str(src), '-af', af,
         '-ac', '1', '-ar', '44100', *codec, str(dst)],
        check=True)


def main():
    base = json.loads((VOICE / 'kratos' / 'manifest.json').read_text('utf-8'))
    for pack, effect in EFFECTS.items():
        folder = VOICE / pack
        manifest_path = folder / 'manifest.json'
        manifest = json.loads(manifest_path.read_text('utf-8'))
        own = [c for c in manifest['clips'] if '_full_' not in c['id']]
        full = []
        for clip in base['clips']:
            src = ROOT / 'assets' / clip['file']
            name = f"full_{pathlib.Path(clip['file']).stem}"
            af = f'{effect},{LOUDNESS}'
            ffmpeg(src, af, folder / f'{name}.ogg',
                   ['-c:a', 'libvorbis', '-q:a', '4'])
            ffmpeg(src, af, folder / f'{name}.mp3',
                   ['-c:a', 'libmp3lame', '-b:a', '80k'])
            full.append({
                'id': f"{pack}_full_{clip['id']}",
                'beat': clip['beat'],
                'when': clip['when'],
                'family': clip['family'],
                'file': f'voice/{pack}/{name}.ogg',
            })
        manifest['clips'] = own + full
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', 'utf-8')
        print(f'{pack}: {len(own)} own + {len(full)} full lines')


if __name__ == '__main__':
    main()
