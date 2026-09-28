# PLAN-V3 — Mafia Master · سيد المافيا — month-1 income plan

Final plan from the four-round debate (2026-09-28). Supersedes `PLAN.md`. Creative detail
is in `CONTENT-SYSTEM.md`, dates and operations in `LAUNCH-RUNBOOK.md`, decisions in
`DECISIONS.md` (Round 7), terms in `CONTEXT.md`. Nothing is published before «ابدأ شغل».

**Tags:** **[V]** verified 2026-09 · **[E]** estimate · **[A]** assumption. Every dollar
figure is month 1 (L → L+30), middle case, unless stated.

---

## 1. The month-1 income plan in one screen

The owner's priority: income from the game itself in month 1. The honest line:

| | Middle case |
|---|---|
| Month-1 installs | ~8,700 [E] |
| Average DAU | ~960 [E] |
| **AdMob** | **~$86** [E] |
| In-app purchases (net, one number) | ~$20 [E] |
| Target: **AdMob alone ≥ $100** | **~$14 short today** |

**What gets it over** (any one, with normal ad serving; details §3):

1. D7 retention +1 point (10% → 11%) → ~$103 [E].
2. Ads reachable in «القعدة» between matches → ~$104 [E].
3. Invite loop K from 0.4 → 0.5 → ~$103 [E].

**Plan for two of them, not one** — each alone clears $100 by a thin margin. The
precondition for all of them: AdMob serving is normal in L-week (§3, lever 4). If it is
"limited", month 1 lands near $43 and no lever saves it.

**Where the money is made:** month 1 is overwhelmingly ads, and ads are DAU × eCPM. So
the plan spends on three things only: a concentrated L-day spike, retention, and the
invite loop. Everything that does not move those is cut or parked (§3).

---

## 2. The model

Inputs from `docs/BIG-UPDATE-EGYPT-ECONOMICS.md` in the 1.1 worktree [E]:

| Input | Low | Middle | High |
|---|---|---|---|
| eCPM rewarded / automatic / banner | $0.8 / 0.4 / 0.03 | $1.5 / 0.8 / 0.08 | $2.5 / 1.3 / 0.15 |
| Fill | 70% | 85% | 95% |
| Ad revenue per DAU-month (Egypt) | — | ~$0.068 | — |

- Online matches per player per day rise with DAU (rooms need ≥ 5): 0.05 at 10 DAU,
  0.9–1.0 at 1,000+ [E].
- Retention: D1 30%, D7 10–12%, D30 ~5% [A]. Active days per install in month 1:
  3.0 / 3.3 / 3.6 [E]. Each D7 point ≈ +20% DAU [E].
- Rewarded extra clue + streak-save: +7% on ads [E].
- Gulf players earn ~4× an Egyptian player [A, unverified]; Gulf share of DAU 3% / 8% / 15% [A].
- IAP: 0.3% of installs buy, ~$0.82 net each [E].

### The funnel

| | Pessimistic | Middle | Optimistic |
|---|---|---|---|
| Pre-launch views, all platforms | 0.8M | 2.5M | 8M |
| Pre-registrations per 1k views | 0.5 | 1.0 | 1.5 |
| Pre-registrations | 400 | 2,500 | 12,000 |
| Pre-registration → install | 35% | 50% | 65% |
| Installs from pre-registration | 140 | 1,250 | 7,800 |
| Month-1 views | 1M | 3M | 10M |
| Installs per 1k views | 0.3 | 0.8 | 1.5 |
| Installs from content | 300 | 2,400 | 15,000 |
| Creator lives × installs each | 3 × 100 | 6 × 300 | 10 × 700 |
| Seed installs | 740 | 5,450 | 29,800 |
| Host-invite multiplier 1/(1−K) | 1.2 | 1.6 | 1.9 |
| **Month-1 installs** | **~900** | **~8,700** | **~56,600** |
| **Average DAU** | **~90** | **~960** | **~6,800** |
| AdMob base | $4 | $65 | $480 |
| + streak-save / extra clue | $0.3 | $4.5 | $34 |
| + Gulf uplift | $0.4 | $17 | $231 |
| **AdMob total** | **~$5** | **~$86** | **~$745** |
| AdMob if serving is limited (×0.5) | $2 | $43 | $370 |
| IAP (net) | $1 | $20 | $140 |

All rows [E]. The middle case needs ~5.5M views over ~10 weeks: in practice 1–2
breakout posts of 500k+ [E]. The plan maximizes shots on goal and clones any winner
within 24 h.

