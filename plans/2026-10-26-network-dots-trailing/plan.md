# Menu Bar Network Block: Dots to the Trailing Edge

- Date: 2026-10-26
- Trigger: USER DIRECTIVE — "please move the red and blue dots of the networking to the right instead of current left"
- Phase: IMPLEMENTATION (R2 UI)
- Risk class: R2 — visible layout change inside the status item; zero logic, zero length change; offscreen render tests verify (repo precedents: `2026-10-25-menubar-item-gap-uniform-minimum`, `2026-10-26-menu-bar-gpu-mem-swap`).
- Design: 5-part blueprint from the designer (session 2026-10-26T02-00-41, verbatim in the Appendix). Blueprint is final; do not restructure it. Planner corrections are listed in "Blueprint integration corrections".
- Oracle matrix: not triggered (pure UI/UX directive → designer path).
- Reconnaissance: scout report (session 2026-10-26T01-31-30) plus planner first-hand verification of every test citation (session 2026-10-26).

## Context

### Current state (measured)

- The NET block rows sequence `[Circle 5 pt][Spacer(minLength: 1)][Text]` — `StatsLite/MenuBarStackedItemView.swift:189-215`. The spacer pushes each dot to the block's **leading** edge (`x = 0`) and the rate text flush **trailing** (`x = 50 pt`).
- Pinned geometry: `networkBlockWidth = 50` pt (`StatsLite/MenuBarBlockModel.swift:73`), `rowHeight = 11` pt (`:83`), `gap = 4` pt, `padding = 2` pt. All five metrics = 187 pt (`MenuBarLayout.length`).
- Downstream measurements owned by the dot position:
  - TEMP↔NET ink gap = 21 ± 1 px at 2× is measured **from the red dot's left edge** — `StatsLiteTests/MenuBarRenderSnapshotTests.swift:474` (`redDotLeft`, `:496`).
  - The centroid test reads the dot as the **leftmost cluster** of the NET region — `:391` (`leftmostClusterCentroidY` at `:417`, `:443`).
  - Network clearance arithmetic: "999 MB/s" = 42.1084 pt, total clearance 2.8916 pt ≥ 1.8 pt — `StatsLiteTests/MenuBarValueTypographyTests.swift:667-699`.

### Target state

- Both rows sequence `[Text][Spacer(minLength: 1)][Circle]`: rate text left-anchored at `x = 0`, both dots pinned to the trailing edge (`x = 45..50 pt`), forming one stable vertical column (same x for both rows, all tick rates).
- Unchanged: 50 pt frame, 11 pt rows, colors/tokens (`networkUpload`/`networkDownload`, 5 pt dot), 4 pt gap, all `MenuBarLayout.length` totals, discrete transitions (no `.animation`/`.contentTransition`), the VoiceOver composite label, the popover `NetworkCardView`.

## Blueprint integration corrections (planner, with evidence)

