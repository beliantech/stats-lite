# Menu Bar GPU/MEM Positional Swap

- Date: 2026-10-26
- Trigger: USER DIRECTIVE — "swap the gpu and mem positions in the menubar"
- Phase: IMPLEMENTATION (R2 UI)
- Risk class: R2 — visible layout-order change to the status item; zero logic change; reversible by reverting one branch; offscreen render tests verify (repo precedent: `2026-10-25-menubar-item-gap-uniform-minimum` was R2).
- Design: 5-part blueprint from the designer (session 2026-10-25T23-40, verbatim in the Appendix). Blueprint is final; do not restructure it. Planner corrections are listed in "Blueprint integration corrections".
- Oracle matrix: not triggered (pure UI/UX directive → designer path).
- Reconnaissance: scout report (session 2026-10-25T23-51) with exact `path:line` for every breaking assertion; folded into Steps and `isc.md`.

## Context

### Current state (measured)

- The status item renders blocks left-to-right in `CPU → MEM → GPU → TEMP → NET` order.
- Order is decided in exactly one place: `MenuBarBlockBuilder.blocks` appends `.cpu` (`StatsLite/MenuBarBlockModel.swift:141-152`), then `.ram` (`:154-171`), then `.gpu` (`:173-184`), then `.temp`, then `.network`. `MenuBarStackedItemView.body` iterates `ForEach(blocks, id: \.kind)` (`StatsLite/MenuBarStackedItemView.swift:42-52`) — it renders builder order verbatim.
- The VoiceOver composite label has its own order: CPU (`StatsLite/MenuBarAccessibility.swift:30-36`), Memory Pressure (`:37-45`), GPU (`:46-48`).
- Geometry: `MenuBarLayout.blockWidth = 27` pt for all three standard blocks, `gap = 4` pt, `padding = 2` pt. 3-metric slot = 93 pt (`MenuBarLayout.length`, `MenuBarBlockModel.swift:100-111`).
- Ink gap rule (fixed-width frames, trailing-aligned content): gap = 4 pt + right block's leading slack. Because all frames are 27 pt, a boundary's ink gap depends only on the block on its right.

### Target state

- The menu bar reads `CPU → GPU → MEM → TEMP → NET` (left to right).
- The VoiceOver composite label speaks in the same order: `Stats Lite: CPU 14 percent, GPU 28 percent, Memory Pressure Normal at 25 percent, …` (WCAG 1.3.2 Meaningful Sequence).
- Nothing else changes: widths, gaps, typography, tints, tokens, length totals, animation rules, temp/network blocks.
- Doc comments that state the order are updated to the new sequence.

## Blueprint integration corrections (planner, with evidence)

1. **Cold-band constants must follow the right block, not the boundary name.** Ink gap depends only on the right block's content (all frames 27 pt). Old measurements: boundary-after-CPU (MEM right) = 11–14 px, boundary-after-MEM (GPU right) = 17–20 px. After the swap, CPU→GPU (GPU right) = **17–20 px** and GPU→MEM (MEM right) = **11–14 px**. Fix: in `MenuBarRenderSnapshotTests.swift` rename `coldMemGpuGapFloor/Ceiling` (`:120/:121`, value 17–20) to `coldCpuGpuGap*` and `coldCpuMemGapFloor/Ceiling` (`:118/:119`, value 11–14) to `coldGpuMemGap*`; values stay, names follow the new boundary. Both values are an `unverified prior` from the fixed-width geometry until the coder's measured run confirms them (ISC-4).
2. **Single-digit band carries over to CPU→GPU.** `singleDigitGapFloor/Ceiling` (23–27, `:106/:107`) measured `adjacent(mem, singleDigitGPU)`. After the swap the production pair is `adjacent(cpu, singleDigitGPU)` with identical geometry (same 27 pt left frame), so the band value carries over; only the pair, the test name (`:1011`), the doc (`:101`), and messages (`:1043`, `:1052`) change. Confirm by measurement (ISC-4).
3. **Boundary-2 x in the composition test.** `:1198` computes `groupLeft + cpuWidth + gapPixels + memWidth + gapPixels / 2`. Update symbolically to `gpuWidth` even though `cpuWidth == gpuWidth == memWidth` today; otherwise the test silently couples to block-width equality.
4. **Rightmost-ink assert `:1257-1264`.** The threshold already subtracts `memWidth`; after the swap MEM is the rightmost block, so the threshold becomes correct and the message ("GPU frame", `:1261-1262`) plus comment (`:1244-1248`) must be updated together.
5. **VoiceOver order follows the visual order** (blueprint §4, WCAG 1.3.2). This makes the 7 string assertions in `MenuBarAccessibilityTests.swift` part of the contract. Skipping it would leave a green test suite with a diverging label — not acceptable.
6. **`MenuBarBlockBuilderTests.swift:250` is a hard failure, not a message mismatch.** `result[2]` becomes MEM (it carries a dot). Fix to `result[1]` (GPU) in the same edit as the kind arrays, or the suite stays red for the wrong reason.

