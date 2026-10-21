Plan name: 2026-10-21-popover-outside-click-dismissal-monitor

# Plan: popover-outside-click-dismissal-monitor

**Date:** 2026-10-21
**Repository:** /Users/jonathan/beliantech/stats-lite-macos
**Risk class:** R1 (normal behavior change: event-handling code in `StatusItemController`; no visual, copy, or layout change — no designer required)

## Intent

Make the status-item popover dismiss when the user clicks outside it. Today dismissal depends on `popover.behavior = .transient` alone (`StatsLite/StatusItemController.swift:63`); the app has no fallback (`rg 'NSEvent|popoverShould' StatsLite/` → no matches). Outside-click dismissal has never been live-tested (`artifacts/2026-10-21-popover-panel-fix/behavior-checklist.md:16` = `VERIFIED-IN-CODE`).

## Attribution evidence (before any root cause)

1. **Scout (code):** dismissal mechanism is only the `.transient` behavior (`StatsLite/StatusItemController.swift:63`); no `NSEvent` monitor, no `popoverShouldClose`, no gesture/tracking code in the app target.
2. **Oracle (AppKit binary disassembly, report at `.pi/oracle/2026-10-21-popover-dismiss-report.md`):** `.transient` registers only a **local** event monitor plus `NSWindowDidResignKey`/`NSApplicationDidResignActive` notifications (`_NSTransientUIElementRegisterForEvents`, `AppKit[0x185bd4624]`). All three triggers stay inert in this app: clicks in other processes never reach the local monitor; `_NSPopoverWindow` never becomes key (`acceptsFirstResponder` = NO path, `AppKit[0x18517d4a0]`); the `LSUIElement` agent is never active (`NSApp.isActive == false`). Status-button clicks work only because they land in-process (local monitor).
3. **Prior measurements:** awake `performClose` completes in 0.33–0.90 s (`artifacts/2026-10-21-popover-panel-fix/step2-close-behavior-awake.txt:16-19`); display-asleep close stalls (known, `AGENTS.md`).

## Hypotheses and falsification signatures

| ID | Hypothesis | Verdict | Falsification signature |
| --- | --- | --- | --- |
| H1 | Display-sleep stalled close leaves a stuck-open popover | Secondary confound only (weakens for awake user clicks) | T1 runs with `CGDisplayIsAsleep == 0`; if the popover ignores an awake outside click, H1 cannot own the awake symptom |
| H2 | AppKit `.transient` misses outside clicks in the non-activating LSUIElement app; no app-level fallback | Primary candidate — **to be confirmed by T1** | T1: window still present at +1 s and +2.5 s after the synthetic outside click → H2 owned. Window gone by +1 s → H2 dead, plan stops (FM1) |
| H3 | `--open-popover` cycle auto-reopens | Ruled out for normal runs (`StatsLite/StatsLiteApp.swift:75-77`) | T1 uses `--popover-cycles 1`: no close or reopen exists before +16 s, so any window at +1 s is the original popover |
| H4 | 0.25 s debounce race (`StatusItemController.swift:103-105`) | Disproven for outside clicks | `togglePopover` fires only from `button.action` (`:95-96`); T1 clicks at (100, 500) at t = 2.5 s, off the button and past the 0.25 s window |

## ISC — binary yes/no criteria

- **IC1 (attribution, pre-fix)** With `caffeinate -u -d` and `CGDisplayIsAsleep == 0`: the T1 command prints `win=<id>` at `before_click`, and still `win=<same id>` at `after_click_1s` and `after_click_2.5s` (outside click ignored → H2 owned). Receipt = the saved T1 log.
- **IC2 (post-fix)** The identical T1 command, same single variable, now prints `win=none` at `after_click_1s` (popover dismissed by the outside click).
- **IC3 (status button preserved)** Clicking the status button still toggles: close when shown, open when closed, no reopen storm within the 0.25 s debounce. Existing `StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease` passes (green run receipt).
- **IC4 (in-popover interaction preserved)** A mouse-down inside the popover window and a mouse-down on the status-button window never trigger the new close path (unit tests on the local-monitor handler pass).
- **IC5 (lifecycle, no leaks)** Monitors exist only while `popover.isShown`; they are removed in `popoverDidClose` and in `deinit`. Unit tests pass; no monitor outlives the controller.
- **IC6 (behavior contracts untouched)** `rg 'animates' StatsLite/*.swift` → no production write (test-only line at `StatsLiteTests/StatusItemControllerPopoverTests.swift:97` stays); no `NSApp.activate` added (opening the popover must not activate the app — `behavior-checklist.md` row 5); `popover.behavior = .transient` kept.
- **IC7 (suite)** Full test suite awake: 0 failures (`xcodebuild test -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS'` under `caffeinate -u -d`).

