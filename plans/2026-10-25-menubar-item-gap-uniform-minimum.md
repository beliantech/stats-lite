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

---

## Task ledger

- [x] **T1** — intrinsic-width gap fix (VAC-A/B/C + ISC-3/ISC-6 corrections). green `674a1f7` · review GO · merged `674a1f7` (ff, 2026-10-25). Suite green ×4 (coder ×3, planner ×1): 435 tests, 0 failures.
- [x] **T2** — frozen positions via fixed-width value text (S1, Appendix B). red `b832ec5` · green `d07c26a` · review GO (own run 436/0) · merged `f619778` (squash, 2026-10-25). VAC-101 spread 0.0 px; gaps 11 px, delta 0.

## T2 — Frozen Positions via Fixed-Width Value Text (S1)

- Defect: after T1 deploy, values crossing digit boundaries (9%→10%, 99%→100%) widen the intrinsic block and shift MEM/GPU right. User directive: "we need to keep the position accommodating these."
- Approval: user picked **S1** on this plan ("ok S1 go", 2026-10-25), accepting fixed-width values (`045%` style) as the cost of holding all four constraints.
- VACs: **VAC-101…109 below replace VAC-A/B/C for T2.** VAC-D…H and all T1 regressions stay.
- Scope (planner-verified 2026-10-25): `MetricFormatters.percent` has exactly three call sites, all in `StatsLite/MenuBarBlockModel.swift` (lines 141, 157, 173). Popover cards use `percentTenth` (natural text, untouched). VoiceOver uses `wholePercent` (untouched).
- TDD: red spawn authors failing tests first (touching no production code), green spawn implements Appendix B.
- Risk class: R2 (UI text + layout change).

### T2 red-phase test scope (runnable red required)

- Author VAC-101 position-freeze test — fails on current intrinsic code (positions shift).
- Update `MetricFormatterTests` / `MenuBarBlockBuilderTests` expectations to the S1 contract (`"000%"`, `"045%"`, `"100%"`, `"−−−%"`) — fails on current formatter.
- Update VAC-B fixtures to `"−−−%"` (U+2212 × 3 + `%`).
- Tests that need the new `MenuBarLayout.standardBlockWidth` constant belong to the green spawn so the red run compiles and produces runtime failures.

### Appendix B — Design Fix Blueprint (designer, 2026-10-25; copied verbatim)

# Appendix B: Design Fix Blueprint — Frozen Block Positions and Gap Resolution

## 1. Executive Summary & Root Cause Analysis

### Defect Report
Following deployment of commit `674a1f7` (plan `plans/2026-10-25-menubar-item-gap-uniform-minimum.md`), the user reported:
> *"once the number increases to 99% or 100% it expands, we need to keep the position accommodating these."*

### Root Cause
Commit `674a1f7` replaced `.frame(width: block.width, alignment: .trailing)` with `.fixedSize(horizontal: true, vertical: false)` on `MenuBarBlockView`.
This change made standard metric blocks size to their intrinsic content.
At 12 pt monospaced regular font, text width varies by digit count:
- 1-digit values (`"0%"` to `"9%"`): **18.66 pt** (37.3 px at 2×).
- 2-digit values (`"10%"` to `"99%"`): **26.22 pt** (52.4 px at 2×).
- 3-digit values (`"100%"`): **33.78 pt** (67.6 px at 2×).
- Unavailable placeholder (`"--%"`): **22.42 pt** (44.8 px at 2×).

Because blocks size intrinsically, a value crossing digit boundaries causes the block width to expand:
- `9%` to `10%` expands the block by **7.56 pt** (+15.1 px at 2×).
- `99%` to `100%` expands the block by **7.56 pt** (+15.1 px at 2×).
- Total expansion from `0%` to `100%` is **15.12 pt** (+30.2 px at 2×).

Because blocks sit in an `HStack` centered inside the 129 pt slot:
1. Every expansion of CPU shifts MEM and GPU rightward.
2. Centering divides expansion symmetrically. The left block shifts leftward by half the delta.
3. Every metric transition across digit thresholds produces visible horizontal jitter.