## Steps

1. **Baseline capture (before the first code edit).** Display awake. Run `scripts/capture_menubar.sh`; copy outputs to `artifacts/2026-10-26-menu-bar-gpu-mem-swap/before/`. Live captures are spot checks only (AGENTS.md); the offscreen render tests are the gate.
2. **Worktree.** `MAIN_REPO=/Users/jonathan/beliantech/stats-lite-macos`, `TASK_NAME=2026-10-26-menu-bar-gpu-mem-swap`, `BRANCH=feat/2026-10-26-menu-bar-gpu-mem-swap`, `WORKTREE_DIR=${MAIN_REPO}/worktrees/${TASK_NAME}`. Create with `git worktree add -B "${BRANCH}" "${WORKTREE_DIR}" main`. All code work happens there.
3. **Red phase — test edits only, production untouched.** Update every order expectation to `CPU → GPU → MEM` (full line list in `tasks.md` T2):
   - `MenuBarBlockBuilderTests.swift`: `:54`, `:55`, `:81`, `:82`, `:250`→`result[1]`, `:349`, `:350`, `:432`, stale name `:338`, comment `:73`.
   - `MenuBarAccessibilityTests.swift`: `:31`, `:47`, `:64`, `:80`, `:160-161`, `:180-181`, `:238`.
   - `MenuBarTempBlockTests.swift`: `:181-184` (doc/name), `:199-200`, `:210`, `:219-221`, messages `:196`, `:201-204`, `:222`, MARK `:179`.
   - `MenuBarTempVerificationTests.swift`: canonical append order `:223-224`, doc `:181`, message `:232-234`.
   - `MenuBarRenderSnapshotTests.swift`: boundary arrays `:819-822`, `:956-959`, `:1189-1202` (with correction 3), composition order `:705-709` and `:744-751`, second inter-block pair `:516-557` → `adjacent(mem, temp)`, single-digit pair `:1030-1035` → `adjacent(cpu, singleDigitGPU)`, cold-band rename per correction 1, stale messages/docs `:866`, `:992`, `:1043`, `:1052`, `:1261-1262`, `:81-83`, `:94`, `:101`, `:1073`, `:1184-1188`, `:1244-1248`.
   - Run the suite under `caffeinate -i xcodebuild … test` (display awake). Record the failing set; it must be exactly the order-expectation tests. Any other red test = stop condition (report, do not fix blind).
4. **Green phase — production edits (only these two files):**
   - `StatsLite/MenuBarBlockModel.swift`: move the `if showGPU` append block (`:173-184`) before the `if showRAM` block (`:154-171`); update the doc at `:120-121` to `CPU, GPU, MEM, TEMP, NET`.
   - `StatsLite/MenuBarAccessibility.swift`: move the `if showGPU` part (`:46-48`) before the `if showRAM` part (`:37-45`).
   - Comment-only updates: `StatsLite/MenuBarStackedItemView.swift:91-92` → `CPU, GPU, RAM, TEMP, NET`; `StatsLite/StatusItemController.swift:311-313` → `CPU 14 percent, GPU 28 percent, Memory Pressure …`.
   - No other production file changes. `MenuBarAccessibility.swift:50-51` stays true (GPU still precedes Temperature) — verify, do not touch.
