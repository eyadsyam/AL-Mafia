"""Imports raw_assets/art-v2 (story covers, tool icons, locations) as webp.

    python tool/stories/import_art_v2.py

Covers go to assets/images/stories/covers/ and are written into each story's
`coverImage` by story number; tool icons to assets/images/tools/; locations
to assets/images/stories/locations/. Missing source files are skipped and
listed, so a partial batch can be imported and the rest added later.
"""

import glob
import json
import os

from PIL import Image

SRC = 'raw_assets/art-v2'
COVERS = 'assets/images/stories/covers'
TOOLS = 'assets/images/tools'
LOCATIONS = 'assets/images/stories/locations'
# The painted location behind each story that has one, by story number.
SCENES = {
    1: 'cafe_alley', 2: 'rooftop_wedding', 3: 'butcher_shop', 4: 'family_house',
    5: 'gold_souq', 6: 'sleeper_train', 7: 'zamalek_museum', 8: 'bank_vault',
    17: 'cinema_1955', 18: 'shepheard_hotel', 19: 'newspaper_press',
    20: 'garden_city_palace',
}


def save(src, dst, size, quality):
    img = Image.open(src)
    img = img.convert('RGBA' if img.mode in ('RGBA', 'LA', 'P') else 'RGB')
    img.thumbnail(size, Image.LANCZOS)
    img.save(dst, 'WEBP', quality=quality, method=6)


def main():
    for d in (COVERS, TOOLS, LOCATIONS):
        os.makedirs(d, exist_ok=True)
    missing = []

    for path in sorted(glob.glob('assets/stories/*.json')):
        raw = open(path, 'rb').read()
        story = json.loads(raw.decode('utf-8'))
        n = '%02d' % story['number']
        src = f'{SRC}/cover_{n}.png'
        if not os.path.exists(src):
            missing.append(src)
            continue
        dst = f'{COVERS}/cover_{n}.webp'
        save(src, dst, (640, 960), 80)
        changed = story['coverImage'] != dst
        story['coverImage'] = dst
        scene = SCENES.get(story['number'])
        if scene and os.path.exists(f'{SRC}/loc_{scene}.png'):
            loc = f'{LOCATIONS}/loc_{scene}.webp'
            changed = changed or story.get('sceneImage') != loc
            story['sceneImage'] = loc
        if changed:
            out = json.dumps(story, ensure_ascii=False, indent=2) + '\n'
            if b'\r\n' in raw:
                out = out.replace('\n', '\r\n')
            open(path, 'wb').write(out.encode('utf-8'))

    for src in sorted(glob.glob(f'{SRC}/tool_*.png')):
        name = os.path.basename(src)[:-4]
        save(src, f'{TOOLS}/{name}.webp', (192, 192), 90)

    for src in sorted(glob.glob(f'{SRC}/loc_*.png')):
        name = os.path.basename(src)[:-4]
        save(src, f'{LOCATIONS}/{name}.webp', (1152, 768), 78)

    print('missing:', len(missing))
    for m in missing:
        print('  ', m)


if __name__ == '__main__':
    main()
