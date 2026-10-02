# Phase 93 — resumed, shared ownership

> SUPERSEDED by the owner's latest full takeover request. Read docs/CLAUDE-FINAL-TAKEOVER.md first. Codex is no longer editing; Claude owns all remaining work. The read-only review actually completed and is saved in docs/CLAUDE-REVIEW-93.md.

Worktree: `.claude/worktrees/crash-fixes-and-testing-b6c2f5`. Do not build main.

Owner resumed Codex and requested cooperation with Claude. This file supersedes the full-takeover instructions in CLAUDE-CONTINUE-92-93.md while both are active.

## Codex owns
- Public UI/onboarding source, assets and capture harness.
- Review of ballot epoch guard, focused regressions and visual corrections.
- PROGRESS and this coordination file.

## Claude owns
1. Independent read-only audit of realtime host metadata preservation, late open-ballot responses, onboarding/deep-link/save recovery. Put concrete findings in `docs/CLAUDE-REVIEW-93.md`; no concurrent edits to Codex-owned files.
2. After SOURCE FROZEN: full Flutter suite, analyze, signed 1.1.1+4 APK/AAB/web candidates, R8/16KB/signature checks. Preserve earlier deliverables.
3. Emulator/browser smoke validation and `docs/CLAUDE-VERIFY-93.md`, including exact results, hashes and remaining human checks.

No Docker, production publication, account changes, coin activation or game-rule changes. See CLAUDE-CONTINUE-92-93.md for paths and prior evidence. Original artwork is finished; do not regenerate it.

## Current state
SOURCE FROZEN — Codex's implementation and focused checks are complete.
Claude may now review, test and build. If review discovers a concrete defect, fix it with a regression test and record the change rather than silently weakening tests. No other agent is editing this source.

Latest evidence superseding the stopped handoff:
- build/phase93-capture.log: 22/22 PASS. Fonts fixed, all four new AR portrait captures generated and visually inspected; AR/EN portrait/landscape interaction tests passed.
- build/phase93-analyze.log: 0 errors, 0 warnings, 83 informational diagnostics.
- build/phase93-ballot.log: 3/3 PASS, including a new slow-network test.
- Important extra fix: `_ballotApplied` compares against the latest APPLIED reply, not latest STARTED request. Otherwise latency longer than the two-second polling interval could starve all replies. Epoch transitions invalidate older requests, out-of-order replies cannot regress already-applied data, while a merely pending newer poll does not hide useful data.
- The slow-network widget test disposes transport in `tester.runAsync` to close async streams outside the fake clock. An earlier version left a periodic timer/awaited cleanup in the fake clock; that test harness issue is fixed.
- build/experience-review/{01-language,02-identity,03-preferences,04-pact}.png are now valid fresh widget renders. They are NOT emulator screenshots. No tofu/debug banner in the inspected captures.
- Full suite still needs one complete run: the pre-stop partial951/1skip is not a complete result. No1.1.1 release artifacts built.

Communication: browser remote control was unavailable; the owner clarified that local CLI is available. Local claude.exe is authenticated. Codex dispatched docs/CLAUDE-REVIEW-93-PROMPT.txt via `claude -p --model opus --effort medium`, with only Read/Grep/Glob tools and no MCP tools. Review result is expected in build/claude-review-93.json. No review result received yet; do not invent findings. The alias-selected model will be verified from returned metadata.
