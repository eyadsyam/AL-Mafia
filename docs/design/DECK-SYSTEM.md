# «نظام الكوتشينة» — the Deck design system

> 2026-10-16: identity isolation applied (§2). Where §10 below says "dark case file", "Ruqaa" or "warm" for a Mafia screen, read Home's look with deck panels, seals and text tabs; those words now describe «قصص وتحقيقات» only.

Agreed and signed 2026-10-08 after five rounds between Claude (proposer) and an independent critic. Nothing here is built yet; waiting for the owner.

## 1. Foundation
The home screen is the source: Victorian monochrome playing cards (ink black, aged bone paper, engraved silver, arched portrait window, filigree back) on a dark oxblood backdrop, plus the characters on the cards.

- **Silver = structure** (frames, dividers, icons). **Gold = value only** (coins, rewards, purchases, claimable dots). **Bone = the one primary action**, exactly like home's «ابدأ اللعبة».
- Characters are the art language: any card with art uses the card-face recipe (bone hairline margin + dark arched window + figure, feathered at the bottom). **One face per viewport**, except the role picker where faces are the content (48×64 windows).
- Card motion only for literal cards (role flip, a bought card). Areas use one shared-axis slide.

## 2. Tokens
| Token | Value | Use |
|---|---|---|
| ground | `#0F0F0F` (Home's `AppColors.groundBase`) | public screens (with home vignette + weave) |
| panel | `#1A1A1A` | ArtCard, sheets, `DeckPanel` |
| raised | `#252525` | pressed, selected chip, native-ad rows |
| line | `#313131` | dividers |
| text / text2 / muted | `#E9E4D9` / `#ADA99F` / `#908C83` | |
| silver / silverLight | `#67635F` / `#9E9891` | frames, icons, rim buttons |
| bone | `#C2BBB3` (pressed `#A9A29A`) | primary button fill |
| gold | `#C9A45C` (+ `#F1DFA8`, `#7A5C26` gradient only) | value only; the three old golds merge into this |
| ink | `#1A120C` | label on bone/gold |
| seam | `#0A0A0B` | the curtain's darkest point |

In-match private surfaces keep the neutral charcoal palette (Doc 05). **Every Mafia screen is Home's look** (owner, 2026-10-15/16): the warm brown ground, the case-file paper, rubber stamps, cork board and Ruqaa belong to «قصص وتحقيقات» only (`StoryDeckTokens`, `StoryPalette`, `lib/ui/screens/stories/widgets/`), which feels like another game inside Mafia and shares only coins and rewards. Mafia's result, match file, profile and casebook use `DeckPanel`, `DeckSeal` and `DeckTabs` (`lib/ui/widgets/deck/deck_paper.dart`). Guard: `test/architecture/identity_isolation_test.dart`.

Type: Plex Sans Arabic for body; titles in the headline cut (Cairo); **Aref Ruqaa only inside «قصص وتحقيقات»**. Sizes 28 screen title (Bold) / 20 card title / 17 body+controls / 15 meta. Line height 1.6, letter-spacing 0, scale 1.0. Western digits.

Motion: press 160 ms, sheet 260 ms, area slide 260 ms, flip 320 ms; reduce-motion = 150 ms fade; never touches game timers or Doc 05 minimums.

## 3. Components (4 dp grid)
- **ArtCard**: radius 12, panel fill, 1 dp bone hairline at 40%, padding 12. List variant: start-side arched window 64×88 (top radius 32, silver hairline, bottom 40% feather), title 20 Bold, meta 15 (≤2 lines), silver chevron, min height 112. Hero variant (stories): 16:9 art, 48 dp feather, Ruqaa 22. Pressed = raised fill. Selected = 2 dp bone hairline + 20 dp bone check. Locked = art 40% + lock 16 + reason line; title stays readable.
- **Row**: 56 / 72 dp, icon 24 silverLight in a 40 slot, title 17, meta 15 muted, divider inset 56.
- **BoneButton** 56 dp, radius 16, SemiBold 18 ink; disabled 40% + reason line. **RimButton** 48 dp, 1.5 dp silverLight border. **GoldButton** 56 (48 in rows), gradient, always shows amount + coin glyph. One bone primary per active surface.
- **Sheet**: top radius 20, panel fill, top hairline, handle 36×4, close icon «اقفل» at top-end, max 90%, primary pinned to bottom, no banner inside.
- **Pill** 32 dp; **coin pill** gold + ink number in a 48 slot; **selectable chip** 48 dp.
- **NarratorEmpty**: hooded Citizen in an arched window (120×160 / 88×120), one line, one button («جرب تاني» on errors).
- **Header**: 72 dp, back arrow «رجوع» at start, title 28 Bold, coin pill only on المحل and ملف القضايا.

## 4. Navigation
```
الرئيسية (composition kept: fan, title, bone button; small additions: rim «قصص وتحقيقات», «ملف القضايا» replaces «السجل», المحل becomes the coin pill)
├─ bone «ابدأ اللعبة» → «اختار طريقة اللعب»
│    ├─ «مع صحابك» (موبايل واحد، من 5 لـ15) → «مين بيلعب؟» → «الأدوار» → الماتش
│    ├─ «أونلاين» (كل واحد من موبايله) → «العب أونلاين»: tabs «العب · صحابك · المجلس» → الأوضة → الماتش
│    └─ «ضد الكمبيوتر» (لوحدك، في أي وقت) → sheet «العب ضد الكمبيوتر» → الماتش
├─ rim «قصص وتحقيقات» → «قصص وتحقيقات» → sheet القضية → الماتش
├─ fan card → sheet «الدور ده بيعمل إيه»
└─ top row: «بروفايلك» · «ملف القضايا» (gold dot when claimable; wheel inside «النهارده») · «المحل» (coin pill, hidden until the first match ends) · «إزاي نلعب» (sheet) · «الإعدادات» (sheet)
     بروفايلك tabs: «أنا · شخصياتي · ألقابي · السجل»; band = player's most-played character
الماتش → النتيجة: bone «العب تاني», rim «الرئيسية»
```
Depth ≤ 2 for areas (screen → sheet); the play flow is a wizard. The word «بوتات» disappears from UI copy.

## 5. Ads
Footer bottom-up: system inset → banner (collapses when unfilled) → 16 dp gap with a line divider → primary. Native cards: Row grade only, «إعلان» pill, never in the first viewport, ≤ 1 per 4 items, never in المحل's grid or the casebook, CTA as a 40 dp rim button.

## 6. In-match aids (role-identical)
Fixed status line (table screens: «الليل · 3 من 8», «النهار · النقاش · 2:58»; in-hand: the phase word only «الليل» / «النهار», no count, name or timer); «؟» rules sheet on table screens only (all roles listed in fixed order); public pass line «والباقي يبصّوا بعيد»; day stepper «الكلام ← التصويت ← النتيجة»; «شوف كارتك تاني» for everyone through the standard pass + hold gate, text-only card. Bone-shaped button in-match uses the neutral fill, same size/position on every night screen including the pass screen; confirm stays a long-press («دوس ثانيتين عشان تكمل»). Forbidden: role-only tips, "your role" shortcuts, private recaps, path-dependent countdowns, confirm haptics, role art on in-hand surfaces.

## 7. First run
One screen «نكلّمك إزاي؟» (ولد / بنت) with a passive terms line → home as guest. Name asked first time online or on a casebook claim; onboarding deck/video moves into «إزاي نلعب». Fastest path: «ابدأ اللعبة» → «ضد الكمبيوتر» → «ابدأ الماتش» — 3 taps from home, 4 from install including «نكلّمك إزاي؟» (8 players, classic, normal preselected).

## 8. Risks and guards
1. «السجل» moves → keep the word as a profile tab + a Row in the casebook. 2. Coin pill pushy → hidden until first match, no animation. 3. Two apps feel → shared text/type/button geometry + seam golden test. 4. Tabs hide things → ≤ 4 text tabs, remembered, home cues (dot, invites count). 5. 360×640 crowding / half-migrated paths → migrate by user path, check 360×640 and 430×932.
Widget test: character art and NarratorEmpty banned from night/day/pass surfaces and from «شوف كارتك تاني»; in distribution only the existing `RoleCard` face may render art. Verified 2026-10-08: all seven roles carry a night-special string; keep the slot in the golden tests.

## 9. Rollout (by user path)
1. Tokens + kit, no visible change; Doc 05 guard test.
2. Home + mode + bots sheet together.
3. Stories hub + case.
4. Players / roles / groups.
5. Online entry (tabs) + lobby.
6. Profile (tabs incl. السجل, titles, characters).
7. المحل + scenario store + casebook (the only GoldButton homes).
8. Result.
9. Settings / how-to-play / help as sheets.
10. First run.
11. In-match aids (separate review against Doc 05).

## 10. Agreed screens, 2026-10-09 (HTML mockups, owner-approved; supersede §4 and §7 where they differ)
Mockups live in `build/` (not tracked): `play_choice_merge.html`, `players_roles_mockup.html`, `case_file_dark.html`, `store_drawers.html`, `result_mockup.html`, `settings_howto_mockup.html`, `first_run_full.html`.
- **Home**: only «ابدأ اللعبة» + the top row (profile, casebook, المحل with coins, how-to-play, settings). No stories button on Home.
- **«هتلعب إيه؟»** (merge of 1+2+4, with the flip): two equal playing cards fanned like Home's, Mafia and «قصص وتحقيقات». Stories card → stories hub. Mafia card lifts to the top, scales down, flips to the card back, and deals three small cards out of itself: «مع صحابك» / «أونلاين» / «ضد الكمبيوتر», each with its player count; title cross-fades to «المافيا»; back (arrow, rim «رجوع», or the turned card) reverses it. No sheet.
- **Online screens**: frozen, not redesigned.
- **«مين بيلعب؟»** (option 1 of `players_4ways.html`, dealt grid): saved groups as chips on top; add row (name + ولد/بنت + «+»); each player is a dealt Mafia card (Mafia avatar, never story busts, name plate, seat number), flies out on remove; long-press lifts a card and dragging moves it to another seat; «كمّل» disabled below 5 with the count still needed.
- **«الأدوار»**: presets «عادي / صعب / على مزاجك» (any edit → custom); a big, spread fan of every seat's card above; one balance sentence; role rows (arched face, name, one-line power, − n +); citizens computed; «أدوار تانية»; bone «وزّع الكروت».
- **Dark case file** (profile, casebook): dark brown paper (#30251C→#241B14, edge #4A3A2C), light ink, crimson stamps (#C4574B). Profile = file with photo, fields, stamp, paper-tab dividers «شخصياتي · ألقابي · السجل». Casebook = dark cork board with pinned notes and red string; a finished note is stamped «اتقفلت» and coins fly to the pill.
- **المحل «السوق السودة»**: search + «اللي عندي»; one «وصل جديد» card; **drawers** (one per category: أدوات الماتش، صوت الراوي، أجواء الأوضة، شكلك، الباقات), each peeking three items, its count and how many owned — a new category is one more drawer. Inside: other drawers as chips, a 2-column grid with price tags, «عندك» stamp, ▶ preview for narrators. Buy sheet: big item, kind + once/permanent, gold button with price, «هيفضل معاك X» or «ناقصك X» (disabled), stamp «اتباع» on purchase, then «استخدم».
- **Result**: full-bleed outcome art + Ruqaa verdict, stamp (green «القضية اتقفلت» / crimson «محدش وقفهم»), «كنت …» card, a line from that character, every seat's card flips in turn (✕ on the dead), coin rows then total counts up and flies to the pill, casebook progress; bone «العب تاني» + rim «الرئيسية» pinned. «ملف الماتش»: MVP + night-by-night timeline + «شارك الملف».
- **Settings / «إزاي نلعب»**: sheets over Home. Settings: الصوت (narrator on + pick with preview, music, volume, vibration), قواعد الماتش (discussion minutes, open/secret vote, doctor self-save, reveal on death), عام (language, notifications, reduce motion), links (account, feedback, privacy); auto-save with an «اتحفظ» toast, no save button. How-to: a paged booklet (الفكرة، الليل، النهار، التصويت، مين يكسب، الأدوار with flip cards), one-minute video, FAQ accordion.
- **First run** (3 steps, progress dots): deck fans into the logo → «نكلّمك إزاي؟» with the generic hooded boy/girl avatars (`AppImages.avatarMale/Female`) as two big cards, one checkbox «عندي 18 سنة أو أكتر، وموافق على الشروط والخصوصية» (cards dimmed and shake until checked), «English» in the corner → «اسمك إيه؟», the chosen card lands and the name is written on its plate live, «كمّل» from 2 letters → «نحفظ لعبك؟» (only with a server): what is kept, Google / email / «بعدين، العب كضيف» → Home with «أهلاً يا <name>» once. Sound/music/motion leave first run (defaults, in settings); the video moves into «إزاي نلعب».
- **Stories (dark case file)**: archive = one folder per case (tab with its number, clipped cover photo, Ruqaa title, category/minutes/difficulty, stamp «لسه مفتوحة» / «اتحلّت 4/5», locked = red wax seal + how it unlocks, title stays readable), category chips. Solo investigation: «اسمع القضية» narrator bar (play/pause, waveform, progress; the real narration), synopsis, move pips that dim as spent, each move pins its clues as Ruqaa paper notes on «اللي لقيته», unaffordable moves dim, pinned «أنا عرفت مين». Accusation: three Ruqaa questions (مين / ليه / إزاي), suspect photos lift with a red frame, «اقفل القضية» → stamp «اتحلّت» with the score.
- **Stories with friends**: case + cast (each player gets a suspect) → pass «الملف ده لـ X» + hold → private dossier identical for every seat, culprit included (photo, who you are, «اللي لازم تعمله», three clue notes, same 5 s before it hides) → table: discussion timer, narrator replay, cast lineup with who plays whom → shared search (table move budget, turn passes, clues pinned for all) → secret ballot pass (مين/ليه/إزاي, long-press confirm) → reenactment timeline lit moment by moment with the narrator → who solved it, the culprit's star for hiding well; bone «قضية تانية», rim «الرئيسية».
- **«ضد الكمبيوتر» sheet**: «على الترابيزة» stepper 5–10 with your avatar card and the computer's cards fanning in, three level cards with faces and one line each (سهل/عادي/صعب), gold reward line per level, small «الأدوار … والراوي» line, bone «ابدأ الماتش» → the table fills seat by seat with names, then «الليلة الأولى». (Centre the art in polish.)
- **Offline and online matches**: unchanged for now (owner, 2026-10-09); the HTML match mockup/simulation is reference only and its rule simplifications are not adopted.
- **Order agreed**: agree every screen → final polish pass on all mockups → implementation (plan: `docs/plans/DECK-IMPLEMENTATION-PLAN.md`, executed by Sonnet 5.5 medium).
