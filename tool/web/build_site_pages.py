"""Builds the static content pages of saidalmafia.com from tool/web/articles/*.txt.

Writes web/articles/<slug>/index.html, web/articles/index.html,
web/contact/index.html, refreshes the shared nav/footer of the hand-written
pages and regenerates web/sitemap.xml. Run from the repo root:

    python tool/web/build_site_pages.py

Article file format (UTF-8):
    slug: role-mafia-guide
    title: ...
    description: ...
    image: mafia            (a file in web/img/, without .webp)
    image_alt: ...
    date: 2026-10-07
    ---
    paragraphs separated by blank lines; "## " starts a section heading,
    "- " lines form a list.
"""
from __future__ import annotations

import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "web"
SRC = Path(__file__).resolve().parent / "articles"
SITE = "https://saidalmafia.com"
TODAY = "2026-10-07"

NAV = [
    ("/", "العب دلوقتي"),
    ("/how-to-play/", "إزاي تلعب"),
    ("/roles/", "الأدوار"),
    ("/articles/", "مقالات"),
    ("/about/", "عن اللعبة"),
    ("/contact/", "تواصل معانا"),
    ("/privacy/", "الخصوصية"),
]


def nav(current: str) -> str:
    links = "\n".join(
        f'    <a href="{h}"{" aria-current=\"page\"" if h == current else ""}>{t}</a>'
        for h, t in NAV
    )
    return f'<nav class="site" aria-label="التنقل في الموقع">\n{links}\n  </nav>'


FOOTER = (
    '<footer class="site">\n'
    '    <p><a href="/">العب</a> · <a href="/how-to-play/">إزاي تلعب</a> · '
    '<a href="/roles/">الأدوار</a> · <a href="/articles/">مقالات</a> · '
    '<a href="/about/">عن اللعبة</a> · <a href="/contact/">تواصل معانا</a> · '
    '<a href="/privacy/">الخصوصية</a> · <a href="/delete-data/">حذف البيانات</a></p>\n'
    "    <p>© 2026 سيد المافيا: Mafia Master</p>\n"
    "  </footer>"
)


def head(title: str, desc: str, path: str, image: str = "/og-image.jpg",
         og_type: str = "website", ld: list | None = None) -> str:
    url = SITE + path
    t, d = html.escape(title), html.escape(desc)
    blocks = "".join(
        f'\n  <script type="application/ld+json">{json.dumps(x, ensure_ascii=False)}</script>'
        for x in (ld or [])
    )
    return f"""<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>{t}</title>
  <meta name="description" content="{d}">
  <link rel="canonical" href="{url}">
  <link rel="alternate" hreflang="ar" href="{url}">
  <meta name="theme-color" content="#0F0F0F">
  <meta property="og:type" content="{og_type}">
  <meta property="og:site_name" content="سيد المافيا">
  <meta property="og:locale" content="ar_EG">
  <meta property="og:url" content="{url}">
  <meta property="og:title" content="{t}">
  <meta property="og:description" content="{d}">
  <meta property="og:image" content="{SITE}{image}">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="icon" type="image/png" href="/favicon.png">
  <link rel="stylesheet" href="/site.css">{blocks}
</head>
<body>
  <a class="skip" href="#main">تخطّى للمحتوى</a>
  {nav(path)}
  <main id="main">
"""


def tail() -> str:
    return f"""  </main>
  {FOOTER}
</body>
</html>
"""


def breadcrumb(items: list[tuple[str, str]]) -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": i + 1, "name": n, "item": SITE + p}
            for i, (n, p) in enumerate(items)
        ],
    }


def render_body(text: str) -> str:
    out, para, lst = [], [], []

    def flush():
        if para:
            out.append("<p>" + html.escape(" ".join(para)) + "</p>")
            para.clear()
        if lst:
            out.append("<ul>" + "".join(f"<li>{html.escape(x)}</li>" for x in lst) + "</ul>")
            lst.clear()

    for line in text.splitlines():
        s = line.strip()
        if not s:
            flush()
        elif s.startswith("## "):
            flush()
            out.append("<h2>" + html.escape(s[3:]) + "</h2>")
        elif s.startswith("- "):
            if para:
                flush()
            lst.append(s[2:])
        else:
            if lst:
                flush()
            para.append(s)
    flush()
    return "\n    ".join(out)