## 2. Verification of Planner Impossibility Proof

### Mathematical Proof
Let Block A be followed by Block B in an `HStack` with fixed inter-frame spacing g = 4.0 pt.
1. By Constraint 1 (Position Freezing), Block A and Block B have fixed frame origins X_A, X_B and fixed frame widths W_A, W_B.
2. By Constraint 3 (Right-Alignment Directive), all rows align to trailing edges. Block A rightmost ink sits at X_A + W_A − r_A, where r_A is the right glyph side bearing.
3. In Block B, text has ink width w_B. Because Block B is trailing-aligned to X_B + W_B, Block B leftmost ink sits at (X_B + W_B − r_B) − w_B.
4. The horizontal ink gap: gap = g + (W_B − w_B) + (r_A − r_B).

In this equation: g constant (4.0 pt); W_B constant (Constraint 1); (r_A − r_B) constant within glyph bearing variance (≤ 1.0 pt). The only independent variable is w_B.

Therefore: ∂gap/∂w_B = −1, and Δgap = −Δw_B.

**Conclusion**: the proof is mathematically irrefutable. If positions are frozen and rows are right-aligned, the visible ink gap must vary inversely with the text ink width. A uniform ink gap is mathematically impossible unless w_B is invariant.

## 3. Evaluation of Candidate Solutions (S1–S5)

| Candidate | C1: Frozen Positions | C2: Uniform & Minimal Gap | C3: Right Alignment | C4: 129 pt Length Contract | UX & Copy Verdict |
|---|---|---|---|---|---|
| **S1: Constant Ink Width** (normalized 3-digit text) | **PASS** (100% frozen) | **PASS** (8.4 px at 2×; Δ = 0 px) | **PASS** (flush right) | **PASS** (129 pt preserved) | **REQUIRES USER APPROVAL** (zero-padding: `"005%"`, `"045%"`, `"100%"`) — **GRANTED 2026-10-25** |
| **S2: Fixed Worst-Case Frame** (F = 34 pt, natural copy) | **PASS** (100% frozen) | **FAIL** (gaps swing 8.4 to 38.7 px; delta up to 30.2 px) | **PASS** (flush right) | **PASS** (129 pt preserved) | **PASS** (natural copy) |
| **S3: Intrinsic Width** (T1, commit 674a1f7) | **FAIL** (shifts 15.1 px per digit crossing) | **PASS** (8–12 px at 2×) | **PASS** (flush right) | **PASS** (129 pt preserved) | **FAIL** (user rejected; horizontal jitter) |
| **S4: Leading Ink Marker** (dot on value row) | **PASS** (100% frozen) | **PARTIAL** (value row uniform; label row sparse) | **FAIL** (value row split left/right) | **FAIL** (F ≥ 40 pt exceeds 129 pt) | **FAIL** (visual clutter; unexplained dots) |
| **S5: Figure-Space Padding** (U+2007) | **PASS** (frame frozen) | **FAIL** (spaces have zero ink; identical to S2) | **PASS** (flush right) | **PASS** (129 pt preserved) | **PASS** (reads as unpadded) |

## 4. Analysis and Rejection of Candidates

- **S2 (F = 34 pt, trailing-aligned)**: value `"100%"` → gap 4.22 pt (8.4 px); `"45%"` → 11.78 pt (23.6 px); `"0%"`/`"5%"` → 19.34 pt (38.7 px); `"--%"` → 15.58 pt (31.2 px). Max cross-boundary delta 30.24 px at 2× — four times the 7.0 px delta that triggered the initial complaint. **REJECT against C2.**
- **S3 (status quo)**: **REJECT against C1** — user confirmed post-deploy defect.
- **S4 (leading marker)**: **REJECT against C3 and C4** — frame ≥ 40 pt breaks the 129 pt contract; adds visual noise.
- **S5 (U+2007 figure space)**: digit-width space, but whitespace produces zero ink; leftmost ink stays the first digit. Ink gap identical to S2. **REJECT against C2.**

## 5. Architectural Recommendation

