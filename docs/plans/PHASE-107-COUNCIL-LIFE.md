# Phase 107: Council Life (engagement and growth)

Server half: `supabase/migrations/20260925000300_council_life.sql`, `supabase/functions/_shared/economy_actions.ts`.
Tests: `supabase/tests/council_life.sql` (11 gates), `supabase/tests/council_life.test.mjs`.
The client half (the Council hub, toasts, celebration and Starter Bundle UI) is built from this document next.

## 1. What the player gets

| Feature | Rule | Coins |
|---|---|---|
| Daily contracts | 3 per UTC day, drawn deterministically per player and day. Slot 0 is always a "finish" contract, so one match can always complete something. Slots 1 and 2 come from two other groups. | 15–40 each, plus 30 for completing all three |
| Weekly contract | Finish 10 online matches in the ISO week (Mon 00:00 UTC). | 150 coins + 150 XP |
| Council Rank | 30 XP per completed match, +20 for a win (losers still get 30). XP stops after 20 matches in a UTC day. Levels 1–50: level L needs `100(L-1) + 10(L-1)(L-2)` XP, which is 28,420 for level 50. | 25 per level, 100 at every 5th level, 300 at level 50 (2,175 total) |
| Weekly leaderboard | Top 50 by XP earned this ISO week, plus the caller's own position. | none |
| Invite a friend | Each player has a 7-character code. A new account (≤ 7 days old, no completed online match yet) can redeem one code, once. Both are paid only when the invitee completes an online match. | Inviter 100 (at most 20 invites), invitee 50 |
| Starter Bundle | One-time Play product `mm_starter_bundle`: 600 coins + the exclusive frame `frame_council_seal`. One per account. | paid |

Ethics check against `UPDATE-1.0.1-BUSINESS.md`:
- Nothing is lost by missing a day or a week. Unclaimed contracts simply end.
- Nothing is random-for-money.
- Coins buy cosmetics only.
- There are no countdowns designed to pressure the player. The "resets in" line is plain information.
- The bundle is a permanent offer, not a limited-time deal.
- Rank titles are cosmetic and grant nothing in the match.

## 2. Zero leakage (Doc 05)

- Progress, XP and invite payouts come only from rooms with `status='finished'` and a public `outcome` (`mafia`/`town`). This is the moment the result screen flips every card (doc 12 "Result"). A live match changes no read. Gate C10 asserts that every read is byte-identical before and after roles are dealt.
- Records store the **team**, never the role, and are pruned after 21 days. Only the owner ever sees their own progress.
- The leaderboard returns name, gender (for the avatar), equipped frame, level/title and week XP. It returns no user ids, no per-match rows, and no team or role (C7, C10 scan the JSON). Blocked pairs are hidden from each other.
- Client rule: show contract toasts and the level-up celebration **only on the result screen or later**, never during a phase. The client must not poll Council reads while in a match.

## 3. Capabilities

`capabilities` now also returns the following (all `false` on a fresh migration or a missing config row):

```json
"council": { "contracts": false, "rank": false, "leaderboard": false, "invites": false,
             "starterBundle": false, "starterBundleOwned": false }
```

`products` lists `mm_starter_bundle` (`kind:"bundle"`, `coins`, `item`) only while `starterBundle` is on, the product is active, and the account does not own one. The client hides every Council surface whose flag is false. An old server answers `BAD_REQUEST` to the new actions, which the client reads as "absent".

Operator switches (in `economy_config`): `council_contracts_enabled`, `council_rank_enabled`, `council_leaderboard_enabled` (also needs rank), `council_invites_enabled`, `starter_bundle_enabled`. The bundle additionally needs `play_products.active=true` and a Console product.

## 4. API contract (POST `economy`, body `{action, ...}`; caller from the session)

Every read first settles invite rewards and records the caller's finished matches. Reads return `{"enabled":false}` when the feature is off. Claims raise `FEATURE_OFF` (409) when it is off.

### `contracts_get` → `council_contracts`
```json
{ "enabled": true, "day": "2026-09-25", "nextDayAt": "2026-09-26T00:00:00Z",
  "contracts": [ { "slot": 0, "code": "finish_1", "metric": "finish", "target": 1,
                   "progress": 1, "coins": 15, "claimed": false, "claimable": true } ],
  "bonus":  { "coins": 30, "claimed": false, "done": 0 },
  "weekly": { "week": "2026-W39", "nextWeekAt": "2026-09-28T00:00:00Z", "target": 10,
              "progress": 4, "coins": 150, "xp": 150, "claimed": false, "claimable": false },
  "levelUps": [ { "level": 2, "coins": 25 } ] }
```
Metrics: `finish`, `town`, `mafia`, `win`, `host`, `reunion` (finished a match alongside someone you finished another match with in the last 7 days).