1. **Wireframes carry a stale block order.** Blueprint §1/§2 diagrams show `CPU | MEM | GPU | TEMP | NET`. Current main reads `CPU → GPU → MEM → TEMP → NET` (plan `2026-10-26-menu-bar-gpu-mem-swap`, merge `546870e`). Diagram-only; no code impact.
2. **Two blueprint test names do not exist.** §4/§5 cite `testBlockFittingDimensionsMatchLayoutConstants` (`:220`) and `testProductionBlocksRenderMinimumInkInBothAppearances` (`:285`) — planner `rg` finds neither. The real guards: `testEveryBlockRenderProducesInk` (`MenuBarRenderSnapshotTests.swift:219`), `testRenderDimensionsMatchProductionGeometry` (`:283`), `testInkFloorFiresOnBackgroundOnlyRender` (`:363`). The verification plan uses these names.
3. **Widest-string arithmetic uses the pinned numbers.** Blueprint §2 says 42.91 pt / 2.09 pt clearance; the pinned test measures 42.1084 pt / 2.8916 pt (`MenuBarValueTypographyTests.swift:669-699`). Use the pinned numbers. That test is order-agnostic (pure arithmetic) and stays unchanged.
4. **VAC-7 (21 px holds) is an `unverified prior`.** Leftmost NET ink switches from the dot edge (≈0 bearing) to the first glyph's left bearing (~1 px at 2×). Prediction: TEMP↔NET measures 22 ± 2 px, MEM↔TEMP stays 21 ± 1 px. Because `interBlockGap = 21` (`MenuBarRenderSnapshotTests.swift:47`) is **shared by both legs**, a diverging TEMP↔NET leg needs its own constant (e.g. `tempNetInkGap`) — never move the shared 21. Adjustment bound: measured value within 21..24 px, change only that constant plus its messages/comment, quote the measurement in the ledger; two attempts max, then escalate to the planner. Re-issue the VAC with the measured value (Addendum B precedent). Outside the bound = stop and re-derive; do not chase the number.
5. **Centroid retarget, concretized.** Narrow the dot queries' `xRange` to the trailing dot band — `pixelsWide - 10 ..< pixelsWide` (the dot occupies 45..50 pt = 90..100 px at 2×) — reusing the existing `leftmostClusterCentroidY` (`MenuBarRenderHarness.swift:174`). No harness change. Note: on current production that band can hold trailing rate text, so the retargeted test alone is **not** the red discriminator; the new tests in T2 are.
6. **Doc/comment contract.** Update the file header (`MenuBarStackedItemView.swift:14-17`, "networkUpload dot plus upload rate above networkDownload dot plus download rate") and the network view doc comment to rate-then-dot. Keep the section comments `// Line 1: Upload rate` / `// Line 2: Download rate` — VAC-12 locates the rows by those strings (`MenuBarValueTypographyTests.swift:895-920`); removing them breaks the suite for the wrong reason.
7. **Order-safe source tests, verified.** `fontToken(after: "Text(block.valueText)")` (`MenuBarValueTypographyTests.swift:524-531`) searches after the `Text` token — order-agnostic. `testNetworkBlockStackUsesZeroRowSpacing` (`:756`) and `testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum` (`:667`) do not depend on element order. None of them change.

## Steps

1. **Baseline capture (before the first code edit).** Display awake. Run `scripts/capture_menubar.sh`; copy outputs to `artifacts/2026-10-26-network-dots-trailing/before/` including `capture-note.txt`. Live captures are spot checks only (AGENTS.md); the offscreen render tests are the gate.
2. **Worktree.** `MAIN_REPO=/Users/jonathan/beliantech/stats-lite-macos`, `TASK_NAME=2026-10-26-network-dots-trailing`, `BRANCH=feat/2026-10-26-network-dots-trailing`, `WORKTREE_DIR=${MAIN_REPO}/worktrees/${TASK_NAME}`. Create with `git worktree add -B "${BRANCH}" "${WORKTREE_DIR}" main`. All code work happens there.
3. **Red phase — test edits only, production untouched** (full line list in `tasks.md` T2):
   - New source test `testNetworkRowsSequenceTextBeforeDot` (in `MenuBarValueTypographyTests.swift`, beside `testNetworkBlockStackUsesZeroRowSpacing`): within each network row's `HStack(` scope, `Text(` appears before `Circle(`. Precedent: existing source-scope tests (`:756`, `:887-920`).
   - New render test `testNetworkDotsPinTrailingAndTextLeads` (in `MenuBarRenderSnapshotTests.swift`, beside the centroid test): render `MenuBarNetworkBlockView(networkBlock())` standalone plus a widest fixture (`MenuBarBlock(valueText: "999 MB/s", secondaryValueText: "999 MB/s", …)` pattern from `MenuBarValueTypographyTests.swift:795-806`); for each row band (`line1`/`line2`) × both appearances:
     a. leading anchor — `leftmostInkX(row, 0..<90) ≤ 2` px;
     b. gutter — `rightmostInkX(row, 0..<90) + 3 ≤ leftmostInkX(row, 90..<100)` px (text strictly left of dot);
     c. trailing dot — `rightmostInkX(row, 90..<100) ≥ 99` px (`pixelsWide - 1` at 2×);
     d. column — `abs(leftmostInkX(line1, 90..<100) - leftmostInkX(line2, 90..<100)) ≤ 1` px.
     On current production a/b/broadly fail (text is trailing: left edge ≥ 16 px; no gutter at 90..100 boundary) — that is the red.
   - Retarget `testTempLabelCentroidsAlignWithNetworkDotCentroids` (`:391-460`): both dot queries narrow `xRange` to `pixelsWide - 10 ..< pixelsWide` per correction 5; ISC-2/VAC-16/17 messages stay.
   - Do **not** touch `interBlockGap` (correction 4; measured in step 5).
   - Run the suite under `caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test`. Record the failing set; it must be exactly the two new tests plus (possibly) the retargeted centroid test. Any other red test = stop condition (report, do not fix blind). Diff must show `StatsLiteTests/` only.
