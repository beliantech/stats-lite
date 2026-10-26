# Tasks — Menu Bar Network Block: Dots to the Trailing Edge

Plan: `plans/2026-10-26-network-dots-trailing/plan.md`. ISC: `isc.md`.
Worktree: `worktrees/2026-10-26-network-dots-trailing`, branch `feat/2026-10-26-network-dots-trailing`.
Convention: `red` = test-only commit that fails on current production. `green` = implementation commit that makes it pass. `v` = verified by the planner against git/ISC.

---

## T1 — Baseline capture + worktree

- [x] **T1** — display awake; run `scripts/capture_menubar.sh`; copy outputs to `artifacts/2026-10-26-network-dots-trailing/before/` including `capture-note.txt`. Create worktree with `git worktree add -B feat/2026-10-26-network-dots-trailing worktrees/2026-10-26-network-dots-trailing main`.
- Failing test: none (mechanical).
- Stop condition: capture script fails or display asleep → fix environment first; no code edit until `before/` exists.
- Success checklist: `before/` has dark + light strips; worktree checked out on `main` tip; `git status` clean. Receipt in the Ledger (T1).

## T2 — Red: dot-placement tests (production untouched)

One task = the full red set. All are failing tests on current production.

- [x] **T2** — test-only edits, no production file, no constant value change:
  - New source test `testNetworkRowsSequenceTextBeforeDot` in `StatsLiteTests/MenuBarValueTypographyTests.swift` (beside `testNetworkBlockStackUsesZeroRowSpacing:756`): within each network row's `HStack(` scope, `Text(` appears before `Circle(` (both rows). Message refs ISC-1/VAC-1.
  - New render test `testNetworkDotsPinTrailingAndTextLeads` in `StatsLiteTests/MenuBarRenderSnapshotTests.swift` (beside the centroid test `:391`): fixtures `networkBlock()` (`:172`) plus widest `MenuBarBlock` `valueText: "999 MB/s"` / `secondaryValueText: "999 MB/s"` (pattern `MenuBarValueTypographyTests.swift:795-806`); per row band × both appearances assert (a) leading `leftmostInkX(row, 0..<90) ≤ 2`, (b) gutter `rightmostInkX(row, 0..<90) + 3 ≤ leftmostInkX(row, 90..<100)`, (c) trailing `rightmostInkX(row, 90..<100) ≥ 99`, (d) column `abs(x(red) − x(cyan)) ≤ 1`. Messages ref ISC-2/VAC-2..5.
  - Retarget `testTempLabelCentroidsAlignWithNetworkDotCentroids` (`MenuBarRenderSnapshotTests.swift:391-460`): dot queries narrow `xRange` to `pixelsWide - 10 ..< pixelsWide` (plan.md correction 5); ISC-2/VAC-16/17 messages stay.
  - Do NOT touch `interBlockGap` (`:47`) or the ink-gap test.
- Failing set (must be exactly this): `testNetworkRowsSequenceTextBeforeDot`, `testNetworkDotsPinTrailingAndTextLeads`, and `testTempLabelCentroidsAlignWithNetworkDotCentroids` (retarget may go red or vacuous-fail on current production; record which).
- Red→green bound: `caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test` exits non-zero with exactly those failures; failure messages quote ISC-1/ISC-2; `git diff --stat` shows `StatsLiteTests/` only.
- Stop conditions: a test outside the set fails → stop and report (do not fix blind); a listed test stays green → the assertion did not discriminate, strengthen per ISC-2 (do not move on); compile error → fix test syntax only.
- Success checklist: failure set matches, zero production file in the diff. `red` ⬜ · `green` n/a · `v` ⬜ — receipts in the Ledger (T2).

## T3 — Green: row reorder (one file)