Solution S1 is the only mathematically possible solution satisfying all four constraints. Every percentage string formats to 3 digits plus `%`:
- Format: `"%03d%%"` (for example `"005%"`, `"045%"`, `"100%"`).
- Missing/unavailable: `"−−−%"` (three U+2212 minus signs plus `%`). Typographic evidence: in San Francisco monospaced digits U+2212 has width 7.5586 pt, identical to numeric digits; `"−−−%"` width = 33.7793 pt, matching `"100%"` to four decimals.
- User approval: **GRANTED** (2026-10-25, "ok S1 go").

## 6. Solution S2 Fallback Specification (inactive — S1 approved)

Kept for reference only: standard blocks pin `MenuBarLayout.standardBlockWidth = 34` with trailing alignment, natural text, relaxed gap contract (8–40 px at 2×, cross-boundary delta ≤ 31 px). Do not implement unless the user withdraws S1.

## 7. Resulting Gap Mathematics at 2×

### Frame and Slot Dimensions
- Status item length: 129.0 pt (258 px at 2×). Outer padding 2.0 pt/side (4 px).
- Standard block frame width (F): **34.0 pt** (68 px). Inter-block frame spacing (g): 4.0 pt (8 px).
- Block group total: 3 × 34.0 + 2 × 4.0 = **110.0 pt** (220 px). Left/right void: (125 − 110)/2 = **7.5 pt** (15 px) each.

### S1 Ink Gap Math (normalized values)
- Text width for all values (`"000%"`…`"100%"`, `"−−−%"`): **33.78 pt** (67.56 px).
- Leading clearance inside frame: 34.0 − 33.78 = **0.22 pt** (0.44 px). Trailing clearance: 0 (flush right).
- Mathematical ink gap: 4.0 + 0.22 = **4.22 pt** (**8.44 px** at 2×).
- Measured bitmap ink gap with glyph bearings: **10 to 11 px at 2×**.
- Boundary delta: **0 px** (uniform).

## 8. Exact Code Locations for Implementation

1. `StatsLite/MenuBarBlockModel.swift` line 62 — add:
   ```swift
   /// Pinned width of standard metric blocks (CPU, MEM, GPU).
   /// Accommodates "100%" (33.78 pt) with 0.22 pt clearance.
   static let standardBlockWidth: CGFloat = 34
   ```
   Line 61: keep `static let blockWidth: CGFloat = 39` to preserve `MenuBarLayout.length` calculations.
2. `StatsLite/MenuBarStackedItemView.swift` line ~137 — replace `.fixedSize(horizontal: true, vertical: false)` with:
   ```swift
   .frame(width: MenuBarLayout.standardBlockWidth, alignment: .trailing)
   ```
   Line ~49: keep `.frame(maxWidth: .infinity, alignment: .center)` on the root `HStack`.
3. `StatsLite/MetricFormatters.swift` lines 15–18 — replace `percent`:
   ```swift
   static func percent(_ value: Double?) -> String {
       guard let value, value.isFinite else { return "−−−%" }
       let clamped = min(max(value, 0), 1)
       return String(format: "%03d%%", Int((clamped * 100).rounded()))
   }
   ```
   Update the doc comment (line 12) to the new contract.

## 9. Affected Tests List

1. `StatsLiteTests/MenuBarValueTypographyTests.swift` — `testMetricBlockFrameUsesIntrinsicFixedSizeWidth()` (line 594): update the pin to assert `.frame(width: MenuBarLayout.standardBlockWidth, alignment: .trailing)`.
2. `StatsLiteTests/MenuBarRenderSnapshotTests.swift`:
   - VAC-A (`testStandardBlockGapsAreUniformAndMinimal`, lines 580–640): passes under S1 with gap in [8, 12] px and delta ≤ 1 px — keep as-is.
   - VAC-B (`testExtremeValuesKeepBlockGapsOpen`, lines 687–745): fixture `"--%"` → `"−−−%"`; ceiling 13 px holds.
   - ISC-6 (`testRenderDimensionsMatchProductionGeometry`, lines 220–250): `pixelsWide <= blockWidth * scale` holds (68 ≤ 78 px).
   - VAC-C (`testStackedItemCompositionKeepsGapsAndCenteredVoid`, lines 747–875): void delta 15 − 15 = 0 px passes.