5. **Band confirmation (ISC-4).** Run the render suite under `caffeinate` with the display awake. If a band assertion fails: rerun that single test (screen on), record the measured px value in the task ledger, and adjust only that constant, within ±2 px of the prediction in corrections 1–2, with the measurement quoted. Beyond ±2 px = stop and re-derive the geometry; do not chase the number.
6. **Full suite green ×2** in the worktree: `caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test`. Runner exit 0, zero failures, both runs.
7. **After capture.** Re-run `scripts/capture_menubar.sh`, copy to `artifacts/2026-10-26-menu-bar-gpu-mem-swap/after/`. Compare with `before/`: the GPU block now sits between CPU and MEM. Spot check only.
8. **Commit** in the worktree as one commit: `feat(menubar): swap GPU and MEM status item positions` (conventional commit per the git-commit skill). Then hand to the reviewer.

## Visual Acceptance Checklist (VAC)

Mapped 1:1 to `isc.md`. Numbering below is the gate checklist; the designer's blueprint in the Appendix carries its own VAC-1..12 numbering (same content, same measurements).

- VAC-1 (ISC-1): `MenuBarBlockBuilder.blocks()` with all metrics on returns labels `["CPU", "GPU", "MEM"]`, kinds `[.cpu, .gpu, .ram]`; toggle subsets and 5-block temp/network sequences follow the same order. Existing builder/temp tests, updated.
- VAC-2 (ISC-2): offscreen composition renders CPU ink left of GPU left of MEM; block x-origins stay frozen (0.0 px spread) across value sweeps. Existing `MenuBarRenderSnapshotTests` freeze/composition tests, updated.
- VAC-3 (ISC-3): `MenuBarAccessibility.compositeLabel` outputs CPU phrase, then GPU phrase, then Memory Pressure phrase. Existing `MenuBarAccessibilityTests`, updated.
- VAC-4 (ISC-4): new-boundary ink gaps at 2×: CPU→GPU and GPU→MEM each 8–12 px (2-digit), uniformity ≤ 1 px; cold fixture CPU→GPU 17–20 px, GPU→MEM 11–14 px; single-digit GPU at CPU→GPU 23–27 px; both appearances. Existing render snapshot tests, updated — the bands are `unverified prior` until the measured run confirms them.
- VAC-5 (ISC-5): MEM→TEMP inter-block gap still 21 ± 1 px (temp/network untouched). Existing `testInterBlockInkGapsMeasureTwentyOnePixels`, second pair switched to `adjacent(mem, temp)`.
- VAC-6 (ISC-6): `MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: true) == 93` pt; slot-fill voids ≤ 1 px. Existing `MenuBarLayoutTests` + composition test.
- VAC-7: no `.animation` / `.contentTransition` anywhere on the status item path. Existing `MenuBarRedrawChurnTests`.
- VAC-8: sparkline time axes untouched (`SparklineTimeAxisView` not in the diff). Existing tests.
- VAC-9: `before/` vs `after/` capture shows GPU between CPU and MEM. Spot check, not the gate.

## Falsification

- **H:** the rendered order is fully determined by the `MenuBarBlockBuilder.blocks` append sequence; the view and accessibility label carry no independent ordering.
- Test: after moving the `if showGPU` block ahead of `if showRAM`, the offscreen composition shows GPU ink between CPU and MEM (ISC-2) and the composite label speaks GPU before Memory Pressure (ISC-3).
- Kill: if the builder returns `[cpu, gpu, ram]` but the render still shows MEM second, H is dead — the view orders independently (sort/`ForEach` id) and the plan stops for re-scout. One variable per round: production diff is limited to two files, both pure block-order moves; no other production edit lands in the same measurement round.

