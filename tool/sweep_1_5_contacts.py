"""Make contact sheets from build/sweep_1_5/{width}x{height}/*.png.

Run after the Dart screenshot harness: python tool/sweep_1_5_contacts.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

root = Path('build/sweep_1_5')
for folder in sorted(root.iterdir()):
    if not folder.is_dir():
        continue
    paths = sorted(folder.glob('*.png'))
    if not paths:
        continue
    cell_w, cell_h, columns = 240, 280, 4
    rows = (len(paths) + columns - 1) // columns
    sheet = Image.new('RGB', (cell_w * columns, cell_h * rows), '#202020')
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(paths):
        with Image.open(path) as image:
            image.thumbnail((cell_w - 12, cell_h - 34))
            x = index % columns * cell_w + (cell_w - image.width) // 2
            y = index // columns * cell_h + 26
            sheet.paste(image.convert('RGB'), (x, y))
        draw.text((index % columns * cell_w + 6, index // columns * cell_h + 6),
                  path.stem, fill='white')
    sheet.save(root / f'contact_{folder.name}.png')
    print(f'{folder.name}: {len(paths)} images')
