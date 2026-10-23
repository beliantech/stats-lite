# T-E VAC evidence — plan 2026-10-23-top-processes-breakdown

All screenshot-verifiable VAC items: 1–9, 12, 13. VAC-10 and VAC-11 are not
screenshot-verifiable. They live as FT-1 and FT-2 tests, green in
`final-te.txt` (347/0, TEST SUCCEEDED).

## Method

- Baseline images: `baseline/dark.png`, `baseline/light.png`, captured before
  the first code edit (G1).
- Post images: `post/*.png` (9 files) via `post/capture-te.sh` (deviation D1)
  and `post/capture-cue-dot.sh` (deviation D3).
- Pixel probes: python3 + Pillow over the PNGs at 1x capture scale. The window
  content band measures 280 px, so 1 px = 1 pt in these captures.
- Zero-tolerance visual check: every post image was opened and inspected for
  wrapping, clipping, and overlap. None was found.

## VAC table

| VAC | Verdict | Evidence | Notes |
| --- | --- | --- | --- |
| VAC-1 (280 pt width) | PASS | All 11 captures measure 306 px total with the window content band at x 13–292, that is 280 px/pt. Same number in `baseline/dark.png`, `baseline/light.png`, and all 9 post images. | Width is fixed by `.frame(width: 280)` at `PopoverContentView.swift:131`. One viewport was captured. The frame constant proves other viewports. |
| VAC-2 (240 pt inner content) | PASS | The Memory card's `Used` track spans x 33–272, that is 240 px/pt, in `baseline/dark.png` (y 286), `baseline/light.png` (y 286), `post/dark.png` (y 306), and `post/light.png` (y 306). Card body spans x 23–282 (260 pt) with 10 pt `MetricCardStyle` padding. | 280 − 2×10 pt stack padding = 260 pt card. 260 − 2×10 pt card padding = 240 pt content. Matches `DesignTokens.swift:46`. |
| VAC-3 (chevron flip, no displacement) | PASS | Collapsed `› Top Processes` sits at y 159–168 in `post/dark.png`. Expanded `⌄ Top Processes` sits at y 160–168 in `post/dark-cpu-expanded.png`. Same row, 1 px difference is antialias noise. | Chevron flip is visible in every expanded capture. `Cores Breakdown` above stays at y 140–148 in both images. |
| VAC-4 (4 pt cue dot) | PASS | `post/dark-cue-dot.png`: collapsed dark popover, `CPU Total 99.9%`, an amber dot of 4×4 px at x 121–124, y 161–164, color (255, 146, 48) = systemOrange, trails the `Top Processes` label. No process name shows while collapsed (AMD-1). | The dot shows at the warning state, that is a window average of 0.80–0.95, not at the instant reading. The idle captures show no dot, which is the correct normal state. No test drives `cpuCueState` directly. The shared `>=` boundaries are pinned by `MenuBarBlockBuilderTests.testCPUValueTintThresholds` (fix 0bda080). |
| VAC-5 (single 18 pt rows, tail ellipsis) | PASS | Row text tops in `post/dark-cpu-expanded.png`: 180, 198, 216, 234, 252. Uniform 18 px pitch. Same pitch in `light-cpu-expanded` (182…254) and both memory captures (359, 377, 395, 413, 431). Tail ellipsis is visible on `WallpaperAerialsExt…` and `VTDecoderXPCServ…`. | One text group per row, so no row wraps. All 9 post images were inspected. No wrap, clip, or overlap found anywhere. |
| VAC-6 (44 pt right-aligned values) | PASS | Value glyphs end at x 270 on every row of all four list captures. Left edges vary with text length (238–248), which proves right alignment. `351 MB`, `291 MB`, and the percent values render complete with no clip. | The trailing frame is `.frame(width: 44, alignment: .trailing)` at `TopProcessesView.swift:96`. Right edge 270 sits 2 px inside the 272 content edge on every row. |
| VAC-7 (44×5 pt gauge) | PASS | Gauge rect measures x 179–222 (44 px) and 5 px tall at every row of `dark-cpu-expanded`, `dark-memory-expanded`, `light-cpu-expanded`, and `light-memory-expanded`. One light row edge reads 43 px at the pixel threshold, which is antialias noise. | Capsule geometry is continuous in all images. |
| VAC-8 (at most 5 rows) | PASS | Exactly 5 rows render in each list capture: CPU dark, CPU light, memory dark, memory light. The GPU capture shows the unavailable container instead of rows. | The fewer-than-5-rows case is not in any capture. It is covered by `prefix(5)` at `MetricSamplerActor.swift` and by `testEmptyStateShowsNoProcessDataLine` and `testRealRowsShowNoPlaceholder`. |
| VAC-9 (GPU unavailable) | PASS | `post/dark-gpu-expanded.png` and `post/light-gpu-expanded.png`: 4 pt rounded rect with dashed separator border, `exclamationmark.triangle`, copy `Per-process GPU metrics unavailable` on one line. No crash, no empty space, no clip. | Wrap is allowed by the plan here. The copy is pinned by `testGPUUnavailableMessageMatchesPlanCopy`. |
| VAC-12 (dark and light) | PASS | Dark/light pairs exist for all states: collapsed (`dark.png` / `light.png`), cue (`dark-cue-dot.png` plus collapsed light), CPU, memory, and GPU expanded. 9 post images total. | Text, gauges, and the dashed container render correct in both appearances. Semantic tokens are code-level (`DesignTokens.swift`). |
| VAC-13 (loading line) | PASS (test-backed) | No capture shows the loading line. Every capture settles after the first samples land. The primary evidence is FT-4: `testLoadingLineWinsOverRowCountWhileBootstrapHolds` and `testLoadingStateShowsStaticSamplingLine`, green in `final-te.txt`. | Screenshot gap recorded below. The line copy `Sampling top processes…` is asserted by both tests. |