## Non-goals

- No `SettingsView` toggle reorder (`StatsLite/SettingsView.swift:99-101` keeps Memory Pressure before GPU; no test pins that pair; the directive covers the menu bar only).
- No change to `MenuBarLayout.blockWidth` (27), `gap` (4), `padding` (2), `length(...)`, or any length total.
- No typography, color, tint, dot, temp, or network block changes.
- No `.animation` / `.contentTransition` (AGENTS.md: status item views stay discrete).
- No `DESIGN.md` change (it states no item order — verified 2026-10-26; `ARCHITECTURE.md` does not exist in this repo).
- No popover, settings, or footer work.

---

## Appendix — Design Blueprint (designer, verbatim)


# 5-Part Design Blueprint: Menu Bar GPU and Memory (MEM) Status Item Swap

## Executive Summary & Code Location Citations

This blueprint specifies the positional swap of the GPU and Mem (memory) status items in the macOS menu bar. All visual styling, typography, color tokens, and fixed-width allocations remain unchanged. Only the sequential order of items changes.

### Path and Line Citations

1. **Item Generation Order (`StatsLite/MenuBarBlockModel.swift:137-188`)**:
   - Line 120: Comment documents `CPU, MEM, GPU, TEMP, NET` order.
   - Lines 137–148: Appends the `.cpu` block.
   - Lines 150–171: Appends the `.ram` (`MEM`) block.
   - Lines 173–184: Appends the `.gpu` block.
   - Lines 186–218: Appends the `.temp` block.
   - Lines 220–245: Appends the `.network` block.
   - **Target Change**: Move lines 173–184 (`if showGPU`) before lines 150–171 (`if showRAM`).

2. **Visual Hierarchy Display (`StatsLite/MenuBarStackedItemView.swift:42-52`)**:
   - Lines 42–52: Iterates over `blocks` through `ForEach(blocks, id: \.kind)` inside an `HStack`.
   - The view renders blocks in the exact sequence that `MenuBarBlockBuilder.blocks` creates.
   - Lines 93–94: Comment documents `CPU, RAM, GPU, TEMP, NET` order.

3. **Accessibility Speech Sequence (`StatsLite/MenuBarAccessibility.swift:28-50`)**:
   - Lines 28–36: Appends CPU speech parts.
   - Lines 37–47: Appends Memory Pressure speech parts.
   - Lines 48–50: Appends GPU speech parts.
   - **Target Change**: Move lines 48–50 (`if showGPU`) before lines 37–47 (`if showRAM`). This change preserves WCAG 1.3.2 Meaningful Sequence parity with visual order.

4. **Controller Summary Description (`StatsLite/StatusItemController.swift:306-311`)**:
   - Lines 306–311: Comment describes the VoiceOver composite label string. Update the text to match the new order.

---

## 1. Visual Hierarchy & ASCII Wireframe

Evidence source: `artifacts/2026-10-24-temp-labels-cg/visual-vac/menubar-dark-v2.png` and `artifacts/2026-10-24-temp-labels-cg/visual-vac/menubar-light-v2.png`.

### Current Production Layout (CPU → MEM → GPU)
```text
|<-------------------------------- NSStatusItem (93 pt = 186 px @ 2x) -------------------------------->|
| 2 pt |<------- CPU (27 pt) ------->| 4 pt |<------- MEM (27 pt) ------->| 4 pt |<------- GPU (27 pt) ------->| 2 pt |
+------+-----------------------------+------+-----------------------------+------+-----------------------------+------+
| Pad  |                  Text("CPU")| Gap  |       ●  4pt   Text("MEM")  | Gap  |                  Text("GPU")| Pad  |
| 2 pt |       8 pt reg menuBarLabel | 4 pt | 4pt dot + 2pt + 8 pt reg    | 4 pt |       8 pt reg menuBarLabel | 2 pt |
|      |               (width 17.32) |      |        (total width 25.36)  |      |               (width 17.56) |      |
|      |                 flush right |      |                 flush right |      |                 flush right |      |
+------+-----------------------------+------+-----------------------------+------+-----------------------------+------+
|      |                  Text("00%")|      |                  Text("18%")|      |                  Text("00%")|      |
|      | 12 pt reg monospacedDigit   |      | 12 pt reg monospacedDigit   |      | 12 pt reg monospacedDigit   |      |
|      |       valueYOffset (-1 pt)  |      |       valueYOffset (-1 pt)  |      |       valueYOffset (-1 pt)  |      |
|      |                 flush right |      |                 flush right |      |                 flush right |      |
+------+-----------------------------+------+-----------------------------+------+-----------------------------+------+
```