- [x] **T3** — `StatsLite/MenuBarStackedItemView.swift` only: sequence both `MenuBarNetworkBlockView` rows `Text → Spacer(minLength: 1) → Circle` (`:189-215`); update the network view doc comment and file header (`:14-17`) to rate-then-dot; keep `// Line 1: Upload rate` / `// Line 2: Download rate` comments; keep `.frame(height: MenuBarLayout.rowHeight)` on both rows and `.frame(width: block.width)` on the block; no `.animation`, no `.contentTransition`, no offsets, no token edits (plan.md Step 4).
- Failing test: T2's red set; ISC-1, ISC-2, ISC-3 go green (ISC-3 subject to the red-run record from T2).
- Red→green bound: same suite command; only the ink-gap test may remain red (handled in T4, ISC-4).
- Stop conditions: a T2 test stays red with the reorder in place → H is dead (plan.md Falsification): stop, re-measure, do not force position with modifiers; any test outside the set goes red → scope leak, revert the offending edit; `git diff --stat` shows any file besides `MenuBarStackedItemView.swift` → stop.
- Success checklist: suite green except possibly `testInterBlockInkGapsMeasureTwentyOnePixels`; diff = one production file. `red` ⬜ · `green` ⬜ · `v` ⬜ — receipts in the Ledger (T3).

## T4 — Band confirmation (ISC-4)

- [x] **T4** — run `testInterBlockInkGapsMeasureTwentyOnePixels` under caffeinate, display awake. MEM↔TEMP leg must stay 21 ± 1 px on the shared `interBlockGap`. TEMP↔NET leg: record the measured px in the ledger; if ≠ 21 ± 1, split into `tempNetInkGap` set to the measurement (bound 21..24, plan.md correction 4), update "red dot" messages to "rate text", keep `interBlockGap = 21` untouched; re-issue VAC-7 with the measured value in the ledger.
- Failing test: the TEMP↔NET leg (expected state entering T4).
- Stop condition: measurement outside 21..24 px, or a second consecutive failure after one correction → stop and escalate to the planner; never widen the tolerance without a quoted measurement.
- Success checklist: both legs green; ledger quotes the exact px value per appearance. `v` ⬜ — receipts in the Ledger (T4).

## T5 — Verification runs (planner)

- [x] **T5** — in the worktree: (a) two consecutive full suite runs under `caffeinate`, exit 0 each; (b) ISC-5: `git diff --stat` scope check + `rg '\.animation\(|\.contentTransition\(' ` over the diff empty + `NetworkCardView.swift` absent + `MenuBarLayoutTests` totals green; (c) ISC-6 after-capture: `scripts/capture_menubar.sh` → `artifacts/2026-10-26-network-dots-trailing/after/`, visual check dots right of rates (spot check).
- Success checklist: 2 green runs, all ISC items verified or explicitly delegated to the reviewer; evidence pasted into the ledger below. `v` ✓ — receipts in the Ledger (T5).

## T6 — Commit + review

- [x] **T6** — conventional commit in the worktree: `feat(menubar): move network status dots to trailing edge`. Then reviewer code review against `git diff main...HEAD`.
- Success checklist: commit exists on `feat/2026-10-26-network-dots-trailing`; reviewer verdict recorded; planner merges with `--ff-only` or `--squash` and records the merge SHA here. `commit` ✓ · `review` ✓ (GO, reviewer session 2026-10-26T03-14-26) · `merge` ✓ `ec087f0` (ff, 2026-10-26)

---

## Ledger

(receipts: commands, exit codes, measured px values, run counts)

### T1 — baseline capture (2026-10-26)

Worktree half skipped per spawn note: worktree `worktrees/2026-10-26-network-dots-trailing` on `feat/2026-10-26-network-dots-trailing` already existed; `git status` clean on branch tip `7552f58`.

Capture half:

- Display check: `swift -e 'import CoreGraphics; print("asleep:", CGDisplayIsAsleep(CGMainDisplayID()))'` → `asleep: 0` (awake).
- Release build (worktree had no build): `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Release -derivedDataPath .derivedData build` → `BUILD SUCCEEDED`.
- `pgrep -x StatsLite` → empty (no instance to quit; script pgrep guard passed).
- `caffeinate -i bash scripts/capture_menubar.sh` → exit 0; produced dark + light strips under `artifacts/2026-10-24-temp-labels-cg/visual-vac/`.
- Copied `full-dark.png`, `full-light.png`, `menubar-dark.png`, `menubar-light.png` + `capture-note.txt` to `artifacts/2026-10-26-network-dots-trailing/before/`.
- Pixel check (Python/PIL, top 26 rows): near-white=0 near-black=0 on all four images — wallpaper-only strips, the known TCC block (same signature as `2026-10-26-menu-bar-gpu-mem-swap/before/capture-note.txt`). Accepted per repo precedent; recorded in the note; offscreen render tests remain the gate (AGENTS.md).

