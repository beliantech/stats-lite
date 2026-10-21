# Verification report: popover panel fix (plan 2026-10-21-popover-panel-fix)

This file collects the wave-3 verification sections. The F1 memory gate
runs first. The visual (F3) verification appends its own section later.

## F1 memory gate: full content in the app-owned panel

Date: 2026-10-21 10:09 +08 (Asia/Kuala_Lumpur). Branch `fix/panel-popover`,
commit `ef3a1bf`. One variable: the container swap already implemented on
this branch (NSPopover -> app-owned `PopoverPanel`), full production
`PopoverContentView` content, Release build. Plan:
`.pi/plans/2026-10-21-popover-panel-fix.json`, hypothesis F1.

### 1. Gate verdict: FAIL on peak. The panel alone does not reach the target

The F1 gate passes at `max_graphics_mb_across_opens <= 80.0` MB and fails
at or above 140.0 MB. Measured value: **265.0 MB**. The falsification
signature fires: full content in the panel wires a graphics pool of its
own, independent of the container. Per the plan, no fix was attempted in
this branch. The Canvas -> CoreGraphics redraw lever (step2a pattern) is
the fallback candidate and lives on a separate branch. The planner owns
that decision.

One sub-condition passed. The F1 signature also asks for a 40 s tail at
or below 40 MB footprint. Measured tail: **27.0 MB footprint, 0.7 MB
gfx Dirty**. The panel removes the post-close residue that the NSPopover
path left behind. The residue is gone. The while-open peak is not.

Recorded metrics, all from the harness summary block:

| Metric | Value |
| --- | --- |
| max_graphics_mb_across_opens | 265.0 MB (FAIL vs 80 target, FAIL vs 140 ceiling) |
| per-cycle peak gfx Dirty | 265.0 / 249.0 / 145.0 MB |
| per-cycle peak footprint | 299 / 283 / 179 MB |
| run_phys_footprint_peak_mb | 299.0 |
| idle-after-close gfx (footprint) | 0.6 (30.0) / 8.7 (39.0) / 8.7 (39.0) MB |
| 40 s tail (footprint / gfx Dirty) | 27.0 / 0.7 MB |
| max_gfx_regions | 44 |
| IOSurface Dirty while open | present, max 1.9 MB per sample, 98 of 107 open-window samples above 0 |
| samples / no_process_ticks / footprint_failed_ticks | 193 / 0 / 0 |

### 2. Run

Command, verbatim:

```text
worktrees/measure-footprint-harness/scripts/measure_popover_footprint.sh \
  --binary /Users/jonathan/beliantech/stats-lite-macos/worktrees/panel-popover/.derivedData/Build/Products/Release/StatsLite.app \
  --output /Users/jonathan/beliantech/stats-lite-macos/artifacts/2026-10-21-popover-panel-fix/step1-full-content-panel.txt \
  --cycles 3 --hold 15
```

Deviation from the task's literal command, with reason. The
`scripts/measure_popover_footprint.sh` on this branch is identical to
main's 198-line version. It predates the wave-1 harness fix of the
attribution plan. It samples by `pgrep -x StatsLite` per tick and its
summary has no region, IOSurface, or idle_after_close columns. The task
explicitly requires exact-PID sampling as fixed in wave 1. The wave-1
harness lives in `worktrees/measure-footprint-harness`. Its
`--binary` flag points it at this branch's Release build, so the script's
own build logic is skipped and `xcodebuild -configuration Release
-derivedDataPath .derivedData build` ran by hand in this worktree first
(same command the script runs). The artifact header records the binary
path as provenance. Cycle semantics are identical to the step0/step1/
step3b runs, so the numbers stay comparable.

`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` was exported
for `xcodebuild` because the active developer directory is CommandLineTools.

### 3. Summary block, verbatim from the artifact

From `artifacts/2026-10-21-popover-panel-fix/step1-full-content-panel.txt`
(main repo root, untracked):

