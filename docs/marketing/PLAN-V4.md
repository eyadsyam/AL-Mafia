# PLAN-V4 — Mafia Master · سيد المافيا — the plan built on what 1.1 ships

Converged on 2026-10-01 in a seven-round Claude ↔ Codex (gpt-6-sol, high) debate. Supersedes
`PLAN-V3.md` where they differ; V3 keeps its listing copy, keyword bank and guardrails except
where noted. Nothing public is posted before the owner says «ابدأ شغل».

Tags: **[V]** verified · **[E]** estimate · **[A]** assumption.

## 0. What changed from V3

1. **Truth audit.** V3 marketed things 1.1 does not ship: the Daily Case client was never finished
   (draft quarantined at `build/quarantine/case_of_day_sheet.dart.txt`, server flag off) [V]; the
   Gang how-to scenes (F18) are 1.1.1 [V]; family mode is out [V]; `/case/today` and
   `/p/<character>` do not exist [V]. All are removed from the listing, screenshots and videos.
2. **The web is open now.** saidalmafia.com runs the full 1.1. Phase W sends people to play on the
   web while Play is gated; Phase P starts when the production listing is **live**.
3. **One viewer is not a table.** Online and local play need five players [V:
   `start_match/index.ts:54`, `balance_guard.dart`]. Content alone cannot fill tables; staffed
   Thursday rooms, creators and organisers do. Completed matches are the score, not views.
4. **Testers by group and form.** The closed track now uses the Google Group
   `mafia-master-testers@googlegroups.com` (anyone can join; owners-only posting and member list).
   `saidalmafia.com/beta` takes a name and email, and one automatic email gives the three steps.

## 1. Phases and goals

| Phase | When | Goal |
|---|---|---|
| **W — web + testers** | «ابدأ شغل» → Play listing live | ≥ 12 testers continuously opted in (recruit ≥ 25, each asked for 2 matches); staffed Thursday nights that start; verified completed online matches (stretch 100, counted only once a privacy-safe counter verifies outcome + platform) |
| **P — Play** | listing live → +30 days | V3's Play scenarios as old scenarios; reforecast at L+7 from installs, D1 and completed matches |

**Date.** T = the day the 12th tester is continuously opted in. Earliest production access
≈ T + 14 days + access review, then the first-release review. L = the first Thursday event after
the listing is live; first availability itself is never promised for a Thursday. Planning
scenario: Thu Nov 5 [A]. No public date until the listing is live.

**Content-only sensitivity (5 weeks, 35 shorts) [E]:** 300 views/short → ~0 matches; 1,000 → ~3;
3,000 → ~32. 100 matches from content alone needs ~1.1M views at working rates. Liquidity comes
from hosts.

## 2. Channels

TikTok = discovery. Facebook = Egypt's largest audience (page, own group, owner's group posts).
Reels and Shorts (Shorts only with owner approval) = clean cross-posts. **WhatsApp channel** = the
owned retention channel: one tier-1 note a week signed by one of the Four, the Thursday call.
Bio link = the web game (a light landing page is an A/B, kept only if completed matches per 1,000
bio opens rise).

## 3. Content

**Five franchises (≥ 70% of posts), each closed by a real app beat:**

| Franchise | Strength proved | Group mechanic |
|---|---|---|
| «نور الشاشة» | the hand-off hides your role (verify on device) | forward |
| Gang situations | visibly marketing fiction; the real reveal carries the claim | tag |
| «خرجت؟» | witness view, as configured | question |
| «ليلة الخميس» | the weekly night — only when a staffed room exists | appointment |
| «الأثر» | morning trace from a finished match, labelled «ماتش تجريبي» until real 5-person play | «هتشك في مين؟» |

The fictional serial case and the Oct-29 finale «الدليل الرابع جوه اللعبة» are cut (it pointed at
the unbuilt Daily Case). Data shorts are cut (the server cannot produce those facts).

