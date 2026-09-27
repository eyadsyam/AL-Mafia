"""Slices one generated art sheet into the exact 1.0.1 asset files.

Image-generation credits are spent per image, so every family of small icons
is generated as ONE sheet (a uniform grid, one object per cell) and cut here.
See docs/ART-REQUEST-CODEX-1.0.1.md, section "توفير الكريدت".

    python tool/slice_art_sheet.py <SHEET_ID> <path/to/sheet.png>
    python tool/slice_art_sheet.py --list

Per cell: key out the background (true alpha, or flat #00FF00 chroma with
despill), trim to the object, fit it inside the target box with a small
margin, save the full-size cell as raw_assets/update101b/<name>.png and the
target-size WebP at the asset path, stepping quality down until it is under
the size cap. Cells named None are left empty on purpose.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, 'raw_assets', 'update101b')
ICON_CAP = 40 * 1024
COVER_CAP = 120 * 1024

# id: (cols, rows, [(asset path, (w, h), cap) or None, ...] row by row)
C = 'assets/images/council/'
S = 'assets/images/store_v3/'
E = 'assets/images/economy_v2/'
SHEETS = {
    'A_ranks': (5, 2, [(f'{C}rank_tier_{i:02d}.webp', (128, 128), ICON_CAP)
                       for i in range(1, 11)]),
    'B_contracts': (3, 3, [(f'{C}contract_{n}.webp', (96, 96), ICON_CAP) for n in (
        'finish', 'town', 'mafia', 'win', 'host', 'reunion', 'weekly',
        'bonus_all3', 'claimed_check')]),
    'C_council_small': (3, 3, [
        (f'{C}leaderboard_podium_1.webp', (128, 128), ICON_CAP),
        (f'{C}leaderboard_podium_2.webp', (128, 128), ICON_CAP),
        (f'{C}leaderboard_podium_3.webp', (128, 128), ICON_CAP),
        (f'{C}invite_reward_badge.webp', (96, 96), ICON_CAP),
        (f'{C}council_hub_tab.webp', (96, 96), ICON_CAP),
        ('assets/images/profile/badge_founder.webp', (128, 128), ICON_CAP),
        ('assets/images/profile/stat_matches.webp', (64, 64), ICON_CAP),
        ('assets/images/profile/stat_wins.webp', (64, 64), ICON_CAP),
        ('assets/images/profile/stat_streak.webp', (64, 64), ICON_CAP),
    ]),
    'D_store_covers': (3, 2, [
        (f'{S}starter_bundle_cover.webp', (768, 768), COVER_CAP),
        (f'{S}quiet_pass_cover.webp', (768, 768), COVER_CAP),
        (f'{S}coins_pack_small.webp', (768, 768), COVER_CAP),
        (f'{S}coins_pack_medium.webp', (768, 768), COVER_CAP),
        (f'{S}coins_pack_large.webp', (768, 768), COVER_CAP),
        None,
    ]),
    'E_store_small': (3, 2, [
        (f'{C}invite_illustration.webp', (256, 256), ICON_CAP),
        (f'{S}web_pay_transfer.webp', (256, 256), ICON_CAP),
        (f'{S}web_pay_pending.webp', (128, 128), ICON_CAP),
        (f'{S}web_pay_approved.webp', (128, 128), ICON_CAP),
        ('assets/images/ads/ad_free_seal.webp', (128, 128), ICON_CAP),
        (f'{E}double_coins_badge.webp', (128, 128), ICON_CAP),
    ]),
    'F_daily': (3, 3, [
        (f'{E}daily_coffer_open.webp', (384, 384), ICON_CAP),
        (f'{E}wheel_pointer.webp', (128, 160), ICON_CAP),
        (f'{E}wheel_hub.webp', (192, 192), ICON_CAP),
        (f'{E}streak_day_empty.webp', (96, 96), ICON_CAP),
        (f'{E}streak_day_done.webp', (96, 96), ICON_CAP),
        (f'{E}streak_day7.webp', (96, 96), ICON_CAP),
        (f'{E}ad_reward_film.webp', (96, 96), ICON_CAP),
        (f'{E}extra_spin_token.webp', (96, 96), ICON_CAP),
        None,
    ]),
    'G_awards': (4, 2, [(f'assets/images/awards/award_{n}.webp', (128, 128), ICON_CAP)
                        for n in ('mvp', 'sharp_eye', 'survivor', 'silver_tongue',
                                  'lifesaver', 'perfect_crime', 'first_blood')] + [None]),
    'H_reactions': (4, 2, [(f'assets/images/reactions/react_{n}.webp', (96, 96), ICON_CAP)
                           for n in ('laugh', 'shock', 'suspicious', 'applause',
                                     'rose', 'skull', 'coffee', 'crown')]),
}


def key_out(cell):
    """True alpha stays; a flat #00FF00 background becomes transparent."""
    cell = cell.convert('RGBA')
    if cell.getextrema()[3][0] < 250:  # already has real transparency
        return cell
    px = cell.load()
    w, h = cell.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            green = g - max(r, b)
            if green > 90:
                px[x, y] = (r, g, b, 0)
            elif green > 25:  # soft edge: fade and remove the green spill
                alpha = int(255 * (90 - green) / 65)
                px[x, y] = (r, max(r, b), b, min(a, alpha))
    return cell


def fit(obj, size):
    w, h = size
    box = (int(w * 0.92), int(h * 0.92))
    obj = obj.copy()
    obj.thumbnail(box, Image.LANCZOS)
    out = Image.new('RGBA', size, (0, 0, 0, 0))
    out.paste(obj, ((w - obj.width) // 2, (h - obj.height) // 2), obj)
    return out


def save_capped(img, path, cap):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for q in (92, 88, 84, 80, 76, 72, 68, 64, 60):
        img.save(path, 'WEBP', quality=q, method=6)
        if os.path.getsize(path) <= cap:
            return q
    return q


def main():
    if len(sys.argv) == 2 and sys.argv[1] == '--list':
        for sid, (cols, rows, cells) in SHEETS.items():
            names = [c[0].split('/')[-1] if c else '(empty)' for c in cells]
            print(f'{sid}: {cols}x{rows} -> {", ".join(names)}')
        return
    if len(sys.argv) != 3 or sys.argv[1] not in SHEETS:
        sys.exit(__doc__)
    cols, rows, cells = SHEETS[sys.argv[1]]
    sheet = Image.open(sys.argv[2])
    cw, ch = sheet.width / cols, sheet.height / rows
    os.makedirs(RAW, exist_ok=True)
    for i, spec in enumerate(cells):
        if spec is None:
            continue
        path, size, cap = spec
        x, y = i % cols, i // cols
        cell = sheet.crop((round(x * cw), round(y * ch),
                           round((x + 1) * cw), round((y + 1) * ch)))
        cell = key_out(cell)
        bbox = cell.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
        if not bbox:
            print(f'EMPTY CELL {i} for {path} — regenerate the sheet')
            continue
        obj = cell.crop(bbox)
        name = os.path.splitext(os.path.basename(path))[0]
        obj.save(os.path.join(RAW, name + '.png'))
        if min(obj.width, obj.height) < 0.8 * min(size):
            print(f'WARN {name}: object only {obj.size} for target {size}; '
                  'a bigger sheet will look sharper')
        q = save_capped(fit(obj, size), os.path.join(ROOT, path), cap)
        print(f'{path}  {size[0]}x{size[1]}  q{q}  {os.path.getsize(os.path.join(ROOT, path))} B')


if __name__ == '__main__':
    main()
