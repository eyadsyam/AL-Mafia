"""Gives every story character a suspect bust: never the same face twice in
one story, the right gender, and an age close to the character's.

    python tool/stories/assign_faces.py

Imports raw_assets/art-v3/suspect_n13..n30.png as webp first. Gender and age
come from the name (titles such as «الحاجة», «أم», «عم» and a list of given
names); the faces' own gender and age from raw_assets/art-v3/MANIFEST.json.
Across stories the least-used matching face wins, so the 30 faces spread.
"""

import glob
import json
import os

from PIL import Image

FACES = 'assets/images/stories'
MANIFEST = 'raw_assets/art-v3/MANIFEST.json'

FEMALE_TITLES = ('أم', 'الحاجة', 'الست', 'ست', 'مدام', 'الأستاذة', 'أستاذة',
                 'الدكتورة', 'دكتورة', 'أبلة', 'الأبلة', 'طنط')
FEMALE_NAMES = set('''بسمة حنان داليا دعاء دينا رباب رجاء رحاب رشا ريم زينات
سعدية سلمى سلوى سميحة سنية سوزان شيماء صبرية صفاء عزة فادية فتحية ليلى منال
منى مها مرفت ميرفت نادية ناهد نجلاء ندى نهال نهى نورا هالة هبة هدى هنان وفاء
ويزو بهية سعاد سميرة نعمات نوال عفاف أمينة سارة نور زينب فاطمة عائشة مريم
إيمان أميرة'''.split())
OLD_TITLES = ('الحاج', 'الحاجة', 'عم', 'أم', 'أبو', 'الشيخ', 'المعلم', 'اللواء')
AGES = {'20s': 25, '30s': 35, '40s': 45, '50s': 55, '60s': 65, '70s': 75}


def is_female(name):
    words = name.replace('«', '').replace('»', '').split()
    if words and words[0] in FEMALE_TITLES:
        return True
    return any(w in FEMALE_NAMES for w in words)


def age_of(name):
    words = name.split()
    if words and words[0] in OLD_TITLES:
        return 60
    if words and words[0] in ('الأستاذ', 'الأستاذة', 'دكتور', 'د.', 'مدام'):
        return 45
    return 32


def main():
    for i in range(13, 31):
        src = f'raw_assets/art-v3/suspect_n{i:02d}.png'
        if os.path.exists(src):
            img = Image.open(src).convert('RGBA')
            img.save(f'{FACES}/suspect_n{i:02d}.webp', 'WEBP', quality=88, method=6)

    faces = []
    for e in json.load(open(MANIFEST, encoding='utf-8')):
        n = e['file'][len('suspect_'):-len('.png')]
        path = f'{FACES}/suspect_{n}.webp'
        if os.path.exists(path):
            faces.append((path, e['gender'] == 'f', AGES.get(e['age'], 40)))
    used = {f[0]: 0 for f in faces}

    for path in sorted(glob.glob('assets/stories/*.json')):
        raw = open(path, 'rb').read()
        story = json.loads(raw.decode('utf-8'))
        taken = set()
        for c in story['characters']:
            female = is_female(c['name'])
            age = age_of(c['name'])
            pool = [f for f in faces if f[1] == female and f[0] not in taken]
            if not pool:
                pool = [f for f in faces if f[0] not in taken]
            best = min(pool, key=lambda f: (abs(f[2] - age) // 15, used[f[0]], f[0]))
            c['image'] = best[0]
            taken.add(best[0])
            used[best[0]] += 1
        out = json.dumps(story, ensure_ascii=False, indent=2) + '\n'
        if b'\r\n' in raw:
            out = out.replace('\n', '\r\n')
        open(path, 'wb').write(out.encode('utf-8'))

    print('faces used:', sorted(used.values()))


if __name__ == '__main__':
    main()
