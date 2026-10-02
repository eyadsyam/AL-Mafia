# How much does the game earn in Egypt? From 10 players upward (Claude)

Egypt only, in EGP. Starts at 10 players a day and includes the case where
**nobody pays at all**.
These are estimates, not promises. After the first 2 weeks of real play, every
ad rate here gets replaced by the real figures from the owner's AdMob account.

## Assumptions (all adjustable)
- **Exchange rate:** 1 USD = 50 EGP. AdMob pays in dollars. If the dollar
  moves ±15%, the ad income in EGP moves the same ±15%.
- **Ad rate for 1,000 views (eCPM), Egyptian Android audience:**

  | Case | Rewarded | Automatic (interstitial / app-open) | Banner | Fill |
  |---|---:|---:|---:|---:|
  | Pessimistic | $0.8 | $0.4 | $0.03 | 70% |
  | Middle | $1.5 | $0.8 | $0.08 | 85% |
  | Optimistic | $2.5 | $1.3 | $0.15 | 95% |

  These are planning figures, not a source. The owner's AdMob account is the
  only real source.
- **Views per player per day:**
  - Rewarded (voluntary): the daily ad and its extras, plus 2 offers per
    online match. Take-up is 25% / 35% / 45%.
  - Automatic: at most 2 a day (the agreed decision); on average 0.5 / 0.8 /
    1.2.
  - Banners: 2 / 4 / 8 impressions.
- **Online grows with player count — very important.** An online match needs
  ≥5 people in a room. With 10 players a day, a public room almost never fills,
  so most play is on one phone at home and the match ads barely happen.
  Assumed online matches per player per day, by daily players:

  | Players/day | 10 | 20 | 50 | 100 | 200 | 500 | 1000+ |
  |---|---:|---:|---:|---:|---:|---:|---:|
  | Online matches per player | 0.05 | 0.1 | 0.2 | 0.35 | 0.5 | 0.7 | 0.9–1.0 |

- **Purchases in Egypt:**
  - Monthly players ≈ 2.5–3.5 × daily players.
  - Monthly payer share: **0%** (nobody pays) / 0.1% / 0.3% / 0.8%.
  - Average spend per payer: 35 / 55 / 70 EGP.
- **What reaches the owner from each sale:** the Play price includes Egypt's
  14% VAT (assumed collected by Google), then Google's 15% fee. The owner keeps
  **74.6%** of the price:

  | Price | Owner receives |
  |---|---:|
  | 29.99 | 22.4 EGP |
  | 49.99 | 37.3 EGP |
  | 79.99 (season pass) | 59.6 EGP |
  | 99.99 | 74.6 EGP |
  | 180 | 134.2 EGP |

## Results — EGP per month (middle case)

"Ads only" is the **nobody-pays** case.

| Players/day | Ads only | Purchases | Total/month | Total/year | Months to AdMob's first payout ($100) |
|---:|---:|---:|---:|---:|---:|
| 10 | 22 | 4 | 26 | 314 | ~222 (practically never) |
| 20 | 46 | 7 | 54 | 644 | ~108 |
| 50 | 122 | 18 | 141 | 1,690 | ~41 |
| 100 | 265 | 37 | 302 | 3,621 | ~19 |
| 200 | 570 | 74 | 644 | 7,725 | ~9 |
| 500 | 1,559 | 185 | 1,743 | 20,919 | ~3 |
| 1,000 | 3,385 | 369 | 3,754 | 45,050 | ~1.5 |
| 2,000 | 7,038 | 738 | 7,776 | 93,314 | under a month |
| 5,000 | 17,595 | 1,845 | 19,440 | 233,285 | monthly |
| 10,000 | 35,190 | 3,691 | 38,881 | 466,569 | monthly |

### Pessimistic and optimistic (total/month in EGP)
| Players/day | Pessimistic (ads only) | Pessimistic total | Optimistic (ads only) | Optimistic total |
|---:|---:|---:|---:|---:|
| 10 | 5 | 6 | 69 | 84 |
| 20 | 10 | 12 | 142 | 171 |
| 50 | 28 | 32 | 371 | 444 |
| 100 | 63 | 70 | 791 | 937 |
| 200 | 139 | 152 | 1,677 | 1,970 |
| 500 | 388 | 421 | 4,514 | 5,244 |
| 1,000 | 861 | 926 | 9,669 | 11,130 |
| 10,000 | 9,030 | 9,682 | 99,892 | 114,507 |

## What these numbers honestly mean
1. **Below 100 players a day, the game earns almost nothing.** A few pounds a
   month, and **AdMob pays nothing until the balance reaches $100**. At 50
   players a day that takes more than 3 years; at 100 players, about a year and
   a half.
2. **Ads, not purchases, are the Egyptian income.** Even in the middle case,
   purchases are only about 10% of the total. So the most important design
   decision is that the rewarded ads (the voluntary ones) are *worth watching*
   and appear in every match — not that we push people to pay.
3. **The real driver is player numbers, not ad rates.** From 500 to 1,000
   players a day, income more than doubles, because online rooms start filling
   and the match ads start working. Everything that brings players back and
   fills the tables (series, «ليلة الخميس», friends, «قضية اليوم») is
   effectively revenue work.
4. **Costs (must be deducted):**
   - Supabase: the free tier is enough early on, but it has limits (e.g.
     concurrent connections, bandwidth, and pausing an inactive project). Once
     online play really grows it will need **Pro ≈ $25 ≈ 1,250 EGP/month**.
   - Vercel: the free tier is for non-commercial use. A website carrying ads
     or payments needs **Pro ≈ $20 ≈ 1,000 EGP/month**.
   - **Break-even (middle case) is around 600–700 players a day** if both paid
     tiers are needed. Before that, the game costs more than it earns — unless
     it stays on the free tiers.
5. **Egyptian seasons:**
   - Ramadan after iftar is the biggest play peak, and ad rates usually rise in
     Ramadan and Q4.
   - Exam seasons drop play.
   - Thursday is the week's best night.
   - A rough multiplier for a Ramadan month is ×1.5–2 on income, but that is an
     estimate to verify later.

## What changes in the plan because of this
- **Fill the tables before selling.**
  - At launch, focus on «ليلة الخميس» (players concentrated at one time
    instead of scattered), plus friends and invite links.
  - Quick match shows «فيه X مستنيين» only when the number is honest.
- **Rewarded ads are the core.** Give them a worth-it reward, never force
  them, and show them in pass-and-play too (the daily ad, the wheel), because
  that is where most early play happens.
- **Season pass at 79.99:** its value in Egypt is a strong offer, not the main
  income. Keep it, but don't build expectations on it.
- **Sensible Egyptian prices:** 29.99 / 49.99 / 79.99 are fine. 180 is the
  "whale" price, and very few in Egypt will buy it — keep it for the rare
  high spender.
- **Watch costs:** stay on the free tiers as long as the traffic allows, with
  an alert before any limit is reached (usage metering already exists in the
  project).
- **After two weeks of launch:** replace every ad rate with the real figures
  from the AdMob account, and recalculate this table.
