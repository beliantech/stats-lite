Plan name: popover-test-close-animation-determinism

# Plan: popover-test-close-animation-determinism

**Date:** 2026-10-22
**Repository:** /Users/jonathan/beliantech/stats-lite-macos
**Risk class:** R1 (test-only change; no production code, no visible UI, no designer required)

## Intent

Make `StatsLiteTests/StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease` deterministic regardless of display-sleep state. The test currently fails with exactly 5 assertions whenever the display is asleep and passes when awake.

## Root cause — attribution evidence (measured before any hypothesis)

1. **This-session A/B, one variable:** with `CGDisplayIsAsleep(165) = 1`, the isolated test failed 5× (04:09:48 worktree, 04:10:58 main reproduction); after changing ONLY display state (`caffeinate -u`, `CGDisplayIsAsleep = 0`), the same test passed with **0 failures in 6.07 s**.
2. **Power-log timeline (oracle, `pmset -g log`):** every failing run (04:08:21, 04:09:48, 04:10:58) executed after "Display is turned off" at 04:07:59; both passing coder runs (03:40, 03:54:35) executed with the display on. `xcodebuild` holds `PreventUserIdleSystemSleep` (`kCPU`) but NOT `PreventUserIdleDisplaySleep` (`kDisp`).
3. **Repo prior:** `.pi/plans/2026-10-21-popover-panel-fix.json:112` — "StatusItemControllerPopoverTests fails asleep (5) and passes awake (299/299)"; `artifacts/2026-10-21-popover-panel-fix/verification-report.md:274-282, :340-345` — same test, `CGDisplayIsAsleep=1` → 5 failures, `caffeinate` awake → 0.
4. **Mechanism:** `StatusItemController.init` leaves `popover.animates` at the AppKit default `true` (`StatsLite/StatusItemController.swift:62-64`). `togglePopover` calls `popover.performClose(sender)` (`:107`). The close runs as a window-transform animation whose completion path (`_windowTransformAnimationDidEnd:` → `_executeClosingBlock` → `popoverDidClose`) clears `contentViewController` at `:178`. On macOS 14+, AppKit drives this via `CADisplayLink`, which suspends when the display is asleep — teardown never completes, so the `contentViewController == nil` wait times out at `StatusItemControllerPopoverTests.swift:57`; failures at `:110/:117/:123` are consequences (stale `first` controller never released).
5. **Disproven hypotheses (oracle):** TCC/Apple Events permissions (test uses in-process selector, no AX/Apple Events, H5); `performClose` delegate veto (no `popoverShouldClose` implemented; passes awake, H4); 0.25 s debounce race (would fail earlier at `waitUntilShown`, H3).

## ISC — binary yes/no criteria

