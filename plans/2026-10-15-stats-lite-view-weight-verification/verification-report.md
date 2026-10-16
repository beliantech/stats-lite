# Verification Report: Reduce StatsLite View-Layer Weight

Date: 2026-10-15
Plan: `.pi/plans/2026-10-15-stats-lite-view-weight.md`
Commit verified: `de33eab` on `feat/2026-10-15-stats-lite-view-weight`
Baseline for pixel comparison: `f27eff3` (detached worktree, removed after AC-4)
Scope of this pass: Success Criteria AC-1, AC-4, AC-5 (VAC-1 to VAC-11) and AC-6.
Verification only. No code was changed to make any check pass.

---

## Result summary

| AC | Verdict | Measured value against target |
| :--- | :--- | :--- |
| AC-1 idle CPU | **FAIL** | SparklineView.body while closed: 0 executions (target 0, sub-check PASS). Idle process CPU: 3.77 % average (target < 0.1 %, sub-check FAIL). |
| AC-4 pixel equivalence | **PASS** | 0 differing pixels in light and dark at 240 pt (target 0). |
| AC-5 VAC ledger | **PASS** | 11 of 11 VAC items pass. 120 pixel checks, 0 failures. |
| AC-6 footprint | **FAIL** | 208 MB footprint (target < 50 MB). |

---

## Method

1. A temporary XCTest harness renders `SparklineView` through `ImageRenderer` at
   scale 2, which produces 2x pixel buffers (240 pt renders as 480 px wide).
   The harness sets `.environment(\.colorScheme, ...)` for light and dark mode.
   The harness asserts that light output differs from dark output, so a broken
   appearance override fails the run instead of producing wrong evidence.
2. The fixed synthetic series for all renders:
   `v_i = clamp(0.15 + 0.55 * i/30 + 0.12 * sin(1.7 * i), 0.02, 0.98)` for i = 0 to 30.
   AC-4 uses the first 30 values, so N = capacity = 30.
3. Pixel diffs and geometry checks use Python with Pillow. The full check log is
   `vac-analysis.txt`: 120 checks, 0 failures.
4. A first attempt overrode appearance with `NSAppearance.performAsCurrentDrawingAppearance`.
   That produced byte-identical light and dark files, so the override had no effect.
   The method changed to the environment colorScheme override and the harness kept
   the light-versus-dark inequality assertion.
5. The designer reference images are still in `/tmp/designer/`. The harness renders
   show the same geometry: right-anchored newest point, empty left region in warm-up,
   full-width stroke at N = 30. A pixel diff against the designer images is not valid
   because the designer used a different synthetic series.

---

## AC-1: idle CPU with the popover closed — FAIL

Protocol: a Release build of `de33eab` with temporary print hooks (removed before
this commit). The app launched at 20:55. A launch argument opened the popover at
+3 s and closed it at +8 s. `top -l 41 -s 10 -pid <pid>` sampled the process from
20:57:24 to 21:04:08, which is 40 interval samples over 6 m 44 s.

Sub-check A: `SparklineView.body` never executes while the popover is closed — **PASS**.

- The body-eval log shows 12 evaluations between the open marker and the close
  marker (9 while open, 3 during the close animation) and 0 evaluations after
  `VERIFY POPOVER DID CLOSE (controller released)`.
- The zero-evaluation window runs from 20:55:47 to the last capture at 21:11,
  which is about 15 minutes with the popover closed.
- Structural basis: `StatusItemController.swift` references
  `contentViewController` only at line 107 (lazy mount inside `togglePopover`,
  line 94) and line 128 (release inside `popoverDidClose`, line 122).
  `init` sets no content controller, so no popover view exists at launch.
- `StatusItemControllerPopoverTests` passed in the same test run.
- Evidence: `ac1-popover-cycle-body-eval.log`.

Sub-check B: main-thread idle CPU below 0.1 % — **FAIL**.

| Measurement | Window | Average process CPU |
| :--- | :--- | :--- |
| This instrumented instance (PID 87113), `top -l 41 -s 10` | 20:57:24 to 21:04:08 | **3.77 %** (min 1.3 %, max 6.2 %) |
| Same instance, quiet-machine re-measure | 21:06:49 to 21:08:53 | **2.92 %** |
| User's uninstrumented instance (PID 6497), same quiet window | 21:06:49 to 21:08:53 | **3.20 %** |

