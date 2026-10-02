# Phase 99 — public journey design review

Scope: Home, mode choice, onboarding, profile, online entry, lobby. The store
(phase 98) and settings kit (phase 97) set the visual language: charcoal
ground, restrained gold, raised panels with a hairline border, the gold
segmented track, labelled 48 dp controls. No palette change, no new mechanics,
no server change.

## How the audit was done

`test/widget/journey_screenshots.dart` (new, not a test — like the store and
council capture harnesses) renders every journey screen with real fonts and
bundled art in Arabic and English, at 360/390 dp and a 1280×800 desktop window.
The phase-98 state is kept in `build/phase99/before/`; the after state in
`build/phase99/`. These are widget renders, not device screenshots.

## What the captures showed, in priority order

1. **Profile (from Home) was a dead end and could show an empty name.**
   No back control (on desktop/web the only way out was to save), the
   button said «كمل»/Continue although this is an edit, and the name field
   read the profile once in `initState` — if the provider had not resolved
   yet, a returning player saw an empty field and 0/20 and could overwrite
   their saved name. Fix: optional back action (Home, and the online door
   when editing from there), «حفظ»/Save when a profile exists, the saved
   profile fills the form when it arrives (never over what was typed), and
   the same identity art as onboarding.
2. **The required gender choice was two unlabeled glyphs.** Onboarding step 2
   and Profile both disable Continue until a gender is chosen, but the choice
   was ♂/♀ icons under the field with no label — nothing on screen said why
   the button was dead. Fix: one shared `ProfileIdentityFields` (avatar, name,
   labelled ولد/بنت segmented track from the settings kit, with a line saying
   why we ask: Arabic addresses players by gender). The compact
   `GenderPicker` stays where it was designed for — the offline add-players
   row, where vertical space is the constraint. *Challenge to the earlier
   "task 8" choice:* that rationale (save a row) is right for a list of ten
   names, wrong for a one-time identity page whose only job is this answer.
3. **Online door: a stray letter and unequal actions.** The player's name was
   printed alone under the title (with a one-letter name it read as a
   rendering glitch: «A»), separately from the avatar button that edits it.
   Create/Join were a `Wrap` of two buttons of different widths. Fix: one
   identity chip («هتلعب باسم A», avatar, edit — a single 48 dp target), and
   Create (filled) / Join (outlined) as an equal-width pair. The empty list
   was a bare sentence; it is now a quiet panel that says what to do next
   (create and share a code, or refresh). No quick-match, offline or
   duplicate "new public room" control added; back still goes to the mode
   chooser.
4. **Room-tile chevron pointed the wrong way in Arabic.** The tile chose
   `chevron_left` for RTL, but that glyph already mirrors itself
   (`matchTextDirection`), so Arabic showed «›» — backwards. Fixed to the
   self-mirroring forward chevron.
5. **Lobby invite was two bare glyphs.** For a host in an empty room,
   inviting is the only useful action, and the hint below literally says
   «شارك دعوة الأوضة» — but the control was an unlabeled iOS share glyph.
   Fix: a labelled «ادعي صحابك» button (same native share path, same key,
   same session) with copy kept as an icon beside it. Also the disabled start
   button used an Arabic-Indic «٥» while every other count on the screen is
   «5»; unified. Roster, readiness, settings and voice are untouched.
6. **Onboarding preferences used stock list tiles** while Settings uses the
   kit's rows. Now the same `SettingsSwitchRow`s on a raised panel, so the
   first settings a player sees look like the ones they will find later.
   Order, progress, required unchecked consent and linked terms unchanged.

## Deliberately not changed

- **Home.** The card spread, first-frame backdrop/loop fallback and single
  gold action are the strongest screen in the app; nothing observed warranted
  churn.
- **Mode choice.** Clear hierarchy already (online emphasised, both visible,
  explained when unavailable); reviewed at 360 and desktop, left as is.
- **Lobby seat order / header icons.** The council band is the match's own
  band; changing seat direction or its header would touch the table.
- **Colours.** No palette work (owner reverted lounge brown).

## Deferred for Codex (not UI polish)

- A labelled leave/exit in the lobby header (currently an icon among
  toggles) — worth a product decision together with host "keep room".
- Whether the store should be reachable from the online door.

## Files changed in phase 99 (relative to the phase-98 state)

- New: `lib/ui/widgets/profile_identity.dart`; `test/widget/journey_v99_test.dart`
  (8 tests); `test/widget/journey_screenshots.dart` (capture harness, not a
  test); this document.
- `lib/ui/screens/setup/profile_screen.dart` — back action, late profile
  fill, Save/Continue label, identity art, shared identity fields.
- `lib/ui/screens/onboarding/first_run_screen.dart` — shared identity fields
  on step 2, settings-kit switch rows on step 3. Steps, progress, consent
  and terms unchanged.
- `lib/ui/screens/online/online_entry_screen.dart` — identity chip, equal
  48 dp create/join pair, empty-state panel, self-mirroring room chevron,
  profile back from the door.
- `lib/ui/screens/online/lobby_screen.dart` — labelled invite button (same
  key, same share path) with copy beside it.
