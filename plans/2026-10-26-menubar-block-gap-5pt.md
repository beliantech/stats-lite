# Menubar Inter-Block Gap: 4 pt → 5 pt

**Date**: 2026-10-26 · **Risk**: R1 (UI pixel change, measured VAC ripples) · **Branch**: `menubar-gap-5pt`

## Problem

The user wants more breathing room between the metric blocks in the menu bar status
item: the gap between CPU↔GPU and GPU↔MEM grows from 4 pt to 5 pt. The gap is one
design token, `MenuBarLayout.gap`, applied uniformly to every adjacent block pair
(invariant from plan 2026-10-25-menubar-item-gap-uniform-minimum). The token change
therefore moves all block boundaries and widens the item by 1 pt per active gap.

## ISC

- If `MenuBarLayout.gap` becomes `5`, then `MenuBarLayout.length(showCPU: true,
  showRAM: true, showGPU: true, showNetwork: true, showTemperature: true)` moves from
  `187` to `191`, because 4 active gaps each add 1 pt.
- If the token becomes `5`, then the VAC-A closest-approach ink gap at 2× moves from
  the `[8, 12]` px band to `[10, 14]` px, because the frame gap grows 8 px → 10 px and
  the glyph bearings are unchanged.
- If any ink-gap band does not move as predicted, the mechanical model is wrong and
  the task stops for re-measurement before any band value is committed.

## Design Blueprint (designer, 2026-10-26, session 2026-10-26T07-52-40)

Full blueprint in the designer session above. Key points:

**Tokens** (`StatsLite/MenuBarBlockModel.swift:92`): `static let gap: CGFloat = 5`.

**Length matrix** (formula `2×padding + ΣblockWidths + (blocks−1)×gap`):

| Configuration | Old | New |
|---|:---:|:---:|
| All metrics off | 4.0 pt | 4.0 pt |
| One standard metric | 31.0 pt | 31.0 pt |
| Two standard metrics | 62.0 pt | 63.0 pt |
| CPU + Network | 85.0 pt | 86.0 pt |
| Three standard metrics | 93.0 pt | 95.0 pt |
| 3 standard + Network | 147.0 pt | 150.0 pt |
| All five metrics | 187.0 pt | **191.0 pt** |

**Pixel band ripples** (all at 2×, in `StatsLiteTests/MenuBarRenderSnapshotTests.swift`):

| Constant | Old | New | Class |
|---|:---:|:---:|---|
| `minimalGapFloor` | 8 | 10 | mechanical (+2 px) |
| `minimalGapCeiling` | 12 | 14 | mechanical |
| `singleDigitGapFloor` / `Ceiling` | 23 / 27 | 25 / 29 | mechanical |
| `extremeGapFloor` / `Ceiling` | 7 / 27 | 9 / 29 | mechanical |
| MEM↔TEMP `interBlockGap` | 21 ±1 | 23 ±1 | re-measure |
| TEMP↔NET `tempNetInkGap` | 24 ±1 | 26 ±1 | re-measure |
| `coldCpuGpuGapFloor` / `Ceiling` | 17 / 20 | 19 / 22 | mechanical |
| `coldGpuMemGapFloor` / `Ceiling` | 11 / 14 | 13 / 16 | mechanical |
| `gapUniformityTolerance`, slot-void bounds | — | unchanged | invariant |

**Constraints**: no `.animation` or `.contentTransition` in the status item hierarchy;
offscreen `MenuBarRenderHarness` renders are the only verification (no live capture).

## VACs

1. `MenuBarLayout.gap == 5`.
2. VAC-A two-digit closest-approach ink gap in `[10, 14]` px at 2×, both appearances.
3. Gap uniformity `|CPU→GPU − GPU→MEM| ≤ 1` px.
4. Single-digit GPU band `[25, 29]` px.
5. Extreme values (`99%`, `--%`): gap `≥ 9` px and `≤ 29` px, no ink merge.
6. MEM↔TEMP ink gap `23 ±1` px; TEMP↔NET `26 ±1` px.
7. All-five-metrics length `191` pt; 3-standard length `95` pt.
8. Cold-fixture bands `[19, 22]` and `[13, 16]` px; slot voids `≤ 1` px.

## Tasks

- **T1 [coder+worktree]** Token change and measured test updates, red/green:
  - Red: update `MenuBarLayoutTests` length expectations (187 → 191, etc.) and the
    render-snapshot band constants to the blueprint targets; run the suite, confirm
    the gap-token and length tests fail against the old token.
  - Green: set `MenuBarLayout.gap = 5` in `StatsLite/MenuBarBlockModel.swift`; fix
    the token doc comment. Re-measure MEM↔TEMP and TEMP↔NET ink gaps from the harness
    output; adjust those two bands to the measured values (blueprint predicts 24 px
    and 26 px). Update stale "4 pt gap"/"8 px token" comments.
  - `rg 'gap|MenuBarLayout.gap' --glob '*.swift'` for any remaining hard-coded 4/8.
  - Add the DESIGN.md line: uniform inter-block spacing 5 pt (`MenuBarLayout.gap`).
  - `xcodebuild test` full suite green.
- **T2 [reviewer]** Review the diff against this plan + DESIGN.md; confirm every VAC
  is asserted by a test and the render bands match the measured harness output.

## Falsification / Stop Rules

- If a band moves by more than the predicted +2 px, do not tune the constant to make
  the test pass. Record the measurement, revert, and report back.
- If the item fails `testStackedItemCompositionFillsSlotEdgeToEdge` (slot fill is exact
  at 95 pt = 190 px), stop and report the measured slot width.

## Risks

- R1: menu bar visual change; wider item may affect users with many status items.
  Max growth is +4 pt (five metrics on).
- Ink-gap bands are bearing-sensitive; the re-measured MEM↔TEMP and TEMP↔NET values
  must come from the harness run, not from the blueprint's predictions.

## Receipts

- **Plan review**: GO (session 2026-10-26T08-11-57, reviewer).
- **Red phase**: 9 failures / 440 passed against old token (length totals +
  TEMP↔NET leg). Widened floor/ceiling bands cannot fail red by construction;
  the token and length tests carried the red.
- **Green measurements** (both appearances identical): MEM↔TEMP 24 px (old-token
  render 22 px, +2 px mechanical), TEMP↔NET 26 px (old 24 px, +2 px). Bands set
  to the measured values ±1. No band moved more than +2 px; no STOP hit.
- **Green suite**: 449 tests, 0 failures (xcodebuild, macOS destination).
- **Review**: GO (session 2026-10-26T08-38-19, reviewer; VAC-1..VAC-12 verified
  against the diff, no leftover gap literals).
- **Merge**: fast-forward to main, merge commit `7b849c6`.

## Out of scope

- No change to block widths, fonts, padding, or valueYOffset.
- No live screen capture; no popover or settings work.