### Target Production Layout (CPU → GPU → MEM)
```text
|<-------------------------------- NSStatusItem (93 pt = 186 px @ 2x) -------------------------------->|
| 2 pt |<------- CPU (27 pt) ------->| 4 pt |<------- GPU (27 pt) ------->| 4 pt |<------- MEM (27 pt) ------->| 2 pt |
+------+-----------------------------+------+-----------------------------+------+-----------------------------+------+
| Pad  |                  Text("CPU")| Gap  |                  Text("GPU")| Gap  |       ●  4pt   Text("MEM")  | Pad  |
| 2 pt |       8 pt reg menuBarLabel | 4 pt |       8 pt reg menuBarLabel | 4 pt | 4pt dot + 2pt + 8 pt reg    | 2 pt |
|      |               (width 17.32) |      |               (width 17.56) |      |        (total width 25.36)  |      |
|      |                 flush right |      |                 flush right |      |                 flush right |      |
+------+-----------------------------+------+-----------------------------+------+-----------------------------+------+
|      |                  Text("00%")|      |                  Text("00%")|      |                  Text("18%")|      |
|      | 12 pt reg monospacedDigit   |      | 12 pt reg monospacedDigit   |      | 12 pt reg monospacedDigit   |      |
|      |       valueYOffset (-1 pt)  |      |       valueYOffset (-1 pt)  |      |       valueYOffset (-1 pt)  |      |
|      |                 flush right |      |                 flush right |      |                 flush right |      |
+------+-----------------------------+------+-----------------------------+------+-----------------------------+------+
       |<--- boundary 1: CPU→GPU --->|      |<--- boundary 2: GPU→MEM --->|
```

### Spatial Alignment & Geometry
- **Outer Padding**: Pinned at 2.0 pt leading and 2.0 pt trailing (`MenuBarLayout.padding = 2`).
- **Standard Block Width**: Pinned at 27.0 pt (54 px at 2x) for CPU, GPU, and MEM (`MenuBarLayout.blockWidth = 27`).
- **Inter-Block Gap**: Pinned at 4.0 pt (8 px at 2x) (`MenuBarLayout.gap = 4`).
- **Slot Width (3 Metrics)**: 3 × 27 pt + 2 × 4 pt + 2 × 2 pt = 93.0 pt (186 px at 2x).
- **Line Heights**: Row 1 and Row 2 pin to 11.0 pt height (`MenuBarLayout.rowHeight = 11`).
- **Full Sequence with 5 Metrics**: CPU (27 pt) → GPU (27 pt) → MEM (27 pt) → TEMP (36 pt) → NET (50 pt).

---

## 2. Template / Component Skeleton

