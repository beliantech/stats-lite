# VAC Ledger — Menu Bar Row Alignment (8 pt Labels, 11 pt Rows)

Plan: `2026-10-16-menu-bar-row-alignment`
Branch: `feat/2026-10-16-menu-bar-row-alignment`
Red SHA: `1d9e178` · Green SHA: `ee96ec9`
Suite: `Executed 229 tests, with 0 failures (0 unexpected)` (xcodebuild, serial testing
flags), `** TEST SUCCEEDED **`

Production citations are as-at green HEAD `ee96ec9`. Gate measurements come from
`artifacts/2026-10-16-emulate-stats-layout/gate-report-alignment.md` (§2, §3).

Waiver (user authority, 2026-10-16, no Screen Recording permission): screenshot and strip
captures are skipped. Three recorded `screencapture -x` probes exit 1 with `could not
create image from display`. Basis: `artifacts/2026-10-16-emulate-stats-layout/waiver-note.md`,
section "Carry-over — plan `2026-10-16-menu-bar-row-alignment`". No new probe runs for
this plan. All test-based rows read `pass`. The zero-tolerance visual policy stays active
for any defect the user reports by eye.

Evidence for every `pass` row comes from the T3 green run at `ee96ec9`. The T4
self-verify re-ran the same xcodebuild command at `ee96ec9` and got the same result: 229
tests, 0 failures, `** TEST SUCCEEDED **`.

## Verdicts

