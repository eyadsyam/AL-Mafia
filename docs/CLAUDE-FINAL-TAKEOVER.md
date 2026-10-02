# Full Claude takeover — latest owner instruction

This file supersedes split ownership in PARALLEL-93.md. The owner asked Codex to stop trying to operate Claude and let Claude finish everything remaining. Codex is no longer editing or running builds. All generated artwork is complete. Claude owns implementation, verification and candidate delivery from here.

## Workspace and reading order

Work ONLY in `D:/Flutter Data/Projects/AL Mafia/.claude/worktrees/crash-fixes-and-testing-b6c2f5`. Main is stale. Preserve all earlier uncommitted work. No reset/clean/discard. No new worktree unless you deliberately transfer the entire current state.

Read this file, docs/CLAUDE-REVIEW-93.md, the latest PROGRESS entries, then docs/CLAUDE-CONTINUE-92-93.md for detailed context/commands. PARALLEL-93.md contains useful latest verification but its ownership restrictions are superseded. Read relevant root05-zero-leakage-spec.md before modifying UI/phase flow.

## FIRST: independent review returned two correctness findings

The second local read-only review completed successfully before takeover. Returned model metadata confirms `claude-opus-5-5`; requested effort medium. Full result is preserved in docs/CLAUDE-REVIEW-93.md. It ran no tests and changed no files. Codex has NOT yet independently reproduced or fixed these two findings; verify them with regressions, then fix the actual root cause:

1. **Clock correction erased by partial realtime rows.** supabase_backend synthesizes server_now from the device clock for room_state events, and online_transport recalculates skew on that partial row. A device20s fast can lose its corrected countdown/deadline after a same-phase speaker update. Suggested approach: update skew only from a genuine server-timestamped full response. Ensure the fake models production's synthetic timestamp. Regression: skewed device, full fetch correction, partial same-phase push, countdown/deadline remain corrected.
2. **An in-flight full resync may overwrite a newer same-phase delta.** A newer activeSpeaker/openingSeat update may be published, then replaced by an older fetchRows response. Suggested minimal approach: mark `_resyncAgain` when a same-phase delta arrives during `_resyncInFlight`, so the existing drain loop refreshes again. Validate ordering and avoid an unbounded resync loop under repeated events; don't blindly apply a one-line fix without a test.
3. Add the requested ballot regression using **pushStateDelta**, not only full setState: same-day revote must preserve openVoting/host metadata and discard old votes. Existing full-push tests do not pin that dependency.

These findings are now the priority before cosmetic additions/builds. The review agreed that the applied-response ballot ordering and existing onboarding recovery logic hold. Potential piling-up of long-running ballot reads was only an improvement suggestion, not demonstrated breakage; address only if justified without starving valid replies.

## Already finished — reuse rather than redo

- Four-page AR/EN onboarding, persistent progress/back/next, profile/prefs/legal gates, reduced-motion transitions.
- Quiet public surfaces, online-first responsive mode selector, new empty-room council art. Private role/game-rule behavior was not redesigned.
- Three original images at assets/images/experience_v2/{invitation,council,pact}.webp, total105806bytes. Originals and provenance at raw_assets/experience-v2/. No more images are needed for the current campaign.
- Open-ballot epoch and applied-response ordering guard, with3 regressions including slow-network1→3→2 completion order.
- Source version1.1.1+4. No binaries built for this version yet;1.1.0 files are previous candidates.

## Current evidence — exact limits

- Hosted revote38/38 newly passed; no hosted deployment this turn.
- Latest core client suites81/81 passed (build/phase93-core.log).
- UI/capture focused suite22/22 passed (build/phase93-capture.log), including AR/EN portrait390×844 and landscape740×360.
- Ballot guard3/3 passed (build/phase93-ballot.log).
- Analyze0errors/0warnings/83infos (build/phase93-analyze.log).
- Four fresh onboarding widget renders in build/experience-review visually inspected with fonts fixed. They are widget renders, NOT emulator screenshots.
- Full suite was interrupted at951passed/1skip/0failures so far at the owner's earlier stop request. It is incomplete, not a full PASS.
- No1.1.1 emulator/browser/release build verification yet. No human full-match/real two-phone audio/weak-network proof.

## Finish all remaining work in order

1. Reproduce/fix the review findings and add focused regressions. Keep the existing voting ack/revote/host tests meaningful. Preserve one engine/two transports and zero-leakage parity.
2. Finish any evidence-driven UI corrections. Review actual new pages at phone sizes/keyboard/landscape/English; keep the restrained brand, no distracting wallpaper. Do not silently implement the speculative neighbourhood-round mechanic.
3. Run focused tests after fixes, then ONE full Flutter suite with concurrency2 and analyze. Record real totals. Use Docker-free SQL only if SQL changes require it; don't spend time fixing Docker.
4. Build signed online-configured1.1.1+4 APK, AAB and web candidates into NEW build/deliverables-1.1.1/. Preserve old artifacts and original signing. Validate R8 regression,16KB native alignment and signer; generate SHA256SUMS and concise Arabic README.
5. Verify actual release startup/upgrade and online entry on Pixel_9_Pro_2, plus available web browser. Check mode-back navigation, profile/language in place, saved consent, invite deep links. Preserve or back up emulator state before resets. Review downscaled device screenshots. Be explicit about tests not possible.
6. Update PROGRESS and publishing handoff with final source/build state, actual evidence, paths, hashes and remaining owner checks. Source is heavily dirty from multiple sessions; do not assume all changes belong to you or discard any.
7. Deliver the testable APK and web candidate to the owner. Owner keeps the final human match. Do NOT claim guaranteed bug-free, full audio verification or publish-ready while gates remain open.

No production publishing, Google/AdMob account changes, real payments, or coin sales activation. Those remain separate owner/Codex publishing work. Never use tool/build_web.ps1 -Publish. Never expose dart_defines, signing secrets, tokens or bank details. Existing coin_orders migration005 remains unapplied and sales off; do not accidentally enable it while preparing candidates.

Tools/commands and all source-file details are in CLAUDE-CONTINUE-92-93.md. Complete the authorized work autonomously, report concrete blockers honestly, conserve tokens through targeted reads and short log tails. Do not wait for Codex to edit files or supply assets; his work is handed over.