### Model Builder (`StatsLite/MenuBarBlockModel.swift:130-185`)
```swift
var blocks: [MenuBarBlock] = []

if showCPU {
    blocks.append(
        MenuBarBlock(
            kind: .cpu,
            label: "CPU",
            dotState: nil,
            valueText: MetricFormatters.percent(cpuPercent),
            valueTint: usageTint(cpuPercent),
            width: MenuBarLayout.blockWidth
        )
    )
}

// Swapped: GPU builds before MEM
if showGPU {
    blocks.append(
        MenuBarBlock(
            kind: .gpu,
            label: "GPU",
            dotState: nil,
            valueText: MetricFormatters.percent(gpuPercent),
            valueTint: usageTint(gpuPercent),
            width: MenuBarLayout.blockWidth
        )
    )
}

// Swapped: MEM builds after GPU
if showRAM {
    let resolvedState = pressurePercent.map {
        (pressureState ?? .unknown).displayState(pressure: $0)
    } ?? .unknown
    blocks.append(
        MenuBarBlock(
            kind: .ram,
            label: "MEM",
            dotState: resolvedState,
            valueText: MetricFormatters.percent(pressurePercent),
            valueTint: pressurePercent == nil ? .tertiary : .primary,
            width: MenuBarLayout.blockWidth
        )
    )
}

if showTemperature {
    // Temperature block remains downstream
    let cpuCelsius = temperature?.cpuCelsius
    let gpuCelsius = temperature?.gpuCelsius
    blocks.append(
        MenuBarBlock(
            kind: .temp,
            label: "C",
            dotState: nil,
            valueText: MetricFormatters.degrees(cpuCelsius),
            valueTint: cpuCelsius == nil ? .tertiary : .primary,
            width: MenuBarLayout.tempBlockWidth,
            secondaryValueText: MetricFormatters.degrees(gpuCelsius),
            secondaryValueTint: gpuCelsius == nil ? .tertiary : .primary,
            secondaryLabel: "G"
        )
    )
}

if showNetwork {
    // Network block remains trailing
    blocks.append(
        MenuBarBlock(
            kind: .network,
            label: "",
            dotState: nil,
            valueText: MetricFormatters.networkRate(uploadRate),
            valueTint: uploadRate == nil ? .tertiary : .primary,
            width: MenuBarLayout.networkBlockWidth,
            secondaryValueText: MetricFormatters.networkRate(downloadRate),
            secondaryValueTint: downloadRate == nil ? .tertiary : .primary
        )
    )
}
```

### Visual Container (`StatsLite/MenuBarStackedItemView.swift:42-52`)
```swift
HStack(alignment: .center, spacing: MenuBarLayout.gap) {
    ForEach(blocks, id: \.kind) { block in
        if block.kind == .network {
            MenuBarNetworkBlockView(block: block)
        } else if block.kind == .temp {
            MenuBarTempBlockView(block: block)
        } else {
            MenuBarBlockView(block: block)
        }
    }
}
.frame(maxWidth: .infinity, alignment: .center)
.padding(.horizontal, MenuBarLayout.padding)
.accessibilityHidden(true)
```

---

## 3. Complete State & Responsive Matrix

### Inter-Block Ink Gap Matrix at 2x (Bitmap Pixels)
Because the downstream neighbor changes, the observed ink gaps change across boundaries:

| Boundary | Downstream Block State | Content Width | Leading Frame Slack | Ink Gap at 2x |
|---|---|---|---|---|
| **CPU→GPU** | GPU 2-digit (`10%`..`99%`) | 26.22 pt | 0.78 pt (1.56 px) | **10–11 px** |
| **CPU→GPU** | GPU 1-digit (`0%`..`9%`) | 18.66 pt | 8.34 pt (16.68 px) | **25–26 px** (band 23–27 px) |
| **CPU→GPU** | GPU placeholder (`"--%"`) | 22.42 pt | 4.58 pt (9.16 px) | **18–19 px** (band 17–20 px) |
| **GPU→MEM** | MEM 2-digit (`10%`..`99%`) | 26.22 pt | 0.78 pt (1.56 px) | **10–11 px** |
| **GPU→MEM** | MEM 1-digit (`0%`..`9%`) | 25.36 pt (label floor) | 1.64 pt (3.28 px) | **12–13 px** |
| **GPU→MEM** | MEM placeholder (`"--%"`) | 25.36 pt (label floor) | 1.64 pt (3.28 px) | **12–13 px** (band 11–14 px) |
| **MEM→TEMP** | TEMP active (`"C 45°"`) | 36.00 pt (fixed) | 0.00 pt (fixed) | **21 ± 1 px** (ISC-3) |