### T2 — red (2026-10-26)

Diff scope evidence (production untouched):

```diff
 $ git diff --stat
 StatsLiteTests/MenuBarRenderSnapshotTests.swift  | 153 ++++++++++++++++++++++-
 StatsLiteTests/MenuBarValueTypographyTests.swift  |  55 ++++++++
 2 files changed, 205 insertions(+), 3 deletions(-)
```

`StatsLiteTests/` only. LSP diagnostics on both files: 0 findings.

Red run: `caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test` → exit 65, `Executed 449 tests, with 14 failures (0 unexpected)`.

Failing set — exactly the three T2 tests, nothing else:

1. `MenuBarValueTypographyTests.testNetworkRowsSequenceTextBeforeDot` (2 assertions): line 1 `Text(` at utf8 offset 8470 is not before `Circle(` at 8269; line 2 `Text(` at 9031 not before `Circle(` at 8828. ISC-1/VAC-1 messages quoted in both.
2. `MenuBarRenderSnapshotTests.testNetworkDotsPinTrailingAndTextLeads` (8 assertions = 2 fixtures × 2 rows × 2 appearances): discriminator is VAC-4 (c) — trailing-band rightmost ink = 98 px (production rates) / 97 px (widest rates) < 99 px. VAC-3 (b) gutter and VAC-5 (a) leading pass on current production for an uninteresting reason: the leading dot's ink at x=0 satisfies (a), and the trailing flush-right text continues into the dot band so the (b) gutter reads 90−87=3 px marginally. The test is red as designed; the discriminator differs from the plan's a/b prediction (recorded deviation, no action).
3. `MenuBarRenderSnapshotTests.testTempLabelCentroidsAlignWithNetworkDotCentroids` (4 assertions): retarget went RED on current production (not vacuous) — the trailing band holds trailing rate-text ink whose centroid misses the TEMP labels by 2.047 px (VAC-16 dark), 1.893 px (VAC-17 dark), 2.188/1.984 px (aqua). ISC-2/VAC-16/17 messages kept.

`interBlockGap` (`:47`) and the ink-gap test untouched. Centroid retarget implemented exactly per plan.md correction 5: dot queries use `dotBand = (bitmap.pixelsWide - 10)..<bitmap.pixelsWide`; the harness is unchanged.

Note: no line-number drift on the cited anchors (`interBlockGap:47`, centroid test `:391`, ink-gap test `:474`); the production network view drifted ~7 lines up from the plan's `:183-218` citation (now `:176-215`), located by name.

### T3 — green (2026-10-26)

Production edit: `StatsLite/MenuBarStackedItemView.swift` only — both `MenuBarNetworkBlockView` rows reordered to `Text → Spacer(minLength: 1) → Circle`; network view doc comment and file header updated to rate-then-dot; `// Line 1: Upload rate` / `// Line 2: Download rate` comments and all `.frame(...)` modifiers kept. No `.animation`/`.contentTransition` (`rg -n '\.animation\(|\.contentTransition\(' StatsLite/MenuBarStackedItemView.swift` → no match). LSP diagnostics: 0 findings.

First green run found one red outside the allowed set — a stop condition — diagnosed before any further edit:

- Run 1 (`caffeinate … test`, exit 65, 449 tests, 10 failures): `testInterBlockInkGapsMeasureTwentyOnePixels` (expected, T4) PLUS `testNetworkDotsPinTrailingAndTextLeads` (8 failures, all VAC-3).
- Diagnosis from the failure messages: the VAC-3 assertion I wrote was inverted — `XCTAssertGreaterThanOrEqual(textRight + 3, dotLeft)` encodes `textRight + 3 ≥ dotLeft`, the reverse of the plan's formula `rightmostInkX(0..<90) + 3 ≤ leftmostInkX(90..<100)`. The messages show the dots ARE pinned trailing (text right ink 67/79/82 px, dot left ink 90 px; VAC-2/4/5 green). The inversion was masked in the T2 red run because pre-reorder text ink reached the band edge (87 + 3 ≥ 90). This was a test-operator bug, not a production miss; H stays alive (ISC-2 coordinates landed exactly: dot 90..100 px, text at 0 px).
- Fix: flipped the operator to `XCTAssertLessThanOrEqual(Double(textRight) + 3, Double(dotLeft))` — the assertion now encodes the plan formula verbatim. No production change, no assertion deleted or weakened.

