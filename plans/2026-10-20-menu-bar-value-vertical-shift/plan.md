# Plan: Menu bar value line vertical shift

- Date: 2026-10-20
- Status: GREEN (T1 d1c708a, T2 7c0fcee); designer VAC verification pending
- User request: "hey the menubar gap to the bottom of the menubar is too small, can we shift up the bottom values a bit (reducing the gap between label and value)"
- Branch: `feat/2026-10-20-menu-bar-value-vertical-shift`
- Plan review round 1: NO GO → fixes applied (ISC section, VAC measurement correction,
  red-phase staging, Tasks section)

## Problem

Each stacked metric block fills the full 22 pt status bar thickness (`rowHeight` 11 × 2 rows,
no vertical padding, hosting view pinned to `button.bounds`). The 12 pt value line therefore
sits ~0.96 pt from the bottom edge of the menu bar — the user reads this as too little gap.
Fix: shift the value line up 1 pt, which opens the bottom gap and tightens the label-to-value
gap, per the blueprint below.

## ISC

### Hypothesis and Falsification
- **Question**: Can shifting the standard metric value line up by 1 pt increase the bottom
  gap and tighten the label-to-value gap without clipping or breaking layout invariants?
- **Hypothesis**: The 12 pt monospaced value centered in an 11 pt frame sits at baseline
  y = 21.04 pt, leaving a 0.96 pt gap to the 22.00 pt menu bar bottom. Setting
  `MenuBarLayout.valueYOffset = -1` moves the baseline to y = 20.04 pt: bottom gap
  0.96 → 1.96 pt, optical gap 4.43 → 3.43 pt, baseline aligns with the network download
  baseline within 0.14 pt.
- **One Variable**: single layout token `MenuBarLayout.valueYOffset = -1` applied to
  `Text(block.valueText)` in `MenuBarBlockView`. Row height stays 11 pt. Fonts stay
  7 pt / 12 pt. Fitting height stays 22.00 pt.
- **Falsification Signature**: if `valueYOffset` is applied, then (1) baseline 21.04 →
  20.04 pt (±0.05), (2) bottom gap 0.96 → 1.96 pt (±0.05), (3) optical gap 4.43 →
  3.43 pt (±0.05), (4) standard vs. network download baselines within 0.14 pt
  (±0.05). If fitting height ≠ 22.00 pt or glyph ink leaves [0.00, 22.00] pt, the
  hypothesis is falsified and the change stops.

### Binary Acceptance Criteria
- [ ] **IC-1 (VAC-1)** — `MenuBarLayout.valueYOffset` declared as
      `static let valueYOffset: CGFloat = -1` in `StatsLite/MenuBarBlockModel.swift`.
- [ ] **IC-2 (VAC-2)** — `MenuBarBlockView` applies
      `.offset(y: MenuBarLayout.valueYOffset)` to `Text(block.valueText)`.
- [ ] **IC-3 (VAC-3…VAC-7, VAC-11)** — new test `testValueBaselineOffsetAndGeometryInvariants`
      in `StatsLiteTests/MenuBarValueTypographyTests.swift` passes: baseline 20.04 pt,
      bottom gap 1.96 pt, optical gap 3.43 pt, top gap 3.21 > bottom gap 1.96, ink
      [11.58, 20.04] inside row 2 with zero clipping, network alignment within 0.14 pt.
- [ ] **IC-4 (VAC-8)** — fitting heights remain 22.00 pt in
      `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness` (preserved, unmodified).
- [ ] **IC-5 (VAC-9)** — all four row containers keep `.frame(height: MenuBarLayout.rowHeight)`,
      `rowHeight = 11`, in `testRowFramesUseRowHeightConstantInBothBlocks` (unmodified).
- [ ] **IC-6 (VAC-10)** — both stacks keep `spacing: 0` (zero-spacing guards unmodified).
- [ ] **IC-7** — no `.animation`/`.contentTransition` on the status item path;
      `MenuBarRedrawChurnTests` passes.
- [ ] **IC-8** — red phase: suite compiles cleanly, only the new assertions fail. Green
      phase: 0 failures, no tests deleted.

## Design Blueprint (from `designer`, verbatim)

Visual Evidence Pass: Display capture probe `screencapture -x` failed with code 1
(`could not create image from display`). The environment is headless macOS without a
WindowServer display connection. Geometry is code-inferred and verified through live
AppKit/SwiftUI font metrics and test suite runs. `DESIGN.md` is absent at the repository
root. Tokens ground in `MenuBarLayout` and `MenuBarStackedItemView.swift`.