4. **Green phase — production edits (one file only):**
   - `StatsLite/MenuBarStackedItemView.swift`: reorder both `MenuBarNetworkBlockView` rows to `Text → Spacer(minLength: 1) → Circle` (`:189-215`); update the network view doc comment and the file header (`:14-17`) to rate-then-dot; keep `// Line 1: Upload rate` / `// Line 2: Download rate` comments, keep `.frame(height: MenuBarLayout.rowHeight)` on both rows, keep `.frame(width: block.width)` on the block. No `.animation`, no `.contentTransition`, no vertical offsets, no token edits.
   - No other production file changes (`git diff --stat` must show this one file).
5. **Band confirmation (ISC-4).** Rerun the suite (display awake, caffeinate). If `testInterBlockInkGapsMeasureTwentyOnePixels` fails on the TEMP↔NET leg: record the measured px in the ledger, split the leg into its own constant (`tempNetInkGap`) keeping `interBlockGap = 21` for MEM↔TEMP, set it to the measured value within 21..24 px, update the "red dot" messages to "rate text" (they are wrong after the move regardless). Beyond the bound or a second failure = stop and escalate (correction 4).
6. **Full suite green ×2** in the worktree under `caffeinate`. Runner exit 0, zero failures, both runs.
7. **After capture.** Re-run `scripts/capture_menubar.sh`; copy to `artifacts/2026-10-26-network-dots-trailing/after/`. Compare with `before/`: dots now at the right of both NET rows, rates at the left. Spot check only (AGENTS.md).
8. **Commit** in the worktree as one commit: `feat(menubar): move network status dots to trailing edge` (conventional commit per the git-commit skill). Then hand to the reviewer.

## Visual Acceptance Checklist (VAC)

Mapped 1:1 to `isc.md`. Numbering below is the gate checklist; the designer's blueprint in the Appendix carries its own VAC-1..10 (same content, same measurements).

- **VAC-1** (row order, source): both network rows sequence `Text` → `Spacer(minLength: 1)` → `Circle`. New source test. `[ISC-1]`
- **VAC-2** (dot column): at 2×, both dots share one x column — `|x(red) − x(cyan)| ≤ 1` px, both rows, both appearances. New render test. `[ISC-2]`
- **VAC-3** (right-of-text): at 2×, per row `rightmostInkX(0..<90) + 3 ≤ leftmostInkX(90..<100)` — text strictly left of the dot with ≥ 3 px gutter. New render test. `[ISC-2]`
- **VAC-4** (trailing pin): dot rightmost ink `≥ 99` px (`pixelsWide − 1`, i.e. within 1 px of the 50 pt edge). New render test. `[ISC-2]`
- **VAC-5** (leading anchor): rate text leftmost ink `≤ 2` px in `0..<90`. New render test. `[ISC-2]`
- **VAC-6** (centroid alignment): retargeted `testTempLabelCentroidsAlignWithNetworkDotCentroids` — `|cy(C) − cy(red)| ≤ 0.30` px and `|cy(G) − cy(cyan)| ≤ 0.30` px, both appearances, dot band query. `[ISC-3]`
- **VAC-7** (ink gap): MEM↔TEMP stays 21 ± 1 px (untouched leg); TEMP↔NET measured and re-issued within 21..24 px per correction 4 — value quoted from the run, not assumed. `[ISC-4]`
- **VAC-8** (pinned geometry): network fitting size 50.0 × 22.0 pt (`testRenderDimensionsMatchProductionGeometry:283`, `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness` `MenuBarValueTypographyTests.swift:784`); `MenuBarLayout.length` totals unchanged (`MenuBarLayoutTests`). `[ISC-5]`
- **VAC-9** (discrete): no `.animation` / `.contentTransition` in the diff; `MenuBarRedrawChurnTests` green. `[ISC-5]`
- **VAC-10** (scope): `StatsLite/NetworkCardView.swift` untouched (`git diff --stat`); popover legend dots stay left. `[ISC-5]`
- **VAC-11** (suite + captures): full suite green ×2 under caffeinate; `before/` and `after/` captures exist with note; after strip shows dots right of rates. `[ISC-6]`

