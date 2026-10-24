# Appendix Fix Blueprint: TEMP Block Optical Alignment + Inter-Block Gap

Two measured defects on the current main build, reported with screenshot
`/var/folders/2r/gfzr0pms3bb5cyshql2g22900000gn/T/herdr-clipboard-images-501/client-110-clipboard-1792806467826153000-0.png`
(602×134, 2× crop; rows 22 px = 11 pt apart):

1. "the C and G doesn't look aligned with the red and blue dots"
2. "why the huge gap between temp and network"

## Part 1 — Vertical optical droop (Item 1)

### Attribution (pixel centroids, 2× px)
| Element | Ink centroid y |
|---|---|
| red upload dot | 46.50 |
| CPU/MEM/GPU labels, `45°` | 46.29–46.62 |
| **`C` label** | **47.47** (droops) |
| blue download dot | 68.52 |
| `32°` | 68.36 |
| **`G` label** | **69.56** (droops) |

Root cause (Rank 1): `StatsLite/MenuBarStackedItemView.swift:233,245` —
`HStack(alignment: .firstTextBaseline, spacing: 2)` locks the 8 pt label to
the 9 pt value baseline (8.90 pt), so the label center sits 6.08 pt vs the
dot center at 5.50 pt in an 11 pt row: **+0.58 pt droop** (+0.90 pt at the
bottom edge).

Rank 2 (contextual, fixed in Part 2): `.frame(width: block.width)` at
`MenuBarStackedItemView.swift:252` has no alignment modifier → SwiftUI
centers the ~24.26 pt content in the 50 pt box → ~12.87 pt dead space each
side.

### Fix
Add `.offset(y: -0.5)` to both label `Text` views in `MenuBarTempBlockView`
(lines 236, 248). Post-fix residual vs dots: ≤0.02 pt.

### Guards
- Existing pins untouched: `MenuBarValueTypographyTests.swift:500-514`
  (8 pt regular secondary), `:635-645` (22.0 pt fitting height),
  `:650-705` (rowHeight), `MenuBarTempBlockTests.swift:398-422` (no
  `.animation`/`.contentTransition`).
- New: `testTempBlockLabelsApplyVerticalOpticalOffset()` in
  `MenuBarValueTypographyTests.swift` — source-scope assert both labels
  carry `.offset(y:-0.5)`.

### VAC (Part 1)
- **VAC-16**: line 1 `C` carries `.offset(y: -0.5)`; ink centroid aligns
  with red dot center within ±0.15 pt, 1× and 2×.
- **VAC-17**: line 2 `G` carries `.offset(y: -0.5)`; ink centroid aligns
  with blue dot center within ±0.15 pt, 1× and 2×.
- **VAC-18**: top ink edge of `C`/`G` aligns with top ink edge of
  CPU/MEM/GPU labels within ±0.20 pt, light and dark.
- **VAC-19**: zero `.animation` / `.contentTransition` in
  `MenuBarTempBlockView`.
- **VAC-20**: fitting height exactly 22.0 pt; width pinned;
  `0°`↔`130°`↔`--°` transitions produce zero horizontal jitter.

## Part 2 — TEMP↔NET gap (Item 2)

### Attribution
`tempBlockWidth = 50 pt` (`MenuBarBlockModel.swift:66-73`) with centered
~24.26 pt content → ~13 pt trailing dead space; NET content fills its 50 pt
box (dots flush leading via leading edge, rates flush trailing via
`Spacer(minLength: 1)`), so the void reads as one ~16.87 pt gap between
`45°` and the red dot.

Right-align inside the 50 pt box is **rejected**: the void would move to the
GPU↔TEMP boundary (~30 pt gap before `C`).

### Fix — width arithmetic
- Widest row `G 130°` = 6.18 (`G`, 8 pt) + 2.00 + 21.92 (`130°`, 9 pt mono)
  = **30.10 pt**.
- Clearance rule ≥ 2.50 pt/side (`MenuBarBlockModel.swift:58-60`):
  30.10 + 2×2.50 = 35.10 → smallest integer **36 pt**
  (35 pt would give 2.45 pt — violation). At 36 pt: 2.95 pt/side worst case.
- Typical row (`C 45°`, 24.26 pt): clearance 5.87 pt/side; gap to red dot =
  5.87 + 4.00 (inter-block) = **9.87 pt** (was 16.87 pt); symmetric on the
  GPU side.
- Total status-item length with all five metrics: 237.0 pt → **223.0 pt**.

### Blast radius
- Edit `MenuBarLayout.tempBlockWidth` 50 → 36 and its doc comment
  (`MenuBarBlockModel.swift:66-73`).
- Consumers are dynamic — no code edits: `MenuBarLayout.length`
  (`MenuBarBlockModel.swift:98-112`), builder `width:` (`:184-198`),
  view `.frame(width: block.width)`.
- Tests: add `testTempBlockWidthIsPinnedTo36()` and
  `testAllFiveMetricsTotal223()` in `MenuBarLayoutTests.swift`; update the
  50 pt failure-message string in `MenuBarTempBlockTests.swift:311-325` if
  present. Symbolic tests pass unchanged:
  `MenuBarTempBlockTests.swift:240-275`,
  `MenuBarTempVerificationTests.swift:340-355, 200-230`.

### VAC (Part 2)
- **VAC-21**: `tempBlockWidth == 36` exactly.
- **VAC-22**: TEMP-value-ink to red-dot gap = 9.87 ±0.30 pt (19.7±0.6 px @2×).
- **VAC-23**: GPU-value-ink to `C` gap = 9.87 ±0.30 pt (symmetric clearance).
- **VAC-24**: `C 130°`/`G 130°` fit 36 pt with ≥2.50 pt/side (2.95 actual);
  no clip/wrap/truncate.
- **VAC-25**: readings `0°`/`45°`/`100°`/`130°`/`--°` keep frame at 36.0 pt;
  neighboring blocks show zero jitter, light and dark.

## Execution — two independent commits (one variable per round)

1. `fix(menubar): apply -0.5pt optical vertical offset to TEMP subsystem
   labels` — `MenuBarStackedItemView.swift` only; verify with
   `MenuBarValueTypographyTests` + dot-alignment measurement.
2. `fix(menubar): shrink tempBlockWidth to 36pt to tighten inter-block gap`
   — `MenuBarBlockModel.swift` + `MenuBarLayoutTests.swift`; verify with
   layout/temp test classes + gap measurement from a capture.

### VERDICT: READY
