"""Build a connected six-frame Google Play screenshot story.

The key art is generated once, then cropped as one panorama so every frame
continues the same scene. The phones contain real app captures only.
"""
from pathlib import Path
import math

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import arabic_reshaper
from bidi.algorithm import get_display


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "store" / "screenshots" / "play-ar"
OUT.mkdir(parents=True, exist_ok=True)

ART = ROOT / "raw_assets" / "store" / "connected-play-panorama.png"
W, H, COUNT = 1080, 1920, 6
IVORY = (239, 233, 220)
GOLD = (188, 159, 94)
MUTED = (184, 177, 165)
INK = (10, 10, 11)


def ar(value: str) -> str:
    return get_display(arabic_reshaper.reshape(value))


def cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def fit_screen(path: Path, box: tuple[int, int]) -> Image.Image:
    image = Image.open(path).convert("RGB")
    scale = min(box[0] / image.width, box[1] / image.height)
    return image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )


def rounded_phone(screen: Image.Image, size: tuple[int, int]) -> Image.Image:
    phone = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((20, 28, size[0] - 20, size[1] - 12), 70, fill=(0, 0, 0, 175))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    phone.alpha_composite(shadow)

    d = ImageDraw.Draw(phone)
    d.rounded_rectangle((14, 8, size[0] - 14, size[1] - 24), 66, fill=(20, 19, 18), outline=GOLD, width=4)
    inner = (34, 30, size[0] - 34, size[1] - 48)
    fitted = fit_screen_from_image(screen, (inner[2] - inner[0], inner[3] - inner[1]))
    mask = Image.new("L", fitted.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, fitted.width, fitted.height), 44, fill=255)
    x = inner[0] + (inner[2] - inner[0] - fitted.width) // 2
    y = inner[1] + (inner[3] - inner[1] - fitted.height) // 2
    phone.paste(fitted, (x, y), mask)
    return phone


def fit_screen_from_image(image: Image.Image, box: tuple[int, int]) -> Image.Image:
    scale = min(box[0] / image.width, box[1] / image.height)
    return image.resize(
        (round(image.width * scale), round(image.height * scale)),
        Image.Resampling.LANCZOS,
    )


def centered(draw: ImageDraw.ImageDraw, y: int, value: str, font: ImageFont.FreeTypeFont, fill):
    shaped = ar(value)
    bounds = draw.textbbox((0, 0), shaped, font=font)
    draw.text(((W - (bounds[2] - bounds[0])) / 2, y), shaped, font=font, fill=fill)


captures = [
    ROOT / "build" / "phase79-online-home.png",
    ROOT / "build" / "phase79-mode-online.png",
    ROOT / "build" / "phase79-online-entry.png",
    ROOT / "store" / "screenshots" / "07-reveal.png",
    ROOT / "store" / "screenshots" / "05-settings.png",
    ROOT / "store" / "screenshots" / "03-players.png",
]

copy_targets = [
    ROOT / "store" / "screenshots" / "10-home-current.png",
    ROOT / "store" / "screenshots" / "11-mode-current.png",
]
for source, target in zip(captures[:2], copy_targets):
    Image.open(source).save(target, optimize=True)

titles = [
    "المافيا بقت أونلاين",
    "اختار اللعب أونلاين",
    "افتح روم واجمع شلتك",
    "دورك سري لآخر لحظة",
    "إنت تلعب.. والتطبيق يحكي",
    "والقعدة المحلية لسه موجودة",
]
subtitles = [
    "صوت حي، اتهامات، وخداع بين لاعبين حقيقيين",
    "من أي مكان، وكل لاعب شايف شاشته هو بس",
    "كود دعوة، دخول سريع، ورومات عامة",
    "كشف خاص من غير ما أي لاعب يشوف دور غيره",
    "مراحل منظمة، توقيت واضح، ونتيجة عادلة",
    "تجربة مافيا كاملة حتى لو الإنترنت مش متاح",
]

panorama = cover(Image.open(ART).convert("RGB"), (W * COUNT, H))
title_font = ImageFont.truetype(str(ROOT / "assets/fonts/IBMPlexSansArabic-SemiBold.ttf"), 70)
subtitle_font = ImageFont.truetype(str(ROOT / "assets/fonts/IBMPlexSansArabic-Regular.ttf"), 34)
number_font = ImageFont.truetype(str(ROOT / "assets/fonts/IBMPlexMono-Medium.ttf"), 24)

for index in range(COUNT):
    frame = panorama.crop((index * W, 0, (index + 1) * W, H)).convert("RGBA")
    veil = Image.new("RGBA", frame.size, (8, 8, 9, 88))
    frame.alpha_composite(veil)
    d = ImageDraw.Draw(frame)

    # The horizontal rule and its dot continue at the same height in every crop.
    d.line((0, 360, W, 360), fill=(*GOLD, 170), width=3)
    dot_x = 104 + ((index * 173) % 872)
    d.ellipse((dot_x - 9, 351, dot_x + 9, 369), fill=IVORY)
    d.text((54, 58), f"0{index + 1}", font=number_font, fill=(*MUTED, 210))
    centered(d, 118, titles[index], title_font, IVORY)
    centered(d, 232, subtitles[index], subtitle_font, MUTED)

    screen = Image.open(captures[index]).convert("RGB")
    phone = rounded_phone(screen, (660, 1460))
    angle = (-4, 3, -2, 3, -3, 4)[index]
    phone = phone.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    x = (W - phone.width) // 2 + (-42, 40, -28, 32, -24, 38)[index]
    y = 404 + (26, 14, 22, 10, 20, 18)[index]
    frame.alpha_composite(phone, (x, y))

    # A restrained bottom fade keeps the frame readable in Play's cropped views.
    fade = Image.new("RGBA", (W, 330), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fade)
    for row in range(330):
        alpha = round(150 * (row / 329) ** 1.7)
        fd.line((0, row, W, row), fill=(*INK, alpha))
    frame.alpha_composite(fade, (0, H - 330))
    frame.convert("RGB").save(OUT / f"{index + 1:02d}.png", optimize=True)

print(f"Generated {COUNT} connected Play screenshots in {OUT}")
