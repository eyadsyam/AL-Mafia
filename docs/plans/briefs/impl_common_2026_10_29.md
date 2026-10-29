# Update 1.5 — shared rules for every implementer (read first)

Project: Flutter app «سيد المافيا: Mafia Master» (Egyptian Arabic party game, offline pass-and-play + online rooms on Supabase).
The plan is `docs/plans/UPDATE-1.5-PLAN.md`. The approved screens are in `design-system/screens/update-1-5-mockups.html` (sections `#u1`…`#u7`). The owner approved the mockups as drawn: match their copy and layout exactly. Do not invent extra copy, tips or advice lines.

## Skills to load before UI work
For any widget/screen work load these skills with the Skill tool and apply them together: `frontend-design`, `ui-ux-pro-max`. For Flutter specifics also use `flutter-fix-layout-issues`, `flutter-build-responsive-layout`, `flutter-add-widget-test`, `flutter-setup-localization` as they apply. The result must look professional and consistent with the existing Home screen look (tokens below), not a new style.

## Non-negotiables (from CLAUDE.md — breaking any of these fails the review)
1. Doc 05 zero leakage (`docs/specs/05-zero-leakage-spec.md`) wins. Nothing on screen may differ by a player's role: same length text, same timing, same geometry, same sounds. If a change could let a player infer another's role, stop and report.
2. `lib/engine/**` is pure Dart: no Flutter imports, no `DateTime.now()`, no unseeded `Random()`. Do not change match rules or timings.
3. No hardcoded colours, sizes, durations: use `lib/ui/theme/design_tokens.dart` (add tokens there if truly needed).
4. Arabic text: line-height 1.6, letter-spacing 0, text scale is locked at 1.0 globally (app.dart) — do not change it.
5. No literal user-visible strings in widgets: add keys to `lib/app/l10n/app_ar.arb` AND `lib/app/l10n/app_en.arb`, then run `flutter gen-l10n` (or the project's existing generation; check `l10n.yaml`). Arabic is Egyptian, short, plain.
6. One engine, two transports. No `if (isOnline)` in widgets except voice controls and the connection banner.
7. Do not touch rewards/economy amounts. Do not reduce ads. Never change the app name.
8. Nothing may overlap anything: verify at 360×640, 390×844 and 640×360 with 20-char Arabic names.

## Gates (run them, read the output, report honestly)
- `flutter analyze --no-pub 2>&1 | tail -30` → no new issues.
- Targeted tests you add/touch: `flutter test --no-pub <paths> 2>&1 | tail -40`.
- Add widget tests for new behaviour (including a no-overflow check at 360×640 and 640×360).
- Low RAM machine: never run the full suite with high concurrency; use `--concurrency=2` if you need more than a few files.

## Boundaries
- No builds (`flutter build`), no deploys, no Play/AdMob actions, no hosted Supabase changes. Migrations are files only.
- Do not print secrets or `--dart-define` values.
- Commit your work on your own branch when gates pass, with a clear message ending `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. Do not push.
- Final report (English is fine): files changed, what each does, gates run with real output tail, anything left open or any Doc 05 doubt.
