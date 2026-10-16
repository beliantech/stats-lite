# Design Gate Report — Menu Bar Label + Network Typography Blueprint (Re-gate)

**Verdict: PASS.** The designer re-issued the blueprint with corrections C1-C5
and notes N1-N3 applied. This re-gate verifies C1-C5 only. All five corrections
verify against source and live measurement. The previously passing VACs and the
approved tokens are unchanged. Screenshot checks stay check-only under the user
waiver. The planner can proceed to plan authoring.

## 1. Gate scope

- Original gate: BLOCKED with 5 corrections. Full evidence is in this file at
  git commit `253100b`.
- Re-issued blueprint: designer session
  `2026-10-16T13-31-08-741Z_7c673e56-0215d49d-15bf40c7-c4e1.jsonl`, final
  message (summary) with the blueprint text delivered as the `cat
  /tmp/reissued_blueprint.md` output. Durable copy:
  `artifacts/2026-10-16-menu-bar-label-network-regular/blueprint-reissued.md`.
- Re-gate scope: C1-C5 only, plus spot checks of previously passing VACs,
  tokens, and measurements.
- Source state: unchanged since the original gate. `git diff 9e9e9f2..HEAD`
  before this update adds only this report file. The five blueprint-referenced
  files keep identical git blobs at `6000441`, `a75fd9e`, and `HEAD`
  (`MenuBarStackedItemView.swift` `354e7e0`, `MenuBarBlockModel.swift`
  `85e2745`, `MetricFormatters.swift` `96b853e`, `StatusItemController.swift`
  `f6e40a0`, `MenuBarValueTypographyTests.swift` `f92a929`).
- Rulings carried over: 768 px is the reference width. Widths 375 px, 1440 px,
  and Retina are check-only. Screenshot checks are check-only (user waiver).
- Approved tokens unchanged: label `.system(size: 8, weight: .regular)` +
  `.secondary`, network `.system(size: 9, weight: .regular).monospacedDigit()`,
  value 10.5 pt `.regular` retained.

## 2. C1-C5 resolution

| # | Required correction | Result | Evidence |
|---|---|---|---|
| C1 | VAC-7 selector `:171` → `:172` | PASS | VAC-7 selector reads `StatsLite/MenuBarStackedItemView.swift:172`. Source: `:171` closes the `VStack`; `:172` is `.frame(width: block.width)`. |
| C2 | Fix or delete the `1024 KB/s` row | PASS | Row now reads medium `47.0030`, regular `46.0063`, spacers `−3.0030` / `−2.0063`, spacer delta `+0.9967`. Live re-measurement: `47.003043`, `46.006348`, `−3.003043`, `−2.006348`, delta `0.996695`. Row verdict is `UNREACHABLE (BLOCKED if raw)`; it does not claim PASS. The other 15 rows are byte-identical to the originally verified table. |
| C3 | Part 2 network skeleton line ranges | PASS | Header states body `142–173`, skeleton as shown `142–191`, struct `139–192`. Source: body `:142`–`:173`, `valueColor` `:175`–`:182`, `secondaryValueColor` `:184`–`:191`, struct close `:192`. |
| C4 | Formatter boundary `44-67` → `44-64` | PASS | Blueprint reads `StatsLite/MetricFormatters.swift:44-64` and "lines 44–64". Source: `networkRate(_:)` spans `:44`–`:64`. |
| C5 | Viewport table: 768 px reference, others check-only | PASS | Tablet (768 px) row = `Reference Width`. 375 px, 1440 px, Retina rows = `Check-only`. All VAC target-environment lines read "768 px reference width, 375 px, 1440 px, and Retina check-only". |

C2 delta-sign note: the blueprint column is "Spacer Delta" (regular spacer minus
medium spacer) = `+0.9967`. The original gate's `−0.9967` was the text-width
delta. Both numbers derive from the same live measurement. There is no conflict.

## 3. Spot checks — previously passing items

