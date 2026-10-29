"""Make contact sheets from build/sweep_1_5/{width}x{height}/*.png.

Run after the Dart screenshot harness: python tool/sweep_1_5_contacts.py

One size folder becomes several pages (contact_<size>_<page>.png), small
enough to read at a glance: 12 per page for the portrait sizes, 16 for the
landscape one. Each cell is labelled with the case name.
"""
from pathlib import Path

from PIL import Image, ImageDraw

root = Path('build/sweep_1_5')
for old in root.glob('contact_*.png'):
    old.unlink()

for folder in sorted(p for p in root.iterdir() if p.is_dir()):
    paths = sorted(folder.glob('*.png'))
    if not paths:
        continue
    with Image.open(paths[0]) as first:
        landscape = first.width > first.height
    if landscape:
        cell_w, cell_h, columns, rows = 330, 214, 4, 4
    else:
        cell_w, cell_h, columns, rows = 230, 420, 6, 2
    per_page = columns * rows
    for page, start in enumerate(range(0, len(paths), per_page), start=1):
        chunk = paths[start:start + per_page]
        used_rows = (len(chunk) + columns - 1) // columns
        sheet = Image.new('RGB', (cell_w * columns, cell_h * used_rows), '#202020')
        draw = ImageDraw.Draw(sheet)
        for index, path in enumerate(chunk):
            col, row = index % columns, index // columns
            with Image.open(path) as image:
                image.thumbnail((cell_w - 10, cell_h - 24))
                x = col * cell_w + (cell_w - image.width) // 2
                y = row * cell_h + 20
                sheet.paste(image.convert('RGB'), (x, y))
            draw.text((col * cell_w + 6, row * cell_h + 4), path.stem, fill='white')
        out = root / f'contact_{folder.name}_{page}.png'
        sheet.save(out)
        print(f'{out.name}: {len(chunk)} images')
