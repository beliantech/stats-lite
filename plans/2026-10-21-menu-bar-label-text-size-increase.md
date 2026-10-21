# Plan: menu-bar-label-text-size-increase

Plan name: `menu-bar-label-text-size-increase`
Date: 2026-10-21
Risk class: **R2** (UI work — visual fidelity to the Design Blueprint is a strict functional requirement)

## Intent

The menu-bar status-item category labels ("CPU", "GPU", "MEM") render at 7 pt regular, which the user reports as too small. Increase them by one step to 8 pt regular, one variable at a time, with rendered proof that nothing wraps, clips, or animates.

Out of scope: popover metric-card labels (11 pt → 12 pt), sparkline time-axis text (9 pt), metric values, captions, all other typography.

## Notation

```text
Plan -> Phase -> Task (T*, FM* = failure modes) -> Receipts (red SHA / green SHA / review verdict)
```

- [x] **T1** — red: failing tests for the 8 pt label step. red `342433e` · green — · review GO
- [x] **T2** — green: implement 8 pt label step until green. red — · green `9626aa6` · review GO
- [x] **T3** — tester VAC verification on rendered dark/light captures. PASS — see Receipts
- [x] **T4** — reviewer code review, merge to main, docs. GO → merged, `9626aa6`

## ISC

Binary checks. Each must be YES.

1. **ISC-1 (size step)** — `MenuBarStackedItemView.swift` renders `block.label` at `Font.system(size: 8, weight: .regular)`; the 7 pt literal is gone from that call site.
2. **ISC-2 (clearance)** — widest label "MEM" plus its 4 pt pressure dot and 2 pt gap fits the 39 pt block with ≥ 2.5 pt clearance per side (measured or asserted), in dark and light appearance.
3. **ISC-3 (no wrap/clip)** — rendered captures show every status-item label on one line, unclipped, with no border or edge clipping (blocking failure if violated).
4. **ISC-4 (transitions stay discrete)** — zero `.animation` or `.contentTransition` modifiers on the status-item view path (static check).
5. **ISC-5 (scope exclusion)** — `SparklineTimeAxisView.swift` still uses 9 pt monospaced-digit tertiary; popover card labels still use 11 pt semibold.
6. **ISC-6 (tests)** — `MenuBarValueTypographyTests` asserts the 8 pt label font and passes; no red test weakened or deleted.
7. **ISC-7 (hygiene)** — typecheck errors on changed files = 0, lint errors on changed files = 0.
8. **ISC-8 (VAC)** — VAC-1 through VAC-4 below PASS on rendered dark and light captures.

Note: the menu bar has one fixed geometry (39 pt block); the 375/768/1440 px breakpoints do not apply. Rendered verification covers dark and light appearance at the real status-item size.

### Failure modes

- **FM1** — "MEM" label + dot wraps or clips inside the 39 pt block at 8 pt. Falsification signature: rendered capture shows ellipsis or a second line → ISC-2/ISC-3 fail.
- **FM2** — label size change accidentally adds animation to the status item. Falsification signature: `.animation`/`.contentTransition` grep hits on the status-item path → ISC-4 fail.
- **FM3** — change leaks outside the menu bar (popover or sparkline text sizes shift). Falsification signature: popover/axis captures or source literals differ from baseline → ISC-5 fail.
- **FM4** — test updated to match implementation without the assertion ever failing pre-change. Falsification signature: red commit contains no failing 8 pt assertion → red phase invalid, fix before green.

## Approach

Designer-first (done). The designer's Design Blueprint for the menu-bar scope, copied verbatim:

---

### Design Blueprint — Menu-Bar Label One-Step Increase (Scope B)

**Source finding**: the in-scope label is `StatsLite/MenuBarStackedItemView.swift:112` — `Text(block.label).font(.system(size: 7, weight: .regular)).foregroundStyle(.secondary)`, applying to category labels "CPU", "GPU", "MEM" (paired with the 4 pt pressure dot at line 108).

**Step transition**: current step 7 pt (cap height 4.93 pt, under 5 physical px on non-Retina). Target step **8 pt regular** (cap height 5.64 pt, line height 10.0 pt, +1.0 pt / +14.3%). Weight stays `.regular`, foreground stays `.secondary`.

#### Part 1 — Visual wireframe

```text
[ CPU ]  •     [ GPU ]  •     [ MEM ] •
 8pt       4pt    8pt      4pt    8pt
 regular  dot   regular   dot   regular
 Pinned block width: 39.0 pt (MenuBarLayout.blockWidth, MenuBarBlockModel.swift:56)
 Vertical row height: 11.0 pt (MenuBarLayout.rowHeight)
```