## Deviations

- D1 (pre-existing, commit d5bed2e): `post/capture-te.sh` replaces
  `scripts/capture_baseline.sh` for post captures. The original script fails
  with -1743 (no TCC Automation permission) on this host. The new harness keeps
  the same launch flags, polling, settle, and `screencapture` call. It switches
  appearance per app through the `--capture-appearance` hook instead of the
  system appearance. The original script is untouched.
- D2 (this task): `scripts/measure_popover_footprint.sh` gained an
  `--expand-processes <cpu|memory|gpu>` flag, marked in the header as a T-E
  hook. Without the flag the launch is unchanged. One expanded run (3 cycles,
  12 s hold, 40 s tail, under `caffeinate -di`) and one collapsed control run
  with the same timing were recorded.
- D3 (this task): `post/capture-cue-dot.sh` captures VAC-4. It loads all cores
  with 24 `yes` burners before launch, then settles 30 s instead of 1.5 s so
  CPU history samples land in the warning band. The trap kills the burners and
  the app on every exit path.

## Gaps for the final reviewer

1. G4 expanded state misses the sustained gate by 2 MB.
   `footprint-te-expanded-cpu.txt`: settled open footprint holds at 42.0 MB for
   about 9 s in cycles 2 and 3 (cycle 1: 34–38 MB). The collapsed control at
   the same timing (`footprint-te-collapsed-control.txt`) tops out at 40.0 MB,
   and the earlier collapsed run (`footprint-te.txt`, 5 cycles) at 40.0 MB.
   The +2 MB tracks the expanded disclosure with its live sampler. Graphics
   dirty stays at 1.4 MB, inside the 2.3 MB limit. Tail stays at 33–35 MB,
   inside the 40 MB limit. The overrun is 2 MB over the 40 MB number on one of
   three sub-metrics in one state. The planner and reviewer decide whether it
   blocks G4.
2. Open-time transient, not counted by the settled gate: at popover open both
   runs spike to about 199–204 MB footprint with 163–165 MB graphics dirty for
   about 1.5 s, then fall to settled values. The collapsed baseline run shows
   the same spike, so the disclosure does not own it. Recorded for context.
3. VAC-13 loading line is not in any screenshot. FT-4 tests are the evidence.
4. VAC-8 fewer-than-5-rows rendering is not in any screenshot. Tests and
   `prefix(5)` are the evidence.
5. Memory rows can show `Process <pid>` as the name. This is the designed T7
   lookup cap: 8 lookups and 5 resolved names per pass, CPU rows first. CPU
   rows take the budget, so memory rows often carry the fallback. Visible in
   `post/dark-memory-expanded.png` and `post/light-memory-expanded.png`.
   `TopProcessesView.swift:63` drops the duplicate PID for fallback names.
6. VAC-1 was captured at one viewport. The `.frame(width: 280)` constant
   covers other viewports at code level.

## Verification commands

- `sips -g pixelWidth -g pixelHeight` over all 11 PNGs: 306 px wide everywhere,
  content band x 13–292 = 280 px.
- Pillow pixel probes: Used track 33–272 = 240 px, gauges 179–222 = 44 px × 5 px,
  row pitch 18 px, value right edge x 270, cue dot 4×4 px at
  (255, 146, 48).
- `swift /tmp/display_awake.swift` printed `0` before each run. All three
  footprint cycles logged matching open and close markers, so the display
  stayed awake.
- `git diff d5bed2e..HEAD -- StatsLite StatsLiteTests StatsLite.xcodeproj` is
  empty, so `final-te.txt` (347/0) covers all source commits on this branch.