def load_articles() -> list[dict]:
    arts = []
    for f in sorted(SRC.glob("*.txt")):
        meta_raw, body = f.read_text(encoding="utf-8").split("\n---\n", 1)
        meta = dict(
            (k.strip(), v.strip())
            for k, v in (l.split(":", 1) for l in meta_raw.splitlines() if ":" in l)
        )
        meta["body"] = body
        meta["order"] = int(meta.get("order", "99"))
        meta["words"] = len(re.findall(r"\S+", body))
        arts.append(meta)
    return sorted(arts, key=lambda a: a["order"])


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def build_article(a: dict, arts: list[dict]) -> None:
    path = f"/articles/{a['slug']}/"
    img = f"/img/{a['image']}.webp"
    ld = [
        {
            "@context": "https://schema.org",
            "@type": "Article",
            "headline": a["title"],
            "description": a["description"],
            "image": SITE + img,
            "inLanguage": "ar",
            "datePublished": a.get("date", TODAY),
            "dateModified": TODAY,
            "author": {"@type": "Organization", "name": "سيد المافيا"},
            "publisher": {"@type": "Organization", "name": "سيد المافيا",
                          "logo": {"@type": "ImageObject", "url": SITE + "/icons/Icon-512.png"}},
            "mainEntityOfPage": SITE + path,
        },
        breadcrumb([("الرئيسية", "/"), ("مقالات", "/articles/"), (a["title"], path)]),
    ]
    others = [x for x in arts if x["slug"] != a["slug"]][:3]
    more = "".join(
        f'<li><a href="/articles/{x["slug"]}/">{html.escape(x["title"])}</a></li>' for x in others
    )
    minutes = max(3, round(a["words"] / 180))
    page = head(a["title"] + " — سيد المافيا", a["description"], path, img, "article", ld)
    page += f"""    <nav class="crumbs" aria-label="مسار الصفحة"><a href="/">الرئيسية</a> › <a href="/articles/">مقالات</a></nav>
    <article>
    <h1>{html.escape(a['title'])}</h1>
    <p class="meta">اتنشر <time datetime="{a.get('date', TODAY)}">{a.get('date', TODAY)}</time> · قراءة {minutes} دقايق</p>
    <figure><img src="{img}" alt="{html.escape(a['image_alt'])}" width="{a.get('w', '480')}" height="{a.get('h', '720')}" fetchpriority="high" decoding="async"></figure>
    {render_body(a['body'])}
    </article>
    <p><a class="cta" href="/">جرّب اللعبة دلوقتي</a></p>
    <section class="more"><h2>اقرا كمان</h2><ul>{more}</ul></section>
"""
    write(WEB / "articles" / a["slug"] / "index.html", page + tail())


def build_index(arts: list[dict]) -> None:
    path = "/articles/"
    cards = "\n".join(
        f"""    <li class="card"><a href="/articles/{a['slug']}/">
      <img src="/img/{a['image']}.webp" alt="" width="{a.get('w', '480')}" height="{a.get('h', '720')}" loading="lazy" decoding="async">
      <span><strong>{html.escape(a['title'])}</strong><br>{html.escape(a['description'])}</span></a></li>"""
        for a in arts
    )
    ld = [breadcrumb([("الرئيسية", "/"), ("مقالات", path)])]
    page = head("مقالات عن لعبة المافيا — سيد المافيا",
                "شرح الأدوار، خطط اللعب، وإزاي تدير سهرة مافيا ناجحة مع صحابك — مقالات بالعامية المصرية من فريق سيد المافيا.",
                path, ld=ld)
    page += f"""    <h1>مقالات سيد المافيا</h1>
    <p>هنا بنكتب اللي اتعلمناه من القعدات: إزاي تلعب كل دور صح، إزاي تقرا الترابيزة، وإزاي تخلّي السهرة تفضل حلوة لآخرها.</p>
    <ul class="cards">
{cards}
    </ul>
"""
    write(WEB / "articles" / "index.html", page + tail())