| Item | Result | Evidence |
|---|---|---|
| Label token (8 pt `.regular` + `.secondary`) | Unchanged | Stated in the intro, the tokens section, VAC-4, and appendix step 3. Source `:112` is still `.bold` (pre-change state) with a TARGET annotation on line 112. |
| Network token (9 pt `.regular` mono) | Unchanged | Stated in scope, tokens, VAC-6, skeleton annotations at lines 153/167. Source `:153` and `:167` are still `.medium` (pre-change state). |
| Value token (10.5 pt `.regular` mono) | Unchanged | VAC-1 selector `:115-116` unchanged. Source `:116` matches the token exactly. |
| VAC selectors | Unchanged | VAC-1 `:115-116`, VAC-3 `:120`, VAC-4 `:111-113`, VAC-5 `:104-114`, VAC-6 `:152-153` / `:166-167`, VAC-11 `StatusItemController.length`. |
| N1 (VAC-6 wording) | Applied | VAC-6 reads "rate `Text` font modifiers at lines 153 and 167 (with `Text` declarations at lines 152 and 166)". |
| N2 (stale VAC comment refs) | Applied | Appendix step 1 instructs updating comments at lines 137–138 from `(VAC-N1)`/`(VAC-9)` to `(VAC-7)`/`(VAC-8)`. Source still carries the stale refs (pre-change state), as expected. |
| N3 (`.light` −0.40) | Applied | Label Option Comparison §2 marks the `-0.40` weight claim `unverified prior`. |
| VAC-8 (no animation) | Unchanged, PASS | `rg` finds `.animation` / `.contentTransition` only in comments at `:14`, `:15`, `:138`. No modifiers exist. |
| VAC-10 (visual blend) | Check-only | "Check-only per user screenshot waiver". Dark/Light viewport rows: `Check-only (Visual) / Applicable (Tokens)`. |
| Measurement tables | Unchanged | The diff against the original blueprint changes only the `1024 KB/s` row in the width table. Label, value, cap-height, and contrast numbers are untouched. |

## 4. Measurement receipts (re-run)

Method: live AppKit `NSFont` APIs, `NSString.size(withAttributes:)`, harness
`/tmp/gate_measure.swift`, re-run for this re-gate. Results are identical to
the original gate:

- Labels, 8 pt regular: CPU `17.3164`, GPU `17.5625`, MEM `19.3594`, MEM row
  `25.3594`, clearance `8.6406`, cap height `5.6367`. All match the blueprint.
- Values, 10.5 pt regular mono: `"100%"` `29.9260` (clearance `4.0740`),
  `"99%"` `23.2200`, `"0%"` `16.5139`, `"--%"` `19.8977`. Cap height `7.3982`.
- Network, 9 pt: `"999 MB/s"` medium `42.9085` / regular `42.1084`, regular
  spacer `1.8916`. `"-- KB/s"` `32.0194` / `31.4868`. `"0 KB/s"` `29.0843` /
  `28.4985`. `1024 KB/s` row: `47.0030` / `46.0063`.
- `1.0 GB/s` spacer delta: unrounded widths give `0.768672` → `0.7687`, which
  matches the blueprint's `+0.7687`.
- Contrast: `secondaryLabelColor` alpha `0.498039` (Aqua) and `0.54902` (Dark
  Aqua). Composite dark `153.525` ratio `5.8898`; composite light `117.97`
  ratio `3.8118`. All match the blueprint.

## 5. Test evidence

- Code is unchanged since the original gate, so the original full-suite result
  stands: `** TEST SUCCEEDED **`, 223 tests, 0 failures at `9e9e9f2`.
- Re-gate re-ran `MenuBarValueTypographyTests` at `253100b`:
  `** TEST SUCCEEDED **`, 5 tests, 0 failures.
- The suite still asserts the current `.bold` / `.medium` state (`:27`, `:31`,
  `:184`, `:218`). The blueprint's "was" claims and appendix step 8 match these
  lines and method names. The two "add a test" items remain real gaps.

## 6. Check-only items

- VAC-10 and every Dark/Light "how it looks" claim: check-only. Screenshot
  waiver, user authority.
- Widths 375 px, 1440 px, and Retina: check-only. 768 px is the reference width.
- Baseline PNG inspection claims in the Visual Evidence section: check-only,
  same waiver.
- Geometry in VAC-3, VAC-5, VAC-7: verified by measurement at the reference
  width. Block widths are pinned, so the numbers hold at any width.
