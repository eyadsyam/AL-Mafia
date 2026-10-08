# Deck system - implementation checklist, phases 1-3 (round 6, agreed 2026-10-08)

I checked the tokens, the existing kit, `mafia_public.dart`, `warm_palette.dart`, the home, mode and bots-sheet code, the router, the ARB files and the tests. Fix the items in section 0 first; everything below is final.

### 0. Mistakes in the spec — now or never
1. **Bone values: keep home pixel-identical.** Home's button today is `colors.accentGold` = `AppColors.agedParchment` `#C2BDB2`, pressed `#8D8169`, label `colors.surfaceBase`, `type.title` (22), `radii.button` (14). So BoneButton uses exactly those, not `#C2BBB3`/`#A9A29A`/18/16. Bonus: this is already the neutral in-match fill, so one widget works everywhere with no special case.
2. **Radii: reuse what exists.** ArtCard and sheet tops use `radii.card` (16), not new values of 12 and 20.
3. **Type: do not touch `MafiaTypography`.** It is display 44 / headline 32 / title 22 / body 16 / bodySmall 14 / caption 12, and in-match goldens depend on it. The kit uses derived `DeckTokens` styles instead.
4. **Do not change `MafiaPublicTheme`'s FilledButton default in phase 1.** It makes every FilledButton gold (`vaultGoldStyle`) on 22 `MafiaScaffold` screens and in 9 `showMafiaSheet` sheets. Switch call sites file by file. Flip the default only after phase 7, once every value button is an explicit GoldButton.
5. **The mode hero is the round-table scene, so the «مع صحابك» crop would duplicate it.** Drop `ExperienceHero` and `councilInvitation` from the mode screen. That is also what makes 3 cards plus the banner fit at 360×640.
6. **`storeTitle` is «المتجر» today.** Set it to «المحل» in ar.
7. **Casebook can be disabled** (`casebookProvider` reports `enabled == false` in builds without a server). In that case the slot falls back to «السجل» with the `historyButton` key. This keeps `onboarding_gate_test` and `session_ad_navigation_test` green.
8. **`story_flow_screen` has a pass step (`storiesCoverAndPass`).** Phase 3 restyles only the hub and the case sheet's start. Its pass and private steps stay as they are until a separate Doc 05 review.
9. **Pre-existing, out of scope:** `day/whisper_compose_screen.dart` and `online/witness/witness_layer.dart` use `VaultTokens.gold` in-match. Do not touch them; flag them for a Doc 05 review.
10. **`modeStoriesBody` uses Arabic-Indic digits.** The key is deleted anyway (see 3. Mode screen).

### 1. `lib/ui/theme/design_tokens.dart`
Add `abstract final class DeckTokens` with:
- **Colours:** `ground = IdentityTokens.ink`, `panel = IdentityTokens.panel`, `raised = IdentityTokens.panelOverlay`, `line = IdentityTokens.line`, `text = IdentityTokens.text`, `text2 = Color(0xFFC2BBB3)`, `muted = Color(0xFF9B978E)`, `silver = Color(0xFF67635F)`, `silverLight = Color(0xFF9E9891)`, `bone = AppColors.agedParchment`, `bonePressed = Color(0xFF8D8169)`, `gold = VaultTokens.gold`, `goldLight = VaultTokens.goldLight`, `goldDeep = VaultTokens.goldDeep`, `ink = Color(0xFF1A120C)`, `seam = Color(0xFF0E0807)`, `hairlineAlpha = 0.4`.
- **Geometry:**
  - Buttons: `bone = 56`, `rim = 48`, `goldInRow = 48`, `adCta = 40`, `rimBorder = 1.5`.
  - Cards and rows: `windowList = Size(64, 88)`, `windowArch = 32`, `windowRole = Size(48, 64)`, `narrator = Size(120, 160)`, `narratorSmall = Size(88, 120)`, `artMin = 112`, `rowOne = 56`, `rowTwo = 72`, `rowInset = 56`.
  - Pills and chips: `pill = 32`, `chip = 48`, `dot = 8`.
  - Feather, sheet, footer, fan: `featherFraction = 0.4`, `heroFeather = 48`, `sheetMax = 0.9`, `footerGap = 16`, `fanMinStage = 200`.
- **Durations:** `press = 160 ms`, `sheet = 260 ms`, `slide = 260 ms`, `seamFade = 400 ms`, `reduced = 150 ms`.
- **Type:** `TextStyle title(MafiaTypography t) => t.headline.copyWith(fontSize: 28)`. Likewise `card` 20, `body` 17, `meta` 15, all `height: 1.6`, `letterSpacing: 0`.

