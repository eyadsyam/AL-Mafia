# Marketing plan — decisions log

Settled in the grilling session that started 2026-09-26. Terms per `CONTEXT.md`.

## Round 1

| # | Decision |
|---|---|
| 1 | Launch waits on Google's testing period; its exact length does not change the plan. |
| 2 | Online (الأوضة) is the priority product; Table mode (القعدة) stays in every campaign as the second message. |
| 3 | Egypt first. Content in Egyptian colloquial Arabic **and** English; the rest of the Arab world is covered by the same content, not a separate launch. |
| 4 | Success metric: **installs**. |
| 5 | Production runs on the Higgsfield API, pay-per-second (video) / per-image. Higgsfield is the only paid spend. |
| 6 | The page's face is AI: the Narrator (الراوي) + the Gang (الشلة). No real people. |
| 7 | Tone ~70% comedy / 30% cinematic, all inside the painted charcoal-and-bone look. |
| 8 | Facebook groups: posted from the owner's personal profile, 3–5 groups/day, varied wording, conversation-first; plus our own group. |
| 9 | Owner time: 1–2 hours/day. Owner presses publish; Claude writes, prompts, schedules. |
| 10 | Platforms: Facebook, Instagram, TikTok. |
| 11 | Creators: micro (10k–150k), paid in-kind only — in-game items and Creator rooms. |
| 12 | Play Store listing (ASO) is in scope and ships before launch. |

## Round 2

| # | Decision |
|---|---|
| 3′ | **Revises 3:** Egyptian colloquial Arabic only — no English on screen, no English captions, one account per platform. Other Arab countries are reached by Egyptian, which they already understand. |
| 13 | Budget this month: **$30 total**, no more. (Higgsfield Pro is $43/mo; Basic $9/mo has no unlimited models; plan "unlimited" does not work over the API.) Route settled in round 3. |
| 14 | Any free tool is allowed (CapCut, Meta Business Suite, free TTS, screen recordings, trending audio). |
| 15 | Name on every platform: **سيد المافيا \| Mafia Master**. Owner creates the accounts; no email exists for them yet. |
| 16 | First weeks promote **private rooms by link** only. No "Mafia hour"; public rooms are not pushed yet. |
| 18 | Launch campaign targets version **1.0.1**. |
| 19 | App changes approved: shareable end-of-match card, "download the app" button on the web room page, invite reward. Tracked as separate engineering tasks. |
| 20 | Nothing is published until the whole strategy is agreed and prepared; the owner starts it with the words «ابدأ شغل». |

## Round 3

| # | Decision |
|---|---|
| 21 | **All $30 on the Higgsfield API**, no subscription. Model roster in round 4. |
| 22 | A dedicated Gmail for the game is created by the owner once the plan is confirmed. |
| 23 | Owner delegates all production to Claude (voice, editing, tools). Claude picks the best free tools. |
| 24 | The comedy Gang stays; the card characters join the plan (how: round 4). |
| 25 | Claude does all production, including screen recordings on the emulator. |
| 26 | 1.0.1 date unknown. Plan is written in L-day offsets; a dedicated announcement video ships when the date is known. |
| 27 | Creator focus: Egyptian gaming streamers (Creator rooms) + board-game cafés (Table nights). Comedy pages and student groups reached through group posts. |

## Round 4

| # | Decision |
|---|---|
| 21′ | Models: **Soul 2** (Gang stills), **Kling 3.0 Standard image-to-video** (almost every clip), **Seedance 2.5** (the 1.0.1 date announcement only). Arabic text is typeset by Claude, never generated. Free stack: Edge TTS `ar-EG`, ffmpeg, the app's own score, emulator recordings. |
| 28 | Gang (comedy) and Card cast (cinematic) are two worlds joined by one recurring beat: a Gang member looks at their card and the card comes alive. |
| 29 | Doctor card: the cross is replaced **inside the painting only**; frame, border, typography and layout untouched. Engineering task; must still pass the L-04 card-face luminance/hue tests. |
| 30 | Creators get a **creator account**: no ads at all, everything unlocked. Viewer codes: an upgraded bundle with fewer ads. |
| 31 | Posting approval is **daily**, not weekly, via a scheduled task. |
| 32 | The weekly report is its own scheduled task. |

## Round 5

