# Product decisions

## Objective and audience

Primary audience: Arabic-speaking friend groups playing social deduction, online on separate phones or pass-and-play on one phone. The first product win is a group completing its first satisfying match and choosing to meet again. Never monetize hidden information, role assignment, survival, votes, matchmaking priority or reconnect access.

Revenue ladder: optional verified rewarded ads → restrained automatic inventory outside matches → cosmetic coin purchases and existing Quiet Pass → later cosmetic bundles. Do not add subscriptions, paid random loot or new currencies in this program. Keep known entitlements and current catalog prices until console verification and a 28-day baseline exist.

## Fixed backlog

| Ticket | Exact change | Existing surface | Measurement |
|---|---|---|---|
| G01 | First-run sequence: language/terms → optional film with immediate skip → name/avatar → choose playable mode; optional account recovery after first completion | `first_run_screen.dart`, onboarding video/account, mode/profile screens | first_open→mode→first_match_completed, time to playable |
| G02 | Three top actions on Home: resume existing game when present; play with friends; pass-and-play. Store stays secondary. Active resume suppresses automatic ads | home, online entry, router | successful resumes; started/completed matches |
| G03 | Online create uses current defaults, capacity/private summary visible; advanced options collapsed. Join preserves invite code through account/reconnect flow | online entry, lobby, account flow | invite_open→lobby_join→match_start |
| G04 | Result hierarchy: outcome/roster → replay with same group → optional double-coins offer → home. Triple offer appears only after verified double; never auto-plays | online result, `rewarded_reward_button.dart`, `_TableRematch` | result→rematch acceptance, group match 2 completion |
| G05 | Existing Casebook: one clear claim-all-eligible action with per-receipt idempotency; show next achievable mission, no role-progress updates in live matches | `casebook_sheet.dart`, `casebook_data.dart` | mission_hub_open→claim; D7 |
| G06 | Preserve existing mission rewards/targets at first release. No missions requiring consecutive hours or ad views. Reroll stays optional once/day; daily and weekly progression settles only after matches | economy/missions server | coins issued by source; completion by cohort |
| G07 | Existing Thursday event uses server Cairo time, one concise event card, opt-in reminder. Outside the event show normal play, not repeated countdown popups | `thursday.dart`, push | invited group starts/completions; reminder opt-out |
| G08 | Referral prompt once after second completed match, or manual from Council. Show pending/settled accurately; settlement remains existing first-eligible-match rules | `room_referral.dart`, council, referral migration | verified referred match completion; fraud/reversal rate |
| G09 | Share card only after public final result; omit room code, private whispers, account identifiers. User chooses share; never auto-post | existing result export/share surfaces | share_export→attributed first completion |
| G10 | Welcome-back card summarizes public cosmetic/mission updates after 72h away, once per return session; no fake losses or fabricated activity | `welcome_back.dart` | return→completed match |
| G11 | Quiet Pass removes ALL automatic formats, including new native and banners. Optional rewarded offers remain explicit. Buy/restore works without ad SDK | play offers, capabilities, native registry | purchase/restore success; refunds; net revenue |
| G12 | Keep coin packs and starter bundle; show localized store prices only. Cosmetic previews free and unrestricted. Bundle never grants gameplay advantages | coin store, cosmetics, play offers | preview→buy; entitlement accuracy |

## Acquisition experiment calendar (launch after quality gates)

These are proposed experiments, not observed winning channels. No ad buying, creator outreach or posting is authorized in this planning turn.

1. Week 1: publish approved, accurate Arabic how-to/roles content and a fast landing page linking directly to play. Preserve invite links. Track campaign buckets, never secret roles.
2. Week 2: prepare six 15–25-second clips: two group-reaction clips with consent, two role-rule explainers, two finished-match puzzles. Use existing attribution categories, add explicit enums for new categories. Compare first-completed-match conversion, not views.
3. Week 3: proposed creator pilot with three opt-in communities; each has a public campaign bucket and an organized play evening. Invite rewards only for valid gameplay, never installs/clicks/ad views alone. Budget defaults to zero until the owner sets a spend cap.
4. Week 4: keep only channels with positive measured contribution, reliable retention and no invalid-traffic anomaly. Do not purchase bulk/incentivized traffic to manufacture ad impressions.

No ranking optimization based solely on session length. Review median/p90 active play time, matches completed, self-reported satisfaction, return rate and opt-outs together. After 60 minutes offer a small dismissible break reminder at a public result screen; never interrupt a match. No lost streak, reward multiplier or notification penalty for leaving. An optional six-hour group session must remain stable but must not be required to unlock items.

## Economy rules

Preserve base match awards and existing fraud caps from `20260929000100_economy_v3.sql`. For a match reward B, one verified double step adds B, second verified triple step adds B: total 3B, not 6B. Bind B when the server creates the claim. Daily/coffer amounts and wheel odds remain authoritative server values, not hardcoded copy. Explicitly disclose random spin outcome and possible rewards before opt-in. Ad rewards are account-bound virtual benefits with no cash-out or player transfer.

No new rewarded experience is needed merely to reach 24 units. Six existing experiences get separate units and telemetry. Later cosmetic trials or season boosts require their own product/economy review; they are excluded from this implementation.