### `contract_claim` `{day:"YYYY-MM-DD", slot:0|1|2}` → `claim_council_contract`
Returns the same status plus `granted`, `bonusGranted` and `balance`. A replay returns `granted:0`.
Errors: `DAY_REQUIRED`, `DAY_CHANGED` (refetch and redraw), `CONTRACT_INCOMPLETE`, `DAILY_PAUSED`, `FEATURE_OFF`.

### `weekly_claim` `{week:"YYYY-Www"}` → `claim_council_weekly`
Returns the status plus `granted`, `xpGranted`, `levelUps` and `balance`.
Errors: `WEEK_REQUIRED`, `WEEK_CHANGED`, `CONTRACT_INCOMPLETE`, `FEATURE_OFF`.

### `rank_get` → `council_rank`
```json
{ "enabled": true, "xp": 650, "level": 5, "tier": 1, "titleAr": "مبتدئ", "titleEn": "Newcomer",
  "maxLevel": 50, "levelXp": 520, "nextLevelXp": 700, "nextReward": 25, "weekXp": 650,
  "levelUps": [] }
```
`levelUps` is non-empty exactly once per level: it drives the celebration. Level coins are paid lazily, on the first Council read after the XP lands.

### `leaderboard_get` → `council_leaderboard`
```json
{ "enabled": true, "week": "2026-W39", "nextWeekAt": "…",
  "entries": [ { "position": 1, "xp": 900, "name": "Laila", "gender": "female",
                 "frame": "frame_gilded", "level": 7, "tier": 2,
                 "titleAr": "مخبر", "titleEn": "Informant", "me": false } ],
  "me": { "position": 12, "xp": 240 } }
```
Ties share a position. `me.position` is `null` when the caller has no XP this week.

### `invite_get` → `council_invite`
```json
{ "enabled": true, "code": "K7QM2XA", "inviterCoins": 100, "inviteeCoins": 50, "cap": 20,
  "rewarded": 3, "pending": 1, "redeemed": { "at": "…", "rewarded": false },
  "canRedeem": false, "redeemUntil": "…" }
```

### `invite_redeem` `{code}` → `redeem_council_invite`
The code is trimmed and uppercased at the edge and must be 7 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. Returns the invite status plus `status`:
- `"redeemed"`: success. Replaying the same code is also a success.
- `"not_found"`: the code does not exist. This is not an error, and it counts toward a limit of 10 misses a day.

Errors: `INVITE_SELF`, `INVITE_EXPIRED`, `INVITE_NOT_NEW`, `INVITE_ALREADY`, `INVITE_LOOP`, `INVITE_LIMIT`, `INVITE_RATE_LIMIT`, `FEATURE_OFF`.

### Starter Bundle (`play_purchase` `verify`, unchanged endpoint)
The response has `kind:"bundle"`, `granted`, `alreadyOwned`, `credited`, `coins`, `item`, `needsAcknowledge` and `needsConsume:false`.
- The client must **never consume** the bundle and must not use autoConsume.
- A second purchase on the same account returns `alreadyOwned:true`. It is left unacknowledged, so Play refunds it automatically.

Refunds and voids use the coin-pack rules:
- Unspent purchased coins leave the wallet. The rest becomes purchase debt.
- Debt that the bundle had paid off comes back.
- Earned coins are never touched.
- The frame is removed (and unequipped) because it was the purchased good itself.

## 5. Screens (client half)

1. **Vault → "Council" tab** (next to Rewards / Store), shown when any Council flag is on:
   - **Rank card**: emblem for the tier, title, level, XP bar (`levelXp` → `nextLevelXp`), and the next reward.
   - **Today's contracts**: three rows with icon, text, progress `n/target`, coins and a Claim button. A bonus strip marks all three done. A small "resets at 00:00 UTC" line, with no ticking countdown.
   - **Weekly contract**: one wide card.
   - **Leaderboard**: a sheet opened from a "This week" button. Top 50 rows show position, avatar with frame, name, rank chip and XP. The caller's row is pinned at the bottom when outside the top 50.
   - **Invite**: the code in large type, Copy and Share (system share sheet), counters for "rewarded n/20" and "waiting", and a "Have a code?" field while `canRedeem`.
2. **Result screen**: after the outcome reveal, one compact toast per contract that became claimable (for example "Contract complete: Finish a match as town +25"), linking to the Council tab. There is no claim inside the result screen, and nothing appears before the result.
3. **Level-up celebration**: a bottom sheet with the new emblem, title and coin amount. It respects reduced motion and the sound/haptics settings, and is shown once per `levelUps` entry after the result screen.
4. **Starter Bundle**: a card in the Play tab showing the frame preview, "600 coins + Council Seal frame" and the localized price. Hidden when owned.