**Merging the golds:**
- Delete `IdentityTokens.gold` (`#D6A64F`). Its only users are `warm_palette.dart` and `bot_match_sheet.dart`.
- `VaultTokens.gold` `#C9A45C` stays the canonical gold. Its value does not change, so no in-match pixel moves.
- `ShareCardTokens.gold` and the push-notification `accent` (`#C2AF81`) stay: they are off-screen picture and notification palettes. Add a comment saying so.

### 2. Kit
**New file `lib/ui/widgets/deck/deck_buttons.dart`.** Allowed in-match; colours come from `context.colors`.
- `BoneButton({Key? key, required String label, required VoidCallback? onPressed, String? disabledReason})`
- `RimButton({Key? key, required String label, required VoidCallback? onPressed, double height = DeckTokens.rim})`

**New file `lib/ui/widgets/deck/deck_public.dart`.** Public only.
- `GoldButton({key, required String label, required VoidCallback? onPressed, bool inRow = false})`. The label comes from an ARB string with the amount in it; a coin glyph leads.
- `ArtWindow({required String asset, Size size = DeckTokens.windowList, Alignment focus = Alignment.center, double zoom = 1})`
- `ArtCard.list({key, required String title, String? meta, required ArtWindow art, VoidCallback? onTap, bool selected = false, String? lockedReason})`
- `ArtCard.hero({key, required String art, required Widget title, Widget? body, List<Widget> pills = const [], Widget? action})`
- `DeckRow({key, IconData? icon, required String title, String? meta, Widget? trailing, VoidCallback? onTap})`
- `Future<T?> showDeckSheet<T>({required BuildContext context, required String title, bool ruqaa = false, required WidgetBuilder body, Widget? primary})`. It wraps `showMafiaSheet` plus `WarmPalette`, with a handle, the close key «اقفل» and the primary pinned to the bottom.
- `DeckPill(String label, {bool ad = false})`
- `CoinPill({key, required int balance, VoidCallback? onTap})`
- `DeckChip({key, required String label, required bool selected, required ValueChanged<bool> onSelected})`
- `NarratorEmpty({key, required String line, required String actionLabel, required VoidCallback onAction, bool primary = true})`
- `DeckHeader({key, required String title, String? subtitle, VoidCallback? onBack, Widget? trailing})`
- `DeckScaffold({key, required String title, String? subtitle, VoidCallback? onBack, Widget? trailing, required Widget body, Widget? primary, BannerPlacement? banner})`. It is `WarmPalette` around `MafiaScaffold`. Footer: `SafeArea(top:false)`, then a Column of primary, a 16 dp gap with a `line` divider, then `WaitingBanner(placement)`.

**Existing kit files:**
- `mafia_kit.dart` and `mafia_public.dart` stay untouched and are wrapped, not replaced.
- Do not add `@Deprecated`: `flutter analyze` would report every use.
- `warm_palette.dart`: one change, `accentGold: DeckTokens.bone`. Gold now means value only.

### 3. Home (`home_screen.dart` and `router.dart`)
- **Top row order:** identity chip, casebook, store, «إزاي نلعب», «الإعدادات».
- **Casebook control:** a new `HomeCasebookButton` in `casebook_sheet.dart`.
  - Watches `casebookProvider`. When `enabled`: icon `Icons.menu_book`, label `l10n.casebookTitle`, tap calls `showCasebookSheet(context)`.
  - Gold dot of `DeckTokens.dot` when `book.ready > 0`. Key `HomeScreen.casebookButton`.
  - Otherwise it is the existing «السجل» `_CornerButton`.
- **Coin pill:** add `pill: true` to `CoinStoreButton`, keeping its State so the `pendingInviteCodeProvider` listener survives.
  - Render `CoinPill(walletProvider.valueOrNull!.balance)` once `profileStatsProvider` reports `local + online > 0`. Before that, the current icon.
  - Router: `CoinStoreButton(compact: true, pill: true)`.
  - Add `ref.invalidate(profileStatsProvider)` when `ResultScreen` mounts. It currently caches with `ref.read`.
  - Assert in a test that a bots match lands in `matchRepositoryProvider.listHistory()`. If it doesn't, count it.
- **Stories button:** new `onStories` parameter and a `HomeScreen.storiesButton` RimButton, 12 dp under the bone, label `l10n.homeStoriesButton`. Router: `() => forwardTo(context, Routes.stories)`. In the stories route, `onBack` goes to `Routes.home`.
- **Primary:** BoneButton with key `startButton`.
- **Avatar:** add `fallbackAsset` to `CosmeticFrameRing`. Pass `AppImages.cardBack` only from `MyIdentityBadge(showName: false)`; online seats are unchanged.
- **Hint:** `DeckTokens.meta` in `colors.textSecondary`.
- **360×640:**
  - `CardSpread` goes in `Positioned.fill(bottom: reserve)`. `reserve` is the bottom block's measured height, including `BondHomeLine` and the banner.
  - Card size: `cardWidth = min(shortestSide*0.5, 280, stage.height*0.8/1.5)`.
  - If the stage is under 200 dp, hide `tapCardHint`.

