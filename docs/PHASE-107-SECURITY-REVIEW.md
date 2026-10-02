# Phase 107 "Council Life" — independent security review and regressions

Reviewed: `supabase/migrations/20260925000300_council_life.sql`, the Council
actions in `supabase/functions/_shared/economy_actions.ts`, and
`docs/PHASE-107-COUNCIL-LIFE.md`, as of 2026-09-25. `20260925000400_web_quiet_pass.sql`
was present at run time; it is covered only by L11 (grants), not reviewed.

Regressions: `supabase/tests/council_life_security.sql`. Each gate runs in its
own rolled-back subtransaction; failures are reported together; the report
block fails if fewer than 13 gates record.

```bash
node tool/test_sql_without_docker.mjs council_life_security.sql council_life.sql
```

The assertions encode the required behaviour. A failing gate is a finding;
do not loosen it to match the implementation.

## Gates

| Gate | Requirement | Run 1 |
|---|---|---|
| L1 | Inviter paid at most `cap` times even after a paid invitee's account is deleted (`complete_data_deletion`) and a new invitee redeems | **FAIL** paid 200 with cap 1 |
| L2 | Same, when the invitee is removed by `purge_orphan_economy` | **FAIL** paid 200 with cap 1 |
| L3 | `INVITE_SELF`, `INVITE_EXPIRED` (8-day account), `INVITE_NOT_NEW`, idempotent retry (case-insensitive), `INVITE_ALREADY`, `INVITE_LOOP`; nobody paid before the invitee's match; inviter 100 / invitee 50 exactly once across repeated reads; 10 unknown codes → a real code is refused with `INVITE_RATE_LIMIT` and nothing stored | PASS |
| L4 | Contract claim: null day `DAY_REQUIRED`, ±1 day `DAY_CHANGED`, slot 3 `BAD_REQUEST`, no match `CONTRACT_INCOMPLETE`; three claims + replays pay 15+25+25 and bonus 30 exactly once; a match that ended yesterday does not complete today's contract | PASS |
| L5 | Weekly: null `WEEK_REQUIRED`, last week `WEEK_CHANGED`, incomplete refused; 150 coins + 150 XP once, replay grants 0 | PASS |
| L6 | XP once per match across repeated sync/reward/rank/contract reads (100 XP for two wins, level-2 coins once); a >21-day match pruned and re-seen never grants twice; daily XP cap holds | PASS |
| L7 | Live, outcome-less, `abandoned`, and kicked rooms produce no record and no XP | PASS |
| L8 | Doc 05: dealing roles in a live room leaves contracts, rank, leaderboard, invite and capabilities byte-identical for a town and a mafia player; no record for the live room | PASS |
| L9 | Leaderboard JSON has no UUID, only the documented keys, no role/team words as keys or values; blocks hide rows both ways; third parties unaffected | PASS |
| L10 | Starter Bundle: untagged refused; 600 once; second token on same account `alreadyOwned`, not acknowledged, no coins; not buyable with coins; debt 500 → credit 100 → void restores debt 500, frame removed and unequipped; void is final on replay; pending→void→active and void-before-verify grant nothing | PASS |
| L11 | No anon/authenticated execute on any `council_*`, `*_base`, wrapper or deletion function; every SECURITY DEFINER one pins `search_path`; every `council_*` table has RLS and no client privileges | PASS |
| L12 | All 17 earlier ledger kinds plus the 6 Council kinds insert; an unknown kind is still a check violation | PASS |
| L13 | `complete_data_deletion` is a superset of 000100/000200: every per-user row gone (ad, daily, entitlements, inventory, wallet, all Council tables, auth); `play_purchases`, `coin_orders` and the SSV registry kept with user nulled; void tombstones kept; redemption inviter nulled; deleted id removed from others' `co_players`; `ACTIVE_ROOM` and `ORDER_UNDER_REVIEW` still refuse | PASS |

## Findings

**C1 — Medium. The invite cap resets when an invitee is deleted** (L1, L2).
The cap is counted from `council_invite_redemptions … inviter_paid`
(`20260925000300_council_life.sql:378-380`, `:495-497`), but deletion removes
the invitee's row (`:959`) and so does the orphan purge (`:984`). A farmer
cycles: throwaway account redeems → finishes one match → inviter +100 →
delete the throwaway → slot is free again. The design's only bound on invite
farming is "paid at most 20 times" (doc §Invites), so this makes inviter
coins unbounded (rate-limited only by match time and deletion latency).
Smallest repair: count the cap from something that outlives the invitee, e.g.
`count(*) from wallet_ledger where user_id=inviter and kind='council_invite_inviter'`
(its `source_key` is the invitee id and is removed only with the inviter), in
both `council_settle_invites` and `redeem_council_invite`.

## Notes (no gate; static)

- **N1 — Info.** `account_tag(owner)=account_tag(p_user)` (`:477`) is a hash of
  the user id, so it only repeats `owner=p_user`; the comment suggests a
  device/purchase binding that does not exist. Accepted by design (throwaway
  invitees), but only while C1's cap holds.
- **N2 — Low, concurrency.** `council_settle_invites` computes its lock set
  (`:362-367`) before taking the locks, then re-reads rows (`:371-373`). A
  redemption committed in between can be credited without its invitee's
  wallet lock. Balances stay correct (`balance=balance+x` is atomic); lock
  discipline only. Re-read the set after locking, or skip rows whose users
  are not in the locked set. PGlite cannot prove either way.
- **N3 — Low, restore.** After the bundle owner deletes their account
  (`play_purchases.user_id` → null), a new account presenting the same token
  gets `granted:true` but no coins or frame: `commit_play_bundle`'s upsert
  never sets `user_id` (`:808-812`) and `granted_at` is already set. Not a
  money leak; decide whether the frame should restore and make the response
  truthful.
- **N4 — Pending.** The leaderboard publishes the last-used display name of
  every player with week XP > 0. The opt-out is being built in another
  session; re-run L9 and add an opt-out gate when it lands (age 16+ privacy).
- Edge contract (`economy_actions.ts`): `contract_claim` passes a missing day
  as null and relies on SQL `DAY_REQUIRED` (L4 proves the SQL half);
  `weekly_claim` and `invite_redeem` validate shape at the edge. No ids from
  the body.