## Falsification

- **H:** element order inside the two `HStack`s is the sole determinant of dot placement; frame geometry, spacers, and tokens already produce the target x positions once the order flips.
- **Test:** after the reorder (single production file, single construct change), VAC-2..5 all go green at the predicted coordinates (dot 90..100 px, text ≤ 2 px).
- **Kill condition:** if the order is correct (VAC-1 green) but the dots do not land at 90..100 px — H is dead: some other layout term pins the position (frame alignment, a modifier outside the rows). Stop, re-measure with a two-variable attribution (toggle one row only), do not add modifiers to force the position.
- One variable per round: red changes only tests; green changes only row order + doc comments; the ink-gap constant (if it moves at all) is its own later round with its own measurement.

## Non-goals

- No change to `MenuBarLayout.networkBlockWidth` (50), `blockWidth` (27), `tempBlockWidth` (36), `gap` (4), `padding` (2), `rowHeight` (11), `length(...)`, or any length total.
- No color, token, typography, tint, or vertical-offset changes; the 5 pt dot size and its centering stay as-is.
- No popover changes (`NetworkCardView.swift` legend untouched).
- No accessibility-label change (`MenuBarAccessibility.compositeLabel` is value-derived; verify, do not edit).
- No `MenuBarRenderHarness` change (correction 5 reuses the existing helper).

---

## Appendix — Design Blueprint (verbatim, from the designer session)

# 5-Part Design Blueprint: Network Block Status Dot Placement

This document specifies the design to move the status dots in `MenuBarNetworkBlockView` from the left edge of each row to the right edge.

---

## 1. Visual Hierarchy & Current State

### Visual Evidence
Visual reference is anchored in the verified menu bar baseline captures:
- Dark appearance: `artifacts/2026-10-24-temp-labels-cg/visual-vac/menubar-dark-v2.png`
- Light appearance: `artifacts/2026-10-24-temp-labels-cg/visual-vac/menubar-light-v2.png`
- Environmental capture diagnostic note: `artifacts/2026-10-26-menu-bar-gpu-mem-swap/before/capture-note.txt`

### Current Layout (Code Citations)
The menu bar network monitor block is declared in `StatsLite/MenuBarStackedItemView.swift:183-218`. The block contains two rows inside a `VStack(alignment: .leading, spacing: 0)`:
- Line 1 (Upload): `HStack(alignment: .center, spacing: 0)` (`StatsLite/MenuBarStackedItemView.swift:189`)
  1. `Circle().fill(Color.networkUpload).frame(width: CGFloat.networkDotSize, height: CGFloat.networkDotSize)` (`StatsLite/MenuBarStackedItemView.swift:191-192`)
  2. `Spacer(minLength: 1)` (`StatsLite/MenuBarStackedItemView.swift:194`)
  3. `Text(block.valueText)...` (`StatsLite/MenuBarStackedItemView.swift:196-200`)
- Line 2 (Download): `HStack(alignment: .center, spacing: 0)` (`StatsLite/MenuBarStackedItemView.swift:204`)
  1. `Circle().fill(Color.networkDownload).frame(width: CGFloat.networkDotSize, height: CGFloat.networkDotSize)` (`StatsLite/MenuBarStackedItemView.swift:206-207`)
  2. `Spacer(minLength: 1)` (`StatsLite/MenuBarStackedItemView.swift:209`)
  3. `Text(block.secondaryValueText ?? "-- KB/s")...` (`StatsLite/MenuBarStackedItemView.swift:211-215`)

Both rows are constrained by `.frame(height: MenuBarLayout.rowHeight)` (`StatsLite/MenuBarStackedItemView.swift:201, 216`), where `MenuBarLayout.rowHeight = 11` pt (`StatsLite/MenuBarBlockModel.swift:83`). The block root frame pins width to `block.width` (`StatsLite/MenuBarStackedItemView.swift:218`), which resolves to `MenuBarLayout.networkBlockWidth = 50` pt (`StatsLite/MenuBarBlockModel.swift:73`).

### Current Spatial Hierarchy (ASCII Wireframe)

