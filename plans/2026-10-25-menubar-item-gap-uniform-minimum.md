# Menu Bar CPU/MEM/GPU Gaps: Uniform and Minimal

- Date: 2026-10-25
- Trigger: USER DIRECTIVE — "in the menubar the gap between cpu, mem, and gpu must be as uniform as possible, and as minimum as possible"
- Phase: IMPLEMENTATION (R2 UI)
- Risk class: R2 (visible layout change to the status item; offscreen pixel tests verify)
- Design: 5-part blueprint from the designer (session 2026-10-24/25). The blueprint is final; do not restructure it. This plan adds four integration corrections with evidence (section "Blueprint integration corrections").
- Oracle matrix: not triggered (pure UI/UX directive → designer path)

## Context

### Current state (measured)

- One `NSStatusItem` hosts all metrics (`StatsLite/StatusItemController.swift:68`). CPU/MEM/GPU are blocks in one `HStack(spacing: MenuBarLayout.gap)` (`StatsLite/MenuBarStackedItemView.swift:36`, `MenuBarLayout.gap = 4` at `StatsLite/MenuBarBlockModel.swift:84`), plus 2 pt outer padding.
- Each standard block pins `.frame(width: block.width, alignment: .trailing)` = 39 pt (`StatsLite/MenuBarStackedItemView.swift:128`, `MenuBarLayout.blockWidth = 39` at `MenuBarBlockModel.swift:61`).
- Root cause of the defect: the block frame is wider than its content, and the content is trailing-aligned. The empty space sits on the leading side of each block and adds to the `gap`. Ink gap = `4 pt + next block's leading slack`, and that slack varies with the next block's text width.
- Designer pixel probe on the production baseline (`artifacts/2026-10-24-temp-labels-cg/visual-vac/menubar-dark-v2.png`, 2×): CPU→MEM gap 45 px (22.5 pt), MEM→GPU gap 38 px (19 pt), delta 7 px. The gaps are unequal and 5× the design token.

### Target state

- The visible (ink) gap between CPU→MEM and MEM→GPU equals `MenuBarLayout.gap` = 4 pt (8 px at 2×), plus glyph side bearings (≤ 2 px per edge at 2×), for every value combination.
- The two gaps are equal within 1 px at 2× on the value row.
- No ink collision at extreme values (`100%`, `--%`).
- The status item length contract is unchanged: `MenuBarLayout.length` still returns 129/86/43/4. The item never resizes.

### Accepted consequence (follows from the directive)

Uniform ink gaps are impossible with fixed-width frames: gap = `4 pt + next block's leading slack`, and the slack changes with the text. The fix makes blocks size to intrinsic content. Two consequences:

1. Discrete position shifts: block x-positions move when a value's digit count changes (monospaced digits, so only `5%→10%→100%`-type crossings). The gaps stay constant. Today the positions are fixed but the gaps jump at the same crossings. The user's directive chooses constant gaps over fixed positions.
2. Slot void: content (≈ 90 pt typical) is narrower than the fixed 129 pt slot. The leftover space becomes one void, split symmetrically left and right of the block group (see correction 4).

## Blueprint integration corrections (planner, with evidence)