**AdMob ≥ $100 needs** ≈ 1,110 average DAU ≈ 10,100 installs at middle eCPM and 8% Gulf;
≈ 950 DAU at 15% Gulf; ~4× those at the low eCPM [E].

---

## 3. Month-1 income levers, ranked

Δ = change in month-1 AdMob at the middle case [E]. Owner: **M** marketing (this
session), **A** 1.1 app, **C** owner in Play Console / AdMob.

| # | Lever | Mechanism | Δ AdMob | Cost / owner time | Owner | Verdict |
|---|---|---|---|---|---|---|
| 4 | **AdMob serving normal in L-week** | Link the listing as soon as AdMob allows (try during pre-registration; else L 16:00) and request review; confirm fill at L 17:00 | protects **$43** | 15 min | C | **Keep — P0** |
| 1 | **L-day concentration** | Pre-registration push + auto-install + finale + creator lives + boost inside 48 h; aims at Egypt's new/free game charts | in base; chart placement +$9–17 | none extra | M + C | **Keep** |
| 2 | **Retention** | Streak-save; Case push at 20:00; «ليلة الخميس»; first-launch «شريكك» prompt that leads straight into the first case | **+$17 per D7 point** | app work | A | **Keep** |
| 5 | **Ads reachable in «القعدة»** | At low DAU most play is one phone in a room. Daily automatic slots (≤ 2/day) and rewarded offers on the on-table result screen between matches — never on in-hand screens, never mid-match | **+$18** if offline has no ad surface today | app work | A | **Keep** |
| 3 | **Invite loop K** | «ابعت للشلة» (§5). K 0.3 → 0.4 → 0.5 = multiplier 1.43 → 1.67 → 2.0 | −$12 at 0.3 · base at 0.4 · **+$17 at 0.5** | app work | A + M | **Keep** |
| 6 | **Rewarded menu** | Streak-save, extra clue, double coins on the result screen, Casebook claim ×2. Target ≥ 0.6 rewarded views / DAU / day | +$9 (0.4 → 0.6) | app work | A | **Keep** |
| 7 | **Launch window** | Earliest valid Thursday (§4) | Dec 17: $83 · Jan 28: $107 | none | C | **Keep the earliest** |
| 10 | **Content volume** | Installs per extra 1M views: TikTok ~800, FB/IG Reels ~500, **YouTube Shorts ~500** | +$10–13 per 1M TikTok views, ~+$8 per 1M Shorts/Reels | production budget | M | **Keep; add Shorts** |
| 11 | **Creators** | Each extra Creator-room live ≈ 300 installs × 1.67 | ~+$5 per live | ~20 min/day owner DMs | M + owner | **Keep** |
| 8 | **IAP** | Season Pass launch price (L → L+14, 59.99 EGP from 79.99); remove-forced-ads product at 49.99 EGP | IAP ~$20 total, a small number | Console setup | A + C | **Keep, expect little** |
| 12 | **Paid tranches** | $3 Meta boost at L-14 (measure cost per pre-registration); $4.5 at L only if tranche 1 ≤ $0.20 per pre-registration | < $1 directly; its value is measurement and amplifying a winner | $7.5 | M | **Keep, small** |
| 9 | **Ad mediation / bidding** | Extra networks for eCPM in emerging markets | unknown | new SDKs + data-safety update + review risk at launch | A | **Park to 1.1.x** |
| — | Paid meme-page reposts | — | below boost on cost per reach [E] | over budget | — | **Cut** (free credited reposts only) |
| — | Anthem / licensed music | — | 0 | over budget, IP risk | — | **Cut** |
| — | Public-room promotion before rooms fill in < 2 min | — | negative (empty rooms churn) | — | — | **Park** |

### The middle case reaches AdMob ≥ $100 in month 1 if…

Normal serving (lever 4) holds, **and** any of:

| Combination | Month-1 AdMob [E] |
|---|---|
| D7 +1 point alone | ~$103 |
| Offline ad coverage alone | ~$104 |
| K = 0.5 alone | ~$103 |
| **D7 +1 point + offline coverage** (recommended target) | **~$123** |
| K = 0.5 + rewarded menu at 0.6 | ~$112 |
| Jan 28 window alone | ~$107 (but less money by any date, §4) |

---

## 4. The launch window

**Rule:** L = the earliest Thursday that is ≥ T+42, has 1.1 approved under managed
publishing, and is outside Jan 3–22 (university exams [V: 2025/26 pattern]). Ramadan
2027 (≈ Feb 8 – Mar 9 [E]) is the first big live event, «ليالي رمضان», not the launch.

