# VAC Ledger — Menu Bar Label and Network Typography (`.regular`)

Plan: `2026-10-16-menu-bar-label-network-regular`
Branch: `feat/2026-10-16-menu-bar-label-network-regular`
Red SHA: `98cc6fb` · Green SHA: `8a82730`
Suite: `Executed 225 tests, with 0 failures (0 unexpected)` (xcodebuild, serial testing
flags), `** TEST SUCCEEDED **`

Waiver (user authority, 2026-10-16, no Screen Recording permission): screenshot and strip
captures are skipped. The probe `screencapture -x` exits 1 with `could not create image from
display`. Basis: `artifacts/2026-10-16-menu-bar-label-network-regular/waiver-note.md`.
All test-based rows read `pass`. The zero-tolerance visual policy stays active for any
defect the user reports by eye.

Evidence for every `pass` row comes from the T3 green run of the T2 xcodebuild command at
`8a82730`. The T4 self-verify re-ran the same command and got the same result: 225 tests,
0 failures.

## Verdicts

| IC | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| IC-1 (VAC-1, value font retained) | Value font token stays `.system(size: 10.5, weight: .regular).monospacedDigit()` at `:115-116` | pass | `MenuBarValueTypographyTests.testValueFontIsTenAndAHalfPointRegularMonospacedDigit` passed at `8a82730`. The suite ran 7 typography tests, 0 failures. |
| IC-2 (VAC-2, monospaced digits) | `.monospacedDigit()` stays on the value font at `:116` | pass | `MenuBarValueTypographyTests.testValueFontKeepsMonospacedDigit` passed at `8a82730`. |
| IC-3 (VAC-3, block width and value clearance) | Block width stays 34.0 pt. `"100%"` fits one line with clearance ≥ 3.5 pt. | pass | `MenuBarValueTypographyTests.testClearanceForWidestValueAtRegularMeetsThreeAndAHalfPoints` passed at `8a82730`. Measurement: `"100%"` at 10.5 pt regular = 29.93 pt width, 4.07 pt clearance (gate re-measurement 29.9260 / 4.0740). |
| IC-4 (VAC-4, category labels) | Labels render `.system(size: 8, weight: .regular)` + `.secondary`, no `.bold` | pass | `MenuBarValueTypographyTests.testLabelFontIsEightPointRegularSecondary` failed at red `98cc6fb`, passed at green `8a82730` when `:112` flipped to `.regular`. |
| IC-5 (VAC-8, zero animation) | No `.animation` or `.contentTransition` modifier on the status item path | pass | `rg -n '\.animation\|\.contentTransition'` over `MenuBarStackedItemView.swift`, `MenuBarBlockModel.swift`, `StatusItemController.swift`, `MenuBarAccessibility.swift` → comment-only hits at `MenuBarStackedItemView.swift:14`, `:15`, `:138`, no modifier in any of the four files. `MenuBarRedrawChurnTests` passed: 4 tests, 0 failures. |
| IC-6 (VAC-9, state colors retained) | CPU/GPU tint thresholds, MEM `.primary`, network dots unchanged | pass | `MenuBarBlockBuilderTests.testCPUValueTintThresholds`, `testGPUValueTintThresholds`, `testMEMValueTintStaysPrimaryInAllPressureStates`, `testNetworkBlockTintsKeyToTheirOwnRateNil` all passed at `8a82730`. `git diff main...HEAD -- StatsLite/` touches only the three weight tokens, no tint code. |
| IC-7 (VAC-10, visual blend) | Regular weight renders nothing heavier than the system clock | waived (user authority, 2026-10-16, no Screen Recording permission) | No capture exists. Basis instead: IC-4 and IC-10 fix the weight by exact token, so the heavier stroke is removed by construction. |
| IC-8 (VAC-11, pinned length) | `statusItem.length` stays 114/168/76/38 pt | pass | `MenuBarLayoutTests` passed at `8a82730`: 13 tests, 0 failures. |
| IC-9 (suite) | Green run executes 225 tests with 0 failures, no test deleted | pass | xcodebuild output: `Executed 225 tests, with 0 failures (0 unexpected)`, `** TEST SUCCEEDED **`. Zero `Test Case ... failed` lines in the log. |
| IC-10 (VAC-6, network rate typography) | Both rate fonts render `.system(size: 9, weight: .regular).monospacedDigit()` at `:153` and `:167`. The value line stays size 10.5. | pass | `MenuBarValueTypographyTests.testNetworkFontsAreNinePointRegularAndValueStaysSizeTenAndAHalf` failed at red `98cc6fb`, passed at green `8a82730` when `:153` and `:167` both flipped. |
| IC-11 (VAC-5, label-row clearance) | Label row fits the 34.0 pt block on one line, clearance ≥ 3.5 pt | pass | `MenuBarValueTypographyTests.testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints` passed at `8a82730`. Measurement: MEM row 4.0 dot + 2.0 gap + 19.36 label = 25.36 pt, 8.64 pt clearance (gate re-measurement 25.3594 / 8.6406). |
| IC-12 (VAC-7, network-block clearance) | 50.0 pt container leaves ≥ 1.8 pt for `Spacer(minLength: 1)` beside the widest rate string | pass | `MenuBarValueTypographyTests.testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum` passed at `8a82730`. Measurement: 50.0 − 6.0 − 42.11 = 1.89 pt ≥ 1.8 (gate re-measurement 42.1084 / 1.8916). |
| IC-13 (scope) | Production diff contains exactly three weight tokens | pass | `git diff main...HEAD -- StatsLite/` shows three changed lines only: `:112` `.bold` → `.regular`, `:153` `.medium` → `.regular`, `:167` `.medium` → `.regular`. `:116` untouched. `--stat` = `MenuBarStackedItemView.swift` + `MenuBarValueTypographyTests.swift` only. |
| Screenshot and strip captures (dark, light, menu bar strips) | Visual render captures | waived (user authority, 2026-10-16, no Screen Recording permission) | Same waiver basis as IC-7. Probe: `screencapture -x` exits 1, `could not create image from display`. |

Counts: 14 rows — 12 `pass`, 2 `waived`.
