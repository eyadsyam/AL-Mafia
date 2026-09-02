# Mafia Master — Working Agreement

## Specs (read from disk, on demand — never paste into chat)

| File | When to read |
|---|---|
| `docs/05-zero-leakage-spec.md` | Before any UI or phase-flow change |
| `docs/09-information-engine.md` | Phases 2–4 |
| `docs/10-online-architecture.md` | Phases 5–8 |
| `docs/11-edge-cases-and-tests.md` | When writing tests |
| `docs/PROMPT-build-online-and-information-engine.md` | Build order + gates |
| `docs/PROGRESS.md` | **First thing after any `/clear`** |

Read only the section you need. Use Grep to find it, then Read with a line range. Never read a whole spec to answer one question.

## Non-negotiables

1. Doc 05 wins every argument. If a change lets a player infer another player's role — stop and report. Never amend the spec yourself.
2. One engine, two transports. Never `OnlineGameEngine`. No `if (isOnline)` in widgets except voice controls and the connection banner.
3. `lib/engine/**` is pure: no Flutter imports, no `DateTime.now()`, no unseeded `Random()`.
4. The app never invents a fact. No eligible trace or confrontation → output nothing.
5. Voice is never load-bearing. Online matches must complete with voice fully broken.
6. Zero hardcoded colours, sizes, durations outside `lib/core/theme/design_tokens.dart`.
7. Arabic: line-height 1.6, zero letter-spacing, text scale locked at 1.0.

## Token discipline

- **Do not narrate.** No "Now I'll…", no "Let me…", no restating the plan. Act, then report once at the phase gate.
- **Grep before Read.** Never read a file to locate something.
- **Read ranges, not whole files** for anything over 300 lines.
- **Truncate command output**: `flutter analyze 2>&1 | tail -30`, `flutter test 2>&1 | tail -40`, `flutter run … | grep -E "error|Error|FAIL"`.
- **Screenshots: downscale before viewing.**
  ```bash
  adb exec-out screencap -p > /tmp/s.png && \
  python3 -c "from PIL import Image; i=Image.open('/tmp/s.png'); i.thumbnail((420,420)); i.save('/tmp/s.jpg',quality=65)"
  ```
  Then view `/tmp/s.jpg`. A full-resolution screenshot costs several times more than a 420px one and shows nothing extra for layout checks.
- **One screenshot per screen**, at the end of the phase — not after every edit.
- **No subagents** unless two tasks are genuinely parallel and independent. A cold agent re-derives context you already hold.
- **Batch independent tool calls** in a single block.
- **Never re-read a file you just wrote.** Edit/Write fails loudly if it did not apply.
- **Do not print file contents back to me.** Say what changed, in one line.

## Phase protocol

1. Read `docs/PROGRESS.md` first.
2. Do the phase.
3. Append to `docs/PROGRESS.md`:
   ```
   ## PHASE n — done | blocked
   Built:      <one line>
   Files:      <paths touched>
   Verified:   <what was actually run>
   Gate:       PASS | FAIL
   Open:       <anything unresolved>
   ```
4. Report the same block in chat. Nothing else.
5. **Stop. Wait for me.** Never start the next phase unprompted.

## Verification

Code that compiles is not evidence. A phase is done when you have run it on the
emulator (`Pixel 9 pro (2)`) and looked at a screenshot — or run the tests and
read the output.

## Commands

```bash
flutter analyze 2>&1 | tail -30
flutter test 2>&1 | tail -40
flutter run -d <id>
adb devices
```