3. `StatsLiteTests/MetricFormatterTests.swift` (lines 15–31): expectations `"0%"` → `"000%"`, `"14%"` → `"014%"`, `"--%"` → `"−−−%"`. VoiceOver tests in `MenuBarAccessibilityTests` use `wholePercent` — unaffected.
4. `StatsLiteTests/MenuBarBlockBuilderTests.swift`: value expectations become `"000%"`, `"050%"`, etc.

## 10. Numbered Visual Acceptance Checklist (VAC) — replaces VAC-A/B/C

- [ ] **VAC-101 (Position Freezing Invariant)**: for every value sweep across `0%`, `5%`, `10%`, `50%`, `99%`, `100%`, and nil (`−−−%`), the x-origin of each standard block (CPU, MEM, GPU) stays constant within 0.0 px.
- [ ] **VAC-102 (Gap Uniformity and Minimality)**: closest-approach ink gap for CPU→MEM and MEM→GPU measures 8–12 px at 2× under both `.darkAqua` and `.aqua`.
- [ ] **VAC-103 (Cross-Boundary Uniformity Delta)**: |gap(CPU→MEM) − gap(MEM→GPU)| ≤ 1 px at 2×.
- [ ] **VAC-104 (Extreme Value Collision Safety)**: at `100%` and `−−−%`, closest-approach gap ≥ 7 px at 2×; no ink merging.
- [ ] **VAC-105 (Trailing Edge Alignment Flushness)**: line 1 and line 2 right ink edges of each standard block align flush within 1 px at 2×.
- [ ] **VAC-106 (Centered Void Symmetry)**: |leftVoid − rightVoid| ≤ 2 px at 2× in the 129 pt slot.
- [ ] **VAC-107 (Status Item Length Contract)**: `MenuBarLayout.length` equals 129.0 / 86.0 / 43.0 pt.
- [ ] **VAC-108 (Discrete Transition Invariant)**: no `.animation` or `.contentTransition` in `MenuBarBlockView` / `MenuBarStackedItemView`.
- [ ] **VAC-109 (Downstream Block Gap Parity)**: GPU→TEMP and TEMP→NET ink gaps stay 21 ± 1 px at 2× (ISC-3).

---

## T3 — Natural Values Clipped to 99 and Minimal Slot Geometry (Appendix C)

- Status: [x] **T3** — implemented Appendix C (natural text, clip 99, blockWidth 39→27, length 129→93). red `a3fc0e2` · green `b704ad7` · review: GO reported (7 s turnaround — not accepted as a suite run; planner re-verified diff scope, the 4 red supersessions against Appendix C, and ran the suite personally: 437/0) · merged `24cffb4` (squash, 2026-10-25). Green measurements: VAC-C101 spread 0.0 px · two-digit gaps 12 px (Δ0) · single-digit 27 px · slot voids 0 px · lengths 93/62/31/147/85/187.
- Approval: user confirmed 2026-10-25 after the Appendix C gap table was presented. The three approval items: (1) ~25 px gap in front of a single-digit value (idle GPU `0%`), (2) slot width 129 → 93 pt, (3) VoiceOver keeps announcing the true `100 percent` while the menu bar clips to `99%`.
- VACs: **VAC-C101…C110 below replace VAC-101…109 for T3.** ISC-3 parity and no-animation rules carry over.
- Supersession: this supersedes T2/S1 in the plan — `standardBlockWidth` is deleted, `blockWidth` becomes 27, length totals change to 93/62/31 (the old "Non-goals" lines about `blockWidth = 39` and 129/86/43 are superseded by Appendix C; `MenuBarLayout.gap = 4` and `padding = 2` remain untouched).
- Scope: `MetricFormatters.percent` (menu bar only — popover `percentTenth` and VoiceOver `wholePercent` untouched); `MenuBarBlockModel`; `MenuBarStackedItemView`; docs/comments. `StatusItemController` reads `length()` dynamically — no change (verified Appendix C §7.6).
- TDD: red authors failing tests only (compile-clean, no new production symbols referenced); green implements Appendix C §7.
- Risk class: R2 (UI text + layout + length contract change).

