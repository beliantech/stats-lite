# VAC-B evidence — plan `plans/2026-10-23-top-processes-breakdown.md` fix cycle (T-H)

Date: 2026-10-23. Branch `feat/2026-10-23-top-processes-breakdown-fix`.
AFTER captures: `artifacts/2026-10-23-top-processes-breakdown/fix/after/`
(10 images: dark + light, collapsed, CPU expanded, memory expanded, GPU
arg inert, cue dot). BEFORE captures:
`artifacts/2026-10-23-top-processes-breakdown/fix/baseline-before/` (8 images).
All captures run caffeinate-wrapped with `CGDisplayIsAsleep == 0` checks
(`fix/capture-after.sh`, `fix/capture-cue-dot-after.sh`). Suite evidence:
`fix/final-th.txt` — 348 tests, 0 failures, `** TEST SUCCEEDED **`.

## VAC-B table

| Item | Verdict | Evidence | How verified |
| --- | --- | --- | --- |
| VAC-B1 — rows are `name (pid)`, zero `Process <digits>` | PASS | `after/dark-memory-expanded.png`, `after/light-memory-expanded.png`, `after/dark-cpu-expanded.png`, `after/light-cpu-expanded.png` | Screenshot. Memory dark+light: `node (75478)`, `Xcode (33839)`, `node (28849)`, `VTDecoderXPCServ... (1518)`, `node (43497)` — 5 rows, real names. CPU dark: `WallpaperArialiesExt... (1488)`, `Activity Monitor (36236)`, `node (79298)`, `MenuBarAgent (1458)`, `VTDecoderXPCServ... (1518)`. CPU light: `WallpaperArialiesExt... (1488)`, `node (49277)`, `node (75328)`, `node (79298)`, `herdr (21642)`. Zero `Process <digits>` rows in all 10 after/ images. BEFORE state: `baseline-before/dark-memory-expanded.png` shows 5 `Process NNNNN` rows. |
| VAC-B2 — k-fail rows drop, all-fail shows empty line, no stuck loading | PASS | `StatsLiteTests/SystemMonitorProcessSamplingTests.swift:370`, `:397`; `StatsLiteTests/MetricProcessSamplerTests.swift:477`, `:506`; `StatsLiteTests/ProcessDisclosureTests.swift:353` | Test names (fixture-driven, deterministic): `testVACB2MemoryAllNameFailShowsEmptyStateAfterTickZero`, `testVACB2CPUAllNameFailShowsEmptyStateAfterWarmUpPass`, `testUnnamedCandidateDropsFromThatPassList`, `testAllNameFailuresYieldEmptyLists`, `testPIDSuffixRendersOnEveryRow`. Screenshot support: no after/ image shows a blank slot, fallback text, or a stuck `Sampling top processes…`. |
| VAC-B3 — GPU card has no disclosure, no dashed box | PASS | `after/dark.png`, `after/light.png`, `after/dark-gpu-expanded.png`, `after/light-gpu-expanded.png`, both cue-dot shots. Target: `artifacts/2026-10-23-top-processes-breakdown/baseline/dark.png` | Screenshot: the GPU card renders header (`display` icon, `GPU Usage`, value), sparkline, `SparklineTimeAxisView` — same form as the pre-feature target. No `› Top Processes` row, no dashed box in any state. BEFORE: `baseline-before/dark-gpu-expanded.png` shows `⌄ Top Processes` + `⚠ Per-process GPU metrics unavailable`. Source cross-check: `rg -nF 'Per-process GPU' StatsLite/` and `rg -n 'GPUUnavailableProcessesView' StatsLite/` return no matches (T-G negative source asserts in `ProcessDisclosureTests` pass). |
| VAC-B4 — collapsed −16 pt vs deployed, GPU expansion zero, footer never clipped | PASS (measured −20 pt, see note) | Image pairs `baseline-before/{dark,light,dark-gpu-expanded,light-gpu-expanded}.png` vs `after/{dark,light,dark-gpu-expanded,light-gpu-expanded}.png` | Screenshot measurement. Collapsed: 1314 px @2× = 657 pt → 637 px @1× = 637 pt → −20 pt. The extra 4 pt vs the blueprint's −16 pt is the 4 pt lead spacing of `GPUCardView`'s `VStack(spacing: 4)` that served the removed row: 16 pt row + 4 pt spacing = 20 pt. Expanded: 751 pt → 731 pt (−20 pt). GPU-expanded: 709 pt → 637 pt (−72 pt = −52 pt dashed box − 16 pt row − 4 pt spacing). `after/dark-gpu-expanded.png` is 637 px = `after/dark.png` 637 px → GPU expansion contributes 0 pt. Cross-check: pre-feature `baseline/dark.png` = 597 pt, and 597 + 20 (CPU disclosure) + 20 (Memory disclosure) = 637 pt exactly — no other geometry changed. Footer `Updated every 5s` and `v1.0.1 (1)` fully visible in all 10 after/ images, never clipped. |
| VAC-B5 — one 18 pt line per row, tail-truncate, zero wrap | PASS | `after/dark-cpu-expanded.png`, `after/dark-memory-expanded.png`, `after/light-cpu-expanded.png`, `after/light-memory-expanded.png` | Screenshot. Expansion delta = 94 pt before (751 − 657) and after (731 − 637) → row geometry unchanged. Every row is one line. Long names tail-truncate inside the name column: `VTDecoderXPCServ... (1518)`, `WallpaperArialiesExt... (1488)` — pid suffix still visible. Value column right edge and 44×5 gauges align across all rows in both appearances. Zero wrap, zero clip, zero overlap. |
| VAC-B6 — collapsed cue dot, expanded list, accordion swap, loading line | PASS (loading line = test evidence) | `after/dark-cue-dot.png`, `after/light-cue-dot.png`; the four expanded captures; `StatsLiteTests/SystemMonitorProcessSamplingTests.swift:298`; `StatsLiteTests/ProcessDisclosureTests.swift:157`, `:134`, `:142` | Screenshot: with 24 CPU burners at CPU 100.0 % (dark) and 99.8 % (light), the collapsed `› Top Processes` row carries the 4 pt amber cue dot in both appearances (the metric crossed the 0.80 warning boundary, so the cue-dot state was captured, not skipped). Accordion swap: the cpu-expanded and memory-expanded captures taken in sequence show exactly one list open at a time. Loading line: test names — `testFT4LoadingWindowHoldsWhileFirstCPUSampleIsHeldAndClosesWhenItResolves`, `testLoadingLineWinsOverRowCountWhileBootstrapHolds`, `testLoadingStateShowsStaticSamplingLine`, `testEmptyStateShowsNoProcessDataLine` (the 250 ms bootstrap window is not deterministically catchable in a screenshot, so test evidence covers this item, as the task allows). |