### State Behaviors
- **Default Appearance**: Labels render with `.menuBarMetricLabel()` (8 pt regular text with adaptive `Color.menuBarLabel`). Values display natural unpadded numbers up to `"99%"`.
- **Warning Appearance (Usage ≥ 80%)**: Value text changes to orange (`MenuBarValueTint.warning`).
- **Critical Appearance (Usage ≥ 95%)**: Value text changes to red (`MenuBarValueTint.critical`).
- **Nil / Uninitialized Metric**: Value text renders `"--%"` with tertiary foreground tint (`MenuBarValueTint.tertiary`).
- **Transition Rule**: No `.animation` or `.contentTransition` modifiers exist in the view tree. Changes occur discretely.

### Viewport Adaptation Matrix
- **Compact Viewport (375 pt mobile equivalent)**: Status item occupies 93 pt (3 metrics) or 187 pt (5 metrics). The item fits without clipping or line wrapping.
- **Medium Viewport (768 pt tablet equivalent)**: Status item maintains fixed length 93 pt to 187 pt. Content remains centered.
- **Wide Viewport (1440 pt desktop equivalent)**: Status item maintains fixed length 93 pt to 187 pt. Height remains pinned to 22 pt.

---

## 4. Accessibility (WCAG 2.2) & Interaction Contracts

### WCAG 2.2 Criteria
- **1.3.2 Meaningful Sequence (Level A)**: The VoiceOver speech order must match visual sequence:
  ```swift
  "Stats Lite: CPU 14 percent, GPU 28 percent, Memory Pressure Normal at 25 percent"
  ```
  Move the GPU speech builder before the Memory Pressure builder in `StatsLite/MenuBarAccessibility.swift:28-50`.
- **1.4.3 Contrast (Minimum) (Level AA)**:
  - Metric labels use `Color.menuBarLabel` from `DESIGN.md`. The color renders 80% white in dark appearance and 75% black in light appearance. Both appearances maintain contrast ratios above 4.5:1.
- **2.5.8 Target Size (Minimum) (Level AA)**:
  - The status bar item button spans full status bar thickness (22 pt) and width 31 pt to 187 pt. This geometry satisfies macOS click target requirements.

### Interaction Contract
- Clicking the status item opens or closes the main popover.
- Pressing `Esc` dismisses the popover.
- Clicking outside the popover dismisses the popover through AppKit event monitors.

---

## 5. Numbered Visual Acceptance Checklist (VAC)

### Offscreen Render Tests (`StatsLiteTests/MenuBarRenderSnapshotTests.swift`)
- [ ] **VAC-1 (Standard Block Sequential Order)**: When all standard metrics are enabled, `MenuBarBlockBuilder.blocks()` produces items with labels `["CPU", "GPU", "MEM"]` and kinds `[.cpu, .gpu, .ram]`.
- [ ] **VAC-2 (CPU→GPU Minimal Gap)**: In `StatsLiteTests/MenuBarRenderSnapshotTests.swift`, the closest-approach ink gap between CPU and GPU measures **8–12 px** at 2x across forced `.aqua` and `.darkAqua` appearances for two-digit values.
- [ ] **VAC-3 (GPU→MEM Minimal Gap)**: In `StatsLiteTests/MenuBarRenderSnapshotTests.swift`, the closest-approach ink gap between GPU and MEM measures **8–12 px** at 2x across forced `.aqua` and `.darkAqua` appearances for two-digit values.
- [ ] **VAC-4 (Standard Boundary Gap Uniformity)**: In `StatsLiteTests/MenuBarRenderSnapshotTests.swift`, `|gap(CPU→GPU) − gap(GPU→MEM)|` measures **≤ 1 px** at 2x for matching digit classes.
- [ ] **VAC-5 (Single-Digit GPU Value Gap Band)**: When GPU displays `"0%"`, the CPU→GPU closest-approach ink gap measures between **23 px and 27 px** at 2x (`singleDigitGapFloor` to `singleDigitGapCeiling`).
- [ ] **VAC-6 (Cold Fixture Composition Gap Bands)**: When metrics are uninitialized (`"--%"`):
  - CPU→GPU ink gap measures **17–20 px** at 2x (`coldMemGpuGapFloor` to `coldMemGpuGapCeiling`).
  - GPU→MEM ink gap measures **11–14 px** at 2x (`coldCpuMemGapFloor` to `coldCpuMemGapCeiling`).
