# Separate follow-up: online presentation and shared media

Requested by the user on 2026-09-20. Begin after the current reliability/release
work. This is not part of the current stability acceptance gate.

## Outcome

Reuse the existing offline videos (verify their actual formats, including WebM)
and suitable images, transitions, animations and sound effects in online play.
Make both modes feel consistent while improving online UX/UI. Preserve all
features and the single-engine/two-transports architecture.

## Work

- Inventory existing offline assets and their license/source before making new
  ones. Prefer reuse; generate additional original assets only for clear gaps.
- Map shared media to lobby, role reveal, public phase transitions and result.
  Online phase state remains authoritative: media must never delay a move,
  advance a phase, replay a secret or prevent recovery after reconnect.
- Read the binding root `05-zero-leakage-spec.md` before any UI change. Keep
  night layouts, timings, luminance and silence equal across roles. Never add
  role-specific audible effects, status indicators or revealing transitions.
- Improve room discovery, room settings, lobby readiness and result controls
  using existing design tokens and Arabic/English localization.
- Web media: explicit bounds/aspect ratio, lazy loading, no duplicate full-file
  download gate, graceful reduced-motion/muted/offline fallbacks, no large
  preload that competes with game requests. Test portrait and landscape.
- Review actual Android and web screenshots. Run focused tests for changed
  behavior. Do not replace the architecture, remove features or expose keys.

## User-owned validation

## Phase 67 implementation (2026-09-20)

Shared silent animated WebP media is now used for the online lobby, ballot
and public winner backdrop, retaining the council controls and existing audio
director. Night and private reveal retain their neutral static art. Shared
AmbientMedia clips the artwork, ignores pointers, isolates repaints and uses
static fallbacks for reduced motion, inactive routes and failed animation
loads. Offline AppBackdrop uses the same component. No new asset downloads,
generated images or additional sound tracks were added.

Room creation now keeps its confirmation outside the scrolling settings list;
the close control has a localized accessibility tooltip. The desktop reading
column already existed and was preserved. Focused tests cover portrait,
landscape and desktop button reachability. Broader visual redesign, new art and
morning outcome sequences remain future scope, not completed work.

The user explicitly took ownership of the complete multiplayer match test.
Do not claim it passed without their feedback. Human audio quality and
Android-to-web audibility likewise need real listening evidence.
