# Round 10b (sign-off) and marketing round M1 — Sol critiques Claude's proposals

Claude proposed; Sol criticised (owner roles, 2026-09-28). Part A edits are applied to
`BIG-UPDATE-1.1-FINAL.md`. Part B went to the marketing session as round 5.

## Part A — FINAL sign-off deltas

| Item | Verdict | Reason |
|---|---|---|
| **A1 Ownership** | **ACCEPT** | Owner direction is unambiguous: Claude owns all implementation; Sol owns adversarial review and image generation. State the launch-critical estimate honestly as ≈5,900 minutes/98 hours before device and rollout time. |
| **A2 M5 correction** | **MODIFY** | The diagnosis is correct, but `.lt("night", phaseNumber)` alone is insufficient: same-night updates must also preserve `used_bullet = existing.used_bullet OR requested.used_bullet`, so a later non-bullet submission cannot refund a committed bullet. Estimate 20–25 minutes plus race/retry tests. |
| **A3 M6 whisper replay** | **ACCEPT** | For a once-per-day message, exact recipient plus exact stored body is a valid replay identity. On mismatch, keep the generic refusal. Add concurrent-identical and different-recipient tests. |
| **A4 Month-one target** | **MODIFY** | Use total game income ≥$100 as the target and ads ≥$100 as stretch. At the FINAL’s Egypt-middle bands, 1,000 active devices/day gives about $58 ads + $13.5 in-app purchases; therefore ≈1,400 devices/day reaches $100 total and ≈1,730 reaches $100 ads. Do not mix the separate Gulf assumption into the Egypt baseline. |
| **A5 Defer four direct premium packs** | **ACCEPT** | They add large art, catalogue and QA scope against an expected ≈$13.5/month per 1,000 active devices. L keeps the three coin packs, Starter Bundle, Quiet Pass and Season Pass. |
| **A6 First-release listing** | **MODIFY** | The strength-first direction is correct, but two claims need correction and the prose should be tighter. |
| **A7 Creator night 21:00** | **ACCEPT** | Aligning creators with «ليلة الخميس» concentrates rooms and creates one memorable weekly ritual. |
| **A8 Founder lore-only** | **ACCEPT** | It preserves puzzle equality and character attachment without turning an offer into the story. |

### A6 listing critique

The title and short description are strong, natural and search-relevant. The full description needs three edits:

- Replace «مفيش راوي يغش» with «مفيش حد يقعد برا اللعب أو ينسى خطوة»; accusing human narrators of cheating creates unnecessary negativity.
- «كل الأدوار بتشوف نفس الشاشات» is false: private information differs. Use: «التسليم له نفس المدة والإضاءة لكل الأدوار، فالموبايل ما يفضحش دورك».
- The witness bullet is accurate inside the app but advertises the owner-accepted external-messaging risk. Safer copy: «بعد خروجك تتابع الحقيقة من غير ما تأثر على الأحياء داخل اللعبة.»

«المستذئب» is a generic genre reference, but it adds little after «مين القاتل». Keep it once in a natural final sentence, never in a keyword list and never name competing apps. The screenshots and trailer are materially better than the old reward-led versions.

---

## Part B — Marketing Round M1

### Verdict

The plan is strategically strong enough to pursue the owner’s goals and now respects the strength-first principle.  
Its strongest pieces are the narrator problem, recurring Daily Case, Partner identity and creator-hosted tables.  
Its forecasts remain too optimistic because “DAU” still confuses humans with active devices and the invite multiplier treats browser joins as installs.  
AI-only content can build a following, but only through recognizable recurring characters and rituals—not sheer post volume.  
The single biggest weakness is distribution realism: the plan assumes millions of views before proving one unmistakable repeatable format.

### C1–C11 verdicts