```
+-------------------------------------------------------------------------+
| NSStatusItem (Total length = MenuBarLayout.length)                      |
| Horizontal outer padding: 2 pt leading, 2 pt trailing                   |
| Inter-block gap: 4 pt                                                   |
+---------+---------+---------+-----------+-------------------------------+
|   CPU   |   MEM   |   GPU   |   TEMP    |   NET (50 pt frame width)     |
| (27 pt) | (27 pt) | (27 pt) |  (36 pt)  |                               |
+---------+---------+---------+-----------+-------------------------------+
|   CPU   |  * MEM  |   GPU   |  C  51°   | (R) [Spacer]          15 KB/s | <- Line 1
|   0%    |   16%   |   23%   |  G  39°   | (C) [Spacer]          21 KB/s | <- Line 2
+---------+---------+---------+-----------+-------------------------------+
                                            |---|                        |
                                           x=0 pt                      x=50 pt
                                        (dots pinned                (text pushed
                                          to left)                    to right)
```

In the current layout, the `Spacer` pushes the 5 pt red and cyan dots to the left boundary of the network block (`x = 0 pt`). The rate text is pushed to the right boundary (`x = 50 pt`).

---

## 2. Target State & Component Skeleton

### Layout Decisions

1. **Dot Placement Relative to Rate Text (Trailing Edge Pinning)**:
   The dots must pin to the trailing edge of the 50 pt block frame.
   - Text sits on the left (`x = 0 pt`).
   - A flexible `Spacer(minLength: 1)` sits in the middle.
   - The indicator dot sits on the far right (`x = 45 pt` to `x = 50 pt`).

   *Design Justification*:
   - If dots were placed immediately after the rate text (`Text -> fixed gap -> Dot`), the dot X position would change on every tick when network speed digits change. For example, "0 B/s" (25 pt) versus "120 KB/s" (38 pt) would cause the dots to jump back and forth horizontally. The upload and download dots would also misalign horizontally with each other whenever upload and download string lengths differ.
   - Pinning the dots to the right edge guarantees that both dots share the exact same X coordinate (`x = 47.5 pt` center). They form a stable vertical column.
   - Left-aligning the rate text anchors the start of the text at `x = 0 pt`. The ink gap between the preceding TEMP block and the NET block remains stable and does not jitter across ticks.

2. **Vertical Optical Alignment**:
   The 5 pt dot must remain vertically centered in the 11 pt row via `HStack(alignment: .center)` without any vertical offset (`offset(y: 0)` / omit `offset`).
   - Row height = 11 pt (`StatsLite/MenuBarBlockModel.swift:83`).
   - Dot diameter = 5 pt (`StatsLite/DesignTokens.swift:80`).
   - In an 11 pt row, a 5 pt circle in `HStack(alignment: .center)` has 3 pt top margin and 3 pt bottom margin. Its center sits at `y = 5.5 pt` (11.0 px at 2x Retina).
   - In `StatsLiteTests/MenuBarRenderSnapshotTests.swift:391-460`, `testTempLabelCentroidsAlignWithNetworkDotCentroids` asserts that the TEMP label vertical centroids align with the network dot vertical centroids within 0.30 px at 2x. The TEMP labels ("C" and "G") were calibrated to match this unshifted 5.5 pt dot center. Adding an `offset(y: -0.5)` would break centroid alignment.

3. **Frame Width and Trailing Clearance**:
   - Pinned width: 50 pt (`MenuBarLayout.networkBlockWidth`).
   - Widest rate text: "999 MB/s" measures 42.91 pt (`StatsLite/MenuBarBlockModel.swift:71-73`).
   - 42.91 pt text + 5.0 pt dot = 47.91 pt.
   - The 50 pt frame leaves 2.09 pt clearance in the worst case, satisfying `Spacer(minLength: 1)`.
   - The status item container applies 2 pt outer horizontal padding (`MenuBarLayout.padding`, `StatsLite/MenuBarStackedItemView.swift:56`), which provides trailing clearance from the status item boundary.

### Target Spatial Hierarchy (ASCII Wireframe)

```
+-------------------------------------------------------------------------+
| NSStatusItem (Total length = MenuBarLayout.length)                      |
| Horizontal outer padding: 2 pt leading, 2 pt trailing                   |
| Inter-block gap: 4 pt                                                   |
+---------+---------+---------+-----------+-------------------------------+
|   CPU   |   MEM   |   GPU   |   TEMP    |   NET (50 pt frame width)     |
| (27 pt) | (27 pt) | (27 pt) |  (36 pt)  |                               |
+---------+---------+---------+-----------+-------------------------------+
|   CPU   |  * MEM  |   GPU   |  C  51°   | 15 KB/s         [Spacer]  (R) | <- Line 1
|   0%    |   16%   |   23%   |  G  39°   | 21 KB/s         [Spacer]  (C) | <- Line 2
+---------+---------+---------+-----------+-------------------------------+
                                            |                            |
                                           x=0 pt                      x=50 pt
                                        (text anchored              (dots pinned
                                          to left)                    to right)
```

