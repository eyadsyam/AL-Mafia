"""Check the Google Play listing drafts against Play's length limits.

    python tool/check_store_listing.py

Title <= 30, short description <= 80, full description <= 4000 characters,
counted as Play counts them (Unicode characters, not bytes). Also refuses
claims this release cannot back: quick match, cash prizes or paid spins.
Ads and optional Play purchases are real from 1.0.1 and are declared.
"""
import pathlib
import re
import sys

LIMITS = {'title': 30, 'short': 80, 'full': 4000}
HEADINGS = {
    'store/listing-ar.md': {'title': 'اسم التطبيق', 'short': 'الوصف المختصر', 'full': 'الوصف الكامل'},
    'store/listing-en.md': {'title': 'App name', 'short': 'Short description', 'full': 'Full description'},
}
FORBIDDEN = [r'بحث سريع', r'quick match', r'جوايز نقدية', r'cash prize', r'paid spin',
             r'win real money', r'guaranteed']

failures = 0
for path, heads in HEADINGS.items():
    text = pathlib.Path(path).read_text(encoding='utf-8')
    sections = dict(re.findall(r'^## (.+?)\n(.*?)(?=^## |\Z)', text, flags=re.S | re.M))
    for field, heading in heads.items():
        value = sections[heading].strip()
        ok = 0 < len(value) <= LIMITS[field]
        print('PASS' if ok else 'FAIL', path, field, f'{len(value)}/{LIMITS[field]}')
        failures += not ok
    body = '\n'.join(sections[h] for h in heads.values())
    for pattern in FORBIDDEN:
        if re.search(pattern, body, flags=re.I):
            print('FAIL', path, 'claims', pattern)
            failures += 1
sys.exit(1 if failures else 0)