All styles use design tokens. Arabic uses line-height 1.6 and letterSpacing 0. Text scale is locked at 1.0. Touch targets are at least 48 dp.

## 6. Copy (AR / EN)

| Key | Arabic | English |
|---|---|---|
| councilTab | المجلس | Council |
| contractsTitle | عقود اليوم | Today's contracts |
| contractsReset | تتجدد الساعة 00:00 بتوقيت UTC | Renews at 00:00 UTC |
| contractFinish1 | أكمل مباراة واحدة | Finish 1 match |
| contractFinish3 | أكمل 3 مباريات | Finish 3 matches |
| contractTown | أكمل مباراة في صف المدينة | Finish a match on the town side |
| contractMafia | أكمل مباراة في صف المافيا | Finish a match on the mafia side |
| contractWin1 | افز بمباراة | Win a match |
| contractWin2 | افز بمباراتين | Win 2 matches |
| contractHost | استضف مباراة حتى نهايتها | Host a match to the end |
| contractReunion | العب مجددًا مع من لعبت معهم | Play again with someone you've played with |
| contractClaim | استلم | Claim |
| contractClaimed | تم الاستلام | Claimed |
| contractsBonus | أكمل العقود الثلاثة: +{coins} | Complete all three: +{coins} |
| weeklyTitle | عقد الأسبوع | Weekly contract |
| weeklyBody | أكمل {target} مباريات هذا الأسبوع | Finish {target} matches this week |
| weeklyReward | +{coins} عملة و{xp} نقطة خبرة | +{coins} coins and {xp} XP |
| rankTitle | رتبتك في المجلس | Your Council rank |
| rankLevel | المستوى {level} | Level {level} |
| rankNext | {xp} نقطة للمستوى التالي · +{coins} | {xp} XP to next level · +{coins} |
| levelUpTitle | ارتقيت إلى {title} | You rose to {title} |
| levelUpBody | المستوى {level} · +{coins} عملة | Level {level} · +{coins} coins |
| leaderboardTitle | الأعلى هذا الأسبوع | Top this week |
| leaderboardYou | ترتيبك: {position} | Your position: {position} |
| leaderboardNone | العب مباراة لتدخل القائمة | Play a match to enter the board |
| inviteTitle | ادعُ صديقًا | Invite a friend |
| inviteBody | عندما يُكمل صديقك أول مباراة أونلاين: أنت +{inviter} وهو +{invitee} | When your friend finishes their first online match: you +{inviter}, they +{invitee} |
| inviteCopy | انسخ الرمز | Copy code |
| inviteShare | شارك | Share |
| inviteCounters | مكافآت: {n}/{cap} · بانتظار: {p} | Rewarded: {n}/{cap} · Waiting: {p} |
| inviteHaveCode | لديك رمز دعوة؟ | Have an invite code? |
| inviteRedeemed | تم تسجيل الدعوة. أكمل مباراة لتحصلا على المكافأة | Invite saved. Finish a match to unlock both rewards |
| inviteNotFound | الرمز غير صحيح | That code doesn't exist |
| inviteSelf | لا يمكنك استخدام رمزك | You can't use your own code |
| inviteExpired | الدعوات للحسابات الجديدة خلال 7 أيام فقط | Invite codes are for new accounts within 7 days |
| inviteNotNew | الدعوات قبل أول مباراة فقط | Invite codes work before your first match |
| inviteAlready | استخدمت رمز دعوة من قبل | You've already used an invite code |
| inviteLimit | وصل صاحب الرمز إلى الحد الأقصى | This code has reached its limit |
| inviteRateLimit | محاولات كثيرة، حاول غدًا | Too many tries, try again tomorrow |
| resultContractToast | اكتمل عقد: {name} +{coins} | Contract complete: {name} +{coins} |
| bundleTitle | حزمة البداية | Starter Bundle |
| bundleBody | 600 عملة + إطار ختم المجلس | 600 coins + Council Seal frame |
| bundleOwned | تمتلك حزمة البداية | You own the Starter Bundle |
| frameCouncilSeal | ختم المجلس | Council Seal |

Rank titles (tier = every 5 levels):
1. مبتدئ Newcomer
2. مخبر Informant
3. حارس الليل Night Watch
4. محقق Investigator
5. وجيه Notable
6. عضو المجلس Councillor
7. كابو Capo
8. مستشار Consigliere
9. شيخ المجلس Council Elder
10. عرّاب Godfather

## 7. Art (drawn in code — `lib/ui/economy/council_art.dart`)

