# Tasks — Menu Bar Network Block: Dots to the Trailing Edge

Plan: `plans/2026-10-26-network-dots-trailing/plan.md`. ISC: `isc.md`.
Worktree: `worktrees/2026-10-26-network-dots-trailing`, branch `feat/2026-10-26-network-dots-trailing`.
Convention: `red` = test-only commit that fails on current production. `green` = implementation commit that makes it pass. `v` = verified by the planner against git/ISC.

---

## T1 — Baseline capture + worktree

- [ ] **T1** — display awake; run `scripts/capture_menubar.sh`; copy outputs to `artifacts/2026-10-26-network-dots-trailing/before/` including `capture-note.txt`. Create worktree with `git worktree add -B feat/2026-10-26-network-dots-trailing worktrees/2026-10-26-network-dots-trailing main`.
- Failing test: none (mechanical).
- Stop condition: capture script fails or display asleep → fix environment first; no code edit until `before/` exists.
- Success checklist: `before/` has dark + light strips; worktree checked out on `main` tip; `git status` clean. Receipt in the Ledger (T1).

## T2 — Red: dot-placement tests (production untouched)

One task = the full red set. All are failing tests on current production.

- [ ] **T2** — test-only edits, no production file, no constant value change:
  - New source test `testNetworkRowsSequenceTextBeforeDot` in `StatsLiteTests/MenuBarValueTypographyTests.swift` (beside `testNetworkBlockStackUsesZeroRowSpacing:756`): within each network row's `HStack(` scope, `Text(` appears before `Circle(` (both rows). Message refs ISC-1/VAC-1.
  - New render test `testNetworkDotsPinTrailingAndTextLeads` in `StatsLiteTests/MenuBarRenderSnapshotTests.swift` (beside the centroid test `:391`): fixtures `networkBlock()` (`:172`) plus widest `MenuBarBlock` `valueText: "999 MB/s"` / `secondaryValueText: "999 MB/s"` (pattern `MenuBarValueTypographyTests.swift:795-806`); per row band × both appearances assert (a) leading `leftmostInkX(row, 0..<90) ≤ 2`, (b) gutter `rightmostInkX(row, 0..<90) + 3 ≤ leftmostInkX(row, 90..<100)`, (c) trailing `rightmostInkX(row, 90..<100) ≥ 99`, (d) column `abs(x(red) − x(cyan)) ≤ 1`. Messages ref ISC-2/VAC-2..5.
  - Retarget `testTempLabelCentroidsAlignWithNetworkDotCentroids` (`MenuBarRenderSnapshotTests.swift:391-460`): dot queries narrow `xRange` to `pixelsWide - 10 ..< pixelsWide` (plan.md correction 5); ISC-2/VAC-16/17 messages stay.
  - Do NOT touch `interBlockGap` (`:47`) or the ink-gap test.
- Failing set (must be exactly this): `testNetworkRowsSequenceTextBeforeDot`, `testNetworkDotsPinTrailingAndTextLeads`, and `testTempLabelCentroidsAlignWithNetworkDotCentroids` (retarget may go red or vacuous-fail on current production; record which).
- Red→green bound: `caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test` exits non-zero with exactly those failures; failure messages quote ISC-1/ISC-2; `git diff --stat` shows `StatsLiteTests/` only.
- Stop conditions: a test outside the set fails → stop and report (do not fix blind); a listed test stays green → the assertion did not discriminate, strengthen per ISC-2 (do not move on); compile error → fix test syntax only.
- Success checklist: failure set matches, zero production file in the diff. `red` ⬜ · `green` n/a · `v` ⬜ — receipts in the Ledger (T2).

## T3 — Green: row reorder (one file)

- [ ] **T3** — `StatsLite/MenuBarStackedItemView.swift` only: sequence both `MenuBarNetworkBlockView` rows `Text → Spacer(minLength: 1) → Circle` (`:189-215`); update the network view doc comment and file header (`:14-17`) to rate-then-dot; keep `// Line 1: Upload rate` / `// Line 2: Download rate` comments; keep `.frame(height: MenuBarLayout.rowHeight)` on both rows and `.frame(width: block.width)` on the block; no `.animation`, no `.contentTransition`, no offsets, no token edits (plan.md Step 4).
- Failing test: T2's red set; ISC-1, ISC-2, ISC-3 go green (ISC-3 subject to the red-run record from T2).
- Red→green bound: same suite command; only the ink-gap test may remain red (handled in T4, ISC-4).
- Stop conditions: a T2 test stays red with the reorder in place → H is dead (plan.md Falsification): stop, re-measure, do not force position with modifiers; any test outside the set goes red → scope leak, revert the offending edit; `git diff --stat` shows any file besides `MenuBarStackedItemView.swift` → stop.
- Success checklist: suite green except possibly `testInterBlockInkGapsMeasureTwentyOnePixels`; diff = one production file. `red` ⬜ · `green` ⬜ · `v` ⬜ — receipts in the Ledger (T3).

## T4 — Band confirmation (ISC-4)

- [ ] **T4** — run `testInterBlockInkGapsMeasureTwentyOnePixels` under caffeinate, display awake. MEM↔TEMP leg must stay 21 ± 1 px on the shared `interBlockGap`. TEMP↔NET leg: record the measured px in the ledger; if ≠ 21 ± 1, split into `tempNetInkGap` set to the measurement (bound 21..24, plan.md correction 4), update "red dot" messages to "rate text", keep `interBlockGap = 21` untouched; re-issue VAC-7 with the measured value in the ledger.
- Failing test: the TEMP↔NET leg (expected state entering T4).
- Stop condition: measurement outside 21..24 px, or a second consecutive failure after one correction → stop and escalate to the planner; never widen the tolerance without a quoted measurement.
- Success checklist: both legs green; ledger quotes the exact px value per appearance. `v` ⬜ — receipts in the Ledger (T4).

## T5 — Verification runs (planner)

- [ ] **T5** — in the worktree: (a) two consecutive full suite runs under `caffeinate`, exit 0 each; (b) ISC-5: `git diff --stat` scope check + `rg '\.animation\(|\.contentTransition\(' ` over the diff empty + `NetworkCardView.swift` absent + `MenuBarLayoutTests` totals green; (c) ISC-6 after-capture: `scripts/capture_menubar.sh` → `artifacts/2026-10-26-network-dots-trailing/after/`, visual check dots right of rates (spot check).
- Success checklist: 2 green runs, all ISC items verified or explicitly delegated to the reviewer; evidence pasted into the ledger below. `v` ⬜ — receipts in the Ledger (T5).

## T6 — Commit + review

- [ ] **T6** — conventional commit in the worktree: `feat(menubar): move network status dots to trailing edge`. Then reviewer code review against `git diff main...HEAD`.
- Success checklist: commit exists on `feat/2026-10-26-network-dots-trailing`; reviewer verdict recorded; planner merges with `--ff-only` or `--squash` and records the merge SHA here. `commit` ⬜ · `review` ⬜ · `merge` ⬜

---

## Ledger

(receipts: commands, exit codes, measured px values, run counts)
