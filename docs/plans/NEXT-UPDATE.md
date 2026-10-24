# Next update (after 1.4.0 build 17)

Decided 2026-10-24: 1.4.0 (17) ships as built on 2026-10-23 at 20:21. Everything below waits for the next update.

## App fixes found by the new tests

1. **Investigation result outlives the night.** After a reconnect or resync that lands on the morning, the
   detective's private result (`InvestigateResult`) stays in `MatchController`
   (`lib/ui/screens/match_controller.dart` ~224). It is the player's own result and nobody else sees it, but
   it must be cleared when its night ends, on every path. Test: `phase_resync_privacy_test.dart` (X10).
   Fixed (not released): `match_controller.dart` `_onSnapshot` now clears the private secrets when a server snapshot
   changes phase or day (online only; offline the pass still clears them, so the outgoing actor keeps their view).
2. **Night screen overflows in landscape.** `lib/ui/widgets/hold_pad.dart` ~186 and
   `lib/ui/screens/online/council/voice_band.dart` ~57. Test: `rotation_no_double_submit_test.dart` (X18).
   Fixed (not released): `hold_pad.dart` and `voice_band.dart` switch to a side-by-side row when the box is
   landscape and shorter than the portrait stack (constraints-based; portrait unchanged).
3. **Controller used after dispose.** An async callback in `lib/ui/screens/online/online_table_flow.dart` ~374
   touches the controller after the screen is closed; needs a mounted/disposed guard.
   Fixed (not released): `online_table_flow.dart` and `match_flow.dart` check `privacy.mounted` in the post-frame
   callback before resetting the privacy flag.

### Changed files

- lib/ui/screens/match_controller.dart
- lib/ui/widgets/hold_pad.dart
- lib/ui/screens/online/council/voice_band.dart
- lib/ui/screens/online/online_table_flow.dart
- lib/ui/screens/match_flow.dart
- test/online/phase_resync_privacy_test.dart (new)
- test/widget/rotation_no_double_submit_test.dart (new)

Codex had started on all three when it was stopped. Its unfinished diff is kept in
`docs/plans/next-update/codex-wip-fixes.patch` (not applied, not reviewed). The two tests that found them are in
`docs/plans/next-update/`; move them back to `test/online/` and `test/widget/` with the fixes.
Brief: `docs/plans/briefs/fix_resync_rotation_bugs_2026_10_24.txt`.

## Tests to finish

- `supabase/tests/silence_floor_match.py` D6: quiet night turned off so the save is told (fixed, not yet run live).
- `supabase/tests/hosted_night_tools_match.py` T25: night 1 protects a different seat (fixed, not yet run live).

## Store

- Pending review on Play: the 8 new screenshots and the new feature graphic (saved in the console, not yet sent
  for review when work stopped).
- Trailer: `raw_assets/play-1.4/trailer/mafia_master_trailer_25s_1080p.mp4`; Play takes only a YouTube link.
- Play API account `play-verify@mafia-master-billing.iam.gserviceaccount.com` can't release or edit the
  listing until the owner grants «إصدار التطبيقات إلى مسارات الاختبار» and «إدارة الظهور في المتجر».

## Later (owner's order)

In-game reward rules, then screen polish. Story content stays as it is.