### Component Skeleton (`MenuBarNetworkBlockView`)

```swift
/// Dedicated two-line network speed monitor block:
/// line 1 carries the upload rate text followed by a 5 pt red indicator
/// dot (Color.networkUpload) pinned to the trailing edge.
/// line 2 carries the download rate text followed by a 5 pt adaptive indicator
/// dot (Color.networkDownload: systemCyan in dark mode, systemBlue in light)
/// pinned to the trailing edge.
/// Width pins to block.width (50 pt), so rate string changes never resize
/// the item (VAC-N1). Transitions stay discrete: no .animation and no
/// .contentTransition modifiers (VAC-9).
struct MenuBarNetworkBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Line 1: Upload rate
            HStack(alignment: .center, spacing: 0) {
                Text(block.valueText)
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)

                Spacer(minLength: 1)

                Circle()
                    .fill(Color.networkUpload)
                    .frame(width: CGFloat.networkDotSize, height: CGFloat.networkDotSize)
            }
            .frame(height: MenuBarLayout.rowHeight)

            // Line 2: Download rate
            HStack(alignment: .center, spacing: 0) {
                Text(block.secondaryValueText ?? "-- KB/s")
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(secondaryValueColor)
                    .lineLimit(1)

                Spacer(minLength: 1)

                Circle()
                    .fill(Color.networkDownload)
                    .frame(width: CGFloat.networkDotSize, height: CGFloat.networkDotSize)
            }
            .frame(height: MenuBarLayout.rowHeight)
        }
        .frame(width: block.width)
    }

    private var valueColor: Color {
        switch block.valueTint {
        case .primary, .warning, .critical:
            Color.primary
        case .tertiary:
            Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var secondaryValueColor: Color {
        switch block.secondaryValueTint ?? block.valueTint {
        case .primary, .warning, .critical:
            Color.primary
        case .tertiary:
            Color(nsColor: .tertiaryLabelColor)
        }
    }
}
```

---

## 3. Complete State & Responsive Matrix

The menu bar is an AppKit status item rendered at fixed menu bar height (22 pt). It does not use responsive breakpoints. It renders across appearances and monitor states.

| State / Condition | Upload Row (Line 1) | Download Row (Line 2) | Frame Dimensions | Visual Invariant |
| --- | --- | --- | --- | --- |
| **Normal Traffic (Dark Appearance)** | White rate text (e.g. `15 KB/s`) at left, red dot (`Color.networkUpload`) at right | White rate text (e.g. `21 KB/s`) at left, cyan dot (`systemCyan`) at right | 50 pt x 22 pt | Dots align vertically at `x = 45..50 pt`; text starts at `x = 0 pt` |
| **Normal Traffic (Light Appearance)** | Black rate text at left, red dot (`Color.networkUpload`) at right | Black rate text at left, blue dot (`systemBlue`) at right | 50 pt x 22 pt | `Color.networkDownload` switches adaptively; dot position unchanged |
| **Zero Traffic (`0 B/s`)** | `0 B/s` text at left, red dot at right | `0 B/s` text at left, cyan/blue dot at right | 50 pt x 22 pt | Text stays left-anchored; spacer absorbs 20 pt slack; dots do not jump |
| **High Traffic (`999 MB/s`)** | `999 MB/s` text at left, red dot at right | `999 MB/s` text at left, cyan/blue dot at right | 50 pt x 22 pt | 2.09 pt clearance between text and dot; zero clipping; no frame expansion |
| **Missing / Unread Rates** | `-- KB/s` in tertiary color at left, red dot at right | `-- KB/s` in tertiary color at left, cyan/blue dot at right | 50 pt x 22 pt | Both dots remain visible and rendered; text renders tertiary |
| **Appearance Transition** | Discrete color update | Discrete color update | 50 pt x 22 pt | No `.animation` or `.contentTransition`; discrete rasterization |

---

## 4. Constraints & Scope Boundary