| IC | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| IC-1 (VAC-1, category labels → 8 pt) | `MenuBarStackedItemView.swift:112` reads `.font(.system(size: 8, weight: .regular))` with `.foregroundStyle(.secondary)` at `:113` | pass | `MenuBarValueTypographyTests.testLabelFontIsEightPointRegularSecondary` failed at red `1d9e178` and passed at green `ee96ec9` when `:112` flipped to `size: 8`. |
| IC-2 (VAC-2, values stay 11 pt) | `:117` stays `.font(.system(size: 11, weight: .regular).monospacedDigit())` | pass | `testValueFontIsElevenPointRegularMonospacedDigit` and `testValueFontKeepsMonospacedDigit` passed at `ee96ec9`. |
| IC-3 (VAC-3, metric stack spacing stays 0) | `:103` stays `VStack(alignment: .center, spacing: 0)` | pass | `testMetricBlockStackUsesZeroVerticalSpacing` passed at `ee96ec9`. |
| IC-4 (VAC-4, network stack spacing stays 0) | `:145` stays `VStack(alignment: .leading, spacing: 0)` | pass | `testNetworkBlockStackUsesZeroRowSpacing` passed at `ee96ec9`. |
| IC-5 (VAC-5, widest-value clearance) | `blockWidth` stays 34.0; "100%" at 11 pt regular mono leaves 2.78 pt ≥ 2.5 (relaxed threshold, binding user Option 1) | pass | `testClearanceForWidestValueAtElevenPointRegularMeetsRelaxedThreshold` passed at `ee96ec9`. Gate measurement: width 31.2222, clearance 2.7778 ≥ 2.5. |
| IC-6 (VAC-6, label-row clearance at 8 pt) | The label row fits the 34.0 pt block on one line at 8 pt regular secondary | pass | `testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints` passed at `ee96ec9` (the guard measures its own font). Gate measurements: MEM row 25.3594 → clearance 8.6406 ≥ 3.5; CPU 16.6836 ≥ 16.0; GPU 16.4375 ≥ 16.0. |
| IC-7 (VAC-7, network rate fonts retained) | `:155` and `:170` stay `.font(.system(size: 9, weight: .regular).monospacedDigit())` | pass | `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven` passed at `ee96ec9`. |
| IC-8 (VAC-8, network clearance retained) | `networkBlockWidth` stays 50.0; "999 MB/s" leaves 1.89 pt ≥ 1.8 | pass | `testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum` passed at `ee96ec9`. Gate measurement: width 42.1084, clearance 1.8916 ≥ 1.8. |
| IC-9 (VAC-9, zero animation) | No `.animation` or `.contentTransition` modifier on the status item path | pass | `rg -n '\.animation\|\.contentTransition'` over `MenuBarStackedItemView.swift`, `MenuBarBlockModel.swift`, `StatusItemController.swift`, `MenuBarAccessibility.swift` at `ee96ec9` → comment-only hits at `MenuBarStackedItemView.swift:14`, `:15`, `:140`, never a modifier. The popover `.animation` at `PopoverContentView.swift` is outside the VAC-9 selector. `MenuBarRedrawChurnTests` passed: 4 tests, 0 failures. |
| IC-10 (VAC-10, length contract) | `MenuBarLayout.length` stays 168/114/92/76/54/38/4; the green commit adds a `static let` only | pass | `MenuBarLayoutTests` passed at `ee96ec9`: 13 tests, 0 failures. The 130 pt row stays unpinned (gate N7, recorded deferral). |
| IC-11 (VAC-11, fitting-height equality) | Both blocks fit exactly 22.00 pt against the 22 pt status bar thickness | pass | `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness` failed at red `1d9e178` (std fits 23.00 pt) and passed at green `ee96ec9`. Gate measurements: `MenuBarBlockView` 22.0000, `MenuBarNetworkBlockView` 22.0000, delta 0.0000 (accuracy 0.01). |
| IC-12 (VAC-12, row-height constant + row-frame tokens) | `MenuBarLayout.rowHeight` exists as `static let rowHeight: CGFloat = 11` (`MenuBarBlockModel.swift:63`) and all four row containers carry `.frame(height: MenuBarLayout.rowHeight)` (green-HEAD lines `MenuBarStackedItemView.swift:115`, `:120`, `:159`, `:174`) | pass | `testRowFramesUseRowHeightConstantInBothBlocks` failed at red `1d9e178` (constant absent, no frame tokens) and passed at green `ee96ec9`, with the constant folded in as a source-token assertion (documented Approach item 3). Honest alignment invariant: row frames and edges are exact — extents [0, 11] and [11, 22] in both blocks, block height 22.00 pt, delta 0.0000. Ink baselines differ by ~0.38 pt because an 8 pt label and a 9 pt rate in equal-height rows have different font metrics. That delta is recorded and is not a defect. No test, ledger row, or report claims baseline equality. |
| IC-13 (suite counts) | Red runs 229 tests with exactly 3 failures; green runs 229 tests with 0 failures; no test is deleted | pass | Red at `1d9e178`: 229 tests, exactly 3 failures — `testLabelFontIsEightPointRegularSecondary`, `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness`, `testRowFramesUseRowHeightConstantInBothBlocks` (recorded in the red commit message). Green at `ee96ec9`: `Executed 229 tests, with 0 failures (0 unexpected)`, `** TEST SUCCEEDED **`, zero `Test Case ... failed` lines in the T4 re-run log. |
| IC-14 (scope) | The production diff contains exactly the six Appendix A edits and no other production change | pass | `git diff main...HEAD --stat -- StatsLite/` at `ee96ec9` = `MenuBarBlockModel.swift` +4 (constant + 3 doc lines), `MenuBarStackedItemView.swift` +5/−1 (`:112` flip plus 4 inserted frame lines): 2 files, 9 insertions, 1 deletion. Full stat: the two production files plus `StatsLiteTests/MenuBarValueTypographyTests.swift`, 3 files, 187 insertions, 33 deletions. No width, length, tint, rate/value font, `.monospacedDigit()`, or comment changes. |
| Screenshot and strip captures (dark, light, menu bar strips) | Visual render captures | waived (user authority, 2026-10-16, no Screen Recording permission) | Basis: `artifacts/2026-10-16-emulate-stats-layout/waiver-note.md`, carry-over section for this plan. Three recorded probes exit 1 with `could not create image from display`. No new probe runs for this plan. |

Counts: 15 rows — 14 `pass`, 1 `waived`.