Built as vector painters (owner, 2026-09-25: Codex unavailable), crisp from 22 dp to 112 dp, colours in `CouncilLifeTokens`:
- `RankEmblemPainter`: 10 tiers — bronze shields with 1–3 chevrons (1–3), gold with a laurel (4–6), obsidian with gold trim and a crimson gem (7–9), the Godfather's obsidian, bright gold, star and crown (10). `RankEmblem(shimmer:)` passes one light across a newly earned emblem; still under reduced motion.
- `ContractIconPainter`: hourglass (finish), house (town), fedora (mafia), laurel (win), key (host), linked rings (reunion).
- `paintCouncilSeal` / `CouncilSealArt` / `StarterBundleArt`: the wax-red ring with gold hairline and eight studs, used on the table, in the collection and as the bundle's cover.
- `CoinBurst`: coins radiating once over the claim button; nothing under reduced motion.

The original art brief follows for reference.

### Art needs (original brief)

- 10 rank-tier emblems. Transparent WebP, 128² (rendered at 40–64 dp), with a shared silhouette family in ivory/gold/burgundy. Tier 10 is the only fully gold one.
- 6 contract icons, 96² transparent: finish, town, mafia, win, host, reunion. They must be readable at 32 dp and must not reuse role-card art.
- `frame_council_seal` in the existing frame format (same size and anchor as `frame_gilded`), plus a store cover for the Starter Bundle card (same spec as the store_v2 covers).
- An optional invite illustration (≤ 256², transparent). The level-up sheet uses the tier emblem, so no extra art is needed there.

## 8. Anti-farm summary

- XP stops after 20 matches a day. Each match grants XP once (a primary key per user and match).
- Contracts count only finished rooms with a public outcome, and never kicked seats.
- Invites have these guards:
  - Not your own account.
  - The redeeming account must be ≤ 7 days old with no completed match.
  - One redemption per account, and no mutual pairs.
  - At most 10 unknown-code attempts a day.
  - The inviter is paid at most 20 times.
  - Payment happens only after an online match completes.
- Coins are non-transferable, so throwaway invitees gain nothing for the farmer beyond the capped inviter reward.

Hosted concurrency rests on the wallet advisory locks. Invite settlement takes both locks, sorted, first. This path has not been proven on PGlite.

## 9. Owner decisions (2026-09-25) and the client half

- **Leaderboard opt-out** — `council_preferences.leaderboard_visible` (default on), action `leaderboard_visibility {visible: bool}` → `set_council_leaderboard_visible`; `rank_get` returns `leaderboardVisible`, `leaderboard_get` returns `visible`. A hidden player never appears in anyone's entries (nor is ranked for others) but still gets `me.position`. Switch in the leaderboard sheet and the profile screen. Privacy: `web/privacy/index.html` (AR/EN) and `privacySummaryBody`.
- **Starter Bundle refund removes the frame** — confirmed. The client buys it with `buyNonConsumable` and only acknowledges (`finishEntitlement`) a granted bundle; an `alreadyOwned` answer is left unacknowledged for Play to refund (tested).
- **Anti-farm "same account tag" = not self; account age via `auth.users.created_at`, unknown = refused** — accepted as designed.
- **Rematch contract** — "finished a match alongside someone you finished another with in the last 7 days", accepted.
- **Rank on seats** — `seat_cosmetics()` now adds `rank` (level from XP, only while rank is on) at join; fixed for the match; `SeatCosmetics.rank` → `CouncilSeatData.rank` → a 22 dp crest on the ring, drawn only where frames are (public phases: lobby, day, result).
- **Concurrency** — external gate.

Client files: `lib/ui/economy/{council.dart,council_hub.dart,council_art.dart}`; vault tab in `coin_store.dart`; result strip in `online_table_flow.dart` (only when `outcome` exists); attention dot on the compact vault button (coffer/wheel/contract claimable, Home only); bundle card in `play_offers.dart`; switch in `profile_screen.dart`.

## 10. Web payments (hybrid)

Play build: Play Billing only, no link/QR/mention (unchanged guard test). Web build (`WEB_COIN_SALES=true`): choose a pack → tap "Pay with InstaPay / Vodafone Cash" → the configured page opens inside the tap as a real `<a target=_blank rel=noopener>` link and the order is created alongside → come back, enter the transfer reference → pending review. Links come only from the server secrets `COIN_PAY_INSTAPAY_URL` / `COIN_PAY_VODAFONE_CASH_URL`.

Quiet Pass on the web — migration `20260925000400_web_quiet_pass.sql`: `coin_packs.entitlement` (`quiet_pass`, 0 coins, seeded inactive and unpriced); approval grants `remove_interruptions` through a `coin_order:<id>` purchase row (no token hash, no order id, so Google's void sync can never touch it); refund removes it; an owner gets `ALREADY_OWNED`. The web shows no ads, so the copy says it carries to the Android app on the same linked account. Operator: set `price_piastres` and `active=true` on `quiet_pass`.