### Constraints
1. **Design System & Typography (`DESIGN.md`, `StatsLite/DesignTokens.swift`)**:
   - Indicator dot tokens: `Color.networkUpload` (systemRed), `Color.networkDownload` (adaptive systemCyan on dark, systemBlue on light) (`StatsLite/DesignTokens.swift:71-76`).
   - Indicator dot diameter: `CGFloat.networkDotSize = 5` pt (`StatsLite/DesignTokens.swift:80`).
   - Rate typography: 9 pt regular monospaced-digit (`StatsLite/MenuBarStackedItemView.swift:197, 212`).
2. **Never-Resize Invariant & Status Item Length**:
   - Pinned block width: `MenuBarLayout.networkBlockWidth = 50` pt (`StatsLite/MenuBarBlockModel.swift:73`).
   - Pinned row height: `MenuBarLayout.rowHeight = 11` pt (`StatsLite/MenuBarBlockModel.swift:83`).
   - Total status item length formula in `MenuBarLayout.length` (`StatsLite/MenuBarBlockModel.swift:97-118`) sums pinned constants and must remain invariant across rate changes.
3. **Discrete Transition Rule (`AGENTS.md`)**:
   - Status item views must not use `.animation` or `.contentTransition` modifiers. Transitions stay discrete.
4. **Render Test Invariant Shifts (`StatsLiteTests/MenuBarRenderSnapshotTests.swift`)**:
   - `testBlockFittingDimensionsMatchLayoutConstants` (line 220): fitting size must remain 50 pt x 22 pt.
   - `testProductionBlocksRenderMinimumInkInBothAppearances` (line 285): ink count must remain >= 100 px.
   - `testInterBlockInkGapsMeasureTwentyOnePixels` (lines 470-525): measures ink between TEMP and NET. When the red dot moves to the right, the leftmost ink of NET becomes the rate text glyph (e.g. "1" in "10 KB/s"). Because `Text` begins at `x = 0 pt` (the exact position where the red dot previously began), the TEMP->NET ink gap remains 21 ± 1 px at 2x.
   - `testTempLabelCentroidsAlignWithNetworkDotCentroids` (lines 391-460): currently calls `bitmap.leftmostClusterCentroidY` on the network region. With the dots moved to the right, the red and cyan dots are the rightmost ink cluster in the network region. The test must inspect the dot cluster at the trailing edge of the network columns. The vertical centroid difference `|cy(label) - cy(dot)| <= 0.30 px` must continue to pass.
5. **Zero-Tolerance Visual Policy**:
   - Misaligned dots, clipped text, or frame width drift are blocking defects.

### Scope Boundary
- **Menu Bar View**: `StatsLite/MenuBarStackedItemView.swift` (`MenuBarNetworkBlockView`, lines 183-218) is the ONLY target of this change.
- **Popover Network Card**: `StatsLite/NetworkCardView.swift:96-114` contains a legend row with `Up:` and `Down:` bullet markers. That legend belongs to the popover sparkline chart and is OUT OF SCOPE. Do not modify `NetworkCardView.swift`.
- **Block Model & Layout Constants**: `StatsLite/MenuBarBlockModel.swift` remains untouched.

---

## 5. Accessibility & Verification Plan

### Accessibility (WCAG 2.2)
- **Status Item Accessibility**: The menu bar stacked item view declares `.accessibilityHidden(true)` (`StatsLite/MenuBarStackedItemView.swift:57`). Accessibility is announced by the parent `NSStatusBarButton` via `MenuBarAccessibility.compositeLabel` (`StatsLite/MenuBarAccessibility.swift:52`). The visual move of the dots does not change the composite label: `"Network Upload <rate>, Download <rate>"` remains identical.
- **Color Contrast**: Both dot tokens satisfy WCAG 2.2 graphical component contrast (>= 3:1):
  - Red dot (`systemRed`): contrast ratio > 4.5:1 against dark menu bar and light menu bar.
  - Download dot (`systemCyan` in dark mode, `systemBlue` in light mode): contrast ratio > 3.5:1 against respective backgrounds.