- `lib/app/router.dart` — Profile's back goes Home (system back already did).
- `lib/app/l10n/app_{ar,en}.arb` + generated Dart — 5 new strings
  (`profileAddressLabel/Hint`, `onlinePlayingAs`, `onlineNoPublicRoomsHint`,
  `lobbyInviteFriends`); `onlineNeedFivePlayers` AR uses «5».
- Tests updated for real layout/behaviour changes only:
  `test/widget/profile_flow_test.dart` (ensureVisible before the address
  choice, now below the fold at 800×600); `test/widget/online_entry_test.dart`
  (the chevron assertion encoded the bug: it required `chevron_left` in
  Arabic, which renders «›»; it now requires the self-mirroring forward
  chevron). No assertion removed or weakened.

## Verification

- Focused journey suites (first_run, profile_flow, online_entry,
  online_lobby, invite_share, mode_screen, language_picker, settings_presets,
  accessibility, l10n_coverage): 98 passed, then profile_flow 4/4 after the
  scroll fix (`build/phase99/focused-1.log`).
- New `journey_v99_test.dart`: 8/8.
- Full suite once, `--concurrency=2`: **1166 passed / 1 skipped / 0 failed**
  (`build/phase99/full-tests.log`; phase 98 was 1157/1/0).
- `flutter analyze`: 0 errors / 0 warnings / 89 infos — unchanged from
  phase 98, none in files touched here (`build/phase99/analyze.log`).
- Renders (real fonts + bundled art, widget renders — **no emulator or
  device was attached**, `adb devices` empty): before in
  `build/phase99/before/`, after in `build/phase99/`, reviewed at ≤420 px:
  profile AR 360 / EN desktop, onboarding AR 360 / EN 390 / AR desktop (all
  four steps), online door AR 360 with rooms / EN 390 empty / AR desktop,
  lobby AR 360 / EN desktop, mode and home (unchanged). The `lobby-ar-360`
  capture writes its image but the harness then reports the test-only
  `FlutterWebRTC.Event` MissingPluginException (voice plugin absent in the
  test host); not an app failure.

## Remaining gates (unchanged by this phase)

Owner real-phone human match and two-device voice; phase-98 catalog
migration + compatible functions deployment; no APK/AAB/web rebuilt.

## Review delta (Codex review of phase 99)

1. **Lobby capture exception.** The capture harness now overrides
   `voiceEngineFactoryProvider` with the suite's `FakeVoiceEngine`
   (`test/support/fake_voice_engine.dart`) — the existing fake, no exception
   filtering, no production voice change. All 16 journey captures re-ran with
   no exception of any kind (`build/phase99/capture-final.log`, 16/16;
   lobby-only rerun `build/phase99/capture-lobby-delta.log`, 2/2). Lobby AR
   360 and EN desktop inspected at ≤420 px: labelled invite, roster, readiness.
2. **48 dp choice targets.** The shared `SettingsSegments` put its 3 dp inset
   on the track, so each option's InkWell was ~38 dp tall. The inset now lives
   on the painted thumb only; each option's InkWell spans the full track, and
   `SettingsTokens.segmentHeight` is 44 → 48 (token). Looks the same except for
   being 4 dp taller; it also affects the general settings screen and the room
   settings panel (settings_presets, language_picker and room settings suites
   pass in the full run). The test now measures the InkWell (≥48×48 for both
   options), taps 2 dp inside the top edge (outside the thumb) and runs
   `androidTapTargetGuideline`.
3. **Late profile load.** New tests use the real `PlayerProfileController`
   and `ProfileScreen` with a store whose first read is held: an untouched
   form fills in; a typed name, or a chosen address, before the read is kept.
   **A real bug was found:** saving before the first read finished was undone
   in memory when the stale read landed (disk kept the new profile; the app —
   including the online door's join name — showed the old one). Fixed in
   `lib/data/player_profile.dart`: a save made in this session wins over a
   read that was already in flight. That test failed before the fix
   (`Expected: 'Mona' Actual: 'Karim'`) and passes after.
4. **Audit of touched widgets.** No new literals: sizes come from
   `context.spacing`, `SettingsTokens`, or Flutter's `kMinInteractiveDimension`
   (the framework's 48 dp constant) for the entry pair and lobby invite. Back
   uses `BackAction` (mirrored arrow in Arabic); Profile back goes Home / to
   the door; system back is unchanged in the router. No overflow in any of the
   16 renders or in the test runs. The lobby leave redesign and store access
   from the online door stay out of scope.

Delta files: `test/widget/journey_screenshots.dart`,
`test/widget/journey_v99_test.dart`, `lib/ui/widgets/settings_kit.dart`,
`lib/ui/theme/design_tokens.dart`, `lib/data/player_profile.dart`, this doc,
`docs/PROGRESS.md`.

Final counts: journey_v99_test 12/12 (`build/phase99/journey_v99-delta.log`);
full suite at `--concurrency=2` **1170 passed / 1 skipped / 0 failed**
(`build/phase99/full-tests-delta.log`); analyze 0 errors / 0 warnings /
89 infos (`build/phase99/analyze-delta.log`). Still widget renders only; no
device.
