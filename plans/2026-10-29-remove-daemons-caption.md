# Plan — Remove the "System daemons not included" caption

Plan name: 2026-10-29-remove-daemons-caption
Date: 2026-10-29
Risk class: R2 (UI change — visual fidelity is a blocking requirement)
Design blueprint: plans/2026-10-29-remove-daemons-caption-blueprint.md

## Intent

The Top Processes card shows a caption "System daemons not included". The claim is
false: enumeration (`LiveSystemMetricsProvider.swift:267-317`) has no daemon filter,
so user-session daemons (WindowManager, corespotlightd, sharingd) appear. Only
root-owned processes drop out, by EPERM, not by design. The user wants the caption
removed entirely, with no replacement text.

## ISC

All checks are binary. The popover is fixed at 280 pt width
(`PopoverContentView.swift:129`) with no responsive breakpoints, so VAC items
verify at that fixed width in dark and light appearance. No 375/768/1440 viewports
apply to this native popover.

- VAC-R1 — Expanded CPU card, populated state, dark and light: the string
  `System daemons not included` appears nowhere in the popover.
- VAC-R2 — Expanded CPU card, populated state: the fifth row's bottom edge is
  followed directly by the card's 10 pt bottom padding. The 8 pt caption gap and
  any empty band are gone. The bottom band matches the expanded Memory card's
  bottom band.
- VAC-R3 — Expanded CPU card: five rows keep uniform vertical rhythm and stay
  anchored to the disclosure button. Row heights and gauges unchanged.
- VAC-R4 — Loading (`Sampling top processes…`) and empty
  (`No process data available`) states: placeholder line renders, no caption below
  it, card bottom band equals VAC-R2.
- VAC-R5 — Collapsed CPU disclosure: chevron, label, cue dot unchanged. No caption
  text in the collapsed card.
- VAC-R6 — Memory card, expanded and collapsed: unchanged, no caption in any state.
- VAC-R7 — Cards below CPU (Memory, GPU, Network) keep 6 pt stack gaps and order.
  Popover footer visible. No clipped card borders.
- VAC-R8 — Source guard: `StatsLite/` contains no `System daemons not included`,
  no `helperGapCaption`, no `showsHelperGapCaption`.
- FM1 — Any leftover reference to the removed parameter/constant breaks the build.
  Guard: the suite compiles and passes (VAC-R8).
- FM2 — Removing the caption leaves an orphaned empty band in the card.
  Guard: VAC-R2.
- FM3 — The rewrite of `ProcessDisclosureTests` weakens loading/empty-state
  coverage. Guard: VAC-R4 asserts the placeholder lines still render.
- Build — typecheck errors on changed files = 0; test suite passes.

Evidence screenshots go in `tmp/` (gitignored). Evidence never commits.

## Approach

- Delete the caption plumbing per blueprint section 1: flag declaration
  (`TopProcessesView.swift:26-28`), caption constant (`:35-38`), render block with
  its 8 pt top padding (`:58-64`), CPU-only wiring (`CPUCardView.swift:65`).
- The section VStack spacing is 0 (`TopProcessesView.swift:40`), so deletion
  reclaims the whole caption band with no orphaned gap. Target geometry: the
  expanded Memory card bottom (blueprint evidence capture).
- Rework `ProcessDisclosureTests.swift` per blueprint section 4: flip caption
  asserts to negative source guards, rewrite the three-state render test without
  the removed parameter, delete the caption-specific collapsed test.
- No other view reads the flag. `plans/` and `artifacts/` mentions are historical;
  do not edit them.
- `MenuBarRenderSnapshotTests` covers menu bar blocks only; no render-test change.

## Refactors

The caption flag, constant, and render block are the band-aid being removed —
this plan deletes them rather than leaving dead plumbing. No other band-aids in
the touched code.

## Notation

Plan -> Phase -> Task (`T1`...) -> Receipts (red SHA / green SHA / review verdict,
verified in git before written here).

## Tasks

- [x] **T1** — red: negative tests only (source guard VAC-R8, three-state no-caption
  render test). red `ae8bf86` · green n/a (T2) · review PASS (test-only additions,
  107 insertions 0 deletions; 1 expected red failure confirmed)
- [x] **T2** — green: caption flag/constant/render block + CPUCardView wiring
  removed; tests reworked; suite 522 tests 0 failures; VAC-R1..R3, R5..R8 PASS via
  harness captures (dark + light), VAC-R4 covered by render test only (harness has
  no loading/empty force flag; reviewer accepted). red `ae8bf86` · green `654ca5e` ·
  review PASS
- [x] **T3** — code review GO (no orphaned plumbing, screenshots inspected, no docs
  update needed) then ff-only merge. merge `654ca5e` (main fast-forwarded from
  `e73e0e0`); worktree removed, branch deleted; evidence PNGs copied to
  `tmp/evidence-2026-10-29-remove-daemons-caption/` (gitignored)

## Verification

Delivered: reviewer GO received, merged to main `654ca5e` (ff-only), full suite
522 tests 0 failures. VAC-R4 visual verification impossible with the harness
(render-test coverage accepted by reviewer) — label unverified where it stands.

## Close-out

- Plan committed at `e73e0e0` with blueprint.
- No ARCHITECTURE.md / DESIGN.md / AGENTS.md update needed (caption was undocumented).
- Housekeeping note: `tmp/` was missing from `.gitignore` despite AGENTS.md — fixed
  in the close-out commit.
