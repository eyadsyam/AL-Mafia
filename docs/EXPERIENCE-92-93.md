# Experience campaign: 92–93

## Scope and identity

Worktree: `.claude/worktrees/crash-fixes-and-testing-b6c2f5`. The main checkout is older and must not be built as the new candidate. Preserve earlier uncommitted Claude changes. No production deployment, purchase enablement or game-rule migration is part of this campaign.

Public visual language: quiet charcoal ground, ivory type, the existing antique-gold accent and restrained cinematic illustrations. Existing engine, secret turn shells, private roles, timing, council seating and voice rules remain authoritative. New artwork never depends on a role or match state.

## Implemented

- Four onboarding chapters: language/welcome, identity, sound/music/reduced motion, adult confirmation and terms. Sticky primary action, accessible progress, back through chapters, scrollable content, keyboard-aware decoration, restrained crossfade honoring reduced motion. Terms-only upgrade gate remains compact; acceptance persists only after explicit confirmation. Same controller and gate preserve typed details, failed-save recovery and invite destinations.
- Original invitation, council and pact artwork, 960×640 WebP runtime files totalling 105806 bytes. Original PNGs and generation provenance in `raw_assets/experience-v2/`.
- Shared calm public surfaces for Home, mode choice, online room browser, lobby, profile and setup/help pages. Home retains its interactive cards and card audio while removing the competing wallpaper/video layer.
- Mode choice prioritises online visually, still shows both modes, scrolls on short viewports. Public browser uses council art only when the list is empty; no art pushes occupied rooms down the screen.
- A delayed open-ballot response can no longer repopulate the next phase or overwrite a newer revote. Round changes clear old votes and start the correct poll, even on the same day/phase number. Regression tests deliver the newer reply first and the obsolete one last.

## Evidence interpretation

See PROGRESS phase entries and build/phase92-* logs for actual results. Claude's previous hosted evidence is historical, not newly claimed here. Pixel screenshots of widget renders prove layout, not on-device performance or a complete live match. PGlite does not prove hosted cron/realtime/concurrent connections. No test can establish that online has zero possible bugs.

## Next product discussion — not implemented

The game already has its core social tension: hidden roles, arguments, accusations, votes and night consequences. The likely engagement gap is having too few personal events to talk about between discussions. More decoration alone cannot solve that.

First validate with a small real group: where did people go quiet, who had nothing useful to say, which moment did they retell afterward? Measure waiting and participation before adding a second game inside the game.

A fitting prototype is a brief “neighbourhood round”: everyone makes one meaningful, equally timed decision before council. It should create ambiguous but truthful events the existing information engine can support, giving players a reason to explain a choice. Do not copy navigation/task grinding from Among Us. Do not invent evidence, expose who has a special role through availability or timings, add paid knowledge/power, or silently amend doc05. Specify and review the information model and parity tests before implementation. This is a proposal for the owner, not a shipped feature.