```text
cycle 1/3  open_ts 1792548458.178  close_ts 1792548473.393  peak_footprint_mb 299.0  peak_gfx_dirty_mb 265.0  peak_gfx_dirty+reclaim_mb 265.0
cycle 1/3  gfx_dirty+reclaim invariant: n 33  min 209.0  max 265.0  spread 56.0  spread_pct 21.1  stable no
cycle 1/3  idle_after_close: ts 1792548474.852  footprint_mb 30.0  gfx_dirty_mb 0.6  gfx_dirty+reclaim_mb 216.6
cycle 2/3  open_ts 1792548475.428  close_ts 1792548490.528  peak_footprint_mb 283.0  peak_gfx_dirty_mb 249.0  peak_gfx_dirty+reclaim_mb 249.0
cycle 2/3  gfx_dirty+reclaim invariant: n 32  min 193.0  max 249.0  spread 56.0  spread_pct 22.5  stable no
cycle 2/3  idle_after_close: ts 1792548492.065  footprint_mb 39.0  gfx_dirty_mb 8.7  gfx_dirty+reclaim_mb 200.7
cycle 3/3  open_ts 1792548492.545  close_ts 1792548507.570  peak_footprint_mb 179.0  peak_gfx_dirty_mb 145.0  peak_gfx_dirty+reclaim_mb 200.7
cycle 3/3  gfx_dirty+reclaim invariant: n 32  min 120.7  max 185.0  spread 64.3  spread_pct 34.8  stable no
cycle 3/3  idle_after_close: ts 1792548509.234  footprint_mb 39.0  gfx_dirty_mb 8.7  gfx_dirty+reclaim_mb 120.7
max_graphics_mb_across_opens 265.0
max_gfx_reclaim_mb 216.0  max_gfx_regions 44  max_gfx_dirty+reclaim_mb 265.0
invariant_gfx_dirty_plus_reclaim_stable no (stable if spread <= 20% of per-cycle max, window open+1.0s..close+1.5s)
overall_peak_footprint_mb 299.0
run_phys_footprint_peak_mb 299.0
final_idle_footprint_mb 27.0  final_idle_gfx_dirty_mb 0.7  idle_sample_ts 1792548548.716
samples 193  no_process_ticks 0  footprint_failed_ticks 0
```

### 4. Hook and panel sanity: the panel was what showed

All hook markers matched. The app log carries three
`cycle N/3 open` markers, three `cycle N/3 close` markers, and the final
`cycles complete` marker. `no_process_ticks 0` and
`footprint_failed_ticks 0` in the summary. Zero lines mention a popover
window. The production panel path logged its validity lines on every
cycle:

```text
[measurement] 1792548458.211 panel open fitted 280x538 preferred 0x0
[measurement] 1792548458.213 panel did show frame 280x538
[measurement] 1792548458.737 CG view of same window x=1289 y=89 w=253x485 scale 2 screen 1080
[measurement] 1792548473.393 cycle 1/3 close
[measurement] 1792548473.395 panel did close
```

A watchdog line with `CG view of same window` follows each open. It
queries `CGWindowListCopyWindowInfo` for the panel's own window id, so a
window-server entry exists while the pool is measured. The measured pool
belongs to the panel session. No stale popover was involved.

The content settles at 280x571 pt after the first layout pass. The
first open starts at 280x538 and grows once.

### 5. Comparison table: step0, step1, step3b, this run

| Metric | step0 baseline (full content, NSPopover) | step1 (bare view, NSPopover) | step3b (bare view, NSPanel) | This run (full content, NSPanel) |
| --- | --- | --- | --- | --- |
| max_graphics_mb_across_opens | 279.0 MB | 168.0 MB | 0.0 MB | 265.0 MB |
| per-cycle peak gfx Dirty | 279 / 266 / 250 | 168 / 168 / 152 | 0.0 / 0.0 / 0.0 | 265.0 / 249.0 / 145.0 |
| per-cycle peak footprint | 326 / 305 / 292 | 200 / 201 / 185 | 20 / 20 / 21 | 299 / 283 / 179 |
| run_phys_footprint_peak | 326.0 | 204.0 | 21.0 | 299.0 |
| max gfx regions | 61 | 34 | 0 | 44 |
| IOSurface while open | 2.9-6.2 MB Dirty | RenderBox 596x1178, 2.73 MB | none | harness Dirty max 1.9 MB; snapshot maps no RenderBox surface, maps 1140-page `archive.metallib` |
| idle-after-close gfx Dirty | 162 / 146 / 146 | 1.2 / 1.2 / 1.2 | 0.0 / 0.0 / 0.0 | 0.6 / 8.7 / 8.7 |
| 40 s tail (footprint / gfx) | 185.0 / 146.0 | 28 / 1.2 | 20.0 / 0.0 | 27.0 / 0.7 |
| re-lock while open | every ~5 s | one spike, drains | none | dirty<->reclaim oscillation, invariant ~265 MB in cycle 1 |

