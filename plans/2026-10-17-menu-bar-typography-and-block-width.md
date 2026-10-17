# Plan: Menu bar block typography — label 8→7 pt, value 11→12 pt, blockWidth 34→39 pt

Date: 2026-10-17
Plan name: `2026-10-17-menu-bar-typography-and-block-width`
Risk class: **R2** (UI work — zero-tolerance visual policy applies; visual defects are blocking).
Status: authored 2026-10-17. Awaiting user confirmation, then `[plan-review]`.
Repo HEAD at authoring: `1e906e3`, clean (untracked `.DS_Store`, `worktrees/`, artifacts only).
Baseline suite: **241 tests, 0 failures** at `1e906e3` (run at authoring,
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test`).
Screenshot waiver: carried over (user authority, plan `2026-10-16-menu-bar-regular-weight`) —
`screencapture -x` probe re-run at authoring fails with `could not create image from display`
(exit 1). All screenshot and menu-bar-strip captures stay waived; visual checks are
check-only from test evidence.
Worktree: `<repo>/worktrees/2026-10-17-menu-bar-typography-and-block-width`, branch
`feat/2026-10-17-menu-bar-typography-and-block-width` (non-base). main may advance in
parallel — rebase before the ff-only merge if needed.

## Intent

The user wants the menu bar status item blocks retyped (user scope ruling 2026-10-17:
menu bar items only, popover metric cards out of scope):

1. Category label reduced by 1 pt: 8 pt → 7 pt.
2. Gap between label and value reduced — see the scope ruling below.
3. Metric value increased by 1 pt: 11 pt → 12 pt.

Current state (verified at `1e906e3`):
- `StatsLite/MenuBarStackedItemView.swift:112` — label `Text(block.label)` renders
  `.font(.system(size: 8, weight: .regular))` with `.foregroundStyle(.secondary)`.
- `StatsLite/MenuBarStackedItemView.swift:117` — value `Text(block.valueText)` renders
  `.font(.system(size: 11, weight: .regular).monospacedDigit())`.
- `StatsLite/MenuBarBlockModel.swift:56` — `MenuBarLayout.blockWidth = 34`.
- `MenuBarBlockView` is `VStack(alignment: .center, spacing: 0)` of two rows pinned to
  `MenuBarLayout.rowHeight = 11` (`MenuBarStackedItemView.swift:103`,
  `MenuBarBlockModel.swift:62`).

Target state:
- `:112` renders `.font(.system(size: 7, weight: .regular))`; `:117` renders
  `.font(.system(size: 12, weight: .regular).monospacedDigit())`.
- `MenuBarBlockModel.swift:56` — `MenuBarLayout.blockWidth = 39`, so the widest value
  `"100%"` at 12 pt regular mono (live AppKit measurement 33.7793 pt) keeps ≥ 2.5 pt
  clearance per side (5.2207 pt total, 2.61 pt per side).
- `MenuBarLayout.rowHeight` stays 11, `networkBlockWidth` stays 50, network rate fonts
  stay 9 pt regular mono (`:155`, `:170`), the block `VStack` keeps `spacing: 0`.
  Block heights stay 22 pt (2 × 11 = `NSStatusBar.system.thickness`).

**Gap ruling (user decision 2026-10-17, option A):** the label→value rows are
`spacing: 0` with both rows pinned to 11 pt, so no spacing constant exists to reduce.
The user chose the font swap only: the 7 pt label and 12 pt value tighten the optical
gap by ~0.3 pt. No glyph offsets, no row-height changes, no alignment tricks. Any
offset edit is scope creep and fails IC-13.

The first designer blueprint (popover metric cards) was invalidated by the user's scope
correction and applies to nothing. The authoritative blueprint is archived at
`plans/2026-10-17-menu-bar-typography-and-block-width/blueprint.md` and embedded below.

## Evidence

- Designer measurements (live AppKit `NSFont`, not priors): `"100%"` at 12 pt regular
  mono = 33.7793 pt (line height 15.0, cap 8.4551). Clearance table: 34 pt → 0.11 pt
  per side (fail), 36 pt → 1.11 (fail), 38 pt → 2.11 (fail), **39 pt → 2.61 (pass)**,
  40 pt → 3.11 (pass). The ≥ 2.5 pt-per-side rule is inherited from the repo's
  clearance guard tradition (`MenuBarValueTypographyTests`).
- Labels at 7 pt regular: CPU 15.3057, GPU 15.5210, MEM 17.0933; MEM row
  (4 pt dot + 2 pt gap + text) 23.0933 → 15.9067 pt clearance in a 39 pt block.
- Network unchanged: `"999 MB/s"` at 9 pt regular mono 42.1084 + 6 pt dot leaves
  1.8916 pt for `Spacer(minLength: 1)` in the pinned 50 pt block.
- Row height: 2 × 11 pt = 22 pt = `NSStatusBar.system.thickness`; 12 pt digits
  (cap 8.4551) fit an 11 pt row. `rowHeight` must not grow.
- Test suite 241/241 at `1e906e3` (run at authoring). The suite pins the current state:
  `MenuBarValueTypographyTests.swift:35` (`size:11` value literal), `:37` (`size:8`
  label literal), guards at `:179`, `:218`, `:253`, `:301`, `:338`;
  `MenuBarLayoutTests.swift` pins 114/76/38/168/92/54/4 lengths;
  `MenuBarBlockBuilderTests.swift:19` pins `blockWidth = 34`.
- Designer appendix line numbers for `MenuBarValueTypographyTests` are stale (it cites
  `:28/:30/:146…`); the verified lines above are authoritative. Coders locate guards by
  method name, not line number.
- Band-aid scan at authoring: `rg 'TODO|FIXME|HACK'` over
  `MenuBarStackedItemView.swift`, `MenuBarBlockModel.swift`,
  `MenuBarValueTypographyTests.swift` — no hits. No refactor debt in scope.
- No `DESIGN.md` or `ARCHITECTURE.md` at the repo root (designer verified 2026-10-17).

## ISC — binary checks (every item is yes/no)

> **Screenshot waiver (user authority, carried over):** menu bar strip captures, popover
> captures, and visual blend inspection are SKIPPED — the authoring-session probe
> `screencapture -x` exits 1 (`could not create image from display`). Visual ICs get a
> `waived` row in the ledger. Test-based ICs stay binding.

Citation rule: a bare `:N` means `StatsLite/MenuBarStackedItemView.swift:N`.
Widths: 768 px is the reference width; all geometry is pinned, so layout claims measured
from tests hold at 375 px and 1440 px too (check-only). Each IC ends with a `Widths:` line.

- [ ] **IC-1 (VAC-1, label 7 pt)** — `:112` renders
      `.font(.system(size: 7, weight: .regular))`; guard
      `testLabelFontIsSevenPointRegularSecondary` **fails at red** while `:112` reads
      `size: 8`, and passes at green. Falsification: fail → pass only when `:112` flips.
      Widths: 768 reference; 375/1440 check-only.
- [ ] **IC-2 (VAC-2, value 12 pt)** — `:117` renders
      `.font(.system(size: 12, weight: .regular).monospacedDigit())`; guard
      `testValueFontIsTwelvePointRegularMonospacedDigit` **fails at red** and passes at
      green. `.monospacedDigit()` guard `testValueFontKeepsMonospacedDigit` stays green.
      Widths: 768 reference; 375/1440 check-only.
- [ ] **IC-3 (VAC-3, block width 39)** — `MenuBarLayout.blockWidth` equals `39`
      (`MenuBarBlockModel.swift:56`); standard blocks render at 39.0 pt width.
      Widths: 768 reference; 375/1440 check-only.
- [ ] **IC-4 (VAC-4, widest-value clearance ≥ 2.5 pt per side)** — guard
      `testClearanceForWidestValueAtTwelvePointRegularMeetsTwoAndAHalfPointPerSideRule`:
      `"100%"` at 12 pt regular mono measures 33.7793 pt (±0.05) inside the 39 pt block
      → total clearance 5.2207 pt (±0.05) ≥ 5.0, per-side ≥ 2.5, zero truncation.
      Fails at red (blockWidth is still 34). Widths: 768 reference; 375/1440 check-only.
- [ ] **IC-5 (VAC-5, label-row clearance at 7 pt in 39 pt)** — guard
      `testLabelRowClearanceForMemRowAtSevenPointInThirtyNinePointBlock`: MEM row
      4.0 dot + 2.0 gap + `width("MEM" @ 7 pt)` 17.0933 = 23.0933 → clearance 15.9067 pt
      (±0.05, ≥ 3.5); CPU ≥ 23.0 (23.6943), GPU ≥ 23.0 (23.4790). No label truncates on
      one line. Fails at red. Widths: 768 reference; 375/1440 check-only.
- [ ] **IC-6 (VAC-6, network block retained)** — `networkBlockWidth` stays 50
      (`MenuBarBlockModel.swift:59`); `"999 MB/s"` at 9 pt regular mono plus the 6.0 pt
      dot leaves ≥ 1.8 pt for `Spacer(minLength: 1)` (guard
      `testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum` stays green).
      Widths: 768 reference; 375/1440 check-only.
- [ ] **IC-7 (VAC-7, row height retained)** — `MenuBarLayout.rowHeight` stays `11`
      (`MenuBarBlockModel.swift:62`); both row containers in both block views keep
      `.frame(height: MenuBarLayout.rowHeight)` (guard
      `testRowFramesUseRowHeightConstantInBothBlocks` stays green).
      Widths: 768 reference; 375/1440 check-only.
- [ ] **IC-8 (VAC-8, 22 pt fitting height)** — both block types fit exactly 22.0 pt,
      matching `NSStatusBar.system.thickness` (guard
      `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness` stays green).
      Widths: all.
- [ ] **IC-9 (VAC-9, zero stack spacing)** — both block `VStack`s keep `spacing: 0`
      (guards `testMetricBlockStackUsesZeroVerticalSpacing`,
      `testNetworkBlockStackUsesZeroRowSpacing` stay green). No offset, no alignment
      change, no row-height change anywhere in the block views (gap ruling, option A).
      Widths: all.
- [ ] **IC-10 (VAC-10, pinned lengths)** — `MenuBarLayout.length` yields: all four
      metrics 183, three standards 129, any pair 86, one standard + network 97, single
      standard 43, network only 54, all off 4. The 10 updated length tests
      (`MenuBarLayoutTests.swift`) **fail at red** (blockWidth still 34) and pass at green.
      Widths: 768 reference; 375/1440 check-only.
- [ ] **IC-11 (VAC-11, zero animation)** — `rg -n '\.animation|\.contentTransition'`
      over `MenuBarStackedItemView.swift` and `MenuBarBlockModel.swift` finds only the
      comment hits; `MenuBarRedrawChurnTests` passes. Widths: all.
- [ ] **IC-12 (suite)** — the red run executes 241 tests and fails **only** on the
      updated guards: the label guard (IC-1), the value guard (IC-2), the network
      value-size guard (`testNetworkFontsAreNinePointRegularAndValueStaysSizeTwelve`),
      both clearance guards (IC-4, IC-5), the 10 layout-length tests (IC-10), and the
      `MenuBarBlockBuilderTests` block-width assertions (`:19` literal 34 → 39). Every
      other test stays green. The green run executes 241 tests with 0 failures. No test
      is deleted; only renamed or expectation-updated. Widths: n/a.
- [ ] **IC-13 (scope)** — the production diff against `main` touches exactly three token
      lines (`:112`, `:117`, `MenuBarBlockModel.swift:56`) plus the doc comment above
      `blockWidth` (`MenuBarBlockModel.swift:53-55`, blueprint Appendix B). No popover
      card file, no `rowHeight`, no `networkBlockWidth`, no `gap`/`padding`, no
      `.offset`, no tint, no `.lineLimit` change. `git diff main...HEAD -- StatsLite/`
      shows only those lines; every other change lives in `StatsLiteTests/`. Widths: n/a.

Plan-scoped failure modes:

- **FM1** — the label token stays (or reverts to) 8 pt → IC-1 fails.
- **FM2** — the value token stays (or reverts to) 11 pt → IC-2 fails.
- **FM3** — `blockWidth` is widened to less than 39 (36 or 38) → IC-3/IC-4 fail; the
  measured table shows 38 pt still misses the 2.5 pt-per-side rule.
- **FM4** — scope creep: the coder adds glyph offsets, shrinks `rowHeight`, touches the
  network block or the popover cards → IC-9/IC-13 fail.
- **FM5** — the 12 pt value clips or ellipsizes at any width, or the MEM label row
  truncates in the 39 pt block → IC-4/IC-5 fail.
- **FM6** — stale length tests: one of the 10 updated length expectations is missed or
  miscomputed → IC-10/IC-12 fail.
- **FM7** — screenshot attempt: `screencapture` fails (exit 1) as probed at authoring →
  per the carried-over waiver, record the waiver note instead of captures; visual ICs
  get `waived` rows. This is not a plan failure.

Red-phase falsification rule: if an updated guard passes at HEAD (while the old tokens
are still in production), the guard is not coupled to its production token. Fix the
guard in the red commit; do not start green.

## Approach

1. Archive: the designer blueprint is at
   `plans/2026-10-17-menu-bar-typography-and-block-width/blueprint.md` and embedded
   below verbatim. The coder applies its Appendix B diff and Appendix A test table.
2. Red (coder, commit 1, `[red]`): update the three test files to the blueprint
   expectations — rename and re-expect the typography guards (`MenuBarValueTypographyTests`
   `:35`/`:37` literals → `size:12` / `size:7`; guards at `:179`, `:218`, `:253`, `:301`,
   `:338`), and update the 10 length tests plus the `MenuBarBlockBuilderTests:19`
   literal to 39. Run the suite; report the red output showing exactly the IC-12 failure
   set. Touch no production code.
3. Green (coder, commit 2, same worktree): apply blueprint Appendix B verbatim —
   `:112` → size 7, `:117` → size 12, `MenuBarBlockModel.swift:56` → 39 with the
   updated doc comment. Run the full suite (241/241) and `xcodebuild build`.
   Set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` for all xcodebuild
   invocations (the shell points at CommandLineTools only).
4. Verify: IC-1…IC-13 from test evidence and `rg` output; IC-visual rows waived per the
   screenshot waiver (FM7). Measurements recorded from the guard tests, not re-typed.
5. Review and merge: `[code-review]` on `git diff main...HEAD` in the worktree; after
   GO, rebase if main advanced, then `git merge --ff-only` with the literal branch name
   (or `--squash` with its own conventional commit); then remove worktree and branch.

Decisions:

- `blockWidth` goes to exactly 39 — the smallest integer that satisfies the repo's
  ≥ 2.5 pt-per-side clearance rule at 12 pt (38 pt measures 2.11 pt per side).
- `rowHeight` stays 11 (2 × 11 = 22 = status bar thickness); `networkBlockWidth`
  stays 50; network rate fonts stay 9 pt.
- Gap: option A (font swap only, ~0.3 pt optical tightening). Offsets and row-height
  changes are out of scope by user ruling.
- Menu bar item length grows (e.g. 168 → 183 pt with all four metrics). Expected and
  accepted — the item length stays pinned per configuration, so no data-driven jitter.
- The popover metric cards are out of scope entirely (user ruling 2026-10-17).
- No `.animation` / `.contentTransition` anywhere (repo rule, AGENTS.md).

Refactors:

None. No band-aids introduced or left behind.

## Tasks

- [ ] **T1** — Red-green implementation in worktree
      `worktrees/2026-10-17-menu-bar-typography-and-block-width`, branch
      `feat/2026-10-17-menu-bar-typography-and-block-width`. Red: test-only commit that
      updates the three test files to the blueprint expectations and fails exactly per
      IC-12. Green: blueprint Appendix B verbatim (3 token lines + doc comment). Full
      `xcodebuild test` + build in the worktree with `DEVELOPER_DIR` set. red ⏳ ·
      green ⏳ · review ⏳

## Notation

Plan -> Phase (`## Approach`) -> Task (`T1`; `FM*` = failure modes) -> Receipts
(red SHA / green SHA / review verdict — verify each in git, record on the task line).

## Design Blueprint (verbatim)

Source: `plans/2026-10-17-menu-bar-typography-and-block-width/blueprint.md`
(designer session `2026-10-17T03-19-46-269Z`, menu-bar re-scope). It is the authority for
every visual requirement; the ISC mirrors its VAC-1..VAC-11.

---

# 5-Part Design Blueprint: macOS Menu Bar Status Item Typography & Width Adjustment

## Scope Confirmation & Popover Scope Invalidation

The previous popover metric-card blueprint is **ignored entirely**. No changes apply to `CPUCardView.swift`, `GPUCardView.swift`, `NetworkCardView.swift`, `MemoryPressureCardView.swift`, or `PopoverContentView.swift`.

The scope of this blueprint applies strictly to the macOS menu bar status item:
- `StatsLite/MenuBarStackedItemView.swift`
- `StatsLite/MenuBarBlockModel.swift`
- `StatsLiteTests/MenuBarValueTypographyTests.swift`
- `StatsLiteTests/MenuBarLayoutTests.swift`
- `StatsLiteTests/MenuBarBlockBuilderTests.swift`

## Executive Summary: Current vs Target Values

| Token / Dimension | Location | Current Value | Target Value | Delta & Optical Rationale |
|---|---|---|---|---|
| **Category Label Font** | `MenuBarStackedItemView.swift:112` | `.font(.system(size: 8, weight: .regular))` | `.font(.system(size: 7, weight: .regular))` | -1.0 pt font size (compact label scale) |
| **Metric Value Font** | `MenuBarStackedItemView.swift:117` | `.font(.system(size: 11, weight: .regular).monospacedDigit())` | `.font(.system(size: 12, weight: .regular).monospacedDigit())` | +1.0 pt font size (prominent readability) |
| **Standard Block Width** | `MenuBarBlockModel.swift:56` | `34.0 pt` | **`39.0 pt`** | +5.0 pt to satisfy **≥ 2.5 pt clearance per side** |
| **Network Block Width** | `MenuBarBlockModel.swift:59` | `50.0 pt` | `50.0 pt` (unchanged) | Retained: 1.89 pt spacer clearance satisfies minLength 1 |
| **Row Height** | `MenuBarBlockModel.swift:62` | `11.0 pt` | **`11.0 pt`** (unchanged) | Retained: 2 × 11 pt matches `NSStatusBar.system.thickness` (22 pt) |
| **Label→Value Gap** | `MenuBarStackedItemView.swift:103` | `VStack(alignment: .center, spacing: 0)` | `VStack(alignment: .center, spacing: 0)` | Centered 12 pt font naturally reduces optical gap by 0.36 pt |
| **Network Rate Fonts** | `MenuBarStackedItemView.swift:155, 170` | `.font(.system(size: 9, weight: .regular).monospacedDigit())` | `.font(.system(size: 9, weight: .regular).monospacedDigit())` | Retained: 9 pt regular mono across both rows |
| **Zero Animation** | `MenuBarStackedItemView.swift` | Discrete transitions (0 modifiers) | Discrete transitions (0 modifiers) | Repo invariant: no `.animation` or `.contentTransition` |

## Live AppKit NSFont Measurements & Block Width Analysis

All dimensions derive from live AppKit `NSFont` measurements on macOS Sonoma (14+) using `NSString.size(withAttributes:)`.

### 1. Widest Percentage Value ("100%") at 12 pt Regular Monospaced
- **Target Font**: `NSFont.monospacedDigitSystemFont(ofSize: 12.0, weight: .regular)`
- **Cap Height**: `8.4551 pt` (ascender `11.6016 pt`, descender `-2.5312 pt`, line height `15.0 pt`).
- **Measured String Width**: `"100%"` measures **`33.7793 pt`** (~33.78 pt).

### 2. Clearance Evaluation against the ≥ 2.5 pt Per Side Rule

| Container Width (`blockWidth`) | Text Width | Total Clearance | Clearance Margin Per Side | Rule Compliance (≥ 2.5 pt per side) |
|---|---|---|---|---|
| `34.0 pt` (Current) | 33.7793 pt | 0.2207 pt | **0.1104 pt** | **FAIL** (severe clipping hazard) |
| `36.0 pt` | 33.7793 pt | 2.2207 pt | 1.1104 pt | **FAIL** (< 2.5 pt) |
| `38.0 pt` | 33.7793 pt | 4.2207 pt | 2.1104 pt | **FAIL** (< 2.5 pt) |
| **`39.0 pt` (Target)** | 33.7793 pt | **5.2207 pt** | **2.6104 pt** | **PASS** (satisfies ≥ 2.5 pt per side) |
| `40.0 pt` | 33.7793 pt | 6.2207 pt | 3.1104 pt | **PASS** |

**Conclusion on Block Width**:
At 12 pt, `"100%"` measures 33.78 pt. Inside a 34.0 pt block, total clearance is only 0.22 pt (0.11 pt per side). This violates the required ≥ 2.5 pt clearance per side rule and causes text clipping on non-Retina displays. Expanding `MenuBarLayout.blockWidth` to **`39.0 pt`** provides **`2.61 pt` clearance margin per side** (`5.22 pt` total clearance), strictly satisfying the requirement.

### 3. Metric Value Clearance Spectrum at 12 pt inside 39.0 pt Block

| Value String | Measured Width (12 pt) | Total Clearance (39.0 pt) | Margin Per Side (39.0 pt) | Status |
|---|---|---|---|---|
| `"0%"` / `"5%"` | 18.6621 pt | 20.3379 pt | 10.1689 pt | Pass |
| `"50%"` / `"99%"` | 26.2207 pt | 12.7793 pt | 6.3896 pt | Pass |
| `"100%"` (Widest) | **33.7793 pt** | **5.2207 pt** | **2.6104 pt** | **Pass (≥ 2.5 pt)** |
| `"--%"` (Nil/Tertiary) | 22.4238 pt | 16.5762 pt | 8.2881 pt | Pass |

### 4. Category Label Clearance at 7 pt inside 39.0 pt Block
- Target Font: `NSFont.systemFont(ofSize: 7.0, weight: .regular)`
- `CPU`: width `15.3057 pt` → clearance `23.6943 pt` (margin `11.85 pt` per side).
- `GPU`: width `15.5210 pt` → clearance `23.4790 pt` (margin `11.74 pt` per side).
- `MEM` Row: `4.0 pt dot + 2.0 pt gap + 17.0933 pt ("MEM")` = `23.0933 pt` → clearance `15.9067 pt` (margin `7.95 pt` per side). Exceeds the 3.5 pt clearance floor.

### 5. Network Block Clearance at 9 pt inside 50.0 pt Block
- Widest string `"999 MB/s"` at 9 pt regular mono measures `42.1084 pt`.
- Total row content: `6.0 pt dot + 42.1084 pt = 48.1084 pt`.
- Clearance for `Spacer(minLength: 1)`: `50.0 pt − 48.1084 pt = 1.8916 pt` (≥ 1.0 pt).
- No width change is needed for `networkBlockWidth`.

### 6. Row Height Analysis: Why 11.0 pt Must Not Grow
- `NSStatusBar.system.thickness` measures exactly **`22.0 pt`**.
- Two stacked rows at `11.0 pt` yield `2 × 11.0 = 22.0 pt`.
- The cap height of 12 pt digits is `8.4551 pt`.
- Digits and `%` have zero descenders below the baseline.
- Inside an 11.0 pt row container, 12 pt digits fit with `11.0 − 8.4551 = 2.5449 pt` of vertical margin (`1.27 pt` top, `1.27 pt` bottom).
- If `rowHeight` grew to `12.0 pt`, the block height would become 24.0 pt. This would exceed the 22.0 pt status bar thickness and trigger vertical glyph clipping.
- Therefore, `MenuBarLayout.rowHeight` must remain **`11.0 pt`**.

## Part 1: Visual Hierarchy & ASCII Wireframe

### ASCII Wireframe (Menu Bar Status Item at 183 pt Total Length)

```
+-----------------------------------------------------------------------------------------------------------------------------------+
| Outer Leading Padding: 2 pt                                                                           Outer Trailing Padding: 2 pt|
|                                                                                                                                   |
| +---------------------+   Gap   +---------------------+   Gap   +---------------------+   Gap   +---------------------------------+ |
| |   CPU Block (39)    |   4 pt  |   RAM Block (39)    |   4 pt  |   GPU Block (39)    |   4 pt  |       Network Block (50)        | |
| |                     |         |                     |         |                     |         |                                 | |
| |      [  CPU  ]      |         |   (o) [  MEM  ]     |         |      [  GPU  ]      |         |  (*) Upload      [   5 KB/s ]   | |
| |   7 pt Reg Sec (11) |         |  4pt  7 pt Reg (11) |         |   7 pt Reg Sec (11) |         |  6pt Red         9 pt Reg Mono  | |
| |                     |         |                     |         |                     |         |                                 | |
| |      [ 100% ]       |         |      [ 45%  ]       |         |      [  0%   ]      |         |  (*) Download    [  16 KB/s ]   | |
| |  12 pt Reg Mono (11)|         |  12 pt Reg Mono (11)|         |  12 pt Reg Mono (11)|         |  6pt Blue        9 pt Reg Mono  | |
| +---------------------+         +---------------------+         +---------------------+         +---------------------------------+ |
+-----------------------------------------------------------------------------------------------------------------------------------+
|<--------------------------------------------------------- 183.0 pt -------------------------------------------------------------->|
```

### Layout Mathematics and Fixed Item Lengths

With `blockWidth = 39.0 pt`, `networkBlockWidth = 50.0 pt`, `gap = 4.0 pt`, and `padding = 2.0 pt`:

```
length = 2 * padding + (standardCount * 39.0) + (hasNetwork ? 50.0 : 0) + (totalBlocks - 1) * 4.0
```

| Configuration | Metric Breakdown | Formula | Pinned Length |
|---|---|---|---|
| **All Four Metrics** | CPU + RAM + GPU + NET | `4 + 3×39 + 50 + 3×4` | **183.0 pt** (was 168.0 pt) |
| **All Three Standard Metrics** | CPU + RAM + GPU | `4 + 3×39 + 2×4` | **129.0 pt** (was 114.0 pt) |
| **Any Two Standard Metrics** | CPU + RAM (or CPU + GPU) | `4 + 2×39 + 1×4` | **86.0 pt** (was 76.0 pt) |
| **One Standard Metric + NET** | CPU + NET | `4 + 1×39 + 50 + 1×4` | **97.0 pt** (was 92.0 pt) |
| **Single Standard Metric** | CPU (or RAM or GPU) | `4 + 1×39 + 0` | **43.0 pt** (was 38.0 pt) |
| **Network Only** | NET | `4 + 50 + 0` | **54.0 pt** (unchanged) |
| **All Metrics Disabled** | None | `4 + 0` | **4.0 pt** (unchanged) |

## Part 2: Template / Component Skeleton

### 1. `StatsLite/MenuBarBlockModel.swift`

Location: lines 52–66.

```swift
/// Layout constants shared by the block builder, MenuBarLayout, and
/// the stacked views. Single source of truth for widths.
enum MenuBarLayout {
    /// Pinned width of every standard block. Widest value "100%" at 12 pt
    /// regular mono (33.78 pt) fits with 2.61 pt clearance per side.
    static let blockWidth: CGFloat = 39
    /// Pinned width of the two-line network block. Fits the widest
    /// truncated rate string "999 MB/s" (42.11 pt) plus the 6 pt dot
    /// with 1.89 pt clearance for Spacer(minLength: 1).
    static let networkBlockWidth: CGFloat = 50
    /// Pinned height of each line within a block. Two 11 pt rows yield
    /// a 22 pt block height that matches NSStatusBar.system.thickness
    /// and aligns line 1 and line 2 across standard and network blocks.
    static let rowHeight: CGFloat = 11
    /// Gap between adjacent blocks.
    static let gap: CGFloat = 4
    /// Outer padding: leading 2 pt plus trailing 2 pt.
    static let padding: CGFloat = 2
```

### 2. `StatsLite/MenuBarStackedItemView.swift`

Location: lines 103–121.

```swift
struct MenuBarBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                if let dotState = block.dotState {
                    Circle()
                        .fill(dotState.levelColor)
                        .frame(width: 4, height: 4)
                        .offset(y: -0.5)
                }
                Text(block.label)
                    .font(.system(size: 7, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(height: MenuBarLayout.rowHeight)
            Text(block.valueText)
                .font(.system(size: 12, weight: .regular).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .frame(height: MenuBarLayout.rowHeight)
        }
        .frame(width: block.width)
    }
```

## Part 3: Complete State & Responsive Matrix

### 1. State Matrix (Color, Typography, and Framing)

| State / Metric | Line 1 Label Font | Line 2 Value Font | Value Tint | Indicator Dot | Block Width | Block Height |
|---|---|---|---|---|---|---|
| **CPU Normal** (`< 80%`) | 7 pt Regular Secondary | 12 pt Regular Mono | `.primary` | None | Pinned 39.0 pt | 22.0 pt |
| **CPU Warning** (`80%...94%`) | 7 pt Regular Secondary | 12 pt Regular Mono | `Color(nsColor: .systemOrange)` | None | Pinned 39.0 pt | 22.0 pt |
| **CPU Critical** (`>= 95%`) | 7 pt Regular Secondary | 12 pt Regular Mono | `Color(nsColor: .systemRed)` | None | Pinned 39.0 pt | 22.0 pt |
| **CPU Nil / Waiting** | 7 pt Regular Secondary | 12 pt Regular Mono (`"--%"`) | `Color(nsColor: .tertiaryLabelColor)` | None | Pinned 39.0 pt | 22.0 pt |
| **RAM Normal** (`< 60%`) | 7 pt Regular Secondary | 12 pt Regular Mono | `.primary` | 4 pt `.systemGreen` | Pinned 39.0 pt | 22.0 pt |
| **RAM Warning** (`60%...80%`) | 7 pt Regular Secondary | 12 pt Regular Mono | `.primary` | 4 pt `.systemYellow` | Pinned 39.0 pt | 22.0 pt |
| **RAM Critical** (`> 80%`) | 7 pt Regular Secondary | 12 pt Regular Mono | `.primary` | 4 pt `.systemRed` | Pinned 39.0 pt | 22.0 pt |
| **RAM Nil / Waiting** | 7 pt Regular Secondary | 12 pt Regular Mono (`"--%"`) | `Color(nsColor: .tertiaryLabelColor)` | 4 pt `.systemGray` | Pinned 39.0 pt | 22.0 pt |
| **GPU Normal / High** | 7 pt Regular Secondary | 12 pt Regular Mono | per threshold | None | Pinned 39.0 pt | 22.0 pt |
| **Network Active** | Line 1: 9 pt Regular Mono | Line 2: 9 pt Regular Mono | `.primary` | Up: 6 pt Red, Down: 6 pt Blue | Pinned 50.0 pt | 22.0 pt |
| **Network Nil / Idle** | Line 1: 9 pt Regular Mono | Line 2: 9 pt Regular Mono | `Color(nsColor: .tertiaryLabelColor)` | Up: 6 pt Red, Down: 6 pt Blue | Pinned 50.0 pt | 22.0 pt |

### 2. Responsive Adaptations
- The menu bar status item sits in the macOS system status bar.
- It does not adapt to web viewports.
- Width adapts strictly to the set of enabled metrics via `MenuBarLayout.length(...)`.
- Geometry remains completely invariant to metric data values (prevents menu bar jitter).

## Part 4: Accessibility (WCAG 2.2) & Interaction Contracts

### 1. Contrast Ratios & Legibility Contracts
- **12 pt Regular Monospaced Value**: Primary foreground provides high contrast (> 12:1 in Light Mode, > 14:1 in Dark Mode), exceeding WCAG AAA standards. Monospaced digit styling guarantees equal tabular digit widths (no jitter when digits tick).
- **7 pt Regular Secondary Label**: The user authority override enforces 7 pt regular category labels (`CPU`, `MEM`, `GPU`). VoiceOver provides non-visual access to all metrics.
- **4 pt Pressure Dot**: In the `MEM` block, the 4 pt dot carries semantic color (green, yellow, red, gray) with an optical offset of `y = -0.5 pt` to align with the visual center of 7 pt capital letters.

### 2. VoiceOver & Accessibility Tree Contract
- The SwiftUI status view hierarchy declares `.accessibilityHidden(true)` at `MenuBarStackedItemView.swift:45`.
- `StatusItemController.updateAccessibility()` assigns the VoiceOver string to `statusItem.button` via `button?.setAccessibilityLabel(compositeLabel)`.
- Typography and layout width changes introduce zero alterations to VoiceOver announcements.

### 3. Interaction & Discrete Transitions Contract
- Status item click opens the popover via `button.action = #selector(togglePopover(_:))`.
- **Zero Animation Rule**: Views contain zero `.animation()` or `.contentTransition()` modifiers. Updates remain discrete.

## Part 5: Numbered Visual Acceptance Checklist (VAC)

- **VAC-1 (Category Label Typography)**: `Text(block.label)` (`MenuBarStackedItemView.swift:112`) must evaluate to `.font(.system(size: 7, weight: .regular))`. The font must not use size 8.
- **VAC-2 (Metric Value Typography)**: `Text(block.valueText)` (`:117`) must evaluate to `.font(.system(size: 12, weight: .regular).monospacedDigit())`. The font must not use size 11 or size 10.5.
- **VAC-3 (Standard Block Width Pinned to 39 pt)**: `MenuBarLayout.blockWidth` (`MenuBarBlockModel.swift:56`) must evaluate to `static let blockWidth: CGFloat = 39`. Standard blocks render at exactly 39.0 pt width.
- **VAC-4 (Widest Value Clearance Invariant under ≥ 2.5 pt Rule)**: `"100%"` at 12 pt regular mono (33.7793 pt) inside the 39.0 pt block must produce at least 5.0 pt total clearance (2.5 pt margin per side). Measured clearance: 5.2207 pt total, zero truncation.
- **VAC-5 (Label Row Clearance Invariant at 7 pt inside 39 pt Block)**: All category labels render on one line with zero truncation. MEM row clearance 15.9067 pt (margin 7.95 pt, ≥ 3.5 pt rule); CPU 23.6943 pt; GPU 23.4790 pt.
- **VAC-6 (Network Block Width & Clearance Retention)**: `networkBlockWidth` stays 50.0 pt. `"999 MB/s"` (42.1084 pt) plus the 6.0 pt dot leaves ≥ 1.8 pt for `Spacer(minLength: 1)` (1.8916 pt).
- **VAC-7 (Row Height Alignment Invariant)**: `MenuBarLayout.rowHeight` stays 11. Both row containers in `MenuBarBlockView` and `MenuBarNetworkBlockView` pin `.frame(height: MenuBarLayout.rowHeight)`.
- **VAC-8 (Block Fitting Height Invariant)**: Both block types produce a fitting height of exactly 22.0 pt, matching `NSStatusBar.system.thickness`.
- **VAC-9 (Stack Vertical Spacing Invariant)**: Both block `VStack` containers specify `spacing: 0` (`MenuBarStackedItemView.swift:103`, `:145`).
- **VAC-10 (Layout Length Contract)**: `MenuBarLayout.length` yields 183.0 (four), 129.0 (three standards), 86.0 (any pair), 97.0 (one standard + network), 43.0 (single), 54.0 (network only), 4.0 (all off).
- **VAC-11 (Discrete Transitions / Zero Animation Invariant)**: All three status views contain zero `.animation` or `.contentTransition` modifiers.

## Appendix A: Complete Test Suite Impact & Enumeration

### 1. `StatsLiteTests/MenuBarValueTypographyTests.swift`
- **`expectedValueFont`**: update literal to `".font(.system(size:12,weight:.regular).monospacedDigit())"`.
- **`expectedLabelFont`**: update literal to `".font(.system(size:7,weight:.regular))"`.
- **FM1 guard** → rename to `testValueFontIsTwelvePointRegularMonospacedDigit()`; message updated to `size: 12`.
- **IC-4 guard** → rename to `testLabelFontIsSevenPointRegularSecondary()`; message updated to `must be 7 pt`.
- **IC-10 guard** → rename to `testNetworkFontsAreNinePointRegularAndValueStaysSizeTwelve()`; the `size:11` containment check becomes `size:12`.
- **IC-3 guard** → rename to `testClearanceForWidestValueAtTwelvePointRegularMeetsTwoAndAHalfPointPerSideRule()`: font `NSFont.monospacedDigitSystemFont(ofSize: 12.0, weight: .regular)`; assert `MenuBarLayout.blockWidth == 39.0`, `clearance >= 5.0`, `clearance / 2.0 >= 2.5`, `width == 33.78` (±0.05), `clearance == 5.22` (±0.05).
- **IC-11 guard** → rename to `testLabelRowClearanceForMemRowAtSevenPointRegularMeetsThreeAndAHalfPoints()`: font `NSFont.systemFont(ofSize: 7.0, weight: .regular)`; assert `blockWidth == 39.0`, MEM clearance `15.9067` (±0.05), CPU `23.6943` (±0.05), GPU `23.4790` (±0.05).
- The spacing, network-clearance, fitting-height, and row-frame guards pass unchanged.

### 2. `StatsLiteTests/MenuBarLayoutTests.swift`
Update expected lengths: 168 → 183, 114 → 129 (both tests), 76 → 86 (three tests),
38 → 43 (three tests), 92 → 97. `testNetworkBlockWidthIsPinnedTo50`,
`testNetworkOnlyTotal54`, and `testAllMetricsOffIsPaddingOnly4` pass unchanged.
Rename test methods so the name matches the new total.

### 3. `StatsLiteTests/MenuBarBlockBuilderTests.swift`
- `private let blockWidth: CGFloat = 34` → `39`. All `block.width == blockWidth`
  assertions then pass at green.

## Appendix B: Verbatim Production Code Diffs

```diff
--- a/StatsLite/MenuBarBlockModel.swift
+++ b/StatsLite/MenuBarBlockModel.swift
@@ -53,7 +53,7 @@ enum MenuBarBlockKind: Hashable {
 /// Layout constants shared by the block builder, MenuBarLayout, and
 /// the stacked views. Single source of truth for widths.
 enum MenuBarLayout {
-    /// Pinned width of every block. "100%" at the value font fits
-    /// with clearance.
-    static let blockWidth: CGFloat = 34
+    /// Pinned width of every block. "100%" at 12 pt regular mono (33.78 pt)
+    /// fits with 2.61 pt clearance per side, satisfying the >= 2.5 pt rule.
+    static let blockWidth: CGFloat = 39
     /// Pinned width of the two-line network block. Fits the widest

--- a/StatsLite/MenuBarStackedItemView.swift
+++ b/StatsLite/MenuBarStackedItemView.swift
@@ -109,7 +109,7 @@ struct MenuBarBlockView: View {
                         .offset(y: -0.5)
                 }
                 Text(block.label)
-                    .font(.system(size: 8, weight: .regular))
+                    .font(.system(size: 7, weight: .regular))
                     .foregroundStyle(.secondary)
             }
             .frame(height: MenuBarLayout.rowHeight)
@@ -114,7 +114,7 @@ struct MenuBarBlockView: View {
             }
             .frame(height: MenuBarLayout.rowHeight)
             Text(block.valueText)
-                .font(.system(size: 11, weight: .regular).monospacedDigit())
+                .font(.system(size: 12, weight: .regular).monospacedDigit())
                 .foregroundStyle(valueColor)
                 .lineLimit(1)
                 .frame(height: MenuBarLayout.rowHeight)
```