### Verification Plan
1. **Offscreen Render Tests (`StatsLiteTests/MenuBarRenderSnapshotTests.swift`)**:
   - `testBlockFittingDimensionsMatchLayoutConstants`: verify network block fitting size remains 50 pt wide and 22 pt high.
   - `testProductionBlocksRenderMinimumInkInBothAppearances`: verify network block renders >= 100 ink pixels in dark and light appearance.
   - `testInterBlockInkGapsMeasureTwentyOnePixels`: verify the ink gap between line 1 TEMP value right ink and line 1 NET rate text left ink measures 21 ± 1 px at 2x.
   - `testTempLabelCentroidsAlignWithNetworkDotCentroids`: update test fixture query to locate the dot cluster on the right edge of the NET column band. Verify `abs(cyC - cyRedDot) <= 0.30 px` and `abs(cyG - cyCyanDot) <= 0.30 px`.
   - **New Assertion**: Add an explicit check in `MenuBarRenderSnapshotTests` asserting that in `MenuBarNetworkBlockView`, the rate text rightmost ink X is strictly less than the indicator dot leftmost ink X on both rows, and the dot rightmost ink reaches the block's trailing edge within 1 px at 2x.
2. **Typography Structure Tests (`StatsLiteTests/MenuBarValueTypographyTests.swift`)**:
   - `testNetworkBlockStackUsesZeroRowSpacing`: verify `VStack(alignment: .leading, spacing: 0)` declaration passes.
   - `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness`: verify fitting height remains 22.0 pt.
   - `testRowFramesUseRowHeightConstantInBothBlocks`: verify both upload and download rows retain `.frame(height: MenuBarLayout.rowHeight)`.
3. **Live Screen-Capture Spot Check**:
   - Run `scripts/capture_menubar.sh` with the screen awake and unlocked as an end-to-end sanity check (acknowledging that if TCC screen recording permission is denied on macOS 27, offscreen tests remain the authoritative gate per `AGENTS.md`).

---

## Numbered Visual Acceptance Checklist (VAC)

- **VAC-1 (Row Element Order)**: In `MenuBarNetworkBlockView`, line 1 must sequence rate `Text` before `Spacer(minLength: 1)` before `Circle()`, and line 2 must sequence secondary rate `Text` before `Spacer(minLength: 1)` before `Circle()`.
- **VAC-2 (Dot Horizontal Column Alignment)**: On an offscreen render of `MenuBarNetworkBlockView` at 2x, the red upload dot and cyan/blue download dot must share the identical horizontal bounding box: `leftmostInkX(uploadDot) == leftmostInkX(downloadDot)` within 0.5 px.
- **VAC-3 (Dot Right-of-Text Ordering)**: On an offscreen render at 2x, the rightmost ink pixel of line 1 rate text must be strictly less than the leftmost ink pixel of the red dot, and the rightmost ink pixel of line 2 rate text must be strictly less than the leftmost ink pixel of the download dot.
- **VAC-4 (Trailing Boundary Position)**: On an offscreen render of `MenuBarNetworkBlockView` at 2x, the rightmost ink of both indicator dots must land within 1 px of the 50 pt block trailing edge (`100 ± 1 px` in the 2x bitmap).
- **VAC-5 (Leading Text Anchor)**: On an offscreen render of `MenuBarNetworkBlockView` at 2x, the leftmost ink of line 1 rate text and line 2 rate text must start at the leading edge of the block (`0..2 px` in the 2x bitmap).
- **VAC-6 (Centroid Optical Line Alignment)**: In `MenuBarRenderSnapshotTests.testTempLabelCentroidsAlignWithNetworkDotCentroids`, the vertical centroids must satisfy `abs(cyC - cyRedDot) <= 0.30 px` and `abs(cyG - cyCyanDot) <= 0.30 px` under both `.darkAqua` and `.aqua` appearances.
- **VAC-7 (Inter-Block Ink Gap Invariant)**: In `MenuBarRenderSnapshotTests.testInterBlockInkGapsMeasureTwentyOnePixels`, the ink gap between TEMP line 1 right ink and NET line 1 left ink must measure `21 ± 1 px` at 2x under both appearances.
- **VAC-8 (Pinned Dimensions Invariant)**: `MenuBarNetworkBlockView` fitting size must measure exactly `50.0 pt` width and `22.0 pt` height.
- **VAC-9 (No Animation Modifiers)**: `MenuBarNetworkBlockView` must not declare `.animation` or `.contentTransition`.
- **VAC-10 (Scope Boundary Isolation)**: `StatsLite/NetworkCardView.swift` must remain completely unmodified. Status dots in the popover card legend remain on the left of their labels.
