# Session changelog — 2026-09-24

> **للمالك:** الملف ده بيحكي **كل** حاجة اتعملت في الجلسة دي بالترتيب اللي حصلت بيه
> بالظبط، بما فيها شغل الألوان اللي اتعمل **وبعدين اترجّع بالكامل** بناءً على كلامك
> («سيبك من الألوان خالص دلوقتي»). مكتوب بالإنجليزي عشان Codex هو اللي هيراجعه.

**Branch / worktree:** `claude/crash-fixes-and-testing-b6c2f5`
→ `D:/Flutter Data/Projects/AL Mafia/.claude/worktrees/crash-fixes-and-testing-b6c2f5`
**Nothing was committed.** Every change below is uncommitted working-tree state.
**Nothing was published:** no Vercel deploy, no Play upload, no account or billing change,
no migration applied, no coin sale enabled.

---

## Table of contents

| # | Step | Outcome |
|---|---|---|
| 0 | Answered "what is still missing before publishing" | no code change |
| 1 | Investigated the home-video bug | diagnosis |
| 2 | Investigated the background colours | diagnosis |
| 3 | Read both settings surfaces | diagnosis |
| 4 | **Colour work: lounge-brown ground** | **done, then fully reverted in step 16** |
| 5 | `AmbientMedia` rewritten — the home-video fix | **kept** |
| 6 | `AppBackdrop.tint` added | added in step 5, removed again in step 17 |
| 7 | Home screen backdrop restored | **kept** |
| 8 | `ExperienceSurface` put on the shared ground | **kept** |
| 9 | `SettingsTokens` added | **kept** |
| 10 | `settings_kit.dart` written (new file) | **kept** |
| 11 | Five new l10n strings + `flutter gen-l10n` | **kept** |
| 12 | General settings screen rebuilt | **kept** |
| 13 | `LanguagePicker` rebuilt on the kit | **kept** |
| 14 | Six link buttons given a settings-row form | **kept** |
| 15 | Online room settings panel rebuilt | **kept** |
| 16 | Three test files updated | **kept** |
| 17 | Colour revert (owner's instruction) | 6 files restored |
| 18 | `tint` removed from `AmbientMedia` / `AppBackdrop` | **kept** |
| 19 | Verification: analyze, 157 tests, emulator | **passed** |

---

## 0. The opening question (no code change)

The session opened with *«امال ايه كدا اللي ناقص للعبة غير التحقق عشان تكون جاهزه للنشر»*
— what is left before the game can be published, apart from verification. Answered in chat
only. The gaps named were: the uncommitted work on this branch; Play Console tasks
(Data safety + `AD_ID` declaration, `assetlinks.json` regenerated after Play App Signing);
store screenshots that are stale (all offline, taken at 1.0.0) and listing text; the web
build not deployed; the optional ads / coin-sales / paid-scenario decisions; and two known
in-game gaps (online post-game analytics hidden, bullets offline-only).
**No files were touched for this.**

---

## 1. Diagnosis — the home background video

Reported: *«الفيديو اللي بيكون شغال في الخلفية لما بفتح اللعبة مش بيبقا موجود ولما بخش
مثلا جيم و برجع ال home تاني بلاقي الفيديو بقا موجود»* — the loop is missing on a cold
open and present after returning from a match.

Two compounding causes were found:

1. **In the current tree the home screen had no backdrop at all.** The earlier redesign on
   this branch replaced `AppBackdrop(image:…, loop:…)` with a plain `ExperienceSurface`, so
   the build in the owner's hands shows no loop on Home ever.
2. **Historically `AmbientMedia` painted one image only** — it chose *either* the still
   *or* the loop. `AppVideo.bgHomeLoop` is a 60-frame animated WebP rendered through
   `Image.asset`; on a cold start it has to be read and decoded before its first frame
   exists, and until then the widget painted nothing. On a second visit the image cache is
   warm and the first frame is synchronous. That is exactly "missing when I open, there
   when I come back".

(Confirmed for the record: the ambient loops are animated WebP drawn with `Image.asset` —
there is no `video_player` and no platform view on these screens.)

## 2. Diagnosis — the backgrounds

`AppColors` ground ladder is a **neutral near-black** — `#0F0F0F / #1A1A1A / #252525 /
#313131` — deliberately neutral because doc 05 rule 3 forbids a warm ground at night, and
`test/golden/leakage/role_accent_parity_test.dart` holds `blue >= green >= red` at every
rung. So "some screens are pure black" was literally true of the palette.

The *visible* inconsistency had a second, structural cause: `AppBackdrop` painted the
ground **plus a canvas weave**, while `ExperienceSurface` painted a flat gradient of its
own. Screens on the second one therefore read as flat black next to screens on the first.

## 3. Reading the two settings surfaces

`lib/ui/screens/setup/settings_screen.dart` (general settings, also used inside offline
match setup) and `lib/ui/screens/online/room_settings_panel.dart` (online room settings)
had no shared vocabulary: `ChoiceChip` rows, bare `SwitchListTile`s, `TextButton`s in a
`Wrap`, two different headers, two different footers.

---

## 4. Colour work — DONE, THEN FULLY REVERTED

> This whole step was undone in step 17 after the owner said
> *«طيب سيبك من الالوان خالص دلوقتي»*. It is written out here because the request was for
> literally everything, in order. **None of it is in the tree now.**

What was built:

1. `lib/core/theme/app_colors.dart` — four new constants `loungeBase` `#241C14`-family,
   `loungeRaised`, `loungeOverlay`, `loungeBorder` (`#45372B`), with a doc block
   explaining that the lounge is the ground *outside* a match only.
2. `lib/ui/theme/design_tokens.dart` — a `MafiaColors.lounge` variant plus a doc paragraph
   saying the neutral ladder holds *inside* a match and the lounge holds outside it.
3. `lib/ui/theme/mafia_theme.dart` — `dark` and `lounge` both built from a new shared
   `static ThemeData _build(MafiaColors colors)`.
4. `lib/app/app.dart` — `theme: MafiaTheme.lounge`.
5. `lib/app/router.dart` — the `MatchRoute` branch wrapped in
   `Theme(data: MafiaTheme.dark, child: …)` so everything a player holds keeps the neutral
   ground (doc 05 rule 3), plus the `../ui/theme/mafia_theme.dart` import.
6. `lib/ui/screens/setup/home_screen.dart` — `tint: colors.surfaceBase` on the backdrop so
   the near-black loop art took the brown ground's hue instead of punching a hole in it.

Why it was reverted: the owner looked at the result and chose to drop colour work entirely
for now. The **structural** half of the fix (step 8, `ExperienceSurface` on the shared
ground) was kept, because that part is about texture, not hue.

---

## 5. `lib/ui/widgets/ambient_media.dart` — the home-video fix  *(kept)*

Rewritten. The still is now **always** the floor of a `Stack`, and the loop is laid over it
and faded in on its first decoded frame:

```dart
return IgnorePointer(child: ClipRect(child: RepaintBoundary(child: Stack(
  fit: StackFit.expand,
  children: [
    image(still),
    if (moving) image(loop!, frameBuilder: (context, child, frame, synchronous) =>
        synchronous ? child
          : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: fade, child: child)),
  ],
))));
```

* `moving` is still `loop != null && !ReduceMotion.of(context) && TickerMode.valuesOf(context).enabled`
  — Reduce Motion and an inactive route still get the still alone, which is the only correct
  way to honour the setting for an animated WebP (you hand the engine a different file).
* `fade` reads `MafiaMotion.standard` off the theme, falling back to `MafiaMotion.defaults`.
* `gaplessPlayback: true`, `excludeFromSemantics: true`, `errorBuilder` → `SizedBox.expand()`
  are unchanged.
* There is now **never a frame with nothing behind the screen**.

## 6. `AppBackdrop.tint`  *(added here, removed again in step 18)*

`lib/ui/widgets/textured_surface.dart` gained `final Color? tint;`, passed straight through
to `AmbientMedia`, which screened it over the art with `BlendMode.screen`. It existed only
to serve step 4. After the revert it had no caller, so it was removed — see step 18.

## 7. `lib/ui/screens/setup/home_screen.dart` — backdrop restored  *(kept)*

The screen was on a bare `ExperienceSurface`. It is now:

```dart
body: BulbFlicker(
  // The one screen a returning host sees every time, and the one with
  // the longest dwell. Its loop is near-featureless on purpose — the
  // falling icons and the spread are drawn over it. `AmbientMedia`
  // keeps the still under the loop, so the backdrop is there on the
  // very first frame of a cold start (owner, 2026-09-24).
  child: AppBackdrop(
    image: AppImages.bgHome,
    loop: AppVideo.bgHomeLoop,
    child: Stack(…)
```

Imports: added `../../../app/asset_constants.dart`; swapped `experience_surface.dart` for
`textured_surface.dart`.

## 8. `lib/ui/widgets/experience_surface.dart` — one ground everywhere  *(kept)*

`ExperienceSurface` no longer paints a flat gradient of its own. It now wraps
`AppBackdrop` (shared ground + canvas weave) and keeps only its gold top glow:

```dart
Widget build(BuildContext context) => AppBackdrop(
  child: DecoratedBox(
    decoration: BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [
        context.colors.accentGold.withValues(alpha: ExperienceTokens.backgroundGlow),
        context.colors.accentGold.withValues(alpha: 0),
      ])),
    child: child,
  ),
);
```

This is the part of the colour brief that survived: every quiet public surface now has the
same texture as the painted ones, so nothing reads as flat black next to its neighbour.
`ExperienceHero` is unchanged.

## 9. `lib/ui/theme/design_tokens.dart` — `SettingsTokens`  *(kept)*

Appended, so the new kit has zero hardcoded sizes (non-negotiable 6):

```dart
abstract final class SettingsTokens {
  /// The round badge each panel's icon sits in.
  static const iconBadge = 38.0;
  static const iconSize = 20.0;
  /// The smaller badge on a link row.
  static const linkBadge = 32.0;
  static const linkIconSize = 18.0;
  /// A segmented control's track, and the inset its lit thumb keeps.
  static const segmentHeight = 44.0;
  static const segmentInset = 3.0;
  /// How strongly the gold washes a badge and the «online only» pill.
  static const badgeWash = 0.14;
  /// Gold lamp-light along the top edge of a panel.
  static const panelGlow = 0.05;
}
```

## 10. `lib/ui/widgets/settings_kit.dart` — NEW FILE  *(kept)*

One look for every settings surface. Public API, in file order:

| Widget | What it is |
|---|---|
| `SettingsPanel` | A raised card: icon badge + title + optional subtitle, then its rows. `divided` (default `true`) draws a hairline between rows; a link panel passes `false` because some of its children render nothing on a given build. Decoration: `radii.card`, `border: borderSubtle`, a top-to-bottom gradient from `alphaBlend(accentGold @ panelGlow, surfaceRaised)` to `surfaceRaised`, and `elevation.level1`. Its body is wrapped in `Material(type: MaterialType.transparency)` so row ink paints on the panel and not on whatever Material sits under it. |
| `SettingsBadge` | A gold icon in a round gold-washed well; `small` picks the link-row size. |
| `SettingsBadgeFrame` | The well on its own, for a badge that is not an icon (the coin). |
| `_Label` (private) | Label + optional `SettingsPill` on the same line (a `Wrap`, so it folds at large text), and the hint sentence under it. Greys the label when the row is disabled. |
| `SettingsPill` | The small gold-washed tag — «في الأونلاين بس». |
| `SettingsSwitchRow` | A genuine on/off. **The whole row is the tap target** (`InkWell` → `onChanged!(!value)`). `switchKey` names the `Switch` so existing widget tests keep their keys. |
| `SettingsOption<T>` | `typedef SettingsOption<T> = (T value, String label, Key? key);` |
| `SettingsSegments<T>` | A choice between a few named values on one track. The lit thumb is a `FractionallySizedBox(widthFactor: 1/n)` inside an `AnimatedAlign(alignment: AlignmentDirectional(x, 0))` where `x = -1 + 2*index/(n-1)` — so it slides, and `AlignmentDirectional` makes it correct in RTL for free. Duration is `motion.standard`, or `Duration.zero` under Reduce Motion. The track is also wrapped in a transparent `Material` for the same ink reason. `onChanged: null` disables every option. |
| `SettingsSegment` | One option. Public **only** so a test can ask `.selected` instead of sampling pixels. Carries `Semantics(button: true, selected: …, inMutuallyExclusiveGroup: true)`. Selected text is `surfaceBase` on gold at `w700`; unselected is `textSecondary`. |
| `SettingsLinkRow` | Opens something else: badge (or a custom `leading`), label + hint, chevron. |
| `SettingsHeading` | A quiet gold heading with an optional sentence, between groups of panels. |

## 11. l10n — five new strings  *(kept)*

Added to `lib/app/l10n/app_ar.arb` and `lib/app/l10n/app_en.arb`:

| key | ar | en |
|---|---|---|
| `settingsSectionGeneral` | عام | General |
| `settingsRulesTitle` | قواعد اللعب | Match rules |
| `settingsRulesHint` | كل ماتش جديد بيبدأ بيها، وتقدر تغيّرها قبل أي ماتش. | Every new match starts from these, and you can still change them before one. |
| `settingsSectionMore` | المساعدة والخصوصية | Help & privacy |
| `onlineRoomSettingsHint` | أي تغيير بيوصل لكل اللي في الأوضة على طول. | Every change reaches everyone in the room right away. |

Then `flutter gen-l10n`, which rewrote `app_localizations.dart`,
`app_localizations_ar.dart`, `app_localizations_en.dart`.

## 12. `lib/ui/screens/setup/settings_screen.dart` — rebuilt  *(kept)*

Rewritten from `_presetSection` to the end of the file.

* `_presetPanel(l10n)` — the preset is now a `SettingsSegments<MatchPreset?>` inside a
  `SettingsPanel(icon: Icons.style_outlined, title: l10n.presetLabel)`. The selected preset
  is still derived exactly as before, via `MatchPreset.identify`, and presets that do not
  fit the current table (`preset.availableFor(playerCount)`) are still not offered. The
  panel's `subtitle` is **always** present — `EngineCopy.presetHint(l10n, current)`, or
  `l10n.presetCustom` when the settings match no preset — so the panel does not change
  height under the thumb, and "custom" reads as a real answer rather than the absence of
  one. Each option carries the existing `SettingsScreen.presetChip(preset)` key.
* `_segmented({…})` now returns a `SettingsSegments<int>` instead of a `ChoiceChip` row.
* `_switch({…})` now returns a `SettingsSwitchRow`, with
  `pill: onlineOnly ? l10n.settingsOnlineOnly : null` — the "online only" note is a pill
  beside the label instead of text buried in the hint.
* `bool get _isDefaults => widget.playerCount == null` — one named test for "am I the app's
  settings screen or the match-setup one".
* The build:

```dart
final rules = [_presetPanel(l10n), _pace(l10n), _information(l10n), _reveal(l10n), _voting(l10n)];
final panels = _isDefaults
    ? [
        SettingsPanel(icon: Icons.translate, title: l10n.settingsSectionGeneral,
                      children: const [LanguagePicker()]),
        _audio(l10n),
        SettingsHeading(title: l10n.settingsRulesTitle, subtitle: l10n.settingsRulesHint),
        ...rules,
        SettingsPanel(icon: Icons.support_agent_outlined, title: l10n.settingsSectionMore,
                      divided: false, children: const [
          CoinStoreButton(tile: true), ScenarioStoreButton(tile: true), AdPrivacyButton(),
          HelpButton(tile: true), SafetyButton(privacy: true), LegalDocuments(),
        ]),
      ]
    : [...rules, _audio(l10n)];
```

  So **from Home**: General (language) → Audio → the `SettingsRules` heading with its
  sentence → preset / pace / information / reveal / voting → Help & privacy.
  **Inside offline match setup**: only the rules and the audio — the host is standing up
  with the table waiting, and the language is not what they came for.
* Panel icons: preset `style_outlined`, pace `timer_outlined`, information
  `manage_search_outlined`, reveal `visibility_outlined`, voting `how_to_vote_outlined`,
  audio `volume_up_outlined`.
* The header keeps `l10n.settingsTitle` and the back affordance; the save button is pinned
  in a bordered bar at the bottom.
* **The scrolling area is a `SingleChildScrollView(child: Column(…))`, not a `ListView`** —
  deliberately. See §18 *Errors*.

## 13. `lib/ui/widgets/language_picker.dart` — rebuilt  *(kept)*

Now a `SettingsSegments<String>` over `['ar', 'en']`. Added
`static const arabicKey = ValueKey('language_ar')` and
`static const englishKey = ValueKey('language_en')` so tests can address an option without
reading colours. The failure message now uses `colors.accentCrimson`.

## 14. Link buttons — one row form  *(kept)*

Every "opens something else" control became a `SettingsLinkRow`:

| File | Before | After |
|---|---|---|
| `lib/ui/screens/setup/coin_store.dart` | `CoinStoreButton({compact})` | `+ tile` → `SettingsLinkRow` with `leading: SettingsBadgeFrame(child: MafiaCoin(…))` |
| `lib/ui/screens/setup/scenario_store.dart` | `ScenarioStoreButton()` | `+ tile`; the retry-on-failure logic extracted into a private `_open()` so both forms share it |
| `lib/ui/screens/setup/help_center.dart` | `HelpButton()` | `+ tile` |
| `lib/ui/screens/online/safety_center.dart` | `SafetyButton()` | `SafetyButton(privacy: true)` → `SettingsLinkRow` |
| `lib/ui/screens/online/rewarded_reward_button.dart` | `AdPrivacyButton` as a `ListTile` | `SettingsLinkRow(icon: Icons.ads_click_outlined, …)` |
| `lib/ui/widgets/legal_documents.dart` | a `Wrap` of two `TextButton`s | a `Column` of two `SettingsLinkRow`s with a `Divider` |

Every call site outside settings keeps its old form (the `tile`/`privacy` flags default to
the previous look), so nothing else on screen changed.

## 15. `lib/ui/screens/online/room_settings_panel.dart` — rebuilt  *(kept)*

`build` and `_titleField` rewritten; everything above them (state, `_send`,
`_cosmeticOptions`, the static keys) untouched.

* The sheet now sits on `ExperienceSurface` inside a transparent `Material`, inside a
  `SafeArea` → `Center` → `ConstrainedBox(maxWidth: spacing.maxContentWidth)` — the same
  reading column the door and the lobby keep, so a desktop browser does not put a switch
  and its label a screen's breadth apart.
* Header: `SettingsBadge(icon: Icons.tune)` + `l10n.onlineRoomSettings` + a close button.
  `l10n.onlineRoomSettingsHint` is shown **only when the room is live**
  (`final live = widget.onChanged == null;`) — in the create form nothing has been sent to
  anyone yet, so promising that "every change reaches everyone right away" would be a lie.
* Four panels:
  1. **الأوضة** `meeting_room_outlined` — visibility segments (private/public), the title
     field (public rooms only: a private room is never listed anywhere its name could be
     read), max-players segments 5/8/10/15, the scenario segments when owned, and a
     cosmetic segment per slot that has more than one option.
  2. **الصوت** `mic_none_outlined` — voice on/off, mute-all-at-night.
  3. **اللعب** `timer_outlined` — speech seconds 30/45/60, discussion minutes 3/5/7,
     discussion mode structured/free, open voting.
  4. **المعلومات** `manage_search_outlined` — trace, confrontation, whispers.
* Footer in a bordered bar, same as the general settings.
* **Every existing widget key is preserved**: `panel`, `visibilityPrivate`,
  `visibilityPublic`, `titleField`, `voiceSwitch`, `muteAtNightSwitch`,
  `discussionStructured`, `discussionFree` — so `online_entry_test` and `online_lobby_test`
  address the same nodes as before.
* `_titleField` keeps `maxLength: 40`, `counterText: ''`, the `onSubmitted` /
  `onChanged` / `onTapOutside` commit logic unchanged.

## 16. Tests updated  *(kept)*

* `test/widget/ambient_media_test.dart` — now asserts that a moving surface renders
  **two** images (`[AppImages.bgVote, AppVideo.bgVoteLoop]`) and that Reduce Motion or an
  inactive `TickerMode` renders only `[AppImages.bgVote]`. This is the regression test for
  the reported bug.
* `test/widget/settings_presets_test.dart` — `chipFor` now reads a `SettingsSegment`
  instead of a `ChoiceChip`; added the `settings_kit.dart` import. The assertions
  themselves (which presets are offered at which table size) are unchanged.
* `test/widget/language_picker_test.dart` — asks `SettingsSegment.selected` for
  `LanguagePicker.arabicKey` / `englishKey`, and still proves the lit option is gold by
  finding a `DecoratedBox` whose `BoxDecoration.color == colors.accentGold`.

---

## 17. The revert  *(owner's instruction)*

After seeing the colour result the owner said *«طيب سيبك من الالوان خالص دلوقتي و كمل في
الباقي»*. A script — `scratchpad/revert_colors.py`, outside the repo — applied six exact
reversions, each guarded by `assert s.count(a) == 1` so a partial match could not silently
half-revert:

1. `lib/app/app.dart` → `theme: MafiaTheme.dark`
2. `lib/app/router.dart` → `MatchRoute` unwrapped from `Theme(data: MafiaTheme.dark, …)`,
   and the now-unused `../ui/theme/mafia_theme.dart` import dropped
3. `lib/ui/theme/mafia_theme.dart` → back to
   `static ThemeData get dark { const colors = MafiaColors.dark; … }` (no `_build`, no
   `lounge`)
4. `lib/ui/theme/design_tokens.dart` → `MafiaColors.lounge` and its doc paragraph removed
5. `lib/core/theme/app_colors.dart` → the four `lounge*` constants and their doc block
   removed
6. `lib/ui/screens/setup/home_screen.dart` → `tint: colors.surfaceBase` removed

Verified afterwards: `grep -rn "lounge" lib test tool` returns **nothing**.

## 18. Post-revert cleanup — `tint` removed  *(kept)*

With no caller left, the parameter was removed rather than kept as a dangling option:

* `AmbientMedia` — `final Color? tint` and its doc dropped; constructor is now
  `const AmbientMedia({super.key, required this.still, this.loop})`; the `color:` /
  `colorBlendMode:` arguments removed from the internal `image()` builder.
* `AppBackdrop` — `final Color? tint` and its doc dropped; constructor is now
  `const AppBackdrop({super.key, this.image, this.loop, required this.child})`; the call is
  `if (image != null) AmbientMedia(still: image!, loop: loop)`.

---

## 19. Errors hit along the way, and how each was fixed

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | `prefer_const_declarations` at `settings_kit.dart:293` | `final inset = SettingsTokens.segmentInset;` | `const inset`, and `const EdgeInsets.all(inset)` |
| 2 | `unused_import` of `design_tokens.dart` in `settings_screen.dart` | the rewrite dropped the last direct token reference | import removed |
| 3 | Bash heredoc died with ``unexpected EOF while looking for matching `'`` | an apostrophe inside a Dart doc comment (`/// Doc 13 §5's preset row.`) | the new Dart tails were written to `scratchpad/settings_tail.dart` and `scratchpad/room_tail.dart` and spliced in with a short `python -c`. A first attempt had silently changed nothing — caught with `git diff --stat` and `grep -c SettingsPanel` returning 0 |
| 4 | **Five settings tests failed** after the rewrite: `find.text('قواعد ومعلومات')` found 0, the online-only pills found 0, audio toggles not found, preset chip assertions failed | the panels were in a **`ListView`**, which builds lazily — off-screen rows did not exist to be found | replaced with `SingleChildScrollView(child: Column(crossAxisAlignment: stretch, children: panels))`, with a comment that nine panels is not a long list and every switch should exist whether or not it has been scrolled to. Re-run: 11 tests passed |
| 5 | `UnicodeEncodeError` (cp1252) when Python printed Arabic | Windows console default encoding | `PYTHONIOENCODING=utf-8` prefix |
| 6 | Ink invisible on the new panels and segments | ink paints from the nearest `Material`, which sat **under** the panel gradient and the segment track fill | both wrapped in `Material(type: MaterialType.transparency)` |
| 7 | The background full-suite `flutter test` was **killed by the system for low memory** | machine memory, not a test failure | not restarted — the standing rule is that a job killed for memory is only restarted when the owner asks. Targeted files were run instead (see §20) |
| 8 | `adb install` of a debug APK refused: `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | the emulator held the **release**-signed 1.1.3 | built the signed **release** APK instead and installed over the top, so the emulator's app data (profile, groups, settings) survived. Nothing was uninstalled |

---

## 20. Verification actually performed

**Static analysis** — `flutter analyze`: **90 issues, all `info`, zero `error`, zero
`warning`**. Every remaining info is pre-existing (`prefer_const_constructors` in tests,
`use_super_parameters` in `lib/engine/models/**`, a deprecated `onPopPage` in one test, a
dangling library doc comment in `test_driver/`). Re-run after the `tint` removal: identical.

**Tests** — run as three targeted batches, **157 tests, all passed**. The full suite was
**not** re-run (see error 7):

| Batch | Files | Result |
|---|---|---|
| 1 | `ambient_media`, `reduce_motion`, `settings_presets`, `audio_settings_preview`, `language_picker`, `token_discipline` | 22 passed |
| 2 | `token_discipline`, `online_entry`, `online_lobby`, `first_run`, `profile_flow`, `app_boots` | 65 passed |
| 3 | `coin_store`, `coin_purchase`, `help_center`, `safety_center`, `accessibility`, `rewarded_reward_button`, `integration/setup_flow`, `platform/card_ground_matches_surface`, `leakage/role_accent_parity`, `leakage/night_color_token`, `leakage/luminance_budget` | 70 passed |

The last batch is the one that matters for the revert: `card_ground_matches_surface`
(`card_ground == AppColors.groundBase`), `role_accent_parity` (`blue >= green >= red` at
every ground rung) and `night_color_token` all pass, i.e. the palette is back to the
neutral ladder the spec requires.

**On the emulator** — `emulator-5554` (Pixel 9 Pro 2), release APK built with
`--dart-define-from-file=dart_defines.json` and installed over the existing 1.1.3:

1. **Cold start** — `am force-stop`, then `am start`. Splash → Home, and the ornate
   backdrop is **present on the first painted frame of Home**, behind the card spread.
   That is the reported bug fixed.
2. **General settings** (gear on Home) — «الإعدادات» header, «عام» panel with the language
   track (العربية lit in parchment), «الصوت» panel, the «قواعد اللعب» heading with its
   sentence, the five rules panels, and «المساعدة والخصوصية» with المتجر / المساعدة والأسئلة
   الشائعة / الخصوصية وحذف البيانات / الشروط والأحكام / سياسة الخصوصية as link rows. Save
   bar pinned. The «في الأونلاين بس» pill renders as a real pill beside «الهمس», with the
   hint under it and the switch on the leading edge. Chevrons mirror correctly in RTL.
3. **Online room settings** (Online → + اعمل أوضة) — «إعدادات الأوضة» with the tune badge,
   the four panels (الأوضة / الصوت / اللعب / المعلومات), segments lit in parchment
   (خاصة, 10, 5 دقائق, بالدور), and the footer pinned. As expected for the create form, the
   "reaches everyone right away" hint is **not** shown. No room was created; the sheet was
   closed with its X.

---

## 21. What is NOT in this session's work

* **No commit, no push.** The tree is dirty by design; the owner has not asked for a commit.
* **No colour change survives.** Only the structural `ExperienceSurface` → `AppBackdrop`
  change (§8), which is about texture, not hue.
* **The full test suite has not been re-run** since the settings rewrite — only the 157
  targeted tests above. Restarting it needs the owner's word (it was killed for memory).
* **Not verifiable here:** a human match on real phones, two-device witness voice, weak
  network, an online match in a real browser, and anything to do with publishing.
* The coin_orders migration `20260924000500` remains **unapplied** and sales stay off.

---

## 22. Suggested review focus for Codex

1. `lib/ui/widgets/ambient_media.dart` — is stacking still + loop the right fix, or should
   the loop be pre-warmed via `precacheImage` on the route before Home builds? The current
   fix costs one extra decoded image in memory for the life of the screen.
2. `lib/ui/widgets/settings_kit.dart` — `SettingsSegments` thumb geometry
   (`x = -1 + 2*index/(n-1)`, `widthFactor: 1/n`) at `n == 1`, and the `index < 0` path when
   a value is not in `options`.
3. `lib/ui/screens/setup/settings_screen.dart` — the `SingleChildScrollView` + `Column`
   choice (see error 4). Nine panels is small, but confirm it is not a scroll-performance
   regression on a low-end device.
4. `lib/ui/screens/online/room_settings_panel.dart` — the `live = widget.onChanged == null`
   inversion reads backwards at first glance; confirm it is right for both call sites
   (`lobby_screen.dart:713` and `online_entry_screen.dart:632`).
5. Doc 05: nothing in this session touches phase flow or what a player can see, but the
   settings surfaces do now show more at once. Confirm no rule-3 or leakage implication.
