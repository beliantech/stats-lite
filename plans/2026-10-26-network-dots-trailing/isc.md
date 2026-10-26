# ISC — Menu Bar Network Block: Dots to the Trailing Edge

Risk class: R2. Every item is if/then/measurement/bound/kill/owner.

## ISC-1 — Row element order (source)

- **If** the production reorder in `MenuBarNetworkBlockView` lands, **then** both rows sequence `Text(` → `Spacer(minLength: 1)` → `Circle(` inside their `HStack` scopes, and the section comments `// Line 1: Upload rate` / `// Line 2: Download rate` remain.
- **Measurement:** new source test `testNetworkRowsSequenceTextBeforeDot` (`MenuBarValueTypographyTests.swift`, beside `:756`); VAC-12 row-frame test (`:895-920`) stays green as the comment guard.
- **Bound:** exact token order per row — no tolerance.
- **Kill condition:** any row still sequences `Circle` before `Text` → the green edit is incomplete; stop, do not relax the test.
- **Owner:** coder (green phase; red phase writes the test and it must fail on current production).

## ISC-2 — Rendered dot placement

- **If** the row reorder lands, **then** the offscreen render at 2× shows rate text at the leading edge and both dots in one column at the trailing edge of the 50 pt frame.
- **Measurement:** new render test `testNetworkDotsPinTrailingAndTextLeads` — per row × both appearances: (a) `leftmostInkX(row, 0..<90) ≤ 2` px (VAC-5); (b) `rightmostInkX(row, 0..<90) + 3 ≤ leftmostInkX(row, 90..<100)` px (VAC-3); (c) `rightmostInkX(row, 90..<100) ≥ 99` px (VAC-4); (d) `abs(x(red) − x(cyan)) ≤ 1` px (VAC-2).
- **Bound:** as above; dot band = columns 90..100 (45..50 pt at 2×).
- **Kill condition:** ISC-1 green but the dots do not land in 90..100 px → element order is not the sole determinant (plan.md Falsification H dead); stop, re-measure one variable at a time, do not add modifiers to force position.
- **Owner:** coder (red fails on current production: text is trailing, left edge ≥ 16 px, no gutter at the 90 px boundary).

## ISC-3 — Centroid optical alignment (retargeted)

- **If** the dots move to the trailing edge, **then** the centroid test's dot queries read the trailing dot band (`pixelsWide - 10 ..< pixelsWide`) and `|cy(C) − cy(red)| ≤ 0.30` px and `|cy(G) − cy(cyan)| ≤ 0.30` px hold under `.darkAqua` and `.aqua`.
- **Measurement:** `MenuBarRenderSnapshotTests.swift:391-460` (`leftmostClusterCentroidY`, harness helper `MenuBarRenderHarness.swift:174`), tolerance `centroidTolerance` (0.30 px).
- **Bound:** 0.30 px per pair, both appearances.
- **Kill condition:** retargeted query returns no dot ink (`XCTUnwrap` nil) → dot missing or not in the band; centroid delta > 0.30 px → vertical alignment changed (unexpected: no offset was added) — stop, do not tune with offsets.
- **Owner:** coder (red phase: retarget only; band queries fail or go vacuous on current production).

## ISC-4 — TEMP↔NET ink gap re-measurement

- **If** the leftmost NET ink changes from dot edge to glyph bearing, **then** MEM↔TEMP still measures 21 ± 1 px (untouched leg) and TEMP↔NET measures within 21..24 px (prediction 22 ± 2, `unverified prior` from glyph-bearing geometry).
- **Measurement:** `MenuBarRenderSnapshotTests.swift:474` (`testInterBlockInkGapsMeasureTwentyOnePixels`), constant `interBlockGap = 21` (`:47`); display awake under caffeinate.
- **Bound:** MEM↔TEMP keeps the shared `interBlockGap = 21 ± 1`. TEMP↔NET: measured value recorded in the ledger; split into its own constant (`tempNetInkGap`) set to the measurement, only if measured ≠ 21. Messages update from "red dot" to "rate text".
- **Kill condition / empirical correction:** measured outside 21..24 px → stop and re-derive the geometry (frame gap is pinned at 4 pt; something else moved). Two corrections max per constant, then escalate to the planner. Never widen the tolerance without a quoted measurement (Addendum B precedent).
- **Owner:** coder (green run measures; planner verifies the ledger before merge).

## ISC-5 — Pinned geometry, discrete transitions, scope

- **If** only row order changes, **then** width/height/length contracts, animation rules, and the popover scope hold unchanged.
- **Measurement:** `testRenderDimensionsMatchProductionGeometry` (`MenuBarRenderSnapshotTests.swift:283`), `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness` (`MenuBarValueTypographyTests.swift:784`), `MenuBarLayoutTests` length totals (93/62/31/147/54/85/187), `MenuBarRedrawChurnTests` green, `rg '\.animation\(|\.contentTransition\(' ` over the diff returns nothing, `git diff --stat` touches only `StatsLite/MenuBarStackedItemView.swift` + `StatsLiteTests/`, `NetworkCardView.swift` absent from the diff.
- **Bound:** exact values; binary absence checks.
- **Kill condition:** any total changes → a pinned constant leaked into the edit; revert. `NetworkCardView.swift` in the diff → scope leak, revert that hunk.
- **Owner:** coder (green), planner (verification run).

## ISC-6 — Verification artifacts

- **If** the change is complete, **then** the full suite passes twice under caffeinate and both captures exist.
- **Measurement:** two consecutive `caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test` runs exit 0; `artifacts/2026-10-26-network-dots-trailing/before/` and `after/` each contain dark + light strips plus `capture-note.txt`.
- **Bound:** 0 failures × 2 runs; after-strip shows dots right of rates (spot check).
- **Kill condition:** second run red → flaky or environment-sensitive (display asleep); fix environment first, no merge on a single green run.
- **Owner:** planner (T5).