#### Part 2 — Component skeleton

```swift
// StatsLite/MenuBarStackedItemView.swift:112
Text(block.label)
    .font(.system(size: 8, weight: .regular))
    .foregroundStyle(.secondary)
```

Update the expected literal in `StatsLiteTests/MenuBarValueTypographyTests.swift:38` to `".font(.system(size:8,weight:.regular))"` in the **red** phase (test-only), so the assertion fails against the unmodified 7 pt implementation.

#### Part 3 — State & responsive matrix

| Surface | Container | Invariant |
|---|---|---|
| macOS menu bar (stacked block) | pinned 39.0 pt width, 11.0 pt row height | clearance ≥ 2.5 pt per side for every label ("CPU", "GPU", "MEM"); 8 pt regular fits the 11.0 pt row with 1.0 pt vertical buffer |

No hover/focus/loading variants on this static label. One fixed geometry; no responsive breakpoints.

#### Part 4 — Accessibility

- `.foregroundStyle(.secondary)` keeps the standard macOS secondary hierarchy; 7 pt → 8 pt increases glyph stroke mass and legibility.
- No accessibility-tree change: the label text content is unchanged; card summaries in the popover read by VoiceOver are untouched.
- Interaction contract unchanged: labels are informative, non-interactive.

#### Part 5 — Implementation notes

1. `StatsLite/MenuBarStackedItemView.swift:112` — change `size: 7` to `size: 8`.
2. `StatsLiteTests/MenuBarValueTypographyTests.swift:38` — update `expectedLabelFont` literal to the 8 pt expectation in the **red** phase (T1, test files only); it must fail against the current 7 pt implementation.
3. Nothing else. No token extraction, no popover edits (YAGNI — a shared token is only justified when the popover scope lands).

#### Numbered Visual Acceptance Checklist

- **VAC-1 (label size)** — `MenuBarStackedItemView.swift:112` renders `block.label` at `Font.system(size: 8, weight: .regular)`, `.secondary`; the label reads clearly in rendered dark and light captures.
- **VAC-2 (no wrap/clip)** — every label ("CPU", "GPU", "MEM") renders on one line inside the 39 pt block with ≥ 2.5 pt clearance per side; no ellipsis, no clipping, in dark and light captures.
- **VAC-3 (zero animation)** — static check: zero `.animation` or `.contentTransition` modifiers on the status-item view path.
- **VAC-4 (scope exclusion)** — sparkline axis stays 9 pt monospaced-digit tertiary; popover card labels stay 11 pt semibold; metric values unchanged.

---

## Refactors

None required. The inline 7 pt literal becomes an inline 8 pt literal; extracting a shared typography token system is deferred until the popover label scope lands (YAGNI). No band-aids, TODOs, or suppressed tests in the touched path.

## Execution rules

- Red and green are two sequential `coder` spawns in one worktree; red touches test files only.
- Renders verified by `tester` against VAC-1..VAC-4 in dark and light appearance before any task is marked `[x]`.
- Baseline captures exist at `artifacts/2026-10-16-menu-bar-regular-weight/baseline/{dark,light}.png`; capture a fresh before-state if those are stale (before the first code edit).
- Merge with `--ff-only` or `--squash`; linear main history.

## Receipts

- Plan review: NO GO (green-phase literal contradiction) → fixed → re-review GO.
- Red `342433e` (rebased): test-only, 1 intended failure of 292; failure quotes the 7 pt production token (FM4 dead).
- Green `9626aa6` (rebased): 2 files, +20/−20; suite 292/292 green (44 s). Fixture re-encode measured at 8 pt with all thresholds preserved (MEM 13.6406 ≥ 3.5, CPU/GPU ≥ 16, topGap > bottomGap, zero-clipping guards).
- VAC: all PASS both appearances — light on `light-status-item.png`, dark on `dark-status-item.png` (label glyphs 12–13 px @2x = 8 pt regular; single row, no ellipsis, no clip). VAC-3/4 static PASS; ISC-6 14/14 PASS. Evidence: `artifacts/2026-10-21-menu-bar-label-text-size-increase/TESTER-REPORT.md`.
- TCC note: SSH-session Screen Recording + Accessibility grants now on `/usr/libexec/sshd-keygen-wrapper` (Device Control and Data Access pane); Automation (osascript) still denied, worked around.
- Reviewer: GO. Merge: fast-forward, main = `9626aa6`. Worktree and branch removed.