| | Launch Thu Dec 17, 2026 | Launch Thu Jan 28, 2027 |
|---|---|---|
| Month 1 | Dec 17 → Jan 16 | Jan 28 → Feb 27 |
| Seasonality | Q4 eCPM for 2 weeks, exams in weeks 3–4 | winter break week 1, Ramadan weeks 2–4 (play shifts toward «القعدة») |
| Factor vs base | ×0.97 [E] | ×1.25 [E] |
| **Month-1 AdMob** | **~$83** | **~$107** |
| Cumulative AdMob crosses $100 | ~L+37 (≈ Jan 23) | ~L+28 (≈ Feb 25) |
| Cumulative AdMob by Feb 28 | ~$208 | ~$107 |
| Cumulative AdMob by Mar 31 | ~$295 | ~$200 |

Post-month-1 tail assumed ~$2.5/day, ×1.25 in Ramadan [A]. **The earliest launch makes
more money by every date**, and reaches Ramadan with six weeks of players, reviews and a
tuned funnel. Dec 24 and Dec 31 are valid under the rule but put exams in weeks 2–4; the
owner may prefer Dec 17 or Jan 28 over them.

---

## 5. Loop 2 — «ابعت للشلة» (the invite loop)

The host is the unit of acquisition: every online host needs 4–7 friends.

**Trigger moments (never at signup):**

| # | Moment | Default message (first person, editable) |
|---|---|---|
| 1 | Host has created a room and has < 5 players — the core trigger | «فاتح أوضة مافيا دلوقتي وناقصنا ناس، ادخل 👇» + link |
| 2 | Result screen after a match | «لسه مخلصين ماتش وعايزين رماتش، تعالى 👇» + link |
| 3 | After solving «قضية اليوم» | «حليت قضية النهارده في ٣ محاولات 🟥🟥🟩 وإنت؟» + link |
| 4 | After the founder letter opens | «فتحت رسالة الختم الأول… فيها دليل محدش عنده.» + link |

**Share action:** one tap → WhatsApp with the message pre-filled and the personal room
link; the player can edit before sending. No marketing tone, no brand slogan in the text.

