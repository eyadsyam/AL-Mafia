"""The two images the Play Console asks for, from the app's own art.

    python tool/generate_store_assets.py

Outputs `store/icon-512.png` and `store/feature-graphic-1024x500.png`.

## Why this is a script

Same reason `generate_icons.py` is: the store images have to stay in step with
the app's palette and its source painting, and a pair of images somebody made
once in an editor drift the moment either changes. This regenerates both from
`raw_assets/icon/` and `assets/images/` in a second.

## The Arabic

Pillow has no `raqm` in this environment, so it cannot shape or reorder Arabic
by itself -- given the string raw it prints disconnected letters in the wrong
order. `arabic_reshaper` joins the glyphs and `python-bidi` reorders them; the
`ar()` helper below is both, and every Arabic string here goes through it.

    python -m pip install arabic-reshaper python-bidi

Play crops the feature graphic hard on small surfaces and may overlay the app
name and an Install button on it, so the subject and the title stay inside the
middle band and the outer edges carry atmosphere and nothing that matters.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

try:
    import arabic_reshaper
    from bidi.algorithm import get_display
except ImportError:
    sys.exit('pip install arabic-reshaper python-bidi')

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.makedirs('store', exist_ok=True)

SOURCE = 'raw_assets/icon/Porcelain_mask_in_shadow_2K_202608030657.jpeg'

# -- 512x512 store icon ------------------------------------------------------
# Full-bleed, no transparency, no rounded corner baked in: the store applies
# its own mask, and an icon that pre-rounds itself gets rounded twice and comes
# out with a grey fringe on the corners.
Image.open(SOURCE).convert('RGB').resize((512, 512), Image.LANCZOS)      .save('store/icon-512.png', format='PNG', optimize=True)
print('icon-512.png', os.path.getsize('store/icon-512.png') // 1024, 'KB')

W, H = 1024, 500
GROUND = (15, 15, 15)
BONE = (233, 228, 217)
GOLD = (194, 189, 178)
MUTED = (144, 140, 131)

def ar(text):
    """Arabic, shaped and reordered -- PIL has no raqm here, so both by hand."""
    return get_display(arabic_reshaper.reshape(text))

# ── ground: the night backdrop, blurred and pushed down ──────────────────────
bg = Image.open('assets/images/bg_night.webp').convert('RGB')
scale = max(W / bg.width, H / bg.height)
bg = bg.resize((round(bg.width * scale), round(bg.height * scale)), Image.LANCZOS)
left = (bg.width - W) // 2
top = (bg.height - H) // 3
canvas = bg.crop((left, top, left + W, top + H)).filter(ImageFilter.GaussianBlur(7))
canvas = Image.blend(Image.new('RGB', (W, H), GROUND), canvas, 0.42)

# ── the mask, on the left third (LTR left = the "start" of an RTL read too,
#    because Play's own overlay lands on the opposite side) ───────────────────
mask = Image.open(SOURCE)
mask = mask.convert('RGB').resize((470, 470), Image.LANCZOS)
# Feather the square edge into the ground rather than pasting a visible box.
alpha = Image.new('L', (470, 470), 0)
ImageDraw.Draw(alpha).ellipse((10, 10, 460, 460), fill=255)
alpha = alpha.filter(ImageFilter.GaussianBlur(38))
canvas.paste(mask, (56, 18), alpha)

# ── a gradient scrim under the type, so the words never fight the art ────────
scrim = Image.new('L', (W, H), 0)
sd = ImageDraw.Draw(scrim)
for x in range(430, W):
    sd.line([(x, 0), (x, H)], fill=int(215 * min(1.0, (x - 430) / 210)))
canvas.paste(Image.new('RGB', (W, H), GROUND), (0, 0), scrim)

# vignette
vig = Image.new('L', (W, H), 0)
ImageDraw.Draw(vig).ellipse((-190, -230, W + 190, H + 230), fill=255)
vig = vig.filter(ImageFilter.GaussianBlur(120))
canvas.paste(Image.new('RGB', (W, H), (0, 0, 0)),
             (0, 0), Image.eval(vig, lambda v: 190 - int(v * 0.74)))

d = ImageDraw.Draw(canvas)
title_f = ImageFont.truetype('assets/fonts/IBMPlexSansArabic-SemiBold.ttf', 96)
line_f = ImageFont.truetype('assets/fonts/IBMPlexSansArabic-Regular.ttf', 38)
small_f = ImageFont.truetype('assets/fonts/IBMPlexSansArabic-Regular.ttf', 27)

def right_text(x_right, y, text, font, fill):
    t = ar(text)
    w = d.textlength(t, font=font)
    d.text((x_right - w, y), t, font=font, fill=fill)

RIGHT = W - 62
right_text(RIGHT, 108, 'سيد المافيا', title_f, BONE)
d.line([(RIGHT - 200, 236), (RIGHT, 236)], fill=GOLD, width=2)
right_text(RIGHT, 268, 'التطبيق هو الراوي.', line_f, GOLD)
right_text(RIGHT, 322, 'وإنت أخيراً بتلعب.', line_f, GOLD)
right_text(RIGHT, 404, 'على تليفون واحد، أو أونلاين مع أصحابك', small_f, MUTED)

canvas.save('store/feature-graphic-1024x500.png', format='PNG', optimize=True)
print('feature-graphic-1024x500.png',
      os.path.getsize('store/feature-graphic-1024x500.png') // 1024, 'KB')