The step3b -> this-run delta is the full-content cost inside the panel,
the number that had never been measured: 0.0 -> 265.0 MB peak gfx
Dirty, 0 -> 44 regions, 21 -> 299 MB run phys peak. The bare-view panel
stayed flat. The content wires the pool. While open, this run behaves
like the NSPopover runs: the same order of magnitude (265.0 vs 279.0 MB
step0 peak) and a dirty<->reclaim oscillation. The declining cycle peaks
(265 -> 249 -> 145) show partial retention relief across cycles. After
close, the panel behaves unlike the popover: the pool drains within
seconds and the tail is near idle.

### 6. Unprivileged `footprint -v --unmapped` snapshot while open

Saved as `artifacts/2026-10-21-popover-panel-fix/step1-v-open-own.txt`
(main repo root, untracked). One snapshot at open + ~5 s of a
hook-driven 1-cycle 30 s hold on the same build. The panel was verified
on screen by the `panel did show` log line in the same run.

Snapshot facts, verbatim values:

```text
298 MB      16 MB       880 KB       9066    TOTAL
    phys_footprint: 298 MB
    phys_footprint_peak: 299 MB
```

- 45 rows tagged `Owned physical footprint (unmapped) (graphics)` exist.
  Step3b had zero. 7 further rows carry `Owned physical footprint
  (unmapped)` without the graphics tag.
- Named `IOSurface SID` surfaces are QuartzCore tiles only:
  `0xa8 256x256 (&BGA)`, `0xae 512x256 (&BGA)`, `0xb1 512x256 (&BGA)`,
  `0xb6 512x256 (&BGA)`. No RenderBox-named surface is mapped. Step1
  mapped a 596x1178 RenderBox surface in the popover.
- `mapped file .../archive.metallib` holds 1140 pages, the same file
  and page count step1 mapped while the popover was open. Step3b mapped
  none.
- Accounting caveat: the DRT column of the unmapped graphics rows sums
  to 66.7 MB at this instant. It does not reconcile with the
  `footprint -w` category line of the harness (161.0-265.0 MB while
  open). The harness category line is the gate metric and matches the
  method of step0, step1, and step3b. The row-level page sums stay an
  open question for the planner. The phys_footprint value 298 MB agrees
  with the harness state at peak (299 MB).

### 7. Interpretation

- The container swap alone does not gate. Full content in the panel
  reproduces the NSPopover while-open pool almost exactly: 265.0 vs
  279.0 MB peak gfx Dirty. The pool follows the rendering of the full
  SwiftUI content, not the window container.
- The panel fixes the half of the problem that the popover could not
  fix: post-close residue. Idle-after-close falls from 162 / 146 / 146
  MB (step0) to 0.6 / 8.7 / 8.7 MB. The 40 s tail falls from
  185.0 / 146.0 MB to 27.0 / 0.7 MB.
- The falsification signature of F1 fired at 265.0 MB, at or above the
  140 MB stop condition. This task stops here. The planner decides the
  fallback. The Canvas -> CoreGraphics sparkline lever (step2a, dead as
  a solo NSPopover fix at 168 MB) is the documented candidate for a
  separate branch. Do not batch it into this branch.

### 8. Environment

- macOS 27.0.1 (26A434), arm64. The plan records the machine as an
  Apple M5 Max with a 2x Retina display. The harness log confirms
  `scale 2 screen 1080`. Hardware identity is an unverified prior from
  the plan.
- Release build of `fix/panel-popover` at `ef3a1bf`, binary path in the
  artifact header.
- Numbers are machine-local. Behavior on other hardware is an
  unverified prior.
- The harness quit the user's running StatsLite instance before the
  run, by design of both harness versions, and killed the launched
  instance on exit.

### 9. Files

- `artifacts/2026-10-21-popover-panel-fix/step1-full-content-panel.txt`
  (main repo root, untracked harness artifact, the gate metric source)
- `artifacts/2026-10-21-popover-panel-fix/step1-v-open-own.txt` (main
  repo root, untracked `-v` snapshot)