**Invitee landing:**
- Header: «{name} عازمك على أوضة مافيا».
- Primary button «ادخل من المتصفح» — joins the room in the browser right away; no install.
- Secondary: «عندي التطبيق».
- After the match: «نزّل التطبيق عشان تكمل مع الشلة» (#19).

**Reward (double-sided, released only when the invitee finishes their first online match):**

| | Proposed [E] | Why |
|---|---|---|
| Inviter | 100 coins per qualifying friend | ≈ 4 eligible matches at 25 coins |
| Invitee | 50 coins | ≈ 2 matches; a first-session nudge |
| Weekly cap | 5 rewarded invites (≤ 500 coins/week) | anti-farming; the economy's daily caps still apply |
| Tier 1 friend | the coins above | |
| Tier 3 friends | title «كبير الشلة» | |
| Tier 10 friends | a cosmetic frame (candidate: an existing store frame) | |

The inviter is notified instantly: «{name} لعب أول ماتش — خدت ١٠٠ عملة». Sizes to be
validated against Economy option C (25 coins per eligible match + 10 for a win, 6
coin-eligible matches a day) in the 1.1 spec.

**Metrics (benchmarks [A]):** active referrers 5–15% of DAU · share rate 20–40% of prompt
views · invitee conversion 15–25% · **K = share rate × invites per sharer × conversion**,
target ≥ 0.4. Feeds dashboard loop 2 (`LAUNCH-RUNBOOK.md` §6).

---

## 6. Budget — $30 total

| Item | $ |
|---|---|
| Bake-off: the same still through Hailuo, Wan and Kling + a Seedance Egyptian-voice test | 2.0 |
| Shot library: ~80 Hailuo 2.3 Standard i2v shots × 6 s (≈ 480 s at ~$0.013/s) | 6.3 |
| Per-post new motion: trend-jacks and case beats, ~$0.03 × ~172 posts | 5.2 |
| 4 Kling 3.0 Standard hero loops ("the card comes alive"), reused everywhere | 1.7 |
| ~400 Soul 2 stills | 1.3 |
| Seedance 2.5 date trailer (15 s, 480p) | 3.1 |
| Doctor card (Grok Imagine 2.0 edit, ~10 tries) | 0.8 |
| Retry buffer | 2.1 |
| **Production** | **22.5** |
| Paid tranche 1 (L-14): Meta boost, measure cost per pre-registration | 3.0 |
| Paid tranche 2 (L → L+2): boost the winner, only if tranche 1 ≤ $0.20 per pre-registration; else back to production | 4.5 |
| **Total** | **30.0** |

Prices from the Higgsfield API explore pages [V: 2026-09-26], Kling at its post-Oct-1
rate. TikTok Ads Manager is out (minimum $50/day [V]); TikTok Promote only at ≤ $3/day.
Free tiers are watermarked [V] — tests only, never published. **If Hailuo fails the
bake-off** (Wan 3.0 at ~$0.025/s): library cut to 60 shots, Phase A to 1 post a day,
then P5 cut first.

---

## 7. Store listing (ASO) and search

Goal (owner): anyone searching for مافيا, لعبة المافيا, or anything near it finds us.
Honest limit: a new app ranks on install velocity, rating and retention plus relevance,
so relevance (below) gets us indexed and the L-day spike (§3, lever 1) gets us ranked.

**Policy guardrails [V: Play metadata policy]:** keywords live in natural sentences, never
as lists or repeated blocks; no competitor or trademarked names (Among Us, Town of Salem,
Spyfall, Werewolf-branded apps); no «الجاسوس» (not a feature we have); no "best", "#1",
"first"; no unattributed testimonials. Title ≤ 30, short description ≤ 80.

### 7.1 Title and short description

- **Title:** `سيد المافيا - لعبة المافيا` (26). English: `Mafia Master: Online Mafia` (26). Recount in the Console before saving.
- **Short description:** `لعبة المافيا أونلاين بالصوت مع صحابك، أو قعدة والموبايل هو الراوي` (~64). Store A/B test variant: `…ولغز جديد كل يوم`.

### 7.2 Arabic keyword bank

| Cluster | Phrases people type [E] |
|---|---|
| Core + spelling variants | مافيا · المافيا · مافيه · المافيه · ما فيا · لعبة مافيا · لعبة المافيا · لعبه المافيا · العاب مافيا · لعبة المافيه |
| Online / voice | لعبة مافيا اونلاين · مافيا أونلاين · مافيا بالصوت · لعبة جماعية بالصوت · العاب اونلاين مع الاصحاب · العاب صوتية |
| Language / origin | مافيا بالعربي · مافيا مصري · لعبة مصرية · لعبة عربي |
| Roles | القاتل والدكتور والمحقق · المافيا والدكتور والمحقق · لعبة القاتل · لعبة الأدوار · الراوي · المواطن |
| Gatherings | لعبة سهرة · العاب قعدات · قعدة صحاب · العاب سهرات · العاب جماعية · لعبة صحاب · العاب للأصحاب · العاب رمضان (from Ramadan) |
| Mystery | مين المافيا · مين القاتل · لعبة تحقيق · لعبة غموض · لعبة جريمة · لغز يومي · الغاز |
| Genre (once, as a mention) | المستذئب · الذئب |

### 7.3 English keyword bank

mafia · mafia game · online mafia · mafia voice chat · mafia party game · social
deduction · werewolf-style · murder mystery · who is the killer · detective game ·
daily mystery puzzle · party game with friends · group game · Arabic mafia · Egyptian
mafia game · Sayed El Mafia · Mafia Master.

### 7.4 Where each keyword goes

| Surface | What goes there |
|---|---|
| Title | «سيد المافيا» + «لعبة المافيا» |
| Short description | لعبة المافيا · أونلاين · بالصوت · صحابك · قعدة · الراوي |
| Description ¶1 (hook) | «لعبة المافيا اللي بتلعبها في كل قعدة… دلوقتي أونلاين بالصوت مع صحابك.» |
| Description ¶2 (online) | مافيا اونلاين · بالصوت · العاب اونلاين مع الاصحاب · كل واحد من بيته |
| Description ¶3 (table) | لعبة سهرة · العاب قعدات · الموبايل هو الراوي · من ٦ لـ ١٥ |
| Description ¶4 (roles) | المافيا · الدكتور · المحقق · المواطن · القاتل |
| Description ¶5 (daily) | قضية اليوم · لغز يومي · مين القاتل · لعبة تحقيق |
| Description ¶6 (origin) | مافيا مصري · بالعربي · لعبة مصرية؛ one mention of «زي المستذئب» |
| Spelling variants (مافيه، ما فيا) | **custom store listings only** — never in the main text |
| Custom store listings (if keyword targeting is offered) | (1) مافيا / المافيه / لعبة المافيا / mafia game · (2) العاب جماعية / صحاب / سهرات / قعدات · (3) مين القاتل / لغز يومي / لعبة تحقيق · (4) Gulf-country listings with the same Egyptian text |
| In-app events / promotional content titles | «ليلة الخميس: مافيا بالصوت» · «ليالي رمضان: لعبة المافيا كل ليلة» · «قضية اليوم: مين القاتل؟» |
| Screenshot captions | one keyword each: «مافيا بالصوت» · «لغز كل يوم» · «الموبايل هو الراوي» · «العب مع صحابك» |
| English listing | §7.3, in sentences |

- **Category:** a Games category (needed for game charts and promotional content).

### 7.5 Social search

TikTok and YouTube search are major discovery engines in Egypt [E]. Every video is
findable by «لعبة المافيا»:

- **Caption first line:** a natural sentence containing «لعبة المافيا» or «مافيا».
- **On-screen text:** the phrase appears in the first card or the CTA card.
- **Spoken:** P1 and P4 open with the Narrator saying it.
- **Hashtags:** 3–5 per post, per pillar — full table in `CONTENT-SYSTEM.md` §10. Always #لعبة_المافيا; plus #مافيا · #مين_المافيا · #العاب_جماعية · #سيد_المافيا as fits; #العاب_رمضان from Ramadan only.
- **YouTube Shorts titles:** «لعبة المافيا | [hook]».
- Never real people's names or competitor names as keywords or tags.
- **8 screenshots:** الأوضة · قضية اليوم · ملف القضايا · الأربعة · سهرة من ٣ · القعدة ·
  ليلة الخميس · كارت النتيجة. Promo video: the date trailer cut to 30 s.
- **Ratings:** in-app review prompt after a win or the third solved case.

---

## 8. App changes marketing needs in 1.1

| Must / should | Change | Why, in month-1 $ [E] |
|---|---|---|
| **Must** | Normal AdMob serving: listing linked, consent messaging for EEA/UK | protects ~$43 |
| **Must** | Streak-save rewarded + Case push at 20:00 | D7 +1 point ≈ +$17 |
| **Must** | First-launch «شريكك» prompt → straight into the first case; not skippable, asked once | retention; carries pre-launch attachment into the app |
| **Must** | Ad slots in «القعدة» on the on-table result screen between matches (never in-hand, never mid-match) | ≈ +$18 |
| **Must** | «ابعت للشلة» (4 triggers, WhatsApp share, browser join, double-sided reward, caps) | K 0.4 → 0.5 ≈ +$17 |
| **Must** | Case of the Day share grid → `/case/today` | loop 4; feeds installs and K |
| **Must** | Founder seal: pre-registration reward, founder title, letter with the extra clue | pre-registration conversion → L-day spike |
| **Must** | «القضية الأولى»: finale content locked until L, solve-rate stat | turns the finale audience into installs on L |
| **Must** | Install Referrer captured on every link; server-side, anonymous loop counters (+ privacy-policy line) | lets us move money to what works |
| **Must** | Creator entitlement (#34) + one-week viewer code (D6), server-side | creator lives ≈ +$5 each |
| **Should** | Rewarded menu: extra clue, double coins on result, Casebook claim ×2 → ≥ 0.6/DAU/day | ≈ +$9 |
| **Should** | Referrer → partner pre-select for the four side links | small retention gain |
| **Should** | Season Pass launch price L → L+14; remove-forced-ads product | part of the ~$20 IAP |
| **Should** | Milestone gifts (500 / 2k / 5k / 10k) as server grants | pre-registration momentum |
| **Should** | In-app review prompt | ranking and store conversion |
| **Should** | Four WhatsApp sticker packs, addable from the app | exposure, near-zero $ in month 1 |
| **Should** | Web "download the app" button (#19) | converts browser joiners |
| **Park** | Ad mediation / bidding partners | 1.1.x, after launch |

---

## 9. Risks and kill rules

| Risk | Rule |
|---|---|
| Limited ad serving in L-week | P0 checklist item, owner in AdMob, checked L 17:00 and daily to L+7 |
| AI-slop backlash | Kill a format at ≥ 15% anti-AI comments or completion < 25%; faceless and non-human cast is the defense |
| AI labels | Label every video as AI on every platform; clean masters, no cross-platform watermarks |
| Dialect | Any line not certainly natural Egyptian becomes on-screen text, not voice |
| New-account limits | 7 days without links; Facebook groups 2–3 a day; never the same text twice |
| IP / real people | No names, footage or likeness of real people; no licensed music; no competitor names |
| Violence policy | Deaths implied, never shown |
| 1.1 slips | No date announced before approval; cold cases run indefinitely |
| Empty rooms | Private rooms, Thursday nights and creator rooms only until public rooms fill in < 2 min |
| D1 < 20% | Product problem: stop all spend, fix onboarding first |

**Kill / pivot:** a format survives its 3-episode tournament at completion ≥ 30%, shares
≥ 3 and follows ≥ 5 per 1k views. At L-14, followers < 1,000 and pre-registrations < 300
→ drop drama, go all-in on case posts, creators and groups. At L+7, installs < 1,500 →
the L+7 rules in `LAUNCH-RUNBOOK.md` §5.

---

## 10. OWNER DECISIONS (open items only, each with a recommendation)

| # | Decision | Recommendation |
|---|---|---|
| 1 | Start **Phase A now** (accounts, warm-up, format tournament) with a scoped «ابدأ شغل» for Phase A only | **Yes** — every earlier week is audience at L |
| 2 | Target = **AdMob alone ≥ $100**; accept that the middle case is ~$86 today and the plan is built to close the gap | **Yes** |
| 3 | **Launch-window rule** (§4): earliest valid Thursday ≥ T+42, approved, outside Jan 3–22; Ramadan as the first live event | **Yes** — Dec 17 ≈ $83 month 1 but more money by every date than Jan 28 |
| 4 | Aim for **D7 +1 point + offline ad coverage** as the two levers that carry month 1 over $100 | **Yes** |
| 5 | **Ads in «القعدة»** on the on-table result screen between matches only | **Yes** |
| 6 | Add **YouTube Shorts** to FB / IG / TikTok | **Yes** — one extra upload per video |
| 7 | YouTuber reference: **generic wording only**, cold Creator-room DMs to their teams | **Yes** |
| 8 | **Real-app end card** on every video (2–3 s) | **Yes** |
| 9 | **4–5 s** real-app segment in P2 feature spotlights | **Yes** — a feature can't be shown honestly in AI |
| 10 | "100% AI video" includes **AI stills animated by us** | **Yes** — otherwise costs rise ~5× |
| 11 | **Paid money $7.5** in two conditional tranches (revises D3's ~$20) | **Yes** |
| 12 | The **$30 is the whole budget** until month-1 AdMob earnings pass $100, then revisit | **Yes** |
| 13 | Second approval window at **21:30** (~10 min) for replies and urgent trend-jacks | **Yes** |
| 14 | Owner creates an **Azure AI Speech (F0)** account for the Narrator's licensed voice | **Yes** |
| 15 | **Season Pass launch price** 59.99 EGP (from 79.99), L → L+14 | **Yes** |
| 16 | **Remove-forced-ads product** at 49.99 EGP | **Yes** |
| 17 | The four **sides framed as «شريكك»**, weekly standings normalized by side size | **Yes** |
| 18 | "Made in Egypt" angle as «لعبة مافيا مصرية، اتعملت هنا» — no "first" claim; his personal story optional | **Angle yes, personal story his call** |
| 19 | Meme pages: **free credited reposts only** | **Yes** |
| 20 | **No web «قضية اليوم» before L** unless the 1.1 web build is ready before production access | **No** otherwise |
| 21 | App category = a **Games** category | **Yes, confirm now** |
| 22 | Saudi, UAE and Kuwait in **pre-registration and availability** | **Yes** |
| 23 | **Instagram Trial Reels** for hook tests, if the account has them | **Yes** |
| 24 | Ad **mediation parked** to 1.1.x | **Yes** |

---

## 11. Facts still to verify

1. Whether AdMob accepts linking a listing that is only in pre-registration.
2. Real share of pre-registered users who get the launch-day auto-install.
3. Whether promotional content (launch event, «ليلة الخميس») can be scheduled before the first publish.
4. Whether keyword-targeted custom store listings are offered to a new app.
5. Gulf eCPM vs Egypt, to replace the ×4 assumption.
6. Hailuo 2.3 Standard i2v on Higgsfield: price, 9:16, quality (the bake-off answers it).
7. Seedance 2.5 native Egyptian audio quality.
8. Azure F0: ar-EG voices, SSML styles, commercial terms.
9. Whether the Install Referrer survives pre-registration → auto-install.
10. Limited-time price support for the Season Pass launch price (else a separate launch product that grants the same entitlement).
