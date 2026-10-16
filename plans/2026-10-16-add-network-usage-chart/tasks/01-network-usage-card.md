# Task 1 — Implement mirrored network usage card (data + views + registration + tests)

## Task Input

- Plan: `PLAN.md` in this directory (full design spec, VAC, steps 0–6).
- Goal: add a Network Usage card to the popover with a mirrored dual-series chart —
  upload (systemRed) above a central baseline, download (systemBlue) below — behind the
  existing `showNetwork` toggle.

## Must Do

- Follow the plan's Design spec exactly (row structure, 56 pt chart, baseline at Y=28 pt,
  gradients 0.22→0.04, 1.5 pt round strokes, shared `domainMax` with 10 KB/s floor).
- TDD where geometry permits: write `NetworkSparklineViewTests` (mirrored geometry,
  zero→baseline, domainMax clamp, Equatable) and extend `SystemMonitorNetworkTests`
  (per-tick appends, nil-pass skip, clear on stop, capacity/age trim) BEFORE the
  implementation of the corresponding unit.
- Step 0 first: run `scripts/capture_baseline.sh` (dark + light) into an artifacts dir
  BEFORE any code edit. Keep the outputs; report the paths.
- Reuse existing patterns: `SparklineView.plotPoints` static-geometry style, GPUCardView
  structure, `MetricFormatters.networkRate`, `.metricCardStyle()`, `.equatable()` on the
  chart to skip redraws.
- Append history inside `startNetworkSampling()` after the `latestNetwork` assignment
  (1 point per 1 s tick, both rates non-nil only). Clear both buffers in
  `stopNetworkSampling()`.
- Keep `showNetwork` OUT of `EnabledMetrics`; do not touch the last-one-enabled guard.
- No `.animation` / `.contentTransition` anywhere (hard repo rule).
- After implementation: run `scripts/capture_baseline.sh` again into a separate "after"
  dir, inspect both with the `read` tool, and verify EVERY VAC item in the plan
  (VAC-1..VAC-14, dark AND light mode). Fix any wrap/clip/misalignment — blocking.
- Run `scripts/measure_popover_footprint.sh` and record before/after numbers in your report.
- Run the full test suite and the build (`xcodebuild`); all green before finishing.
- Conventional commit(s); scope `network`. Report the commit SHA and branch at the end.

## Must Not Do

- No refactor of existing cards, sampling loops, or PreferencesStore beyond what the plan lists.
- No Swift Charts import; Canvas/Path only.
- No changes to the menu-bar network block or Settings toggle (already exist).
- No `.animation`/`.contentTransition` on any new view, including the popover card.
- Do not merge to main; the planner owns the merge.

## Recommended Approach

1. Baseline capture (step 0).
2. Tests for mirrored geometry → `NetworkSparklineView`.
3. Tests for buffer appends → SystemMonitor buffers + network-loop append/clear.
4. `NetworkCardView` (states, legend, accessibility label).
5. Register in `PopoverContentView` after the GPU block.
6. Build + full test run.
7. After-captures + VAC verification (read the screenshots, fix defects) + footprint script.
8. Commit on the task branch.

## Context

- Worktree branch: `feat/2026-10-16-add-network-usage-chart` (this IS your cwd — do all
  edits here, not in the main checkout).
- Key file references (verified): `StatsLite/PopoverContentView.swift:45` (insert after
  GPU block), `StatsLite/SystemMonitor.swift:49-51` (buffers), `:179` (network publish,
  append point), `:187` (stop, clear point), `StatsLite/SparklineView.swift:93`
  (`plotPoints` pattern), `StatsLite/GPUCardView.swift` (card + unavailable-state
  pattern), `StatsLite/MetricFormatters.swift:44` (networkRate).
- Network cadence is fixed 1 s (`SystemMonitor.swift:150-153`) — intended; capacity =
  `max(Int(historyDuration), 16)`.
- Nil rate passes are normal (first tick, rollback, timing discontinuity) — skip them,
  never append fake zeros.