- `artifacts/2026-10-21-popover-panel-fix/verification-report.md` (this
  file, committed on the fix branch; the F3 visual section appends
  later)
- No Swift or script file changed. The F1 gate is measurement only.

## T3 memory gate: CoreGraphics sparklines in the NSPopover

Date: 2026-10-21 12:01 +08 (Asia/Kuala_Lumpur). Branch
`fix/coregraphics-sparklines`, commits `3a699e0` (red) + `c4587cc`
(green). One variable: the four metric-card sparklines now draw through
`NSView.draw` (`CGSparklineView` / `CGNetworkSparklineView`) instead of
SwiftUI `Canvas`. NSPopover stays (plan `decision_2026-10-21`, Option
B). Release build from this worktree, no `--probe` flag. Gate targets
per `decision_2026-10-21`:

- (T-a) open-time transient peak <= 168 MB, the measured NSPopover OS
  floor, step2a reference 168 / 156 / 156 MB per-cycle peak gfx Dirty.
- (T-b) sustained while-open footprint <= 40 MB in the settled window.
  Step0 re-locks every ~5 s at 161-279 MB, step2a drains and holds
  1.2-2.3 MB.
- (T-c) 40 s tail <= 40 MB. Step0 185 MB, step2a 34 MB.

### 1. Gate verdict: T-a FAIL on the literal ceiling, T-b PASS, T-c
PASS. Overall FAIL, with reconciliation below

| Sub-target | Metric | Measured | Target | Verdict |
| --- | --- | --- | --- | --- |
| T-a open transient peak | max_graphics_mb_across_opens (gfx Dirty) | 174.0 MB (per cycle 174.0 / 156.0 / 156.0) | <= 168.0 MB | FAIL by 6.0 MB |
| T-b sustained while-open, settled window | gfx Dirty max in open+3 s..close | 2.3 MB (cycle 1: 1.2, cycles 2-3: 2.3). Footprint 36-45 MB | <= 40 MB | PASS |
| T-c 40 s tail | final_idle_footprint_mb at close+39.6 s | 37.0 MB footprint, 2.3 MB gfx Dirty | <= 40 MB | PASS |

The T-a failure needs the reconciliation in section 4. The 6.0 MB
overage is a Dirty/Reclaimable split instant, not extra memory. The
cycle-1 peak pool is gfx Dirty + gfx Reclaimable = 174.3 MB. Step2a
measured the identical 174.3 MB pool. Its summary records
max_gfx_dirty+reclaim_mb 174.3, above its own 168.0 ceiling. The 168 MB
celling is one Dirty-column sample of a pool that flips between Dirty
and Reclaimable at constant size. The planner owns the adjudication:
read on the sampled Dirty instant, T-a fails. Read on pool size, this
run ties step2a exactly and both exceed 168.

### 2. Run

Command, verbatim, from this worktree:

```text
scripts/measure_popover_footprint.sh \
  --output /Users/jonathan/beliantech/stats-lite-macos/artifacts/2026-10-21-popover-panel-fix/step2-cg-sparklines.txt \
  --cycles 3 --hold 15
```

The script built Release into `<worktree>/.derivedData` first. The
binary path in the artifact header records provenance.

Display-state correction, one confound measured and removed. The first
attempt ran with the local display asleep (`CGDisplayIsAsleep` = 1,
confirmed). With the display asleep, the popover close animation stalls.
The window stayed on screen after the close markers and cycles 2 and 3
never re-spiked (peaks 1.2 MB). That run is preserved as
`step2-cg-sparklines-displayasleep.txt` (main repo root, untracked).
A separate probe proved the close path works with the display awake:
the window appears at open with alpha 1.0, tears down at close+0.3 s,
and is gone from the window list by close+0.9 s. Transcript:
`step2-close-behavior-awake.txt`. The gate run was then repeated with
the display held awake by `caffeinate -u -d`. A window-presence poll
ran concurrent with the gate run and confirms a popover window on
every open and none in any gap or after the final close. Poll:
`step2-window-validity-awake.txt`.

### 3. Summary block, verbatim from the artifact

From `artifacts/2026-10-21-popover-panel-fix/step2-cg-sparklines.txt`
(main repo root, untracked):

