# VAC Ledger — Emulate Stats Layout (7 pt labels, 11 pt values, tight stacks)

Plan: `2026-10-16-emulate-stats-layout`
Branch: `feat/2026-10-16-emulate-stats-layout`
Red SHA: `92c28ca` · Green SHA: `ff61edf`
Suite: `Executed 227 tests, with 0 failures (0 unexpected)` (xcodebuild, serial testing
flags), `** TEST SUCCEEDED **`

Waiver (user authority, 2026-10-16, no Screen Recording permission): screenshot and strip
captures are skipped. The probe `screencapture -x` exits 1 with `could not create image from
display`. Basis: `artifacts/2026-10-16-emulate-stats-layout/waiver-note.md`. Every
test-based row reads `pass`. The zero-tolerance visual policy stays active for any defect
the user reports by eye.

Evidence for every `pass` row comes from the T3 green run of the T2 xcodebuild command at
`ff61edf`. The T4 self-verify re-ran the same command and got the same result: 227 tests,
0 failures.

Note on labels: test-file MARK comments use the blueprint's own IC numbering. This table
uses the plan's IC-1 … IC-12 list, which is the authority. The exact test method names
below make each mapping unambiguous.

## Verdicts

| IC | Check | Verdict | Evidence |
| --- | --- | --- | --- |
| IC-1 (VAC-1, category labels → 7 pt) | Labels render `.system(size: 7, weight: .regular)` with `.foregroundStyle(.secondary)` at `:111-113`; no `size: 8` | pass | `MenuBarValueTypographyTests.testLabelFontIsSevenPointRegularSecondary` failed at red `92c28ca` while `:112` carried `size: 8`, and passed at green `ff61edf` when `:112` flipped. The 7 pt legibility override is on record (blueprint Part 4 §1); the waived row notes it. |
| IC-2 (VAC-2, metric values → 11 pt) | Value font stays `.system(size: 11, weight: .regular).monospacedDigit()` at `:115-116`; no `size: 10.5` | pass | `testValueFontIsElevenPointRegularMonospacedDigit` and the value-size guard inside `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven` both failed at red `92c28ca` and passed at green `ff61edf` when `:116` flipped. `testValueFontKeepsMonospacedDigit` passed unchanged. |
| IC-3 (VAC-3, metric block stack spacing → 0) | `:103` reads `VStack(alignment: .center, spacing: 0)` | pass | New guard `testMetricBlockStackUsesZeroVerticalSpacing` failed at red `92c28ca` while `:103` carried `spacing: 1`, and passed at green `ff61edf` when `:103` flipped. |
| IC-4 (VAC-4, network block row spacing → 0) | `:143` reads `VStack(alignment: .leading, spacing: 0)` | pass | New guard `testNetworkBlockStackUsesZeroRowSpacing` failed at red `92c28ca` while `:143` carried `spacing: 1`, and passed at green `ff61edf` when `:143` flipped. |
| IC-5 (VAC-5, widest-value clearance, Option 1) | `blockWidth` stays 34.0 pt. `"100%"` at 11 pt regular monospacedDigit fits with total clearance ≥ 2.5 pt (relaxed threshold, binding user decision Option 1) | pass | `testClearanceForWidestValueAtElevenPointRegularMeetsRelaxedThreshold` passed at `ff61edf`. The guard measures the target font through `NSFont`, so it passes at red and at green. Recorded measurement: width 31.22 pt, clearance 2.78 pt (constants `:293`, `:299`; threshold `:285`). |
| IC-6 (VAC-6, label-row clearance at 7 pt) | The label row fits the 34.0 pt block on one line at 7 pt regular | pass | `testLabelRowClearanceForMemRowAtSevenPointRegularMeetsThreeAndAHalfPoints` passed at `ff61edf`. The guard measures the target font, so it passes at red and at green. Recorded measurements: MEM row 10.91 pt ≥ 3.5 (4.0 pt dot + 2.0 pt gap + 17.09 pt label), CPU 18.69 pt, GPU 18.48 pt (constants `:332`, `:348`, `:364`). |
| IC-7 (VAC-7, network rate fonts retained) | Upload `:153` and download `:167` stay `.system(size: 9, weight: .regular).monospacedDigit()`; no `.medium` or `.bold` | pass | The compound network assertion inside `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven` passed at red `92c28ca` and at green `ff61edf`. |
| IC-8 (VAC-8, network-block clearance retained) | `networkBlockWidth` stays 50.0 pt. `"999 MB/s"` at 9 pt regular monospacedDigit plus the 6.0 pt dot leaves ≥ 1.8 pt for `Spacer(minLength: 1)` | pass | `testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum` passed at `ff61edf`. The guard measures the target font, so it passes at red and at green. Recorded measurement: width 42.11 pt, clearance 1.89 pt (constants `:386`, `:403`). |
| IC-9 (VAC-9, zero animation) | No `.animation` or `.contentTransition` modifier on the status item path | pass | `rg -n '\.animation\|\.contentTransition'` over `MenuBarStackedItemView.swift`, `MenuBarBlockModel.swift`, `StatusItemController.swift`, `MenuBarAccessibility.swift` returns comment-only hits at `MenuBarStackedItemView.swift:14`, `:15`, `:138` and no modifier in any of the four files. `MenuBarRedrawChurnTests` passed: 4 tests, 0 failures (`testMenuBarBlockViewBodyHasNoAnimation`, `testStackedItemBodyHasNoAnimationOrContentTransition`). |
| IC-10 (VAC-10, length contract) | `MenuBarLayout.length` stays 168 pt (4 blocks), 114 pt (3), 92 pt (1 standard + network), 76 pt (2), 54 pt (network only), 38 pt (1), 4 pt (all off). `blockWidth` 34.0, `networkBlockWidth` 50.0, `gap` 4.0, `padding` 2.0 unchanged | pass | `MenuBarLayoutTests` passed at `ff61edf`: 13 tests, 0 failures. `git diff main...HEAD -- StatsLite/` touches no width or length line. The 130 pt row stays unpinned (gate note N3, recorded deferral). |
| IC-11 (suite) | Green run executes 227 tests with 0 failures, no test deleted | pass | T4 re-run at `ff61edf`: `Executed 227 tests, with 0 failures (0 unexpected)`, `** TEST SUCCEEDED **`, zero `Test Case ... failed` lines. Red run at `92c28ca`: 227 tests, exactly 5 failures (recorded in the red commit message). |
| IC-12 (scope) | The production diff against `main` contains exactly four lines: `:103` `spacing: 1` → `spacing: 0`; `:112` `size: 8` → `size: 7`; `:116` `size: 10.5` → `size: 11`; `:143` `spacing: 1` → `spacing: 0` | pass | `git diff main...HEAD -- StatsLite/` shows only those four lines in `MenuBarStackedItemView.swift` (4 insertions, 4 deletions). Every other change lives in `StatsLiteTests/MenuBarValueTypographyTests.swift`. |
| Screenshot and strip captures (dark, light, menu bar strips) and visual render checks | Visual render captures | waived (user authority, 2026-10-16, no Screen Recording permission) | Same reason row for all visual captures. Probe `screencapture -x` exits 1 with `could not create image from display` (`8b0ce41` plus the T1 probe for this plan). Basis: `waiver-note.md` in this directory. The user override for 7 pt label legibility is on record (blueprint Part 4 §1): the labels adopt 7 pt despite the earlier non-Retina legibility finding. VoiceOver access covers the non-visual path. |

Counts: 13 rows — 12 `pass`, 1 `waived`.