### 4. Mode screen
- `DeckScaffold(title: modeTitle, onBack, banner: BannerPlacement.home)`. Remove the hero, the invitation line, `storiesCard` and `onPlayStories` (in `ModeScreen` and the router).
- **Cards:**
  - `offlineCard`: `ArtWindow(ExperienceArt.council, focus: Alignment.center)`
  - `onlineCard`: `ArtWindow(AppImages.cardFaceDoctor, focus: Alignment(0,-0.3), zoom: 1.7)`, with `lockedReason: modeNoServer` when there is no server
  - Bots: `ArtWindow(AppImages.cardFaceCitizen, focus: Alignment(0,-0.3), zoom: 1.7)`
- **ARB values (ar / en):**

| Key | Arabic | English |
|---|---|---|
| `modeOnePhoneTitle` | «مع صحابك» | "With friends" |
| `modeOnePhoneBody` | «موبايل واحد، من 5 لـ15 لاعب» | "One phone, 5 to 15 players" |
| `modeOnlineTitle` | «أونلاين» | "Online" |
| `modeOnlineBody` | «كل واحد من موبايله، من 5 لـ10» | "Everyone on their own phone, 5 to 10" |
| `modeBotsBody` | «لوحدك، في أي وقت» | "On your own, any time" |
| `modeBotsCardTitle` (new) | «ضد الكمبيوتر» | "Against the computer" |
| `homeStoriesButton` (new) | «قصص وتحقيقات» | "Stories & cases" |
| `storeTitle` | «المحل» | (en unchanged) |

- **Delete `modeStoriesBody`.**

### 5. Bots sheet and stories
- **Keys containing بوت:**

| Key | New Arabic |
|---|---|
| `modeBotsTitle` (now the sheet title) | «العب ضد الكمبيوتر» |
| `botSheetLevel` | «مستوى الكمبيوتر» |
| `botWinReward` | «فزت على الكمبيوتر: +{coins} كوينز» |

  The old body text moves to a new key, `botSheetBody`. Code comments that mention «البوتات» can stay.
- **`bot_match_sheet.dart`:**
  - `showDeckSheet(title: modeBotsTitle, ruqaa: true)`.
  - `ChoiceChip` becomes `DeckChip` in all three groups.
  - `FilledButton` becomes `BoneButton(key: startKey)`.
  - Drop the `IdentityTokens.ink` background.
- **`stories_screen.dart`:**
  - `DeckScaffold(title: storiesTitle)`, with `storiesTitle` set to «قصص وتحقيقات».
  - `_StoryCard` becomes `ArtCard.hero`; tags become `DeckPill`.
  - `FilledButton` becomes `BoneButton(key: startKey)`, with `storiesStart` set to «افتح القضية».
  - `NativeAdCard` gets the Row grade with `DeckPill(ad: true)`, starting at index 4 (`i >= 4 && i % 4 == 0`).
- **`story_flow_screen.dart`:** only the first FilledButton (`storiesAccuse`, line 282) is in scope, and it stays as it is (see section 0, item 8).

### 6. Tests and screenshots
- **`test/golden/leakage/handoff_purity_test.dart`:** add forbidden patterns `deck/deck_public.dart`, `\bDeckTokens\b`, `\bWarmPalette\b` and `\bIdentityTokens\.(ink|panel|text)`. Assert the closure may import `deck_buttons.dart`.
- **New `test/widget/deck_kit_test.dart`:**
  - Bone is 56 high and uses `agedParchment`; Rim is 48; every tap target is at least 48.
  - A disabled Bone shows its reason line.
  - GoldButton always shows the coin glyph.
  - DeckScaffold puts the banner below the primary.
  - Tokens resolve inside `token_discipline_test`.
- **`test/widget/mode_screen_test.dart`:**
  - Three cards. Bots leads to bots.
  - `storiesCard` is absent.
  - Everything fits above the banner at 360×640.
- **`test/widget/home_profile_entry_test.dart`, plus a new `home_deck_test.dart`:**
  - Row order.
  - Casebook disabled shows «السجل».
  - The gold dot shows when `ready > 0`.
  - The pill is hidden while the match count is 0.
  - Exactly one BoneButton and one RimButton.
  - The fan stage is at least 200 dp at 360×640, or the hint is hidden.
- **`test/integration/bot_match_test.dart`:** no «بوت» text in the sheet; the result is recorded in history.
- **Screenshots:** `identity_screenshots.dart` at 390 and 360×640 for `08_home`, `00_mode`, `05_bot_match_sheet`, `01_stories_hub`, `02_story_*` and the casebook sheet. Downscale them per CLAUDE.md before viewing.
- **Run:** `flutter analyze 2>&1 | tail -30` and `flutter test 2>&1 | tail -40`. No builds or deploys.