```text
cycle 1/3  open_ts 1792555219.020  close_ts 1792555234.932  peak_footprint_mb 215.0  peak_gfx_dirty_mb 174.0  peak_gfx_dirty+reclaim_mb 174.3
cycle 1/3  gfx_dirty+reclaim invariant: n 36  min 1.2  max 174.3  spread 173.1  spread_pct 99.3  stable no
cycle 1/3  idle_after_close: ts 1792555236.709  footprint_mb 36.0  gfx_dirty_mb 1.2  gfx_dirty+reclaim_mb 1.2
cycle 2/3  open_ts 1792555236.971  close_ts 1792555252.727  peak_footprint_mb 205.0  peak_gfx_dirty_mb 156.0  peak_gfx_dirty+reclaim_mb 156.3
cycle 2/3  gfx_dirty+reclaim invariant: n 36  min 2.3  max 156.3  spread 154.0  spread_pct 98.5  stable no
cycle 2/3  idle_after_close: ts 1792555254.452  footprint_mb 37.0  gfx_dirty_mb 2.3  gfx_dirty+reclaim_mb 2.3
cycle 3/3  open_ts 1792555254.769  close_ts 1792555270.419  peak_footprint_mb 204.0  peak_gfx_dirty_mb 156.0  peak_gfx_dirty+reclaim_mb 156.0
cycle 3/3  gfx_dirty+reclaim invariant: n 36  min 2.3  max 156.0  spread 153.7  spread_pct 98.5  stable no
cycle 3/3  idle_after_close: ts 1792555272.005  footprint_mb 38.0  gfx_dirty_mb 2.3  gfx_dirty+reclaim_mb 2.3
max_graphics_mb_across_opens 174.0
max_gfx_reclaim_mb 173.0  max_gfx_regions 45  max_gfx_dirty+reclaim_mb 174.3
invariant_gfx_dirty_plus_reclaim_stable no (stable if spread <= 20% of per-cycle max, window open+1.0s..close+1.5s)
overall_peak_footprint_mb 215.0
run_phys_footprint_peak_mb 215.0
final_idle_footprint_mb 37.0  final_idle_gfx_dirty_mb 2.3  idle_sample_ts 1792555309.973
samples 202  no_process_ticks 0  footprint_failed_ticks 0
```

### 4. T-a reconciliation: the pool equals step2a, the split instant
does not

This run, cycle 1 raw samples, verbatim:

```text
1792555220.234 SAMPLE 215.0 174.0 0.0 174.0 37 5.4 0.0 18.0 215.0
1792555220.690 SAMPLE 209.0 168.0 6.3 168.0 37 5.4 0.0 18.0 215.0
```

Step2a cycle 1 raw sample, verbatim:

```text
1792534957.676 SAMPLE 209.0 168.0 6.3 168.0 37 2.8 2.6 17.0 209.0
```

One tick earlier this run read gfx Dirty 174.0 with 0.0 Reclaimable.
The next tick read 168.0 with 6.3 Reclaimable. The sum stays 174.3 in
both ticks and in step2a. Region count at peak is 37 in both runs. The
same build measured 168.0 in the display-asleep run, line
`1792554148.518 SAMPLE 206.0 168.0 6.3 168.0 37 ...`, the same split
instant step2a sampled. The pool is identical across runs. The 0.4 s
sampler decides which side of the Dirty-to-Reclaimable flip it records.

Cycles 2 and 3 match step2a exactly: per-cycle peak gfx Dirty 156.0 /
156.0 against step2a 156 / 156, with a drain to 2.3 MB inside ~1.6 s
of each open. IOSurface Dirty rises from 2.8 to 4.7 MB during both
opens, so real content renders in cycles 2 and 3.

### 5. Sanity checks

- Hook markers matched. Seven `[measurement]` lines: three open, three
  close, one `cycles complete`. Same pattern as step0 and step2a.
  This branch emits no popover or panel show lines beyond the cycle
  markers. No panel line exists, as expected.
- Zero process misses. `samples 202  no_process_ticks 0
  footprint_failed_ticks 0`.
- Sample count 202 matches step0 (202) and step2a (205). Adequate.
- Window presence during the gate run. Every open window of all three
  cycles saw StatsLite window id 14867 on every poll. Every gap and the
  full post-close tail saw no StatsLite window. Opens and closes all
  completed.