- Both instances agree within 0.3 percentage points, so the instrumentation does
  not cause the cost. The user's instance runs the same commit without any hook.
- A 4-second `sample` of PID 87113 shows the main thread blocked in `mach_msg`
  for 2,900 of 2,966 samples. The busy samples sit in `CA::Transaction::flush`
  and AutoLayout `systemLayoutSizeFittingSize` for the status item view.
- The popover path is idle, so the residual CPU comes from the menu bar item.
  The allocation evidence in AC-6 locates the same path.
- Evidence: `ac1-idle-cpu.txt`.

Measurement caveat: the user's instance PID 6497 had to stay alive, so two
instances ran at the same time. Each instance was measured separately and both
agree, so the caveat does not change the verdict.

---

## AC-4: pixel equivalence at full buffer — PASS

Protocol: a detached worktree of `f27eff3` at `../baseline-f27eff3`. The same
harness ran in both checkouts and rendered the fixed series at N = capacity = 30,
240 pt width, light and dark, scale 2. Pillow computed the RGBA difference.

| Appearance | Buffer size | Diff bounding box | Differing pixels |
| :--- | :--- | :--- | :--- |
| Light | 480 x 76 px | None | **0** |
| Dark | 480 x 76 px | None | **0** |

The result is empirical and not an algebraic argument. The buffers are identical
pixel for pixel in both appearances. The baseline worktree was removed after the check.

Evidence: `ac4-pixel-diff.txt`, `renders/ac4_baseline_w240_light.png`,
`renders/ac4_baseline_w240_dark.png`, `renders/ac4_current_w240_light.png`,
`renders/ac4_current_w240_dark.png`.

---

## AC-5: VAC-1 to VAC-11 ledger — PASS (11 of 11)

Renders: 30 files for N = 0, 1, 5, 15, 30 at 240 / 375 / 768 pt in light and dark,
in `renders/`, with per-item copies in `vac-1/` to `vac-11/`.
Pixel analysis: `vac-analysis.txt`, 120 checks, 0 failures.

| ID | Verdict | Evidence | Justification |
| :--- | :--- | :--- | :--- |
| VAC-1 | **PASS** | `vac-1/n0_w{240,375,768}_{light,dark}.png`, `vac-analysis.txt` rows `VAC-1` | All six N = 0 renders have an alpha bounding box of None, so they contain zero stroke and zero fill. Height is 38 pt through `.frame(height: 38)` at `SparklineView.swift:85`. |
| VAC-2 | **PASS** | `vac-2/n1_w*.png`, `vac-analysis.txt` rows `VAC-2` | At N = 1 the drawn width is at most 5 px (a 3 px dot plus antialiasing) at every width and mode, so no horizontal flat line crosses the card. |
| VAC-3 | **PASS** | `vac-3/n1_w*.png`, `vac-analysis.txt` rows `VAC-3` | The dot right edge sits within 2.5 px of `x = width - 1.5 pt` at all six renders, and the dot vertical center matches the value formula within 3 px. |
| VAC-4 | **PASS** | `vac-4/n{5,15}_w240_*.png`, `vac-analysis.txt` rows `VAC-4` | For N = 5 and N = 15 at 240 pt the stroke right edge matches `x = width - 1.5 pt` plus the round cap within 3 px, so the newest point anchors at the right edge. |
| VAC-5 | **PASS** | `vac-5/n{5,15}_w*.png`, `vac-analysis.txt` rows `VAC-5`, `SparklineViewTests` | Every rendered warm-up span equals `(N-1) * dx` right-anchored within 3 px AA tolerance at all widths, and `testWarmupSpansRightAnchoredWithFixedStep` asserts the exact `dx` step. |
| VAC-6 | **PASS** | `vac-6/n{5,15}_w*.png`, `vac-analysis.txt` rows `VAC-6` | Every pixel column left of the stroke is fully transparent, and the area fill reaches the bottom row inside the span, so the fill closes beneath the line and leaves the left region empty. |
| VAC-7 | **PASS** | `vac-7/n30_w*.png`, `vac-analysis.txt` rows `VAC-7` | At N = 30 the stroke spans x = 1.5 pt to x = width - 1.5 pt within 1 px at all six renders. |
| VAC-8 | **PASS** | `vac-8/vac8_dx_shift.txt`, `SparklineViewTests` | Two sequential renders on a full buffer (N = 29 then N = 30) shift all 29 shared samples left by exactly dx within 1e-9. The shift holds at 240, 375 and 768 pt, the step stays rigid, and y never moves. `SparklineViewTests` repeats the fixed-step assertions at unit level. |
| VAC-9 | **PASS** | `vac-9/n{5,15,30}_w*.png`, `vac-analysis.txt` rows `VAC-9` | Per-width absolute spans match `(N-1) * dx` within the AA tolerance at 240, 375 and 768 pt with no clipping, and dx scales with plotWidth (8.1724 / 12.8276 / 26.3793 pt). |
| VAC-10 | **PASS** | `vac-10/` full matrix, `vac-analysis.txt` rows `VAC-10` | Light and dark differ in every state (max channel delta up to 255). The stroke uses the adaptive system blue: RGB(0,135,255) in light and RGB(0,145,255) in dark. Fill alpha falls from 23 below the line to 7 near the bottom, which matches the 0.25 to 0.02 gradient. No pixel falls outside the expected geometry in either mode, so no stale pixels exist. |
| VAC-11 | **PASS** | `vac-11/vac-11-evidence.txt` | `SparklineView.swift:86` carries `.accessibilityHidden(true)`. Cards expose complete spoken summaries at `CPUCardView.swift:57`, `MemoryPressureCardView.swift:64`, `GPUCardView.swift:53`. `MenuBarAccessibilityTests` passed, and the full suite ran 148 tests with 0 failures. |