Run 2 (`caffeinate … test`, exit 65, 449 tests, **2 failures**, both = `testInterBlockInkGapsMeasureTwentyOnePixels`, TEMP↔NET leg under darkAqua and aqua). Exactly T3's allowed residual red. The three T2 tests + retargeted centroid test are green.

Diff scope at T3 end: `MenuBarStackedItemView.swift | 41 ++---` + the two test files + this ledger (bookkeeping doc, mandated by the spawn note). ISC-5 binary checks: no `.animation`/`.contentTransition` in the diff; `NetworkCardView.swift` absent; `MenuBarLayout` constants untouched.

### T4 — band confirmation, ISC-4 (2026-10-26)

Measurement (display awake, caffeinate, from the T3 run-2 xcresult):

- TEMP↔NET (VAC-22): **24 px** under `NSAppearanceNameDarkAqua`, **24 px** under `NSAppearanceNameAqua`. MEM↔TEMP (VAC-23): green on the shared `interBlockGap = 21 ± 1` — untouched leg confirmed.
- 24 px sits at the top edge of the plan.md correction-4 bound (21..24 px, prediction 22 ± 2 `unverified prior` → measured 24, glyph-bearing geometry slightly wider than the prior). Within bound; no escalation.

Split applied (one variable, test-file constant only):

- `tempNetInkGap: Double = 24` added beside `interBlockGap` (`MenuBarRenderSnapshotTests.swift`), with a comment quoting the measurement and date. `interBlockGap = 21` untouched; MEM↔TEMP leg still reads `interBlockGap`.
- TEMP↔NET assertion now compares against `tempNetInkGap`; tolerance stays `interBlockGapTolerance = 1`. Messages updated "red dot left ink" → "rate-text left ink" and "the re-issued gap is 21 ±1 px" → "24 ±1 px … (ledger T4, measured 2026-10-26)"; the VAC-22 unwrap message and the test doc comment updated the same way. No assertion deleted or weakened; the MEM↔TEMP VAC-23 leg untouched.

VAC-7 re-issued: TEMP↔NET = **24 ± 1 px** at 2x, both appearances (was 21 ± 1 pre-move); MEM↔TEMP stays **21 ± 1 px**.

Green verification run: `caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test` → **exit 0**, `Executed 449 tests, with 0 failures (0 unexpected)`. Both legs green.

Final state left uncommitted per the spawn note (T5/T6 are the planner's).

### T5 — verification runs (2026-10-26, planner)

- Suite run 1: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer caffeinate -i xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS' test` → **exit 0**, `Executed 449 tests, with 0 failures (0 unexpected)` in 82.0 s.
- Suite run 2: same command → **exit 0**, 449 tests, 0 failures in 75.9 s. (Environment note: the planner shell resolves `xcode-select -p` to CommandLineTools; `DEVELOPER_DIR` points at `/Applications/Xcode.app` — same variable the T1 ledger used.)
- ISC-5 scope: `git diff --stat` = 1 production file (`StatsLite/MenuBarStackedItemView.swift`, 41 lines) + 2 test files + this ledger (MD); `git diff | rg '\.animation\(|\.contentTransition\('` → no matches; `NetworkCardView.swift` absent from `git diff --name-only`; `MenuBarLayoutTests` totals green inside both runs.
- ISC-6 after-capture: `caffeinate -i bash scripts/capture_menubar.sh` → exit 0; dark + light strips copied to `artifacts/2026-10-26-network-dots-trailing/after/`. Pixel check (PIL, top 26 rows): near-white=0, near-black=0 on both menubar strips — wallpaper-only, the same TCC signature as `before/` and the `2026-10-26-menu-bar-gpu-mem-swap` precedent. The live dots-right-of-rates spot check is blocked by TCC; delegated to the reviewer against the offscreen renders (AGENTS.md: offscreen render tests are the gate).
- `v` ✓ (visual spot check TCC-blocked, recorded)