### 1. Visual Hierarchy & ASCII Wireframe
```text
+--- Status Bar Thickness = 22.0 pt -----------------------------------+
| [y=0.00] Top edge of menu bar                                        |
|   | 3.21 pt top gap (to label cap top)                               |
| [y=3.21] Label cap top ("CPU" @ 7 pt regular)                        |
| [y=8.15] Label baseline                                              |
|   | 3.43 pt optical gap (was 4.43 pt, reduced by 1.00 pt)            |
| [y=11.00] Row boundary (Row 1 frame [0, 11], Row 2 frame [11, 22])   |
| [y=11.58] Value cap top ("100%" @ 12 pt mono, shifted up 1.00 pt)   |
| [y=20.04] Value baseline (shifted up 1.00 pt from natural y=21.04)   |
|   | 1.96 pt bottom gap (was 0.96 pt, increased by 1.00 pt)           |
| [y=22.00] Bottom edge of menu bar                                    |
+----------------------------------------------------------------------+
```

### 2. Component Skeleton & Implementation Scope
```swift
// StatsLite/MenuBarBlockModel.swift: enum MenuBarLayout
static let valueYOffset: CGFloat = -1

// StatsLite/MenuBarStackedItemView.swift: MenuBarBlockView
VStack(alignment: .center, spacing: 0) {
    HStack(alignment: .center, spacing: 2) {
        if let dotState = block.dotState {
            Circle().fill(dotState.levelColor).frame(width: 4, height: 4).offset(y: -0.5)
        }
        Text(block.label).font(.system(size: 7, weight: .regular)).foregroundStyle(.secondary)
    }
    .frame(height: MenuBarLayout.rowHeight)
    Text(block.valueText)
        .font(.system(size: 12, weight: .regular).monospacedDigit())
        .foregroundStyle(valueColor)
        .lineLimit(1)
        .frame(height: MenuBarLayout.rowHeight)
        .offset(y: MenuBarLayout.valueYOffset)
}
.frame(width: block.width)
```
- Scope: `StatsLite/MenuBarBlockModel.swift`, `StatsLite/MenuBarStackedItemView.swift`,
  `StatsLiteTests/MenuBarValueTypographyTests.swift` (new assertions only).
- Preserved unmodified: VAC-11 (fitting height 22.0 pt), VAC-12 (rowHeight 11 + frame
  tokens), zero-spacing guards, redraw-churn tests.

### 3. State & Responsive Matrix
- Fixed geometry: 22.0 pt height, `blockWidth` 39, `networkBlockWidth` 50. No scaling.
- Tint states (normal/warning/critical/tertiary) change color only; offset invariant.
- Network block: needs no offset. Row 1 upload baseline 8.90 pt, row 2 download baseline
  19.90 pt; after the standard-value shift the baselines align within 0.14 pt.

### 4. Accessibility, Non-Goals & Risk
- Non-goals: no `.animation`/`.contentTransition`; no font size changes; no width changes;
  no `rowHeight` change (stays 11).
- Accessibility: VoiceOver labels, traits, contrast unchanged.
- Risk/clipping: 12 pt digit cap height 8.46 pt; shifted ink occupies [11.58, 20.04] pt —
  0.58 pt below the row boundary, 1.96 pt above the bottom edge. No clipping. Fitting
  height stays 22.00 pt = `NSStatusBar.system.thickness`.

### 5. Visual Acceptance Checklist (VAC)
- VAC-1: `MenuBarLayout.valueYOffset` declared as `static let valueYOffset: CGFloat = -1`
  in `StatsLite/MenuBarBlockModel.swift`.
- VAC-2: `MenuBarBlockView` applies `.offset(y: MenuBarLayout.valueYOffset)` to the value `Text`.
- VAC-3: Value baseline shifts from y = 21.04 pt to y = 20.04 pt (exact 1.00 pt upward).
- VAC-4: Bottom gap increases from 0.96 pt to 1.96 pt within the 22.00 pt thickness.
- VAC-5: Label-to-value optical gap reduces from 4.43 pt to 3.43 pt.
- VAC-6: Top gap (3.21 pt) exceeds bottom gap (1.96 pt).
- VAC-7: Value glyph ink [11.58, 20.04] pt stays within row 2 bounds, no clipping.
- VAC-8: Standard and network fitting heights remain exactly 22.00 pt (VAC-11 preserved).
- VAC-9: All four row containers keep `.frame(height: MenuBarLayout.rowHeight)`,
  `rowHeight = 11` (VAC-12 preserved).
- VAC-10: Both block stacks keep `spacing: 0`.
- VAC-11: Standard value baseline (20.04 pt) and network download baseline (19.90 pt)
  align within 0.14 pt.

VAC-1, VAC-2, VAC-8, VAC-9, VAC-10 are source-token and fitting-height assertions.
VAC-3…VAC-7 and VAC-11 are computed font-metric geometry assertions implemented with
AppKit `NSFont` metrics (NOT the fitting-height test: `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness`
at `MenuBarValueTypographyTests.swift:484-530` measures only
`NSHostingView.fittingSize.height` — it exposes no baselines or subview geometry).

Baseline formula for single-line text centered in a `rowHeight` row:

```text
rowTop         = rowIndex * MenuBarLayout.rowHeight          // row 0: 0, row 1: 11
rowCenter      = rowTop + rowHeight / 2                     // row 0: 5.5, row 1: 16.5
naturalBaseline = rowCenter + (font.ascender + font.descender) / 2
shiftedBaseline = naturalBaseline + valueYOffset
capTop         = shiftedBaseline - font.capHeight
bottomGap      = 22.0 - shiftedBaseline
opticalGap     = valueCapTop - labelBaseline
```

Verified metrics (unverified prior until the coder's test asserts them): 12 pt mono
ascender 11.6016 / descender -2.5312 / capHeight 8.4551; 9 pt mono 8.7012 / -1.8984 /
6.3413; 7 pt system 6.7676 / -1.4766 / 4.9321. Plugging in: label baseline 8.1455,
capTop 3.2134 (top gap 3.21); natural value baseline 21.0352 (bottom gap 0.9648);
shifted 20.0352 (VAC-3), value capTop 11.5801, bottomGap 1.9648 (VAC-4), opticalGap
3.4346 (VAC-5), topGap > bottomGap (VAC-6), ink [11.58, 20.04] within row 2 (VAC-7);
network download baseline 19.9014, delta 0.1338 (VAC-11). Tolerance ±0.05 pt.

## Evidence (captured during implementation)

- Branch `feat/2026-10-20-menu-bar-value-vertical-shift`, worktree
  `worktrees/2026-10-20-menu-bar-value-vertical-shift`.

- Test command:
  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild test \
    -project StatsLite.xcodeproj \
    -scheme StatsLite \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath .derivedData \
    CODE_SIGN_IDENTITY="-"
  ```
- Red run (commit d1c708a): suite compiled clean; `Executed 244 tests, with 8 failures`
  (0 unexpected) — all 8 in the three new tests (VAC-3 21.0352≠20.04, VAC-4 0.9648≠1.96,
  VAC-5 4.4346≠3.43, VAC-7 capTop 12.5801≠11.58, VAC-11 delta 1.1338≠0.14, plus token/
  modifier asserts). Zero pre-existing tests failed.
- Green run (commit 7c0fcee): exit 0, ** TEST SUCCEEDED ** —
  `Executed 244 tests, with 0 failures (0 unexpected)`.
- Font metrics independently verified by the coder with an AppKit script before authoring
  tests: match the plan's values to 4 decimals (metrics now verified, no longer prior).

### Red-phase compile-safe staging order

1. Production stub: add `static let valueYOffset: CGFloat = 0` to `MenuBarLayout`
   (no `.offset` in the view yet), so test code compiles.
2. Red tests in `MenuBarValueTypographyTests.swift`:
   `testValueYOffsetConstantIsMinusOne` (asserts -1, fails vs. stub 0),
   `testMenuBarBlockViewAppliesValueYOffsetModifier` (source-string assert on the
   `.offset(y: MenuBarLayout.valueYOffset)` token in `MenuBarBlockView`, fails while
   absent), `testValueBaselineOffsetAndGeometryInvariants` (fails: offset 0 computes
   baseline 21.04 / gap 0.96).
3. Red run: compile clean, only new assertions fail.
4. Green: set stub to `-1`, add `.offset(y: MenuBarLayout.valueYOffset)` to the value
   `Text` in `MenuBarBlockView`.
5. Green run: 0 failures.
- Note: the environment is headless (no WindowServer), so no menu bar screenshot is
  possible; geometry evidence comes from the test-measured baselines.

## Verification

Designer verifies the green run output against every VAC item and reports GO/NO-GO.
Tester is not required: this is a status item geometry change with no browser/web surface,
and all visual acceptance is encoded as source/computed assertions.

## Tasks

- [ ] **T1 — worktree + red commit**: create worktree
      `worktrees/2026-10-20-menu-bar-value-vertical-shift` on branch
      `feat/2026-10-20-menu-bar-value-vertical-shift`. Add the `valueYOffset = 0` stub
      and the red tests. Record the red run.
      Commit: `test(menubar): add failing tests for value line vertical shift (-1 pt)`
- [ ] **T2 — green commit**: set `valueYOffset = -1`, add `.offset(y:)`. Green run, 0
      failures. Commit: `fix(menubar): shift value line up 1 pt to increase bottom gap`
- [ ] **T3 — evidence**: fill red/green counts and verified metric values into this
      plan's Evidence section.
      Commit: `docs(plan): record verification evidence for menu bar value vertical shift`
- [ ] **T4 — merge**: `git merge --ff-only` (or `--squash`) into `main`, remove worktree
      and branch. Report merge commit SHA.

## Risks

- Small (1 pt) visual change; the risk of regression is mostly in the test guards — the
  plan touches only two source files plus additive test assertions.
- Clipping checked in blueprint §4: none (ink [11.58, 20.04] inside 22 pt).