Note on VAC-9: the first analysis compared span ratios between widths. The ratio
metric is unstable because the AA bounding box rounds to integer pixels and the
240 pt span is short. The check changed to a per-width absolute span comparison
against the exact `(N-1) * dx` geometry. The per-width numbers pass with margin.

---

## AC-6: footprint after idle — FAIL

Protocol: the same idle Release instance (PID 87113). The popover opened once and
closed at 20:55:47. `footprint` ran at 21:09, which is more than 60 s after close.

| Process | Age at measurement | Footprint | Malloc Small dirty | RSS (`ps`) |
| :--- | :--- | :--- | :--- | :--- |
| PID 87113 (this verification instance) | 13 min after close | **208 MB** | 192 MB in 58 regions | 279,472 KB (273 MB) |
| PID 6497 (user's instance, uninstrumented) | 25 min | **243 MB** | 225 MB in 78 regions | 365,632 KB (357 MB) |
| Fresh probe, popover never opened | 4.5 min | **92.1 MB** | (stack logging active) | n/a |

Target: < 50 MB dirty. The fresh probe passes 50 MB within the first minutes
while its popover never opens, so the growth starts at launch with the popover closed.

Root-cause lead for the planner (not fixed here, verification is report-only):

- `heap 87113 -sortBySize` at 14 minutes: 293,735 live nodes, 189,010,853 bytes.
  251,522 non-object nodes hold 181,455,889 bytes. Largest node counts are 16 B
  (100,141 nodes), 2.5 KB (35,590), 2 KB (35,927), 32 B (21,866), 192 B (18,548).
- `malloc_history <pid> -callTree` on the fresh probe (stack logging on,
  popover never opened): 97,176 allocations, 57.8 MB in 271 s. Of that total,
  55,530 calls and 50.9 MB (88 %) sit under `@objc CGDrawingLayer.draw(in:)`
  (SwiftUI) into RenderBox display list rendering and glyph rasterization
  (`CGGlyphBuilderLockBitmaps`, `CGGlyphBitmapCreate`). That is about 205 SwiftUI
  layer redraws per second.
- AC-1 and AC-6 plausibly share one cause: the menu bar SwiftUI view redraws per
  display frame instead of per 2 s tick. The next step for the planner is an
  Instruments Time Profiler plus Allocations run on one idle instance to find what
  invalidates the menu bar view per frame.

Evidence: `ac6-footprint.txt`, `ac6-heap-histogram-87113.txt`,
`ac6-allocation-calltree.txt` (trimmed excerpt of a 129,771-line call tree).

---

## Failures back to the planner

1. AC-1 sub-check B fails. Idle process CPU with the popover closed measures
   2.9 % to 3.8 % against a target below 0.1 %. Two instances agree, and the
   popover view path provably does not execute. The cost sits in the always-on
   menu bar item.
2. AC-6 fails. Footprint is 208 MB against a target below 50 MB, and a fresh
   instance reaches 92 MB in 4.5 minutes without opening the popover.
3. Both failures point at one path: about 205 SwiftUI `CGDrawingLayer.draw`
   calls per second with the popover closed, which burn CPU and grow the heap.

No code was changed in this pass. All instrumentation was removed before the commit.

---

## Cleanup record

- Temporary print hooks reverted in `SparklineView.swift`, `StatusItemController.swift`,
  `StatsLiteApp.swift`. `rg VERIFY StatsLite/` finds nothing.
- Temporary harness files removed: `StatsLiteTests/TemporaryVACHarnessTests.swift`
  in this worktree and `TemporaryBaselineHarnessTests.swift` in the baseline.
- The baseline worktree `../baseline-f27eff3` was removed.
- Probe and test processes terminated. The user's instance PID 6497 keeps running.
- `git status` shows only this evidence directory as new.

## Evidence files

| File | Content |
| :--- | :--- |
| `verification-report.md` | This report with the AC and VAC ledgers. |
| `ac4-pixel-diff.txt` | AC-4 Pillow RGBA diff result for light and dark. |
| `ac1-idle-cpu.txt` | AC-1 `top` samples, averages and verdict. |
| `ac1-popover-cycle-body-eval.log` | Instrumented launch log with body-eval markers. |
| `ac6-footprint.txt` | `footprint` output for both instances plus `ps` RSS. |
| `ac6-heap-histogram-87113.txt` | `heap -sortBySize` excerpt for the 14-minute instance. |
| `ac6-allocation-calltree.txt` | `malloc_history -callTree` header and draw branch. |
| `vac-analysis.txt` | 120 pixel checks across all VAC items, 0 failures. |
| `vac8_dx_shift.txt` | N = 29 to N = 30 exact dx shift at three widths. |
| `renders/` | 30 state-matrix renders plus 4 AC-4 pair renders. |
| `vac-1/` to `vac-11/` | Per-VAC screenshot copies and the VAC-11 text evidence. |

---

# Revision 2: re-measurement after Phase 5

Date: 2026-10-16
Commit verified: `068441e` (fix(menubar): remove digit-roll animation, pin hosting view sizing) on `feat/2026-10-15-stats-lite-view-weight`.
Measurement instance: PID 40638, fresh Release build of `068441e`, launched 23:33:08. The user's old-build instance PID 6497 was left untouched.
Scope: AC-11a, AC-11b, AC-1, AC-6, and the VAC spot re-check. Verification only. No source code was changed. The temporary render harness was deleted before commit.

## Result summary (revision 2)

| AC | Verdict | Measured value against target |
| :--- | :--- | :--- |
| AC-11a redraw churn | **PASS** | 0 hits on `-[RBInterpolatedDisplayListContents renderInContext:options:]` over 78 s idle with the popover closed (target 0 over >= 60 s). |
| AC-11b 2 s tick | **PASS** | The accessibility label re-armed 38 times in 78 s (one per 2 s tick). Three consecutive ticks sampled 2 s apart change the label: "CPU 17 percent" then "CPU 9 percent" then "CPU 10 percent". One popover open/close cycle ran and the release was verified. |
| AC-1 idle CPU | **FAIL** | 0.1477 % average over 315.0 s (target < 0.1 %). Two corroborating windows read 0.1606 % and 0.1538 %; `ps` TIME and `top` agree. Round 1 measured 2.9 % to 3.8 %, so Phase 5 gives about a 25x reduction, but the target is not met. |
| AC-6 footprint | **PASS** | 31 MB dirty at T0+105 s, 31 MB at T0+6 min, 32 MB at T0+15 min after one popover cycle (target < 50 MB). RSS 129 MB to 129.6 MB. Footprint peak 199 MB since launch, information. |
| VAC spot re-check | **PASS** | 0 differing pixels in every comparison: 10 of 10 sparkline renders against the committed matrix, 2 of 2 status item renders against the pre-Phase-5 build. |

AC-12 requires AC-1 and AC-6 to pass. AC-12 fails on the AC-1 component.

## Revision 2 method

1. No source changes. A temporary XCTest render harness (`TemporaryR2RenderTests.swift`, ImageRenderer at scale 2) was added, run, and deleted before this commit, as in round 1. The baseline renders came from a `git archive` extraction of `274756e` into `/tmp`, not from a second git worktree.
2. The app has no launch arguments. The agent host has no Accessibility and no Screen Recording permission, so UI scripting and screenshots are unavailable. The popover cycle and the tick samples therefore run through lldb: a Python SBAPI script attaches, sets breakpoints, resumes the process, polls the process state, evaluates Swift expressions in the stopped frame, and detaches. `self.togglePopover(nil)` opens and closes the popover in-process.
3. AC-11a uses an lldb batch session with auto-continue breakpoints. The blocked `process continue` command ends on an external SIGSTOP sent to the target, after which lldb prints hit counts and detaches. A third breakpoint on `StatusItemController.updateAccessibility` acts as a pipeline sanity counter.
4. AC-1 uses two instruments: `top -l 37 -s 10` for 360 s, and `proc_pidinfo` (PROC_PIDTASKINFO) counters around a 315 s idle stretch. The counters are mach absolute time units, not nanoseconds: `mach_timebase_info` returns numer=125 denom=3, so 1 unit = 41.6667 ns. The first interpretation in `ac1-r2-idle-cpu.txt` treats them as nanoseconds. The file keeps that error and appends the correction, the recomputed value, and two corroborating windows. The `ps -o time` delta over the same window agrees with the corrected arithmetic.

## AC-11a: redraw churn eliminated - PASS

- Target: `RBInterpolatedDisplayListContents renderInContext:` count = 0 over >= 60 s idle, popover closed.
- Measured: 0 hits on `-[RBInterpolatedDisplayListContents renderInContext:options:]` over 78 s (23:49:42 to 23:51:00).
- Secondary counter: the `CGDrawingLayer.draw` family hit 26 times in the same window, all at `@objc CGDrawingLayer.draw(in:)`, that is 0.33 calls per second. Round 1's allocation trace implied about 205 draw-layer renders per second. What remains are content-driven redraws on the tick, not per-frame churn.
- Sanity counter: `StatusItemController.updateAccessibility` hit 38 times in 78 s, one hit per 2 s tick. The counting pipeline was live for the whole window.
- Evidence: `ac11a-redraw-window.log`.

## AC-11b: status item still updates on the 2 s tick - PASS

- Three consecutive tick stops 2 s apart (00:13:51, 00:13:53, 00:13:55) show changing live values in the accessibility label and in the raw snapshot:
  - tick 1: label "Stats Lite: CPU 17 percent, Memory Pressure Normal at 12 percent, GPU 0 percent", raw cpu = 0.17093784078516902;
  - tick 2: label "Stats Lite: CPU 9 percent, ...", raw cpu = 0.092890503373118841;
  - tick 3: label "Stats Lite: CPU 10 percent, ...", raw cpu = 0.096721311475409841.
- `MenuBarStackedItemView.body` evaluated once per tick in that window (4 hits over the 3-tick window including one initial invalidation), and `updateAccessibility` hit once per tick.
- One popover open/close cycle ran: opened 00:07:05, close called 00:08:42, verified at 00:13:51 with `popover.isShown == false` and `contentViewController` released.
- The log also contains two earlier scripted attempts with recoverable harness API errors. They are kept in `ac11b-tick-samples.log` as history. The first executed expression opened the popover; the controlled close in session C completes the single cycle.
- Evidence: `ac11b-tick-samples.log`.

## AC-1: idle CPU with the popover closed - FAIL

- Target: < 0.1 % over >= 5 minutes, popover closed.
- Instrument 1: `top -l 37 -s 10 -pid 40638 -stats pid,cpu`, 00:15:19 to 00:21:19. 36 interval samples after the cumulative first sample is excluded. Every sample reads 0.1 % at top's 1-decimal resolution (average/min/max 0.1 % / 0.1 % / 0.1 %).
- Instrument 2: `proc_pidinfo` counter window 00:30:11 to 00:35:26, wall 315.0 s, cpu delta 465.4 ms after the timebase correction. Average 0.1477 %.
- Corroboration: a 45.2 s window read 0.1606 % while top sampled the same process; a 60.0 s window read 0.1538 %; the `ps -o time` delta over that 60 s is +90 ms, that is 0.150 %.
- Verdict: average idle CPU is about 0.15 %, above the 0.1 % target. AC-1 fails. The value is about 25x below round 1's 2.9 % to 3.8 %, but the plan's target is not met.
- Residual-cost lead for the planner: the 26 content-driven `CGDrawingLayer.draw(in:)` calls per 78 s plus the per-tick sampling and label path plausibly account for the residual 0.15 %.
- Evidence: `ac1-r2-idle-cpu.txt`.

## AC-6: footprint after one popover cycle - PASS

- Protocol: exactly one popover open/close cycle on instance 40638 (open 00:07:05, close 00:08:42 to 00:08:43). `footprint` readings at T0+105 s, T0+6 min, and T0+15 min.
- Measured dirty footprint: 31 MB, 31 MB, and 32 MB. Malloc Small stays at 19 MB in 16 regions at all three readings. There is no growth, so no vmmap was needed.
- RSS: 129 MB (132256 KB) at T0+105 s, 129.6 MB (132288 KB) at T0+15 min. Footprint peak since launch is 199 MB (information; the peak dates from launch and popover activity, the steady state is 31 MB).
- Verdict: 32 MB at the 15-minute reading, under the 50 MB target.
- Evidence: `ac6-r2-footprint.txt`.

## VAC spot re-check - PASS

- Popover visuals: SparklineView rendered at HEAD with the committed-matrix parameters (the plan's series formula, N in {0, 1, 5, 15, 30}, capacity 30, 240 pt, scale 2, tint `.blue`, light and dark). Pillow per-pixel RGBA diff against the committed round-1 renders: 0 differing pixels in all 10 comparisons.
- Status item visuals: MenuBarStackedItemView rendered at HEAD and at pre-Phase-5 commit `274756e` with identical synthetic values (CPU 10 %, memory pressure 15 % Normal, GPU 42 %, all metrics enabled), light and dark. Per-pixel diff: 0 differing pixels in both comparisons. Both pairs are 228x48 px.
- Harness guards: light and dark renders differ in both view families, so a broken appearance override would fail the run. Both builds report the same synthetic snapshot values in `vac-r2-render-log-*.txt`.
- Evidence: `vac-r2-pixel-diff-spark.txt`, `vac-r2-pixel-diff-menubar.txt`, `vac-r2-render-log-head.txt`, `vac-r2-render-log-base.txt`, `vac-r2-renders/`.

## Revision 2 cleanup record

- The measurement instance PID 40638 was killed after the measurements. The user's instance PID 6497 keeps running.
- The temporary harness `StatsLiteTests/TemporaryR2RenderTests.swift` was deleted. `git status` shows only this evidence directory as new.
- The baseline extraction at `/tmp/statslite-r2-baseline` and the build products under `/tmp/statslite-r2-dd` and `/tmp/statslite-r2-bdd` were removed after the measurements.

## New evidence files (revision 2)

| File | Content |
| :--- | :--- |
| `ac11a-redraw-window.log` | Full lldb session log of the 78 s redraw window, hit counts, summary. |
| `ac11b-tick-samples.log` | Tick samples, label strings, popover state checks, hit counts. |
| `ac1-r2-idle-cpu.txt` | `top` samples, counter windows, unit correction, verdict. |
| `ac6-r2-footprint.txt` | Three `footprint` readings plus RSS after the popover cycle. |
| `vac-r2-pixel-diff-spark.txt` | Sparkline render diff against the committed matrix: 10 of 10 zero. |
| `vac-r2-pixel-diff-menubar.txt` | Status item render diff against `274756e`, sparkline HEAD vs baseline diff: all zero. |
| `vac-r2-render-log-head.txt`, `vac-r2-render-log-base.txt` | Harness logs: synthetic values, render dimensions. |
| `vac-r2-renders/` | 24 render PNGs: sparkline head and base, status item head and base, light and dark. |