1. **ISC-6 breaks.** `testRenderDimensionsMatchProductionGeometry` asserts `pixelsWide == blockWidth * scale` for cpu/mem/gpu (`StatsLiteTests/MenuBarRenderSnapshotTests.swift:227,235,243`). Intrinsic blocks render at content width, not 39 pt. Fix: for the three standard cases, assert `pixelsWide <= Int(MenuBarLayout.blockWidth * scale)` (budget ceiling) and keep the exact height assertion. Comment why: the production geometry of a standard block is its content width, bounded by the `blockWidth` length budget. The temp/network cases keep exact-width assertions.
2. **ISC-3 breaks on its boundary.** `testInterBlockInkGapsMeasureTwentyOnePixels` searches the C label in `xRange: gpuEnd..<…` with `gpuEnd = Int(MenuBarLayout.blockWidth * scale)` = 78 px (`MenuBarRenderSnapshotTests.swift:430-437`). After the change, the GPU block shrinks to content width (≈ 52 px for `32%`) and the C label lands left of 78 px, so the `XCTUnwrap` fails. Fix: derive the boundary from a single-block render: `gpuW = MenuBarRenderHarness.render(MenuBarBlockView(block: blocks.gpu), …).pixelsWide`, search GPU value ink in `0..<gpuW`, and search the C label in `(gpuW + Int(MenuBarLayout.gap * scale))..<pixelsWide`. The expected 21 ± 1 px does NOT change: the GPU ink edge and the TEMP frame both shift left by the same amount, so the gap term cancels.
3. **Ink-gap tolerance must allow glyph side bearings.** The ink gap = frame gap (8 px) + right bearing of the last glyph + left bearing of the first glyph. At 12 pt monospaced digits that is up to ≈ 2 px per edge at 2×, so the blueprint's `8 ± 1 px` would fail on correct code. Spec: assert `8 <= gap <= 12 px` at 2× (floor = design token, ceiling = no regression to today's 38–45 px). Uniformity target stays ≤ 1 px; if bearing asymmetry (MEM pressure dot vs digit) measures higher, record the measurement and raise the tolerance to ≤ 2 px with evidence — never above.
4. **Slot placement is not in the blueprint.** With intrinsic blocks, the root `HStack` no longer fills the 129 pt button, and `NSHostingView` placement of an undersized root is implicit. Fix: pin it explicitly. Add `.frame(maxWidth: .infinity, alignment: .center)` between the root `HStack` and `.padding(.horizontal, MenuBarLayout.padding)` (`MenuBarStackedItemView.swift:36-47`). The block group stays centered in the slot, the void splits symmetrically (≈ 19 pt per side typical), and the first block no longer depends on the hosting view's implicit alignment.

## Steps

1. **Baseline capture (before the first code edit).** Run `scripts/capture_menubar.sh` with the display awake and no running StatsLite instance. Copy the outputs to `artifacts/2026-10-25-menubar-item-gap-uniform-minimum/before/`. Live captures are end-to-end spot checks only (AGENTS.md); the offscreen tests are the verification.
2. **Worktree.** `MAIN_REPO=/Users/jonathan/beliantech/stats-lite-macos`, `TASK_NAME=2026-10-25-menubar-item-gap-uniform-minimum`, `BRANCH=feat/2026-10-25-menubar-item-gap-uniform-minimum`, `WORKTREE_DIR=${MAIN_REPO}/worktrees/${TASK_NAME}`. Create with `git worktree add -B "${BRANCH}" "${WORKTREE_DIR}" main`. All code work happens there.
3. **Production edits (only these):**
   - `StatsLite/MenuBarStackedItemView.swift`
     - `MenuBarBlockView.body`: replace `.frame(width: block.width, alignment: .trailing)` with `.fixedSize(horizontal: true, vertical: false)`. Keep the `VStack(alignment: .trailing)` — both rows stay flush to the block's trailing edge (the 2026-10-24 right-alignment directive is preserved).
     - Root `HStack`: add `.frame(maxWidth: .infinity, alignment: .center)` before `.padding(.horizontal, MenuBarLayout.padding)` (correction 4).
     - Update the file header and the `MenuBarBlockView` doc comment: blocks render at intrinsic width; `blockWidth` is now only the length budget; gap uniformity comes from intrinsic bounds. No `.animation`, no `.contentTransition` (unchanged rule).
   - `StatsLite/MenuBarBlockModel.swift`: update the `blockWidth` doc comment only — "width budget for `MenuBarLayout.length`; standard blocks render at intrinsic width". Keep value 39. Keep `MenuBarBlock.width` (the builder tests assert it).
