# Design Gate Report — Menu Bar Label + Network Typography Blueprint

**Verdict: BLOCKED.** The blueprint needs 5 exact corrections before implementation.
All VAC selectors, tokens, and width measurements otherwise verify against main.
Every number below is a live AppKit measurement or a source reading. No priors.

## 1. Gate scope and baseline

- Blueprint: designer session `2026-10-16T12-28-42-700Z_2e67ac4b-ad8ec132-0814dcf2-6661.jsonl`, final assistant message.
- Named baseline: `6000441` / `a75fd9e`. Current `main`: `9e9e9f2`.
- The five blueprint-referenced files are byte-identical across `6000441`, `a75fd9e`, and `HEAD` (identical git blob hashes):
  `StatsLite/MenuBarStackedItemView.swift` `354e7e0`, `StatsLite/MenuBarBlockModel.swift` `85e2745`,
  `StatsLite/MetricFormatters.swift` `96b853e`, `StatsLite/StatusItemController.swift` `f6e40a0`,
  `StatsLiteTests/MenuBarValueTypographyTests.swift` `f92a929`.
- Result: this gate applies to the named baseline and to current `main`.
- Approved tokens: label `.system(size: 8, weight: .regular)` + `.secondary`, network `.system(size: 9, weight: .regular).monospacedDigit()`, value 10.5 pt `.regular` unchanged.
- Current `main` state: label is `.bold` at `:112`, network is `.medium` at `:153` and `:167`, value is `.regular` at `:116`. The blueprint's "was" claims match.
- Width ruling: 768 px is the reference width. Widths 375 px, 1440 px, and Retina are check-only.
- Screenshot ruling: the user waived screenshot checks (no Screen Recording permission). Screenshot checks are check-only.

## 2. Required corrections

| # | Location in blueprint | Current text | Correction |
|---|---|---|---|
| C1 | VAC-7 selector | `MenuBarStackedItemView.swift:171` as the network container frame | Frame is at `:172`. Line `:171` closes the `VStack`. Write `:172`. |
| C2 | Network width table, `1024 KB/s` row | medium `47.6724`, regular `46.7974`, delta `+0.8750` | Not reproducible. Measured: medium `47.0030`, regular `46.0063`, delta `−0.9967`. Spacers: `−3.0030` / `−2.0063`. Row verdict stays BLOCKED. Fix the numbers or delete the row. |
| C3 | Part 2, network skeleton header | "Target implementation at lines 142–178" | `var body` spans `:142`–`:173`. The shown skeleton (body + `valueColor` + `secondaryValueColor`) spans `:142`–`:191`. The struct spans `:139`–`:192`. Use `142–191`, or `142–173` for body only. |
| C4 | Formatter boundary rule | `StatsLite/MetricFormatters.swift:44-67` | `networkRate(_:)` spans `:44`–`:64`. Write `44-64`. |
| C5 | Viewport and Mode Applicability table | 768 px row says "Check-only", 1440 px row says "Applicable" | Inverts the standing ruling. Set 768 px to reference. Set 375 px, 1440 px, and Retina rows to check-only. |

## 3. VAC results