### Failure modes

- **FM1 — attribution falsifies H2:** if T1 shows `win=none` at `after_click_1s` while awake, H2 is dead. Plan stops; report the reading to the user. No fix is written against an unproven root cause.
- **FM2 — status-button fight:** if the local monitor closes the popover on a status-button click, `togglePopover` and the 0.25 s debounce fight it (reopen/double-close). Guard: local monitor passes `event.window === button?.window`; IC3 fails → fix, do not ship.
- **FM3 — in-popover clicks close the popover:** local monitor must pass `event.window === popover.contentViewController?.view.window`; IC4 fails → fix.
- **FM4 — display asleep during verification:** a stalled close invalidates the reading. Precondition every T1/T4 run with `CGDisplayIsAsleep == 0` (assert in the command); wrap test runs in `caffeinate -u -d` (`AGENTS.md:16-19`).
- **FM5 — double close:** `.transient` and the monitor may both fire; close path guards `guard popover.isShown else { return }` and removes monitors before calling `performClose`.

## Approach

**Chosen (oracle Option A): lifecycle-scoped global + local `NSEvent` mouse-down monitors.**

Keep `popover.behavior = .transient` (`StatsLite/StatusItemController.swift:63`). While the popover is shown:

- `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown])` — closes on clicks in other apps/desktop. No Accessibility/TCC permission needed for global mouse-down monitors.
- `NSEvent.addLocalMonitorForEvents(matching: same)` — closes on clicks in StatsLite's own windows (e.g. Settings); passes the event through unchanged when `event.window` is the popover window or the status-button window (FM2/FM3).
- Guard `popover.isShown` before closing (FM5); remove monitors immediately when the close triggers.
- Install in `openPopover()` (`:112-133`) after `popover.show`; remove in `popoverDidClose(_:)` (`:172-179`) and `deinit` (IC5).
- Store the two monitor tokens as `internal` properties on `StatusItemController` (next to `lastCloseTimestamp`, `:39-40`), each with an `/// Internal so popover lifecycle tests …` doc comment — the repo convention for test seams (`:30`, `:43`).
- Extract the local-event filtering into an `internal` method `func handleLocalClickEvent(_ event: NSEvent) -> NSEvent?` so unit tests can drive it in-process: popover-window and button-window events return the event untouched; other-window events close the popover and return the event. Global monitors cannot fire in unit tests — IC5's global half is covered by token-lifecycle assertions plus the live IC2 run.

**Rejected options (recorded for the reviewer):**

- `NSApp.activate` + `makeKeyWindow` on open — steals focus from the user's active app; violates `behavior-checklist.md` row 5.
- `popover.animates = false` in production — does not make `.transient` detect clicks (H2 unaffected) and is prohibited by `plans/2026-10-22-popover-test-close-animation-determinism.md` IC4.

**Out of scope:** H1 display-sleep stall handling (documented in `AGENTS.md`; separate parked fix for `scripts/measure_popover_footprint.sh`); the `--open-popover` cycle.

## Refactors / band-aids

- `scripts/windowid.swift:6` comment claims the popover window sits at CG layer 101, but recorded readings show `layer=25`. The script filters on owner + nonzero bounds, so behavior is correct — fix the stale comment in the green task so future probes are not misled (one-line comment change).
- No other band-aids found in the touched code (scan: `TODO|FIXME|HACK|workaround` in `StatsLite/StatusItemController.swift` → none).

## Phases and tasks

Notation: Plan -> Phase -> Task (`T*`) -> Receipts (red SHA / green SHA / review verdict).

