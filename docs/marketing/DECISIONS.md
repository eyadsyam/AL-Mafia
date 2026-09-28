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
