"""Fail if R8 removed a constructor that Android calls by reflection at startup.

Regression guard for the 1.0.0 RC launch crash: R8 full mode stripped
`WorkDatabase_Impl.<init>()`, and `androidx.startup.InitializationProvider`
killed the process before Flutter ran. See android/app/proguard-rules.pro.

Reads R8's own report of what it removed, so it checks the build that was just
made rather than the rules file:

    python tool/check_android_r8.py [build/app/outputs/mapping/release]
"""
import pathlib
import sys

# (class, member) pairs that are only ever reached through reflection.
REQUIRED = [
    ('androidx.work.impl.WorkDatabase_Impl', 'public void <init>()'),
    ('androidx.work.OverwritingInputMerger', 'public void <init>()'),
    ('androidx.work.ArrayCreatingInputMerger', 'public void <init>()'),
]

folder = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'build/app/outputs/mapping/release')
usage = (folder / 'usage.txt').read_text(encoding='utf-8').splitlines()
seeds = set((folder / 'seeds.txt').read_text(encoding='utf-8').splitlines())

removed_classes = set()
removed_members = {}
current = None
for line in usage:
    if not line.startswith(' '):
        name = line.rstrip()
        if name.endswith(':'):
            current = name[:-1]
            removed_members.setdefault(current, set())
        else:
            removed_classes.add(name)
            current = None
    elif current:
        removed_members[current].add(line.strip())

failures = 0
for klass, member in REQUIRED:
    if klass in removed_classes:
        ok, why = False, 'class removed'
    elif member in removed_members.get(klass, ()):
        ok, why = False, f'{member} removed'
    elif klass not in seeds and not any(s.startswith(klass + ':') for s in seeds):
        ok, why = False, 'class not kept by a rule'
    else:
        ok, why = True, 'kept'
    print('PASS' if ok else 'FAIL', klass, why)
    failures += not ok
sys.exit(1 if failures else 0)