- [ ] **VAC-7 (Downstream Inter-Block Gap Parity)**: The inter-block ink gap between the last standard block (MEM) and the TEMP block (`MEM→TEMP`) measures **21 ± 1 px** at 2x (`interBlockGap`).
- [ ] **VAC-8 (Slot-Fill and Centering)**: The 3-metric composition render inside the 93 pt slot maintains `leftVoid ≤ 1 px` and `rightVoid ≤ 1 px` at 2x. Rightmost ink terminates at the trailing edge of the MEM frame.
- [ ] **VAC-9 (Position Freezing Invariant)**: Across value sweeps (`0%`, `5%`, `10%`, `50%`, `99%`, `--%`), the single-block frame width and x-origin of CPU, GPU, and MEM freeze with **0.0 px** spread at 2x.

### Screen & Viewport Invariants (375 pt / 768 pt / 1440 pt)
- [ ] **VAC-10 (Fixed Total Item Length)**: `MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: true)` evaluates to exactly **93.0 pt** (186 px at 2x). Total length does not change.
- [ ] **VAC-11 (Single-Line No-Wrap Constraint)**: Across viewports (375 pt, 768 pt, 1440 pt), the status item contents display on two 11 pt rows with zero text wrapping or line breaks.
- [ ] **VAC-12 (VoiceOver Announcement Parity)**: `MenuBarAccessibility.compositeLabel` outputs the CPU phrase, then the GPU phrase, then the Memory Pressure phrase.

---

## 6. Test Synchronization Guide for Coder

1. `StatsLiteTests/MenuBarBlockBuilderTests.swift`:
   - Update line 54 labels to `["CPU", "GPU", "MEM"]`.
   - Update line 55 kinds to `[.cpu, .gpu, .ram]`.
   - Update combination tests at line 81 to `[.gpu, .ram]` and line 82 to `[.cpu, .gpu, .ram]`.
   - Update network combinations at line 349 to `[.cpu, .gpu, .ram, .network]`.
2. `StatsLiteTests/MenuBarAccessibilityTests.swift`:
   - Update all composite label assertions to order GPU before Memory Pressure.
3. `StatsLiteTests/MenuBarTempBlockTests.swift` & `MenuBarTempVerificationTests.swift`:
   - Update expected 5-block sequence to `[.cpu, .gpu, .ram, .temp, .network]`.
   - Update canonical loop in `MenuBarTempVerificationTests.swift:222-226` to append `.gpu` before `.ram`.
4. `StatsLiteTests/MenuBarRenderSnapshotTests.swift`:
   - Update `boundaries` in `testStandardBlockGapsAreUniformAndMinimal` to `("CPU→GPU", blocks.cpu, blocks.gpu)` and `("GPU→MEM", blocks.gpu, blocks.mem)`.
   - Update `boundaries` in `testExtremeValuesKeepBlockGapsOpen` to `CPU→GPU` and `GPU→MEM`.
   - Update `testSingleDigitGpuValueKeepsMemToGpuGapInTwentyThreeToTwentySevenPixels` to evaluate `adjacent(blocks.cpu, singleDigitGPU)`.
   - In `testStackedItemCompositionFillsSlotEdgeToEdge`: set boundary 1 to CPU→GPU (gap 17–20 px), set boundary 2 to GPU→MEM (gap 11–14 px), and verify rightmost ink against `memWidth`.
   - In `testInterBlockInkGapsMeasureTwentyOnePixels`: verify `adjacent(blocks.mem, blocks.temp)` for MEM→TEMP.