| # | Decision |
|---|---|
| 33 | Replace the Doctor's cross in all five places (chest + four corner pips). **No serpent** — the Doctor protects, and a snake reads as danger. Replacement symbol: see round 6. |
| 34 | Creator access = a server-side **Creator** entitlement on their normal Play install (no ads, everything unlocked, revocable). No separate APK. Engineering task in 1.0.1. |
| 35 | Viewer code = upgraded bundle + **forced ads removed for good** (interstitial, app-open, banner). Opt-in rewarded ads stay available for every kind of reward. |
| 36 | Daily approval 11:00 Cairo; weekly report Sunday 21:00 Cairo; both run on the owner's machine and are created at «ابدأ شغل». |

## Round 6

| # | Decision |
|---|---|
| 37 | The Doctor's figure wears a **white doctor's coat**; the chest cross goes. Optional stethoscope around the neck. |
| 38 | The coat is **white-in-shadow**: side-lit, heavy shadow, darker ground, so the whole card stays inside the L-04 ±2% luminance / 3-level hue budget. Only a candidate that passes the real test ships; the budget is never widened; if none passes, back to the owner before any file changes. |
| 39 | Corner pips: the four small crosses become **small stethoscopes**, same size, place and tone. |

**Frontier empty — shared understanding reached 2026-09-27.** Next: `PLAN.md`, then «ابدأ شغل».

## Round 7 — the debate (2026-09-28)

Four rounds between this session and the 1.1 planning session, plus owner answers
relayed from there. Supersedes `PLAN.md` with `PLAN-V3.md`, `CONTENT-SYSTEM.md`,
`LAUNCH-RUNBOOK.md`. "Owner" = decided by the owner; "Debate" = agreed by both sessions,
still inside the owner's standing rules; "Open" = listed in PLAN-V3 §10.