def build_contact() -> None:
    path = "/contact/"
    ld = [
        {"@context": "https://schema.org", "@type": "ContactPage", "name": "تواصل مع سيد المافيا",
         "url": SITE + path},
        breadcrumb([("الرئيسية", "/"), ("تواصل معانا", path)]),
    ]
    page = head("تواصل معانا — سيد المافيا",
                "عندك سؤال أو مشكلة أو اقتراح عن لعبة سيد المافيا؟ ابعتلنا وهنرد عليك.",
                path, ld=ld)
    page += """    <h1>تواصل معانا</h1>
    <p>سيد المافيا لعبة بيعملها فريق صغير في مصر، وكل رسالة بتوصلنا بنقراها بنفسنا. لو لقيت مشكلة في اللعبة، أو عندك اقتراح لدور جديد، أو عايز تسأل عن بياناتك — ابعتلنا.</p>
    <h2>الإيميل</h2>
    <p><a href="mailto:eyadsyam124@gmail.com">eyadsyam124@gmail.com</a> — بنرد عادة خلال يومين شغل.</p>
    <h2>ابعت رسالة</h2>
    <form class="contact" action="mailto:eyadsyam124@gmail.com" method="post" enctype="text/plain">
      <label for="c-name">اسمك</label>
      <input id="c-name" name="الاسم" autocomplete="name" required>
      <label for="c-topic">الموضوع</label>
      <select id="c-topic" name="الموضوع">
        <option>مشكلة في اللعبة</option>
        <option>اقتراح</option>
        <option>سؤال عن الحساب أو البيانات</option>
        <option>حاجة تانية</option>
      </select>
      <label for="c-msg">رسالتك</label>
      <textarea id="c-msg" name="الرسالة" rows="6" required></textarea>
      <button type="submit" class="cta">ابعت</button>
      <p class="hint">الزرار هيفتح تطبيق الإيميل عندك والرسالة جاهزة.</p>
    </form>
    <h2>قبل ما تكتب</h2>
    <ul>
      <li>لو عايز تمسح حسابك وبياناتك: <a href="/delete-data/">صفحة حذف البيانات</a>.</li>
      <li>لو عندك سؤال عن القواعد: <a href="/how-to-play/">إزاي تلعب</a> و<a href="/roles/">الأدوار</a>.</li>
      <li>لو حد ضايقك في غرفة أونلاين: استخدم زرار البلاغ جوّه الغرفة، وابعتلنا كود الغرفة.</li>
    </ul>
"""
    write(WEB / "contact" / "index.html", page + tail())


NAV_RE = re.compile(r"<nav class=\"site\".*?</nav>", re.S)
FOOT_RE = re.compile(r"<footer[^>]*>.*?</footer>", re.S)


def refresh_handwritten() -> None:
    for name in ["about", "how-to-play", "roles", "privacy", "delete-data"]:
        f = WEB / name / "index.html"
        s = f.read_text(encoding="utf-8")
        if NAV_RE.search(s):
            s = NAV_RE.sub(lambda _: nav(f"/{name}/"), s, count=1)
        else:
            s = s.replace("<body>", "<body>\n  " + nav(f"/{name}/"), 1)
        if FOOT_RE.search(s):
            s = FOOT_RE.sub(lambda _: FOOTER, s, count=1)
        else:
            s = s.replace("</body>", "  " + FOOTER + "\n</body>", 1)
        if '/site.css' not in s:
            s = s.replace("</head>", '  <link rel="stylesheet" href="/site.css">\n</head>', 1)
        write(f, s)


def sitemap(arts: list[dict]) -> None:
    pages = ["/", "/how-to-play/", "/roles/", "/articles/", "/about/", "/contact/",
             "/privacy/", "/delete-data/", "/beta/"]
    pages += [f"/articles/{a['slug']}/" for a in arts]
    urls = "\n".join(f"  <url><loc>{SITE}{p}</loc><lastmod>{TODAY}</lastmod></url>" for p in pages)
    write(WEB / "sitemap.xml",
          '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + urls + "\n</urlset>\n")


def main() -> None:
    arts = load_articles()
    for a in arts:
        build_article(a, arts)
        print(f"{a['slug']}: {a['words']} words")
    build_index(arts)
    build_contact()
    refresh_handwritten()
    sitemap(arts)


if __name__ == "__main__":
    main()