## Zero-tolerance sweep

All 10 after/ images inspected one by one: no text wrap, no clipped
element, no overlapping element, no misaligned row, no border clipping.
Verdict: no visual defect found.

## Negative checks

- `rg -n 'Process NNNNN|Per-process GPU' StatsLite/` returns 3 hits,
  all in doc comments that document the ban
  (`TopProcessesView.swift:62`, `MetricSamplerActor.swift:161`,
  `MetricSamplerActor.swift:258`). `Per-process GPU` returns 0 hits.
- No fallback string literal exists: `rg -nF 'Process \(' StatsLite/`
  returns 0 hits. `rg -n 'case gpu' StatsLite/` hits only
  `MenuBarBlockModel.Kind.gpu`, the distinct kept type (Appendix D).
- No after/ screenshot contains a `Process <digits>` row (checked in the
  VAC-B1 screenshot pass).

## Deviations

1. Capture scale: the T-F baseline ran at 2× (612 px wide images). The
   active display is now 1920×1080 at `backingScaleFactor 1.0`
   (checked with `system_profiler` and `NSScreen`), so after/ images are
   1× (306 px wide). Heights are compared in points. The window is 306 pt
   wide in both sets, and the 1× pre-feature `baseline/dark.png` cross-
   check in VAC-B4 compares directly.
2. Blueprint prior vs measurement: the state matrix says collapsed
   −16 pt. The measurement is −20 pt. The 4 pt difference is the row's
   lead spacing in `VStack(spacing: 4)`. Every removed pixel is inside
   the removed GPU disclosure block (VAC-B4 arithmetic closes exactly).
3. First `light-cue-dot` attempt (17:24:55) returned a 2× image with the
   CPU list expanded although no expand flag was passed, and the display
   scale read 2× for that frame. The cause is unknown. The file was
   recaptured at 17:30:04: 306×637, collapsed, cue dot visible. The
   clean capture is the committed evidence.
4. The loading-line states live for at most 250 ms. No screenshot can
   catch them reliably. Test evidence covers the loading line (VAC-B6),
   as the task allows.
