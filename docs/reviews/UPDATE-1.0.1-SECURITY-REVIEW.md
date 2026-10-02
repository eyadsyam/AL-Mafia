# Update 1.0.1 — independent security review and regressions

Reviewed: `supabase/migrations/20260925000100_update101_economy.sql`,
`functions/admob_ssv`, `functions/play_purchase`, `functions/play_voided_sync`,
`_shared/{ad_rewards,play_verify,economy_actions}.ts`, as of 2026-09-25.

Regressions: `supabase/tests/update101_security_regressions.sql`. Each gate runs
in its own rolled-back subtransaction; all failures are reported together.

```bash
node tool/test_sql_without_docker.mjs update101_security_regressions.sql
```

The assertions encode the required behaviour. They are not to be loosened to
match an implementation; a failing gate is a finding, not a flaky test.

## Gates

Gates that exercise a feature turn it on explicitly (`sec_enable`), because
features ship off (G10). The report block fails if fewer than 15 gates record.

| Gate | Requirement | Run 1 (pre-repair) | Run 2 (after 103b + 20260925000200) |
|---|---|---|---|
| G1 | v1/v2 mutual exclusion both ways; a tx id pays one claim across v1/step/daily; retries pay once; signed `user_id` must own the claim; refused commits register nothing | PASS | PASS |
| G2 | Step 1 + step 2 = base exactly (odd base 101) | PASS | PASS |
| G3a | Play: A500 spent+refunded → debt 500; B500 offsets fully (credit 0); refund B → debt **500** (not 0, not 1000); earned untouched; refund idempotent | **FAIL** debt 0 | PASS |
| G3b | Play: debt 500; B1200 → offset 500, credit 700; unspent refund takes 700, debt back to 500 | **FAIL** debt 0 | PASS |
| G3c | Play: as G3b, 100 spent → take 600, debt 600 | **FAIL** debt 100 | PASS |
| G4 | Token voided before its first verify is never credited later | **FAIL** credited | PASS |
| G5 | pending → voided → `active` replay stays revoked (coins and the pass) | **FAIL** credited | PASS |
| G6 | Coin pack with no `obfuscatedExternalAccountId` is not credited | **FAIL** credited | PASS |
| G7 | No `economy_config` row → no step/daily claims, no coins, capabilities not `true` | **FAIL** step claim created | PASS |
| G8 | Yesterday/tomorrow `p_day` → `DAY_CHANGED`; null `p_day` → `DAY_REQUIRED` (coffer, wheel, daily-ad); no rows | PASS (stale only) | PASS (stale + null) |
| G9 | No anon/authenticated execute on the new functions; definer functions pin `search_path`; no client writes on economy tables | PASS | PASS |
| G10 | Fresh migration: all four flags false in the row and explicit `false` in capabilities, no products; step/coffer/wheel/daily-ad → `FEATURE_OFF`; daily on alone does not enable the daily ad; only an explicit config update turns them on | — | PASS |
| G11 | Quiet Pass: pending→void→active, active→void (order only)→active, void-before-verify: never owned, `adFree` false | — (half of G5) | PASS |
| G12a | Manual coin orders, operator refund: same as G3a; second refund `ORDER_NOT_REFUNDABLE` | — | PASS |
| G12b | Manual coin orders: G3b and G3c cases via `admin_refund_coin_order` | — | PASS |

Interstitials have no server path: G10 proves only the capability flag the
client must obey. Client gating stays a client test.

## Findings behind the run-1 failures

Status after run 2: F1–F4 repaired and gated (G3–G7, G11, G12). The only
items still open are T1's Edge half and T2 below.

**F1 — High. Refund of a debt-offsetting purchase loses the offset** (G3).
`revoke_voided_play_purchases` adds `credited - taken` to the debt but never
the `offset_debt` the purchase consumed in `commit_play_product`, so
buy→spend→refund→buy→refund erases debt. Repair: persist the offset per
purchase; on reversal `debt += offset + (credited - taken)`. Same shape exists
in `coin_orders` (operator-driven there, self-service here).
Blocks setting any coin product `active=true`.

**F2 — Medium-High. Voids can be lost or undone** (G4, G5).
Voided sync only updates existing `play_purchases` rows and then advances its
checkpoint, so a void for an unseen token is forgotten. A pending row revoked
by the sync keeps `reversed_at` null, and the next `active` upsert flips it
back and grants; the entitlement upsert sets `state=excluded.state`
unconditionally. Exploitability depends on `products.get` still reporting
`purchaseState=0` after a void (unconfirmed), but the second path needs only
one stale answer. Repair: a void tombstone written for every token/order the
sync sees, checked by `commit_play_product`; `revoked` from a void is terminal.

**F3 — Low-Medium. Untagged coin tokens credit whoever verifies first** (G6).
`p_account_tag is null` skips binding. 1.0.1 always sets the tag; require it
for `kind='coins'`.

**F4 — Low. Missing config fails open** (G7).
`if not (select ad_steps_enabled …)` is NULL → passes. Use
`is not true`/`coalesce(…,false)`; capabilities should return a safe-off object.

## Contract the SQL cannot prove

**T1 — missing `day` on daily actions.** Repaired in SQL (`DAY_REQUIRED`,
covered by G8). The Edge half below is still a TS test requirement.
`economy_actions.ts` maps an absent `day` to `p_day=null`, and the SQL treats
null as "today", so a retry replayed after UTC midnight without its day becomes
a new-day claim. Required: `economyCall({action:'daily_coffer'|'daily_spin'|
'daily_ad_claim'}, uid)` with no `day` returns `null` (BAD_REQUEST). Belongs in
`update101_contracts.test.mjs`; G8 proves only the stale/future-day half.
Alternative repair: make `p_day` required in SQL, in which case add a null-day
case to G8.

**T2 — lock ordering / deadlock (static review only).**
PGlite is one connection; none of these gates prove concurrency.
- Ad create/commit: no cycle found. Creates take the wallet lock and never lock
  claim rows; commits take claim row → registry → wallet. Wallet-first with a
  revalidating row lock is still preferable.
- Voided sync vs verify: a cycle exists. Sync locks T1 row, takes wallet(U),
  then waits on T2's row; `commit_play_product(T2)` holds T2's row and waits on
  wallet(U). Postgres aborts one; no coins lost, but the batch fails. Two
  overlapping sync runs can also deadlock (cursor has no `ORDER BY`). Repair:
  order the cursor and take affected wallet locks in sorted order first, or
  revoke per token. Proof requires a two-connection test on real Postgres.

## Not covered here
Client capability gating / legacy-unit fallback, consent refresh, ad-free
source of truth, and external gates (Play signing, merchant products, real
SSV, licence test).