- [x] **T1** — Phase 1 attribution: run the T1 command (below) from the **main repo root**, where the Release build at `.derivedData/...` exists (verified this session). Receipt: saved log showing `win=<id>` before click and `win=<id>` at +1 s/+2.5 s → IC1. If `win=none` → FM1: stop and report. red n/a · green `artifacts/2026-10-21-popover-outside-click-dismissal/t1-prefix-attribution.txt` (2026-10-21: `win=16338` before, +1 s, +2.5 s; `display_asleep=0` → **IC1 pass, H2 owned**)
- [ ] **T2** — Phase 2 red: `[red]` coder in worktree `worktrees/2026-10-21-popover-outside-click-dismissal-monitor` on branch `feat/2026-10-21-popover-outside-click-dismissal-monitor`. Author failing tests only (IC3/IC4/IC5 failure modes: monitors installed on show; removed on close and deinit; `handleLocalClickEvent` passes popover/button-window events and closes on other windows). The seams (`globalClickMonitor`, `localClickMonitor`, `handleLocalClickEvent`) do not exist yet, so the expected red output is compile errors naming them — record that output as the red receipt. Touch no application code.
- [ ] **T3** — Phase 2 green: same worktree/branch. Implement Option A in `StatsLite/StatusItemController.swift`, including the `internal` seam specified in Approach; fix the `scripts/windowid.swift:6` comment. Suite green. Receipt: red + green SHAs.
- [ ] **T4** — Phase 3 verify (all steps in the **worktree** root): (a) build the fixed binary first — `xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Release -derivedDataPath .derivedData build` — so the worktree's `.derivedData/...` path holds the post-fix app; then run the T1 command unchanged → `win=none` at +1 s (IC2); (b) awake full suite 0 failures (IC7); (c) rg checks (IC6); (d) reviewer `[code-review]` on `git -C <worktree> diff main...HEAD` → GO; (e) merge `--ff-only` or `--squash`, close worktree.

### T1 / T4 attribution command (oracle §3A; identical between runs — one variable per experiment)

Preconditions: run from the repo root where `.derivedData/Build/Products/Release/StatsLite.app` exists (T1: main repo; T4: worktree after the build step). The `swift -e` snippets use double quotes because the whole script is wrapped in single quotes.

```bash
caffeinate -u -d bash -c '
  APP=".derivedData/Build/Products/Release/StatsLite.app/Contents/MacOS/StatsLite"
  pkill -x StatsLite 2>/dev/null || true
  sleep 0.3
  "$APP" --open-popover --popover-cycles 1 --popover-hold 15 2>/tmp/statslite-attr.log &
  PID=$!
  trap "kill $PID 2>/dev/null || true" EXIT
  sleep 2.5
  echo "before_click: win=$(swift scripts/windowid.swift 2>/dev/null) display_asleep=$(swift -e "import CoreGraphics; print(CGDisplayIsAsleep(CGMainDisplayID()))")"
  swift -e "
    import CoreGraphics
    import Foundation
    let pt = CGPoint(x: 100, y: 500)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pt, mouseButton: .left)!.post(tap: .cghidEventTap)
    usleep(50_000)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pt, mouseButton: .left)!.post(tap: .cghidEventTap)
  "
  sleep 1.0
  echo "after_click_1s: win=$(swift scripts/windowid.swift 2>/dev/null)"
  sleep 1.5
  echo "after_click_2.5s: win=$(swift scripts/windowid.swift 2>/dev/null)"
'
```

Preconditions (FM4): Release build present at `.derivedData/.../StatsLite.app` (see above); `display_asleep=0` in `before_click`; click point (100, 500) is far from the popover (recorded bounds `xy=885,26 wh=306x597`, `step2-close-behavior-awake.txt:10`); `cycles=1` means any window at +1 s is the original unclosed popover (rules out H3); `t=2.5 s >> 0.25 s` and the point is not on the status button (rules out H4).

## Verification plan

- IC1/T1 and IC2/T4 use the identical command — single variable (the fix).
- IC3, IC4, IC5: unit tests in the red/green worktree runs (awake, `caffeinate -u -d`).
- IC6: `rg` checks run in T4 on the worktree diff.
- IC7: full suite awake before the reviewer spawn.
- Designer: not required (no visual, layout, or copy change). Oracle: satisfied (mandatory for this non-deterministic bug; report at `.pi/oracle/2026-10-21-popover-dismiss-report.md`).

## ISC snapshot

| IC | Claim | How verified |
| --- | --- | --- |
| IC1 | Pre-fix: popover ignores awake outside click (H2 owned) | T1 log: `win=<id>` at +1 s/+2.5 s |
| IC2 | Post-fix: same click dismisses it | T1 log: `win=none` at +1 s |
| IC3 | Status-button toggle preserved | existing popover tests green |
| IC4 | In-popover / on-button clicks untouched | new unit tests green |
| IC5 | Monitors scoped to shown state; removed on close/deinit | new unit tests green |
| IC6 | No `animates` write, no `NSApp.activate`, `.transient` kept | `rg` on worktree diff |
| IC7 | Full suite awake: 0 failures | `xcodebuild test` run under `caffeinate -u -d` |

## User confirmation

<!-- The interactive plan-approval milestone records user confirmation here. -->

### Receipts

- User approval: 2026-10-21 (“ok” after plan summary).
- `[plan-review]` pass 1: NO GO (3 findings) — `.pi/reviews/2026-10-21-popover-dismiss-plan-review.md`.
- `[plan-review]` pass 2: **GO** (all three findings verified resolved).
