# «نظام الكوتشينة» — the Deck design system (draft for owner sign-off)

Agreed and signed 2026-10-08 after five rounds between Claude (proposer) and an independent critic. Nothing here is built yet; waiting for the owner.

## 1. Foundation
The home screen is the source: Victorian monochrome playing cards (ink black, aged bone paper, engraved silver, arched portrait window, filigree back) on a dark oxblood backdrop, plus the characters on the cards.

- **Silver = structure** (frames, dividers, icons). **Gold = value only** (coins, rewards, purchases, claimable dots). **Bone = the one primary action**, exactly like home's «ابدأ اللعبة».
- Characters are the art language: any card with art uses the card-face recipe (bone hairline margin + dark arched window + figure, feathered at the bottom). **One face per viewport**, except the role picker where faces are the content (48×64 windows).
- Card motion only for literal cards (role flip, a bought card). Areas use one shared-axis slide.

## 2. Tokens
| Token | Value | Use |
|---|---|---|
| ground | `#140F0C` | public screens (with home vignette + weave) |
| panel | `#1F1813` | ArtCard, sheets |
| raised | `#2A211A` | pressed, selected chip, native-ad rows |
| line | `#3A2D23` | dividers |
| text / text2 / muted | `#F1E6D2` / `#C2BBB3` / `#9B978E` | |
| silver / silverLight | `#67635F` / `#9E9891` | frames, icons, rim buttons |
| bone | `#C2BBB3` (pressed `#A9A29A`) | primary button fill |
| gold | `#C9A45C` (+ `#F1DFA8`, `#7A5C26` gradient only) | value only; the three old golds merge into this |
| ink | `#1A120C` | label on bone/gold |
| seam | `#0E0807` | crossfade point warm↔neutral |

In-match private surfaces keep the neutral charcoal palette (Doc 05). Public pre-match screens (players, roles, lobby) and the result screen use the warm ground; the existing curtain crossfades through `seam` over 400 ms.

Type: Plex Sans Arabic everywhere; **Aref Ruqaa only** for story/case titles, the result headline and the casebook. Sizes 28 screen title (Bold) / 20 card title / 17 body+controls / 15 meta. Line height 1.6, letter-spacing 0, scale 1.0. Western digits.

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