| Proposal | Verdict | Evidence and modified version | Estimated month-one effect |
|---|---|---|---|
| **C1 Small-country staged release** | **MODIFY** | Technically useful for making the listing public before the core launch, but it spends operational attention and can collect weak early reviews. Use one non-core country only with the complete playable build, no promotion, launch flags conservative, a 48-hour rollback gate and a target of merely 20–50 real sessions. Do it only if listing review cannot complete from pre-registration. | **Estimated:** protects roughly $20–35 of month-one ad income if it prevents limited serving; negligible direct installs. |
| **C2 Total-income $100 target** | **KEEP** | Corrects the owner-goal mismatch. Publish ads and in-app purchases separately beneath the total. Egypt-middle: ≈$71.5 total per 1,000 active devices/month; ≈1,400 devices/day for $100 total. | **Modelled:** target threshold, not incremental lift. |
| **C3 TikTok role effect** | **MODIFY** | Excellent fit, but a polished camera effect is not truly zero-cost: tracking, device testing and review consume time. Build the CapCut version first. Build the effect only after 10 creators agree to use it or the template produces ≥100 organic uses. The character must remain behind the user without implying their real personality or match role. | **Estimated:** template 20k–100k views and 50–250 pre-registrations; successful effect could exceed this materially. |
| **C4 Partner web quiz** | **MODIFY** | Strong attachment bridge and iPhone-compatible. Use four deterministic outcomes, six short questions, local-only name rendering, profanity filtering and no stored answers/name. Route through `/p/<character>`, not side. | **Estimated:** 5–15% share rate; at 10k visits, 100–500 pre-registrations. |
| **C5 Strength spine** | **MODIFY** | Ranking needs correction. “Identical screens” is inaccurate; witness mode is striking but should not lead because it foregrounds the accepted collusion risk. Phase A leaders: **(1) phone is the narrator, (2) the character rises behind the liar—then prove privacy-safe hand-off, (3) voice rooms reunite distant friends.** Daily Case and the Four follow. Series/Rules wait until 1.1.3 exists. | **Estimated:** recognition-led hooks should improve completion 5–15% versus generic feature lists; verify through the three-post tournament. |
| **C6 Launch-case counter** | **MODIFY** | Never show a raw live counter or rate. Show a delayed rounded solve rate only after ≥50 solves, exactly matching the product privacy floor. The finale can say «آلاف دخلوا القضية» only if true. | **Estimated:** D1/D7 habit benefit; 2–5% uplift in case return rate is plausible but unverified. |
| **C7 Remove offer-led content** | **KEEP** | Correct. Replace videos 12 and 20, founder-extra-clue language, milestone-led Phase B opening and reward-first creator copy. Registration CTA promises access to the game, not a gift. | **Estimated:** probably neutral immediate installs, positive trust and follower quality. |
| **C8 Audience writes the season** | **MODIFY** | Do not turn a commenter’s real first name into a suspect; it creates moderation, consent and unwanted-targeting problems. Use «حط نظريتي في القضية»: a theory becomes a clue/red herring. Polls may choose which fictional Gang character disappears next from two pre-authored branches. | **Estimated:** comments +15–30% on participating episodes; little direct income without strong reach. |
| **C9 WhatsApp-first distribution** | **MODIFY** | WhatsApp is central to actual table formation, but “forwarding beats follows” is unverified. Do not put a forwarding CTA on every short; that becomes repetitive. Use it on one in three situation/case posts and every lobby shortage. Preserve following CTAs on serialized content. | **Estimated:** `K_join` +0.03–0.10; install effect much smaller. |
| **C10 Micro-creators play** | **KEEP with lower forecast** | This is the best low-budget acquisition lever. Require one rehearsal, browser-join test, safety host and creator clip rights. Six lives is a stretch but credible from 60–100 targeted DMs, not casual outreach. | **Estimated:** 3–6 lives × 50–200 installs = 150–1,200 installs; roughly $10–85 total month-one income at the Egypt-middle band. |
| **C11 Weekly meme kit** | **MODIFY** | To obey AI-video-first, supply 6-second looping reaction clips, transparent character reveals and blank caption zones—not static memes alone. No intrusive watermark; require credited repost copy. | **Estimated:** 20k–150k borrowed views/month if 2–5 pages adopt; 10–120 installs at present conversion assumptions. |

## Eight strongest attacks on the existing marketing plan

### 1. The income model still uses the wrong unit

At 960 **active devices/day**, the FINAL’s Egypt-middle bands imply approximately:

- Ads: 2,895 × 0.96 = **2,779 EGP ≈ $55.6**
- In-app purchases expected value: 675 × 0.96 = **648 EGP ≈ $13.0**
- Total: **≈$68.6**

A documented Gulf cohort may lift ads toward Claude’s revised ~$71, producing roughly $84 total, but it cannot silently be folded into the Egypt baseline. Fix every dashboard/model row from “players/DAU” to active devices, with local-only, online-only and mixed composition.

### 2. The invite K forecast is mathematically mislabelled

The plan computes `25% sharers × 4 recipients × 40% conversion = 0.4`, but that 40% includes browser joins, not installs, and multiple recipients may already be users.

Track separately:

- `K_join`: new match participants per host.
- `K_install`: new installs per host.
- `K_active`: invitees active again within seven days.

A credible starting example is `25% × 3 × 20% join = K_join 0.15`; if 25% of browser joiners later install, `K_install ≈0.038`. Do not apply `1/(1-K)` to installation forecasts until cohorts prove it.

### 3. The content volume is incompatible with quality and owner time

Two-and-a-half to three polished AI shorts daily, trend monitoring, creator outreach, community replies and approvals cannot remain “strong production” within $30 and 1–2 hours/day. The 172-post budget implies cents per post and guarantees repetition.