- The settled window for T-b is open+3.0 s to the close marker, while
  the popover stays open. The transient, covered by T-a, ends by
  open+2.4 s in step2a and in the display-asleep run of this build.
  The step0 re-lock cadence of ~5 s sits fully inside this window, so
  the comparison does not hide a re-lock.

### 6. Comparison table: step0, step2a, this run

| Metric | step0 (Canvas baseline) | step2a (Color.clear placeholder) | This run (CoreGraphics real charts) |
| --- | --- | --- | --- |
| per-cycle peak gfx Dirty | 279.0 / 266.0 / 250.0 | 168.0 / 156.0 / 156.0 | 174.0 / 156.0 / 156.0 |
| peak pool (gfx Dirty + Reclaimable) | 279.0 | 174.3 | 174.3 |
| per-cycle peak footprint | 326 / 305 / 292 | 209 / 201 / 201 | 215 / 205 / 204 |
| run_phys_footprint_peak | 326.0 | 220.0 | 215.0 |
| max gfx regions | 61 | 47 | 45 |
| sustained while-open gfx Dirty (open+3 s..close) | 146-266, re-lock every ~5 s | 1.2-2.3 | 1.2-2.3 |
| sustained while-open footprint (open+3 s..close) | 184-309 | 33-41 | 36-45 |
| idle-after-close footprint / gfx Dirty | 201/162, 188/146, 185/146 | 33/1.2, 34/2.3, 34/2.3 | 36/1.2, 37/2.3, 38/2.3 |
| 40 s tail footprint / gfx Dirty | 185.0 / 146.0 | 34.0 / 2.3 | 37.0 / 2.3 |
| display state at run time | unverified | unverified | awake, verified by poll |

The key question: does real CoreGraphics drawing re-lock the pool the
way Canvas did, or stay drained like the placeholder? Answer: it stays
drained like the placeholder. The sustained while-open gfx Dirty of
1.2-2.3 MB matches step2a and stands opposite step0's 146-266 MB
re-lock. The 37.0 MB tail matches step2a's 34.0 MB and stands opposite
step0's 185 MB. The open transient of 174.3 MB equals the step2a pool,
which equals the NSPopover floor plus the full-content cost step2a
already measured. Real drawing adds no memory over the empty-draw
placeholder on this metric set.

One difference from step2a shows in footprint: this run settles at
36-45 MB while open against step2a 33-41 MB. Display state differs
between the runs and is the leading candidate. The gfx Dirty columns,
the gate metric, agree.

### 7. Open items

- The T-a ceiling needs a definition the Dirty-to-Reclaimable flip
  cannot move. Candidate: the
  gfx Dirty + gfx Reclaimable sum, which reproduced exactly at 174.3 MB
  in step2a and in this run. The planner decides.
- Display sleep blocks the popover close teardown in the hook cycle and
  invalidates cycles 2 and 3 of a gate run. Runs must hold the display
  awake. The harness does not check this today. The same stall fails
  `StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease`:
  `Executed 299 tests, with 5 failures` with the display asleep, and
  `Executed 299 tests, with 0 failures` with the display awake, same
  commit, measured 2026-10-21 12:10-12:13 +08.
- The task note references `step2a-report.md` in
  `artifacts/2026-10-20-popover-memory-attribution/`. That file does not
  exist in the repo or worktrees. Step2a numbers in this section come
  from `step2a-no-canvas.txt` and the plan ISC entries of
  `.pi/plans/2026-10-20-popover-memory-attribution.json`.

### 8. Files

- `artifacts/2026-10-21-popover-panel-fix/step2-cg-sparklines.txt`
  (main repo root, untracked, the gate metric source)
- `artifacts/2026-10-21-popover-panel-fix/step2-cg-sparklines-displayasleep.txt`
  (main repo root, untracked, first attempt, display asleep, kept as
  confound evidence)
- `artifacts/2026-10-21-popover-panel-fix/step2-window-validity-awake.txt`
  (main repo root, untracked, window poll concurrent with the gate run)
- `artifacts/2026-10-21-popover-panel-fix/step2-close-behavior-awake.txt`
  (main repo root, untracked, 1-cycle close probe with display awake)
- `artifacts/2026-10-21-popover-panel-fix/verification-report.md` (this
  file, committed on the fix branch)
- No Swift or script file changed. The T3 gate is measurement only.