| VAC | Result | Evidence |
|---|---|---|
| VAC-1 value font retained | PASS | Selector `:115-116` correct. Token at `:116` is exactly `.font(.system(size: 10.5, weight: .regular).monospacedDigit())`. Test `testValueFontIsTenAndAHalfPointRegularMonospacedDigit` passes. |
| VAC-2 digit alignment | PASS | `.monospacedDigit()` at `:116`. Test `testValueFontKeepsMonospacedDigit` passes. |
| VAC-3 block width and value clearance | PASS (measurement) | `.frame(width: block.width)` at `:120` correct. `MenuBarLayout.blockWidth = 34` (`MenuBarBlockModel.swift:55`). Measured `"100%"` at 10.5 pt regular mono = `29.9260`, clearance `4.0740` ≥ 3.5. Blueprint numbers `29.93` / `4.07` match. `.lineLimit(1)` at `:118`. |
| VAC-4 label typography (revised) | PASS (selector + state) | Selector `:111-113` correct. `:112` is `.font(.system(size: 8, weight: .bold))` and `:113` is `.foregroundStyle(.secondary)`. "Was .bold" matches main. Option (a) widths measured: CPU `17.3164`, GPU `17.5625`, MEM `19.3594`. All match the blueprint to 4 decimals. Visual appearance: check-only (screenshot waiver). |
| VAC-5 label row clearance | PASS (measurement) | Selector `:104-114` correct. `HStack` spacing 2, dot frame 4. MEM row = 4 + 2 + 19.3594 = `25.3594`, clearance `8.6406` (blueprint `25.36` / `8.64` match). CPU clearance `16.6836` > 16.0. GPU clearance `16.4375` > 16.0. |
| VAC-6 network weight (scope addition) | PASS (selectors + state) | `.font(.system(size: 9, weight: .medium).monospacedDigit())` sits at exactly `:153` and `:167`. "Was .medium" matches main. Wording note N1 below. |
| VAC-7 network clearance (scope addition) | BLOCKED on selector (C1), measurements PASS | Selector must change `:171` → `:172`. `MenuBarLayout.networkBlockWidth = 50` (`MenuBarBlockModel.swift:59`). Worst formatted string `"999 MB/s"` measured `42.1084` at 9 pt regular mono (blueprint `42.11` match). Spacer = 50 − 6 − 42.1084 = `1.8916` ≥ 1.8. I verified all 16 table rows. Only the `1024 KB/s` row fails reproduction (C2). `"999 MB/s"` is the true worst case: measured `"999 KB/s"` `40.1704`, `"999 GB/s"` `40.9614`, `"9.9 GB/s"` `37.9644`. |
| VAC-8 discrete rendering | PASS | `rg '\.animation\|\.contentTransition'` on the file finds only comments at `:14`, `:15`, `:138`. No modifiers exist. Full suite ran: **223 tests, 0 failures** at `9e9e9f2`, including `MenuBarRedrawChurnTests`. |
| VAC-9 state colors and dots | PASS | `usageTint` (`MenuBarBlockModel.swift:172-177`) acts on the raw fraction clamped to 0...1 (`MetricTypes.swift:65-67`): `≥0.95` critical, `≥0.80` warning, else primary, nil tertiary. View map `:123-130`: warning → `systemOrange`, critical → `systemRed`, tertiary → `tertiaryLabelColor`. MEM value tint: nil → tertiary, else `.primary` (`MenuBarBlockModel.swift:130`). MEM dot: `dotState.levelColor` (`:107`). Upload dot `systemRed` (`:147`), download dot `systemBlue` (`:161`). |
| VAC-10 visual blend (revised) | CHECK-ONLY | Screenshot-based. Waived by user authority. Note: the invariant holds only after the weight changes land. |
| VAC-11 pinned length | PASS | `StatusItemController.swift:48` (`withLength: MenuBarLayout.length(...)`) and `:179` (`statusItem.length = MenuBarLayout.length(...)`). Formula (`MenuBarBlockModel.swift:69-81`) with 34 / 50 / 4 / 2 yields 114, 168, 76, 38. `MenuBarLayoutTests` asserts all four (`:19`, `:89`, pairs, singles) and passed. |

## 4. Measurement receipts

Method: live AppKit `NSFont` APIs on this Mac, `NSString.size(withAttributes:)`, harness `/tmp/gate_measure.swift`.
Fonts: `NSFont.systemFont` for label weights, `NSFont.monospacedDigitSystemFont` for values and rates.

Labels (pt), blueprint value in brackets, all match:

| Token | CPU | GPU | MEM | MEM row | MEM clearance |
|---|---|---|---|---|---|
| 8 pt bold (current) | 18.0098 [18.0098] | 18.1621 [18.1621] | 20.0879 [20.0879] | 26.0879 [26.0879] | 7.9121 [7.9121] |
| 8 pt regular (option a) | 17.3164 [17.3164] | 17.5625 [17.5625] | 19.3594 [19.3594] | 25.3594 [25.3594] | 8.6406 [8.6406] |
| 7 pt regular (option b) | 15.3057 [15.3057] | 15.5210 [15.5210] | 17.0933 [17.0933] | 23.0933 [23.0933] | 10.9067 [10.9067] |
| 8 pt light (option c) | 17.0580 [17.0580] | 17.2561 [17.2561] | 19.0407 [19.0407] | 25.0407 [25.0407] | 8.9593 [8.9593] |

Values at 10.5 pt regular mono: `"100%"` `29.9260` [29.93], `"99%"` `23.2200` [23.22], `"0%"` `16.5139` [16.51], `"--%"` `19.8977` [19.90].
Clearances: `4.0740`, `10.7800`, `17.4861`, `14.1023`. All ≥ 3.5 where required.

Cap heights: 8 pt `5.6367` [5.64], 7 pt `4.9321` [4.93], 10.5 pt `7.3982` [7.40]. All match.

Network rates at 9 pt, all 15 formatted strings match the blueprint to 4 decimals in both weights, for example:
`"999 MB/s"` medium `42.9085` / regular `42.1084`, spacer regular `1.8916`.
`"-- KB/s"` medium `32.0194` / regular `31.4868`.
`"0 KB/s"` medium `29.0843` / regular `28.4985`.
Only the hypothetical `1024 KB/s` row differs. See C2.

Contrast check (Part 3 and Part 4 claims): `secondaryLabelColor` alpha is `0.498039` (Aqua) and `0.54902` (Dark Aqua), measured.
Composited ratios: dark `5.8898:1` [5.89] on `#1E1E1E`, light `3.8118:1` [3.81] on `#EBEBEB`.
Composite values `153.525` and `117.97` match the blueprint `153.5` and `118.0`.

Formatter claims verified at source (`MetricFormatters.swift:44-64`): integer KB under 1000, `1.0 MB/s` at 1000 KB/s, integer MB from 9.95, `1.0 GB/s` at 1000 MB/s, integer GB from 9.95. Mantissa never exceeds three characters. `"1024 KB/s"` and `"1000 KB/s"` are unreachable.

## 5. Check-only items

- VAC-10 and every Dark/Light "how it looks" claim: check-only. Screenshot waiver, user authority.
- Widths 375 px, 1440 px, and Retina: check-only. 768 px is the reference width.
- Baseline PNG inspection claims in the blueprint's Visual Evidence section: check-only, same waiver.
- Geometry in VAC-3, VAC-5, VAC-7: verified by measurement at the reference width. Block widths are pinned, so the numbers hold at any width.

## 6. Test evidence

Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Debug -derivedDataPath .derivedData test -destination 'platform=macOS'`.
Result: `** TEST SUCCEEDED **`, 223 tests, 0 failures, at `9e9e9f2`.
`MenuBarValueTypographyTests` still asserts the current `.bold` / `.medium` tokens (`:27`, `:31`, `:184`, `:218`). The blueprint's Appendix step 8 targets exactly these lines and method names. Both "add a test" items are real gaps: no MEM row clearance test and no network worst-case clearance test exist today.

## 7. Non-blocking notes

- N1 (VAC-6 wording): `:153` and `:167` are the `.font(...)` lines. The `Text(...)` declarations are `:152` and `:166`. Reword to "rate Text font modifiers at `:153`, `:167`".
- N2 (code comment drift): `MenuBarStackedItemView.swift:137-138` cites `(VAC-N1)` and `(VAC-9)` for the width pin and zero animation. This blueprint numbers them VAC-7 and VAC-8. Update during implementation.
- N3 (unverified prior): the `.light` weight value `-0.40` does not reproduce through public `NSFontDescriptor` APIs (`NSCTFontWeightAttribute` returned nil). Keep the `-0.40` claim marked unverified prior. It does not affect any VAC, because option (c) was rejected.
- N4: option (b) and option (c) clearance math checks out as stated. Option (a) remains the approved token.