### T3 red-phase scope (must compile and fail at runtime on T2 code)

1. `MetricFormatterTests` → natural + clip contract: `percent(1.0) == "99%"`, `percent(1.5) == "99%"`, `percent(0) == "0%"`, `percent(0.144) == "14%"`, `percent(nil/.nan) == "--%"` (fails: T2 emits padded/`−−−%` strings).
2. `MenuBarBlockBuilderTests` → natural strings + `width == 27` expectations (fails: T2 pads and uses 34).
3. `MenuBarLayoutTests` → new totals 93/62/31/147/85/187 (fails: T2 returns 129/86/43/183/97/223).
4. `MenuBarRenderSnapshotTests`: VAC-C101 sweep fixtures → `"0%"`,`"5%"`,`"10%"`,`"50%"`,`"99%"`, `1.0`→`"99%"`, `nil`→`"--%"` with string-integrity assertion (fails on T2 formatter); VAC-C104 hand-built single-digit gap bound 23–27 px (fails: T2 frame 34 renders ~40 px for a hand-built `"0%"` block); VAC-C107 slot-fill void ≤ 1 px at `length()` slot (fails: T2 voids are ~15 px).
5. Typography pin → assert source line `.frame(width: block.width, alignment: .trailing)` (fails: T2 pins `standardBlockWidth` line).
- Tests whose bounds already pass on T2 (VAC-C102 two-digit [8,12] px with T2's padded fixture, VAC-C101 spread 0.0, VAC-C106/C109/C110) are written in red as guards but may pass — the red report must list which failed and which were guards, exactly like T2 did.

### Appendix C — Design Fix Blueprint (designer, 2026-10-25; copied verbatim)

# Appendix C: Design Fix Blueprint — Natural Values Clipped to 99% and Minimal Slot Geometry

## 1. Visual Hierarchy & ASCII Wireframe

This fix blueprint supersedes Task 2 (Solution S1) for this plan. It directly implements the user directive:
> *"no leading zeroes, and pls let's clip to 99, no need to show 100 corner case, and thus cut down the unnecessary spacing."*

Baseline: `artifacts/2026-10-24-temp-labels-cg/visual-vac/menubar-dark-v2.png` (2×). Verification: offscreen suite `StatsLiteTests/MenuBarRenderSnapshotTests.swift`.

### ASCII Wireframe (3 Standard Metrics at F = 27 pt)

```text
|<-------------------------------- NSStatusItem (93 pt = 186 px @ 2x) -------------------------------->|
| 2 pt |<------- CPU (27 pt) ------->| 4 pt |<------- MEM (27 pt) ------->| 4 pt |<------- GPU (27 pt) ------->| 2 pt |
+------+-----------------------------+------+-----------------------------+------+-----------------------------+------+
| Pad  |                  Text("CPU")| Gap  |       ●  4pt   Text("MEM")  | Gap  |                  Text("GPU")| Pad  |
| 2 pt |          8 pt reg secondary | 4 pt | 4pt dot + 2pt + 8 pt reg    | 4 pt |          8 pt reg secondary | 2 pt |
|      |               (width 17.32) |      |        (total width 25.36)  |      |               (width 17.56) |      |
|      |                 flush right |      |                 flush right |      |                 flush right |      |
+------+-----------------------------+------+-----------------------------+------+-----------------------------+------+
|      |                  Text("45%")|      |                  Text("99%")|      |                   Text("0%")|      |
|      | 12 pt reg monospacedDigit   |      | 12 pt reg monospacedDigit   |      | 12 pt reg monospacedDigit   |      |
|      |               (width 26.22) |      |               (width 26.22) |      |               (width 18.66) |      |
|      |                 flush right |      |                 flush right |      |                 flush right |      |
|      |          leading slack 0.78 |      |          leading slack 0.78 |      |          leading slack 8.34 |      |
+------+-----------------------------+------+-----------------------------+------+-----------------------------+------+
       |<-- visible gap: ~10-11 px ->|      |<-- visible gap: ~25-26 px ->|
```

### Key Spatial Relationships
1. **Outer Padding**: Pinned at 2.0 pt leading and 2.0 pt trailing (`MenuBarLayout.padding = 2`).
2. **Standard Block Frame (F)**: Fixed at **27.0 pt** (54 px at 2×). It replaces `blockWidth = 39` and retires `standardBlockWidth = 34`.
3. **Inter-Block Frame Spacing**: Fixed at **4.0 pt** (8 px at 2×, `MenuBarLayout.gap = 4`).
4. **Slot Fill**: 3 × 27 pt + 2 × 4 pt + 2 × 2 pt = **93.0 pt** (186 px at 2×). The block group matches the inner slot width (89 pt) edge-to-edge. Side voids drop from ~15 px to 0 px.

## 2. Template / Component Skeleton

### A. Layout Constants (`StatsLite/MenuBarBlockModel.swift:58-99`)

```swift
enum MenuBarLayout {
    /// Pinned width of standard metric blocks (CPU, MEM, GPU).
    /// Accommodates "99%" (26.22 pt) with 0.78 pt clearance,
    /// MEM's label row (25.36 pt) with 1.64 pt clearance,
    /// and "--%" (22.42 pt) with 4.58 pt clearance.
    static let blockWidth: CGFloat = 27

    static let networkBlockWidth: CGFloat = 50
    static let tempBlockWidth: CGFloat = 36
    static let rowHeight: CGFloat = 11
    static let valueYOffset: CGFloat = -1
    static let gap: CGFloat = 4
    static let padding: CGFloat = 2

    /// Total menu bar item length for enabled metrics.
    static func length(
        showCPU: Bool, showRAM: Bool, showGPU: Bool,
        showNetwork: Bool = false, showTemperature: Bool = false
    ) -> CGFloat {
        let metricCount = (showCPU ? 1 : 0) + (showRAM ? 1 : 0) + (showGPU ? 1 : 0)
        let totalBlocks = metricCount + (showNetwork ? 1 : 0) + (showTemperature ? 1 : 0)
        let metricLength = CGFloat(metricCount) * blockWidth
        let networkLength = showNetwork ? networkBlockWidth : 0
        let tempLength = showTemperature ? tempBlockWidth : 0
        let gapsLength = CGFloat(max(totalBlocks - 1, 0)) * gap
        return 2 * padding + metricLength + networkLength + tempLength + gapsLength
    }
}
```

### B. Menu Bar Value Formatter (`StatsLite/MetricFormatters.swift:15-19`)

```swift
/// Formats a fraction in 0...1 as an integer percent string.
/// Clamps values to 0...0.99 so the display clips to "99%".
/// Returns natural unpadded text ("0%", "5%", "45%", "99%").
/// Missing or non-finite values return "--%".
static func percent(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "--%" }
    let clamped = min(max(value, 0), 0.99)
    return "\(Int((clamped * 100).rounded()))%"
}
```

### C. Standard Block View (`StatsLite/MenuBarStackedItemView.swift:125-144`)

Same body as today; the sizing line becomes `.frame(width: block.width, alignment: .trailing)` (back to the block model field, which equals the new 27 pt constant through the builder).

### D. Root Container Skeleton

Keep `.frame(maxWidth: .infinity, alignment: .center)` — a no-op when group width equals slot inner width; it prevents edge clipping if AppKit rounds the host button width.

## 3. State Matrix: Geometry and Clearance (F = 27.0 pt)

| Element | Content | Measured Width | Clearance in 27.0 pt | Clearance at 2× |
|---|---|---|---|---|
| Max percent | `"99%"` | 26.22 pt | 0.78 pt | 1.56 px |
| Typical | `"45%"` | 26.22 pt | 0.78 pt | 1.56 px |
| Single digit | `"0%"`…`"9%"` | 18.66 pt | 8.34 pt | 16.68 px |
| Placeholder | `"--%"` | 22.42 pt | 4.58 pt | 9.15 px |
| MEM label row | 4 pt dot + 2 pt + `"MEM"` | 25.36 pt | 1.64 pt | 3.28 px |
| CPU label row | `"CPU"` | 17.32 pt | 9.68 pt | 19.37 px |
| GPU label row | `"GPU"` | 17.56 pt | 9.44 pt | 18.88 px |

### Visual Gap Mathematics at 2× (The Approval Artifact)

gap(N→N+1) = MenuBarLayout.gap + (F − contentW(N+1)) + bearings, where contentW = max(labelRowWidth, valueRowWidth); bearings ≈ 0.5–1.5 px per edge at 2×.

| Boundary | Next Block State | contentW | Frame Gap | Bitmap Ink Gap |
|---|---|---|---|---|
| CPU→MEM | MEM 2-digit (`10%`..`99%`) | 26.22 pt | 4.78 pt (9.56 px) | **10–11 px** |
| CPU→MEM | MEM 1-digit (`0%`..`9%`) | 25.36 pt (label floor) | 5.64 pt (11.28 px) | **12–13 px** |
| CPU→MEM | MEM `"--%"` | 25.36 pt (label floor) | 5.64 pt | **12–13 px** |
| MEM→GPU | GPU 2-digit | 26.22 pt | 4.78 pt (9.56 px) | **10–11 px** |
| MEM→GPU | GPU 1-digit | 18.66 pt | 12.34 pt (24.68 px) | **25–26 px** |
| MEM→GPU | GPU `"--%"` | 22.42 pt | 8.58 pt (17.15 px) | **18–19 px** |

Cross-boundary deltas: Active `45/50/32` → 10–11 / 10–11 (Δ0). Full load `99/99/99` → 10–11 / 10–11 (Δ0). Idle GPU `45/50/0` → 10–11 / 25–26 (Δ15 px). Low+idle `5/99/9` → 10–11 / 25–26 (Δ15 px). Cold `nil/nil/nil` → 12–13 / 18–19 (Δ6 px).

### Status Item Length Permutations (formula: 4 + n×27 + (n−1)×4 + extras)

| Configuration | New Total | Old Total | Reduction |
|---|---|---|---|
| 3 Standard | **93.0 pt** | 129.0 | −36.0 pt |
| 2 Standard | **62.0 pt** | 86.0 | −24.0 pt |
| 1 Standard | **31.0 pt** | 43.0 | −12.0 pt |
| 3 Standard + Network | **147.0 pt** | 183.0 | −36.0 pt |
| 1 Standard + Network | **85.0 pt** | 97.0 | −12.0 pt |
| All 5 Metrics | **187.0 pt** | 223.0 | −36.0 pt |
| Network only / Temp only / none | 54.0 / 40.0 / 4.0 | unchanged | 0 |

## 4. Accessibility (WCAG 2.2) & Interaction Contracts

- Contrast ≥ 4.5:1 both appearances; click target full status-bar thickness (22 pt), width 31–187 pt.
- **VoiceOver**: `MenuBarAccessibility.compositeLabel` uses `wholePercent(_:)` with the full 0...100 range — saturated load announces `"CPU 100 percent"`, not `"99 percent"`. Justification: visual clipping exists only to fit a 27 pt frame; speech occupies zero pixels; truncating speech misrepresents hardware saturation (WCAG 4.1.2/1.3.1).
- Popover cards keep `percentTenth` — real values including `"100.0%"`.

## 5. Numbered Visual Acceptance Checklist (VAC) — replaces VAC-101…109

- [ ] **VAC-C101 (Position Freezing Invariant)**: across sweep `0%`, `5%`, `10%`, `50%`, `99%`, `1.0` (formats `99%`), `nil` (`--%`): single-block frame width, composition x-origin, and trailing ink edge of CPU/MEM/GPU freeze with spread **0.0 px** at 2×.
- [ ] **VAC-C102 (Two-Digit Gap Uniformity & Minimality)**: when downstream blocks show 2-digit values, closest-approach ink gaps measure **8–12 px** at 2×, both appearances.
- [ ] **VAC-C103 (Cross-Boundary Uniformity, Same Digit Class)**: with all values 2-digit (e.g. `45/50/32`, all `99%`): |Δgap| ≤ **1 px** at 2×.
- [ ] **VAC-C104 (Single-Digit GPU Gap Floor)**: GPU single-digit (`0%`..`9%`): MEM→GPU gap measures **23–27 px** at 2×, both appearances.
- [ ] **VAC-C105 (Extreme Value Collision Safety)**: `99%` everywhere and `--%` everywhere: gap ≥ **7 px** at 2×, no ink merging.
- [ ] **VAC-C106 (Trailing Edge Alignment Flushness)**: line 1/line 2 right ink edges flush within **1 px** at 2×.
- [ ] **VAC-C107 (Slot-Fill Edge-to-Edge Geometry)**: production composition at slot width 93 pt: leftVoid ≤ 1 px and rightVoid ≤ 1 px at 2× (15 px side voids eliminated).
- [ ] **VAC-C108 (Status Item Length Contract)**: `MenuBarLayout.length` returns **93.0 / 62.0 / 31.0 / 147.0 / 187.0 pt** for the configurations in §3.
- [ ] **VAC-C109 (Discrete Transition Invariant)**: zero `.animation`/`.contentTransition` on the menu bar hierarchy.
- [ ] **VAC-C110 (Downstream Block Parity)**: GPU→TEMP and TEMP→NET gaps stay **21 ± 1 px** at 2× (ISC-3).

## 6. Affected Tests and Required Updates

1. `MetricFormatterTests`: missing/non-finite → `"--%"` (rename `…AsTripleMinus` → `…AsHyphens`); `percent(0)`→`"0%"`, `percent(1)`→`"99%"`, `0.144`→`"14%"`, `0.618`→`"62%"`; clamps: `−0.5`→`"0%"`, `1.5`→`"99%"`.
2. `MenuBarBlockBuilderTests`: line 18 `blockWidth` 39→27; line 102 `"020%"`→`"20%"`; 106/124/142 `"−−−%"`→`"--%"`; 110/117/137 `"100%"`→`"99%"`; 132 `"025%"`→`"25%"`; 326 `"062%"`→`"62%"`; 328 `width: 39`→`width: 27`.
3. `MenuBarLayoutTests`: rename/assert 129→93, 86→62 (×3), 43→31 (×3), 183→147, 97→85, 129→93 (network-off), 223→187.
4. `MenuBarValueTypographyTests`: line 424 widest value `"100%"`→`"99%"` (26.22 in 27 pt, 0.78 total clearance); line 470 `blockWidth` 39.0→27.0 (MEM clearance ≥ 1.5 pt); line 598 pin → `.frame(width: block.width, alignment: .trailing)`.
5. `MenuBarRenderSnapshotTests`: line 220 ISC-6 ceiling → `<= blockWidth * scale` (54 px); line 600 sweep fixtures → natural + clip; line 835 extremes → `("99%", 1.0…)` / `("--%", nil…)`; line 930 composition → slot 93 pt, leftVoid/rightVoid ≤ 1 px.

## 7. Exact Code Locations

1. `StatsLite/MetricFormatters.swift:15-19` — clamp 0...0.99, unpadded format, `"--%"`; doc comment lines 10–14.
2. `StatsLite/MenuBarBlockModel.swift:61-64` — `blockWidth = 27`; delete `standardBlockWidth`; doc comments.
3. `StatsLite/MenuBarStackedItemView.swift:142` — `.frame(width: MenuBarLayout.standardBlockWidth, alignment: .trailing)` → `.frame(width: block.width, alignment: .trailing)`.
4. `StatsLite/MenuBarStackedItemView.swift:1-25 & 110-116` — header + `MenuBarBlockView` doc: 27 pt frame, 99% clip contract; remove 39 pt/3-digit wording.
5. Plan Non-goals (this file): superseded per T3 header note.
6. `StatsLite/StatusItemController.swift:69 & 291` — verified read-only, zero changes.

## 8. Items Requiring Explicit User Approval Beyond Directive

1. ~25–26 px gap when GPU shows a single digit (idle state) — **APPROVED 2026-10-25**.
2. Menu bar slot width 129 → 93 pt — **APPROVED 2026-10-25**.
3. VoiceOver announces authentic metrics up to `"100 percent"` — **APPROVED 2026-10-25**.