- **IC1** `StatsLiteTests/StatusItemControllerPopoverTests.swift` sets `popover.animates = false` before any toggle in `testTogglePopoverCyclesMountAndRelease` (path:line cited in receipt).
- **IC2 (asleep verification, consent-gated)** With `CGDisplayIsAsleep == 1`, the isolated test run reports **0 failures**. Fallback if display sleep cannot be triggered on this machine: 5 consecutive isolated runs while awake all pass (0 failures), AND the recorded asleep-red evidence (this plan's evidence section) is cited as the red receipt — with the fallback explicitly noted in the task receipt.
- **IC3** Full suite while awake: 305 tests, 0 failures.
- **IC4** Production untouched: `rg 'animates' StatsLite/*.swift` shows no `animates = false` added to app source; popover stays animated for real users.
- **IC5** Test still drives the production path: `Selector("togglePopover:")` retained; no direct `popover.close()` call added; the 0.25 s debounce guard and `popoverDidClose` release path are still exercised.
- **IC6** Diff touches exactly 1 file (`StatsLiteTests/StatusItemControllerPopoverTests.swift`).

### Falsification / failure modes

- **FM1 — false root cause:** if display sleep is NOT the cause, the post-fix asleep run still fails (IC2 fails) and the plan stops — no second variable is batched in.
- **FM2 — production leak:** if `animates = false` appears in app source, IC4 fails.
- **FM3 — shortcut:** if the test bypasses `togglePopover:` (direct `close()`), IC5 fails; the debounce guard would go untested.
- **FM4 — wrong failure signature:** if failures reappear while AWAKE at different lines (scene-race retry path `:61-76`), that is the separate documented `[StatusBar] Unhandled disconnected scene` issue (plans/2026-10-16-network-monitor.md:437), not this plan's root cause — report, do not silently absorb.

## Approach

**Chosen fix (oracle Option A — minimal, test-scoped):** set `popover.animates = false` inside the test after constructing the controller. Rationale:
- Production behavior unchanged (real users keep the fade-out).
- The test still exercises the exact production action selector, `show(relativeTo:…)`, `performClose`, `popoverDidClose`, `contentViewController = nil`, and the debounce guard.
- Close teardown becomes synchronous — no dependency on display-link vsync ticks → deterministic across display sleep, screen lock, and headless CI.

**Rejected alternatives:**
- `popover.close()` in the test — bypasses the debounce and `isShown` branch (FM3).
- `animates = false` in `StatusItemController.init` — removes the standard fade-out for users (changes production UI).
- `performClose` → `close()` swap in production — same animation path; does not fix the dependency (H4 disproven).
- Process-activity/App Nap workarounds (H2) — unnecessary once teardown is synchronous.

**Mechanism citations:** Apple `NSPopover.close()` docs (animates gates the fade-out), OSX-Runtime-Headers `NSPopover.h` (did-close notification only from animation completion), Apple `CADisplayLink` docs (suspends on inactive display), repo artifacts `step2-close-behavior-awake.txt` (awake teardown 0.33–0.90 s) vs `step2-window-validity.txt` (asleep window open ≥42.6 s).

## Refactors

None. Band-aid scan of the test file: no suppressed assertions or masked values; this change removes an environmental dependency of the test, it does not paper over a product defect (the product behaves correctly for awake users, which is the supported interactive case).

## Out of scope (documented follow-ups, not this plan)

- `scripts/measure_popover_footprint.sh` shares the display-sleep vulnerability (`startMeasurementCycle` closes an animated popover, `StatusItemController.swift:159`) — future task: add a `CGDisplayIsAsleep` startup check or wrap in `caffeinate`.
- The `[StatusBar] Unhandled disconnected scene` race (FM4) if it ever reproduces while awake.

## Tasks

- [x] **T1** — [red] Create worktree `feat/2026-10-22-popover-test-close-animation-determinism`. With user consent, trigger display sleep (`pmset displaysleepnow`) and run the isolated `StatusItemControllerPopoverTests` → capture the 5-failure red output (IC2 precondition). If sleep cannot be triggered, attach the recorded asleep-red evidence + run the awake determinism baseline (5× pass) as the red receipt, noted explicitly. No code edits. red ✅ (asleep precondition met: `pmset displaysleepnow` exit 0, CGDisplayIsAsleep=1 before/during/after, isolated run exit 65 with exactly the 5 expected failures at :57/:110/:117/:57/:123, popover dump shows `animates=1`, working tree clean, display restored via `caffeinate -u`) · green — · review ⏳
- [x] **T2** — [green] Add `popover.animates = false` to the test (IC1). Run isolated test while display asleep → 0 failures (IC2). Run full suite awake → 305/0 (IC3). Then IC4–IC6 rg/diff checks. Commit as one conventional commit (`test:` scope). red ✅ (T1 asleep, 5 failures) · green ✅ eb21651 (IC1 `:97`; IC2 falsification: asleep run 0 failures in 5.98 s vs red 14.07 s/5 failures, one variable; IC3 305/0; IC4 no `animates` in app source; IC5 `togglePopover:` at `:21`, no `close()`; IC6 diff = 1 file, +3 lines) · review ⏳
- [x] **T3** — Verify ✅ (planner-independent): `git diff --stat main...HEAD` = 1 file `+3` (2 comment + 1 code); `rg animates` in test → `:97`; app source → no matches; `togglePopover:` retained at `:21`, no `.close()` in test; full suite awake 305/0 TEST SUCCEEDED; isolated class re-run 0 failures (5.97 s); working tree clean. IC2 asleep evidence: T1 red 5 failures ↔ T2 green 0 failures, both measured `CGDisplayIsAsleep=1` during the run. red — · green — · review ⏳
- [x] **T4** — Reviewer `[code-review]` on `git diff main...HEAD`: test-only diff, IC fidelity, no shortcut (IC5), root-cause evidence chain sound. red ✅ · green ✅ · review ✅ GO (session 085e06dc; IC1–IC6 satisfied, production untouched)
- [x] **T5** — Merge `--squash` to main, record SHA, clean up worktree, update receipts. red — · green — · review ✅
  - Merge SHA: `d8d98bb7e61379c86f4abd1e54add6148f6c2698` (`test: disable popover animation in close-cycle test for display-independent teardown`)
  - Post-merge on main: full suite 305 tests, 0 failures, TEST SUCCEEDED.

Sequencing: T1 then T2 strictly sequential in the same worktree (red and green are separate spawns).
