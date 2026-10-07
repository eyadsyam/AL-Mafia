# Integration status

This worktree is **not a completed Ads v4 release**. Do not merge it with the expectation that the 21 new account units will start serving.

## Baseline and compatibility

Both this worktree and the main checkout were at `5bc7ab0060c2c90c5e643bb0936088e94b7b2dac` when checked on 2026-10-07. Main had no reported local changes. Recheck before integration; other tasks can change it.

- The old theme import remains an export shim; the canonical implementation must be included in any merge.
- Missing `adsV4` keeps legacy automatic behavior. A present v4 payload suppresses the legacy automatic hooks; **do not publish that payload until the v4 runtime adapter is complete**.
- No SDK dependency upgrade or replacement of legacy AdMob IDs occurred.
- Play Android manual transfers are disabled. Direct Android requires both explicit build approval and server approval. Web behavior is preserved.
- The transfer migration is prepared locally and has not been deployed. Never edit a previously applied migration during integration.
- New AdMob IDs are public configuration, not credentials. Production secrets are not part of this package.

## Incomplete release gates

1. Finish M02 public route/lifecycle integration, persistent pacing ownership, callback cancellation, voice/audio restoration and the complete edge-case test matrix.
2. Finish M03 paid-event instrumentation; impression-level revenue remains disabled in the account evidence.
3. Finish M04 server registry and bound SSV settlement; the three new rewarded units have no configured SSV callback and must remain disabled.
4. Finish M05 Android adapter and public banner slots using verified placement IDs, with test ads on the required emulator and a physical device.
5. Finish M06 native templates and attribution/AdChoices validation.
6. Finish M07 web publisher restrictions and M08 responsive/performance validation; mobile browsers are web and cannot use Android AdMob IDs.
7. Finish the remaining planned growth/rollout gates and account readiness. AdSense approval, AdMob review/store linking and Play production eligibility remain external requirements.
8. Create `reward_spin`, `reward_coffer`, `reward_swap` only after AdMob permits it. Daily quota blocked the first attempt. Preserve the 21 units already created; never recreate them.

## Integration procedure after the release gates pass

Save all implementation and verification files in a named Git branch before integrating; this checkout currently started detached. Use the Codex worktree integration action or merge that branch from the main checkout. Check the destination working tree and resolve any conflicts against its current state. Do not reset the destination or overwrite its newer changes.

Re-run the targeted monetization, commerce, theme/leakage, publisher and SQL checks after resolving conflicts. Run the full Flutter suite and analyze on the integrated tree. Keep new inventory disabled during migration deployment and SSV/device validation. Enable only verified, approved placements through server configuration.

Account creation is already an external side effect; reversing a source merge does not remove AdMob units. A source rollback must also restore the server capability payload to legacy/off so old clients do not lose automatic ads.