Fix: 7–10 primary shorts/week:

- 3 Daily Case/story episodes
- 2 situations
- 2 feature proofs
- 1 character/letter ritual
- 0–2 trend/reply remixes

Cross-post clean masters; clone only demonstrated winners.

### 4. Faceless AI can earn views, but the following mechanism is underbuilt

People will not follow “AI Mafia clips.” They may follow Hamada dying first, the Detective’s file, a nightly solvable case and a recognizable Narrator ritual.

Fix recognition within the first half-second:

- Same lamp-click/card-flip sonic mark.
- Same five Gang faces and four character silhouettes.
- One recurring visual composition.
- “Yesterday’s answer” before today’s case.
- A pinned weekly schedule.
- At least 70% recurring franchises, at most 30% experiments.

Measure follows and returning viewers, not merely completion.

### 5. Five of the first twenty videos should be cut

Cut and replace:

- **#5 «الدكتور الأناني»**: teaches a shallow/negative version of the Doctor.
- **#8 «المحقق وأخوه»**: generic joke with weak product proof.
- **#12 «الختم الأول»**: obsolete unfair-clue promise.
- **#19 «سهرة من ٣»**: feature is deferred to 1.1.3.
- **#20 «٥٠٠»**: offer-led and dependent on a milestone.

Replace with phone-narrator proof, safe hand-off/zero-leakage proof, witness mode carefully framed, browser join and Partner memory.

### 6. Web joining is valuable, but the plan treats it as an installation funnel too early

A browser join primarily fills tonight’s room. Many users will leave afterward. That is still success because it prevents host churn.

Fix the web funnel:

1. Landing open.
2. Seat joined.
3. Match completed.
4. App CTA viewed.
5. Install/open attributed.
6. D7 active.

Forecast creator lives using match completions first. Treat installation as a secondary conversion until measured.

### 7. The keyword bank is research, not copy

Repeating spelling variants, “Mafia,” “killer,” “mystery,” “friends,” and genre terms across a description will read manufactured. New apps also cannot rely on keyword-targeted custom listings without known traffic.

Fix:

- Main title and short description carry core relevance.
- Full description uses each important phrase naturally once.
- Keep misspellings only for future measured listing experiments.
- One natural «المستذئب» genre reference is acceptable; no competitor names.
- Search ranking depends on launch velocity, conversion, ratings and retention—not keyword density alone.

### 8. Offers still contaminate the editorial system

Offer-led locations include Phase B access-day milestone announcements, videos 12/20, founder-extra-clue copy, CONTENT §1.6 finale, §1.7 milestone shorts, the founder invite text, “double coins” feature copy and parts of the creator package.

Fix: remove all from the editorial calendar. Milestones remain quiet product operations. Every public video must demonstrate narrator fairness, social play, voice, a case, a character memory, browser access, Thursday concentration or art quality.

## PLAN-V3 §10 owner decisions

| # | Verdict |
|---:|---|
| 1 | **Modify:** start Phase A only after Round M is frozen and S0 character consistency passes. |
| 2 | **Disagree:** target total game income ≥$100; ads ≥$100 is stretch. |
| 3 | **Agree:** earliest qualified Thursday; seasonality remains sensitivity, not certainty. |
| 4 | **Modify:** D7 and local-table coverage are priorities, not guaranteed $100 levers. |
| 5 | **Agree.** |
| 6 | **Agree.** |
| 7 | **Agree:** generic reference only. |
| 8 | **Modify:** real-app closing proof on every feature/explainer and most other videos; do not ruin a strong comedy loop merely to force it. |
| 9 | **Agree.** |
| 10 | **Agree.** |
| 11 | **Modify:** a $3 measurement tranche is statistically weak; reserve the full $7.50 for the strongest organic winner around L. |
| 12 | **Agree**, using total income as the review threshold. |
| 13 | **Agree.** |
| 14 | **Agree**, after one consistency and naturalness bake-off. |
| 15 | **Agree.** |
| 16 | **Disagree:** keep the frozen Quiet Pass price of EGP 199.99, not 49.99. |
| 17 | **Agree.** |
| 18 | **Agree:** Egyptian-made angle; personal story optional. |
| 19 | **Agree.** |
| 20 | **Agree:** no public Daily Case before L. |
| 21 | **Modify:** Games → Board is the best current category fit; verify at listing setup. |
| 22 | **Agree**, while modelling Egypt and Gulf separately. |
| 23 | **Agree if available**, never plan around it. |
| 24 | **Agree.** |

## First idea to kill

Kill the **raw “commenter becomes a suspect” mechanic** first. It creates consent, harassment and moderation risk while adding almost no durable distribution advantage. The stronger replacement—putting a viewer’s theory into a fictional case—delivers the same ownership and comment incentive without turning a real person into an accused character.