**Hooks (frame 0, muted, one idea):** «في قعدة المافيا… واحد بيحلف إنه مواطن.» ·
«خمسة صحاب؟ موبايل واحد يدير القعدة.» · «لسه بتختاروا مين يبقى الراوي؟» ·
«صاحبك عارف دورك من نور الشاشة؟» · «خرجت أول ليلة؟ شوف اللي بيحصل.» ·
«الخميس ٩. الترابيزة مفتوحة.» (only with a confirmed room) · «حمادة شلتكم بعد أول تصويت:».

**One CTA per post**, chosen by what the viewer can do: «ابعتها لشلتك» or the web/Play CTA.
**Cadence:** ≤ 7 shorts a week including reply videos; raise only on sustained quality and
completed-match evidence. **No audible narrator** in any video until the voice records (§6, G6).
**KPIs:** non-follower reach, 3-s hold, shares (diagnostic), link opens, five-player starts,
completed matches.

## 4. Loops

- **Lobby-shortage invite first:** evergreen text «تعال نلعب مافيا: <link>»; aggregate funnel:
  shortage shown → share tapped → link opened → joined → five ready → match completed.
- `/join/*` gets a generic preview (no host name, roster or status) — an improvement, not a gate.
- Sticker set of the Four and the Gang: pilot on two phones with WhatsApp's own sticker maker first.
- Daily Case (C4′): a conditional 1.1.x build, web first, behind seven gates (screen + route,
  salt fail-closed, spoiler-free share card, fresh-guest browser test, retry idempotency with
  `requestId`, bounded abuse, Doc 05 fiction). Never marketed before all pass.

## 5. Store listing (Play)

Title «سيد المافيا - لعبة المافيا»; short description from V3; full description from V3 minus the
Daily Case bullet, with the complete disclosure moved to the end; domain saidalmafia.com
everywhere. Screenshots (captured Android 1.1, short captions), in order: local table
«الموبايل هو الراوي» → voice room «العبوا بالصوت من أي محافظة» → concealed hand-off «التسليم يخبي
دورك» → trace «دليل من أحداث الماتش» → result reveal «كل دور يتكشف بعد النتيجة» → dossiers
«الأربعة فاكرينك» → witness «خرجت؟ تابع اللي بيحصل». One screenshot experiment after launch,
length set by Play.

## 6. Gates before sending people to play

| # | Gate | Status |
|---|---|---|
| G6 | Kratos (the default narrator) — origin + commercial-use record + listener gate, or a cleared default pack | **owner decision** |
| G1 | No Google banner in the online lobby/result while a room or voice is live | **owner decision** (conflicts with "never reduce ads") |
| G3 | One domain in every outward link | done in app texts (web/app rebuild pending) |
| G5 | Remove the referral offer line from the room-invite text | **owner decision** (product feature) |
| G7 | A recorded five-browser completed online match | open |
| G2 | `/beta` rewritten | done |
| G8 | Light landing page A/B | later |
| G9 | Daily Case C4′ | conditional |

## 7. Budget ($30, unchanged)

Real-app beats are free. ~$14 Higgsfield shot library after the S0 cost check, ~$2 retries,
stickers $0 (existing art). **$10 reserve** spent only after an organic winner, a tested
destination and a measured path to completed matches exist; otherwise it funds retries.

## 8. Kill / pivot (clocks start after two weeks of safe traffic)

Diagnose opens → lobbies → five-player starts → verified completions before stopping a CTA. Two
Thursdays that fail to start → pause countdowns until a staffed table is credible. Three posts are
too few to condemn a format. Ramadan 2027 is a second wave decided in mid-December from real
retention, host throughput and creative winners.

## 9. Owner list

1. G6 voice decision. 2. G1 and G5 decisions. 3. «ابدأ شغل». 4. Accounts: TikTok, Facebook page,
Instagram, WhatsApp channel. 5. Thursday safety host. 6. Daily approvals.