4. **Test edits (`StatsLiteTests/MenuBarRenderSnapshotTests.swift`):**
   - ISC-6: apply correction 1.
   - ISC-3: apply correction 2.
   - New VAC tests (use the existing `builtBlocks()`, `adjacent(_:_:)`, `MenuBarRenderHarness` helpers; measure the ink gap per row band as `leftmostInkX(right band region) - (rightmostInkX(left region) + 1)`; block boundary = the single-block render width, production-derived):
     - **VAC-A (uniform + minimal):** for `adjacent(cpu, mem)` and `adjacent(mem, gpu)`, both appearances, compute the gap per band (`line1`, `line2`) and take the minimum (closest approach). Assert `gap ∈ [8, 12]` px for both boundaries and `|gap(cpu,mem) - gap(mem,gpu)| ≤ 1` px (≤ 2 px only with recorded bearing evidence).
     - **VAC-B (extremes, no collision):** build blocks with `cpuPercent: 1.0`, `pressurePercent: 1.0`, `gpuPercent: 1.0` (`100%` everywhere) and with `nil` (`--%`), render both adjacencies, both appearances. Assert the min-band gap `≥ 7` px and `≤ 12` px.
     - **VAC-C (production composition + centering):** render `MenuBarStackedItemView(monitor: SystemMonitor(provider: FakeSystemMetricsProvider()), preferences: PreferencesStore())` wrapped in `.frame(width: MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: true))`, per `MenuBarRedrawChurnTests.swift:99-101` fixture pattern. Assert (a) both standard gaps in `[8, 12]` px, (b) `|leftVoid - rightVoid| ≤ 2` px (the group is centered). If the default preferences do not enable CPU/RAM/GPU, set them explicitly.
5. **Run the full suite** in the worktree: `xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test`. All tests green. Known-unaffected: `MenuBarLayoutTests` (length math unchanged), `MenuBarBlockBuilderTests` (`width == 39` model assertion unchanged), `MenuBarRedrawChurnTests` (no animation modifiers added), ISC-1/2/4/5.
6. **After capture.** Re-run `scripts/capture_menubar.sh`, copy outputs to `artifacts/2026-10-25-menubar-item-gap-uniform-minimum/after/`. Compare with the before strip: the three blocks must sit tighter and evenly spaced. This is a spot check, not the gate.
7. **Commit** in the worktree as one commit: `fix(menubar): make CPU/MEM/GPU block gaps uniform and minimal` (conventional commit per the git-commit skill). Then hand to the reviewer.

## Visual Acceptance Checklist (VAC)

- VAC-A: CPU→MEM and MEM→GPU ink gaps each measure 8–12 px at 2× and are equal within 1 px (both appearances). Offscreen: new test in `MenuBarRenderSnapshotTests`.
- VAC-B: at `100%` and `--%` extremes, both gaps stay ≥ 7 px — no ink merge or collision (both appearances). Offscreen: new test.
- VAC-C: in the production `MenuBarStackedItemView` composition at the 129 pt slot width, both gaps hold and the leftover void is symmetric (≤ 2 px side delta). Offscreen: new test.
- VAC-D: both rows of each block stay flush to the block trailing edge (the 2026-10-24 right-alignment directive holds). Verify in VAC-A renders: right ink of line 1 and line 2 of each block within 1 px, or reuse an existing assertion if present.
- VAC-E: the status item length contract holds: `MenuBarLayout.length` returns 129/86/43/4. Existing `MenuBarLayoutTests`.
- VAC-F: no `.animation` / `.contentTransition` anywhere on the status item path. Existing `MenuBarRedrawChurnTests`.
- VAC-G: sparkline time axes untouched (`SparklineTimeAxisView` not in the diff). Existing tests.
- VAC-H: ISC-3 TEMP↔NET and GPU↔TEMP gaps still measure 21 ± 1 px (the temp/network blocks are unchanged). Existing test, boundary corrected per correction 2.

## Falsification

- H: intrinsic block bounds are the sole cause of the inflated, unequal gaps. Test: after the change, VAC-A measures 8–12 px with ≤ 1 px delta. If the gaps do not move into that range, H is dead — the harness or the HStack spacing is adding space; stop and re-measure before any further edit. One variable per round: the only production changes are the `MenuBarBlockView` frame swap and the root centering frame; the gap tests render blocks directly, so a gap-test failure isolates the frame swap, and a VAC-C-only failure isolates the centering frame.

## Non-goals

- No change to `MenuBarLayout.gap` (4 pt stays the design minimum), `blockWidth` (39), `length(...)`, or any length total.
- No change to the temp and network blocks (fixed widths; their 21 px gaps are a separate issued contract, ISC-3).
- No typography, color, tint, accessibility-string, or animation changes.
- No `DESIGN.md` change (it carries only the 8 pt label rule; verified 2026-10-25).
