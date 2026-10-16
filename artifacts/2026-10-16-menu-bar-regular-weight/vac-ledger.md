# VAC Ledger — Menu Bar Value Font `.medium` → `.regular`

Plan: `2026-10-16-menu-bar-regular-weight`
Branch: `feat/2026-10-16-menu-bar-regular-weight`
Red SHA: `5e2a97c` · Green SHA: `b1e27cc`
Suite: `Executed 203 tests, with 0 failures` (xcodebuild, serial testing flags)

Waiver (user authority, 2026-10-16): screenshot-based checks are skipped. This session has
no macOS Screen Recording permission; `screencapture -R` and cross-process `-l` capture fail
with exit 1. The user waived the visual captures and ordered proceed to merge.

## Verdicts

| Check | Verdict | Evidence |
| --- | --- | --- |
| VAC-1 value font weight `.regular` | PASS | `MenuBarValueTypographyTests.testValueFontIsTenAndAHalfPointRegularMonospacedDigit` green at `b1e27cc`; red at `5e2a97c`. Source: `StatsLite/MenuBarStackedItemView.swift:116` = `.font(.system(size: 10.5, weight: .regular).monospacedDigit())` (`nl -ba` capture). |
| VAC-2 monospaced digits | PASS | `testValueFontKeepsMonospacedDigit` green; token contains `.monospacedDigit()`. |
| VAC-3 block width and clearance | PASS | `testClearanceForWidestValueAtRegularMeetsThreeAndAHalfPoints`: `"100%"` @ 10.5 pt `.regular` = 29.93 pt, clearance 4.07 pt ≥ 3.5 pt (`.frame(width: block.width)` still 34.0 pt, `:120`). Measurement, not a prior. |
| VAC-4 label typography unchanged | PASS | `testLabelFontStaysBoldSecondary`: `:111-113` = `.system(size: 8, weight: .bold)` + `.secondary`. |
| VAC-5 zero animation | PASS | `rg '\.animation\|\.contentTransition' StatsLite/MenuBarStackedItemView.swift` → hits only at lines 14, 15, 138 (comments). `MenuBarRedrawChurnTests` green in the 203-test suite. |
| VAC-6 state color preservation | PASS | `git diff main...HEAD` touches only the weight token at `:116` plus the test file; no `foregroundStyle` / tint code changed. Gate re-verified tint behavior at HEAD (`MenuBarBlockModel.swift:130`, `:172-176`, commit `d985784`). |
| VAC-7 visual blend with clock | WAIVED (user authority, 2026-10-16) | Screenshot capture impossible without Screen Recording permission. Basis instead: VAC-1 (exact `.regular` weight) — the stroke-weight defect is removed by construction. |
| VAC-8 pinned status item length | PASS | `MenuBarLayoutTests` green in the 203-test suite; lengths 114/168/76/38 pt verified by gate computation. |

Screenshot-based render checks (visual blend, dark/light strips): **waived (user authority,
2026-10-16)**. All test-based checks: **pass**. Any visual defect remains a blocking failure
if observed later (zero-tolerance visual policy).