| # | Decision | Source |
|---|---|---|
| 4′ | **Revises 4:** the goal is month-1 income. Target = **AdMob alone ≥ $100**. DAU and online matches are the operating metrics; installs are the leading indicator. | Owner (D2 + priority message) + Debate |
| 18′ | **Revises 18:** launch on **1.1**, the first public release. 1.0.x stays in closed testing. L-day = 1.1 live in production. | Owner (D1) |
| 3″ | Egyptian Arabic only still holds for content. The Play listing also gets an English localization for search only. | Debate |
| 6′ | **Hard condition:** 100% of content is AI video. The only real footage is the real-app end card (2–3 s; 4–5 s in feature spotlights, if the owner allows). | Owner |
| 10′ | Platforms: Facebook, Instagram, TikTok; **YouTube Shorts added if the owner agrees**. | Open |
| 21″ | **Revises 21′:** Hailuo 2.3 Standard i2v for volume, Kling 3.0 Standard for four reusable hero loops, Seedance 2.5 for the date trailer, Soul 2 for stills, Grok Imagine 2.0 edit for the Doctor card. **Azure AI Speech F0** replaces Edge TTS (licensed). Final split only after a $2 bake-off. | Debate |
| 40 | Budget: ~$22.5 production built as a reusable **shot library**, ~$7.5 paid in two conditional tranches (Meta boosts; TikTok Promote ≤ $3/day). TikTok Ads Manager is out ($50/day minimum). | Debate (revises owner D3) |
| 41 | Content = standalone shorts in six pillars P1–P6; the daily case is one pillar. | Owner message + Debate |
| 42 | Cast: the Four **write, never speak**; the Narrator is the only voice; the Gang carries comedy through stills, no lip-sync. Spoiler rule: tier-3/4 bond lines and letters are app-exclusive. | Debate |
| 43 | YouTuber reference: generic wording only («اليوتيوبرز», «١٤ على ترابيزة واحدة»). No names, footage, faces or hashtags of real people. Cold Creator-room DMs to their teams. | Debate |
| 44 | Launch window: L = the earliest Thursday that is ≥ T+42, approved under managed publishing, and outside Jan 3–22. Ramadan is the first live event, not the launch. | Debate (owner confirms) |
| 45 | Pre-registration opens only after production access, and only if the 1.1 ETA is ≤ 60 days away. Reward = the **founder seal** (one lifetime product, server grant, letter with an extra clue to «القضية الأولى»). Milestones 500 / 2k / 5k / 10k as server grants. | Debate (verified gate) |
| 46 | **Publish at 16:00** on L (Thursday); finale 20:00; first «ليلة الخميس» 21:00. Never announce a date before approval. | Debate |
| 47 | Approvals twice a day: **11:00** content, **21:30** replies and urgent trend-jacks. The 09:00 trend radar is Claude's. | Debate (extends 31/36) |
| 35′ | **Revises 35:** the viewer code removes forced ads for **one week**. Creator accounts (#30/#34) unchanged. | Owner (D6) |
| 48 | Additions approved by the owner: WhatsApp channel, character sticker packs, in-app «ابعت للشلة». | Owner (D4) |
| 49 | Attribution: Play Install Referrer on every link; four side links pre-select «شريكك»; a first-launch partner prompt is the must, the pre-select a bonus. | Debate |
| 50 | Loop counters are server-side, anonymous and aggregate; no third-party analytics SDK. | Debate |
| 51 | Ad mediation / bidding partners parked to 1.1.x. | Debate (owner confirms) |

## Round 8 — Codex critique (2026-09-28)

Codex (Sol) critiqued PLAN-V3 / CONTENT-SYSTEM / LAUNCH-RUNBOOK and eleven proposals from
the 1.1 session; the owner added two principles; the 1.1 spec froze some product facts.

| # | Decision | Source |
|---|---|---|
| 52 | **P-A:** every public video proves a real strength of the game; rewards are never the headline of a video, hook or CTA. Phase B CTA: «سجّل من جوجل بلاي، والعبها أول ما تنزل». | Owner |
| 53 | **P-B:** 1.1 is the first public release; never «تحديث». | Owner |
| 4″ | **Revises 4′:** target = **total income from the game ≥ $100 in month 1** (ads + in-app purchases, as totals); **ads alone ≥ $100 is the stretch**. | Codex C2 (owner confirms) |
| 54 | Model unit = **active devices/day**, Egypt bands from the 1.1 spec (~$58 ads + ~$13.5 IAP per 1,000 devices/month, middle). Gulf is a separate line; Ramadan is upside only. Honest middle ≈ 475 devices ≈ $34 total. | Codex attack 1 |
| 55 | K is split into **K_join, K_install, K_active**; start K_join ≈ 0.15, K_install ≈ 0.04; no 1/(1−K) on installs until cohorts prove it. | Codex attack 2 |
| 56 | Volume = **7–10 primary shorts a week**; shots on goal come from hook re-cuts per platform; clean masters; clone only proven winners. Season 1 = ~15 episodes, 3 a week. | Codex attack 3 |
| 57 | Recognition kit (sonic mark, fixed faces/silhouettes, recurring composition, yesterday's answer first, pinned schedule); ≥ 70% recurring franchises. Measure follows and returning viewers. | Codex attack 4 |
| 58 | First-20 list: cut «الدكتور الأناني», «المحقق وأخوه», «الختم الأول», «سهرة من ٣», «٥٠٠»; replaced by strength proofs (phone narrator, hand-off, careful after-you're-out view, browser join, Partner's memory). | Codex attack 5 |
| 59 | Web-join funnel tracked in six steps; creator lives forecast by match completions first. | Codex attack 6 |
| 60 | Keyword bank = research, not copy; store listing uses the frozen 1.1 copy; spelling variants only for measured listing experiments. Category Games → Board. | Codex attack 7 + 1.1 spec |
| 61 | Offer sweep: no founder "extra clue", no milestone shorts, no reward-first creator copy, no "double coins" copy, no founder invite trigger in marketing. | Codex C7 + attack 8 |
| 45′ | **Revises 45:** the founder letter is lore only — no clue, no elimination, no extra attempts. «القضية الأولى» solve rate only at ≥ 50 solves, rounded to 5%. Milestones are quiet product operations. | 1.1 spec |
| 62 | Phase A leads with: the phone narrator → the character behind the liar + privacy-safe hand-off → voice rooms across governorates; then the case and the Four. The after-you're-out view never leads. Series/Draft and House Rules not marketed before 1.1.3. | Codex C5 + 1.1 spec |
| 63 | Audience in the story via «حط نظريتك في القضية» and polls between two pre-authored branches; **viewers' names never become suspects or victims**. | Codex C8 |
| 64 | WhatsApp forward CTA on one in three situation/case posts and every lobby-shortage moment; follow CTAs on serialized content. | Codex C9 |
| 65 | Creators: 60–100 targeted DMs → 3–6 lives × 50–200 installs; rehearsal, browser-join test, safety host, clip rights; Thursday 21:00. Pitch is the game, access mentioned last. | Codex C10 |
| 66 | Growth assets after «ابدأ»: CapCut template «كل واحد وكارته» first (Effect House only after 10 creators or ≥ 100 uses); web quiz (6 questions, 4 deterministic results, nothing stored, `/p/<character>`); meme kit (6 s loops, credited reposts, no intrusive watermark). | Codex C3, C4, C11 |
| 67 | **C1 staged-release fallback** (conditional, L-10) only if AdMob can't link during pre-registration. | Codex C1 (owner decides) |
| 40′ | **Revises 40:** no $3 measurement tranche; the full $7.5 is reserved for the strongest organic winner around L. | Codex (owner decides) |
| 68 | At L the store has: Season Pass (launch price L → L+14), Quiet Pass (permanent, EGP 199.99), Starter Bundle, coin packs. Direct premium cosmetic packs move to 1.1.x. | 1.1 spec |
| 69 | Phase A starts only after this round is frozen and the **S0 art-consistency test** passes. | Codex (owner decides) |

## Round 9 — gap and game (2026-09-28)

Codex's M2 verdicts on closing the month-1 gap, and the closed 1.1 game plan.

| # | Decision | Source |
|---|---|---|
| 54′ | **Revises 54:** honest middle ≈ **4,850 installs → ~536 devices/day (509 Egypt + 27 Gulf) → ~$34 ads + ~$7 IAP ≈ $41.5 total**. Favourable without a breakout ≈ 630 devices ≈ $49.5. $100 total needs ~1,400 devices ≈ 12,500–13,000 installs. **Planning number ≈ $60** with the creator network at mid-range. | Codex M2 |
| 70 | **N1 store organic:** middle 300 / upside 900 month-1 installs, ramp 5 → 10 → 12 → 15/day; exact title, strong icon, narrator/voice/privacy as the first three screenshots, ≥ 4.5★ via the spec's neutral review prompt, fast review replies. A comparable Arabic Mafia app shows 100K+ lifetime at 4.4★ — demand, not a rate. | Codex N1 |
| 71 | **N2 organisers:** trips, camps, scouts, university «أسر», board-game groups; admin-approved, 2–3 placements a week; printable QR host card + host page + dedicated link; middle +250 installs (100–500); one table = one earning device; never target religious identities. | Codex N2 |
| 44′ | **Revises 44:** the rule stays "earliest Thursday that passes every gate"; **Thu Feb 4, 2027** is the late-January contingency, not a deliberate delay. Ramadan is sensitivity only (+25–50% ⇒ +$8–17). | Codex N3 |
| 72 | **Gulf:** a separate line; middle device share 5% (3–8%); Gulf ads ≈ 3× Egypt; the same creative feed; a clean Gulf store variant; no Gulf hashtags on every post. | Codex N4 |
| 73 | **The creator network is the controllable lever:** ~180 DMs → ~10 confirmed → ~8 rehearsed → **~25 sessions in month 1** → ≥ 4 completed matches each → 250–400 attributable installs per creator cohort (~2,600). Measured by completed matches. Clips from every session feed the content system. | Codex M2 |
| 74 | Creators at L **just play**: no creator/viewer codes or special access at L; codes arrive in 1.1.x under the one-week rule (#35′). | 1.1 spec |
| 75 | New launch strengths marketing must show: **F16 «صوت الراوي»** (the same narrator voice in app and videos, public beats only), **F19** reveal signature and sonic mark, **F15** 15-player table in < 4 min a night, **F17 «وضع العيلة»**, **F18** how-to scenes and tabletop layout. | 1.1 spec |
| 76 | **One world:** the Gang's canonical art is the app's painted style (spec S9); marketing animates those stills. Soul 2 is used only for background plates. | 1.1 spec |
| 77 | The F19 reveal is the recurring closing shot of «مواقف» and the default end card; the app's sonic mark opens every video. | Debate |
| 78 | **Never marketed before it ships:** creator/viewer codes, streak-save, extra clue, rematch vote, the Thursday letter, witness setting, last words, same-room phones, match chronicle, «مين صوّت على مين», scheduled public tables beyond Thursday, Series/Draft, House Rules. Thursday is the only fixed public-table ritual at L. | 1.1 spec |
| 79 | The Narrator's stories and our cases are fiction, never presented as in-game clues; no video implies mid-match death stories in the app; app narrator audio appears only on public beats. | 1.1 spec (constitution) |
| 80 | PLAN-V3 §8 becomes a pointer: the product side is frozen in the 1.1 spec. | Debate |
| 81 | Owner time: typical day ≈ 1 h; Thursday ≈ 2 h 25 because of the creator tables. The marketing session takes over all prospecting, drafts, calendar, host kit, clips and reporting; beyond ~6 sessions a week, cap sessions or the owner names a second safety host. | Debate (owner decides) |
