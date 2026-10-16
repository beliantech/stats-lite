# Design Gate Report: Menu Bar Typography & Spacing Blueprint

- Gate target: "Design Blueprint: Menu Bar Typography & Spacing Update (Emulate Stats App Look)",
  final message of designer session `2026-10-16T18-41-00-621Z_18548fff-2cf74cf8-fa2d894d-baa0.jsonl`.
- Gated against: `main` at `cd03d01`.
- Reference: `artifacts/2026-10-16-emulate-stats-layout/reference-stats.png` (check-only, under the standing screenshot waiver).
- Gate date: 2026-10-17.
- Verdict: **BLOCKED** (documentation defects only; every design token and every numeric claim verified correct).

All measurements below were reproduced live on this Mac with AppKit/SwiftUI scripts
compiled from the gate checkout. `MenuBarLayout.length` numbers come from the real
production source (`StatsLite/MenuBarBlockModel.swift` at `cd03d01`), compiled into a
harness, not from a copy.

---

## 1. Verdict summary

The design content of the blueprint is sound. Every width, clearance, height, and
length-contract number in the blueprint reproduces to the printed digit. Both binding
user decisions are recorded correctly. The four Appendix A "Current Code" quotes match
current source exactly. The reference screenshot attributes match.

Three defects block the gate. All three are text corrections in the blueprint. None
changes a design token, and none requires a new measurement round.

| ID | Defect | Class |
|---|---|---|
| B1 | Appendix B omits the IC-10 test update that Edit 3 forces. The plan leaves the suite red. | Blocking |
| B2 | Line-number citations in the VACs and Appendix A are wrong (10 of 11 citations). The blueprint claims they were verified at HEAD. | Blocking |
| B3 | Part 4 §3 claims the controller calls `setAccessibilityValue(...)`. No such call exists in the codebase. | Blocking |

---

## 2. User decision records (binding; verified, not re-argued)

1. **7 pt label override**: record exists in Part 4 §1. The prior finding is quoted
   (7 pt cap height 4.93 pt; light-mode contrast 3.81:1), and the explicit user
   override to enforce 7 pt `.regular` + `.secondary` is stated. Live check: SF 7 pt
   regular cap height = 4.9321 pt, which matches the recorded 4.93 pt.
2. **Option 1 for the 11 pt clearance conflict**: recorded in the Clearance Decision
   section and Appendix B. `MenuBarLayout.blockWidth` stays 34.0 pt (live: 34.0),
   item lengths stay 114/168/76/38 (live: verified, see §4), and the clearance guard
   threshold relaxes from 3.5 pt to 2.5 pt (measured 2.7778 pt, see §3).

---

## 3. Live measurement reproduction (all PASS)

Script: `/tmp/gate-measure/widths.swift` (AppKit `NSString.size` with the exact fonts),
`/tmp/gate-measure/heights.swift` (SwiftUI `NSHostingView.fittingSize` on verbatim
replicas of both block views at target tokens), compiled with the Xcode-CLT `swiftc`
on this machine.

### 3.1 Value widths and clearance (VAC-5)

| String | 10.5 pt width (blueprint) | 10.5 pt live | 11 pt width (blueprint) | 11 pt live | 11 pt clearance live |
|---|---|---|---|---|---|
| "0%" / "5%" | 16.5139 | 16.513916 | 17.2358 | 17.235840 | 16.764160 |
| "50%" / "99%" | 23.2200 | 23.219971 | 24.2290 | 24.229004 | 9.770996 |
| "100%" | 29.9260 | 29.926025 | 31.2222 | 31.222168 | 2.777832 |
| "--%" | 19.8977 | 19.897705 | 20.7485 | 20.748535 | 13.251465 |

- Margin per side at "100%": 1.388916 pt (blueprint 1.3889). PASS.
- Clearance 2.7778 pt >= 2.5 pt threshold (user decision Option 1). No truncation:
  31.22 pt < 34.0 pt. PASS.

### 3.2 Label rows at 7 pt (VAC-6)

| Row | Blueprint | Live |
|---|---|---|
| "CPU" width / clearance | 15.3057 / > 18.0 | 15.305664 / 18.694336 |
| "GPU" width / clearance | 15.5210 / > 18.0 | 15.520996 / 18.479004 |
| "MEM" row (4 pt dot + 2 pt gap + text) | 23.0933 | 23.093262 |
| "MEM" row clearance / margin per side | 10.9067 / 5.4534 | 10.906738 / 5.453369 |

All PASS. Current 8 pt clearances also match the existing IC-11 test constants
(MEM 8.640625, CPU 16.683594, GPU 16.437500).

### 3.3 Network rates at 9 pt (VAC-8)

| String | Blueprint | Live |
|---|---|---|
| "999 MB/s" width | 42.1084 | 42.108398 |
| "999 MB/s" clearance (50 - 6 - width) | 1.8916 | 1.891602 |
| "5 KB/s" width | 28.50 | 28.498535 |
| "16 KB/s" width | 34.33 | 34.334473 |

Clearance 1.8916 pt >= 1.8 pt for `Spacer(minLength: 1)`; no truncation. PASS.

### 3.4 Heights vs status bar thickness

| View (target tokens) | Blueprint | Live (NSHostingView.fittingSize) |
|---|---|---|
| `MenuBarBlockView`, spacing 0 | 23.0 pt (down from 24.0) | 23.0000 (current tokens: 24.0000) |
| `MenuBarNetworkBlockView`, spacing 0 | 22.0 pt (down from 23.0) | 22.0000 (current tokens: 23.0000) |
| `NSStatusBar.system.thickness` | 22.0 pt | 22.0 |

PASS. Supporting figures also reproduce: baseline-to-baseline label-to-value
13.1113 pt at spacing 1 to 12.1113 pt at spacing 0 (blueprint 13.11 to 12.11);
label-descender to value-cap gap 2.8843 pt (blueprint 2.88); vertical gap between
the two 6 pt network dots 5.0 pt at spacing 0, down from 6.0 pt.

---

## 4. Length contract (VAC-10 and Part 3 §2 table) — PASS

Compiled the real `MenuBarLayout.length` from `MenuBarBlockModel.swift` at `cd03d01`
(with `MetricTypes.swift`, `MetricFormatters.swift`, `MetricMath.swift`,
`DesignTokens.swift`) and evaluated every row:

| Configuration | Blueprint | Live |
|---|---|---|
| All four (CPU+RAM+GPU+NET) | 168.0 | 168.0000 |
| Three standard | 114.0 | 114.0000 |
| Two standard pair | 76.0 | 76.0000 |
| One standard + NET | 92.0 | 92.0000 |
| Two standard + NET | 130.0 | 130.0000 |
| Network only | 54.0 | 54.0000 |
| Single standard | 38.0 | 38.0000 |
| All disabled | 4.0 | 4.0000 |

Constants live: blockWidth 34.0, networkBlockWidth 50.0, gap 4.0, padding 2.0.
The function signature matches the VAC-10 selector, including the defaulted
`showNetwork` parameter.

---

## 5. VAC-by-VAC selector check

Selector semantics are correct for all ten VACs. Line numbers are not. See B2 for
the full correction table.

| VAC | Selector target found? | Live status of the invariant |
|---|---|---|
| VAC-1 | Yes, label font modifier (cited :113, actual :112) | Target token `size: 7, weight: .regular` verified against live widths |
| VAC-2 | Yes, value font modifier (cited :117, actual :116) | Target token `size: 11, weight: .regular` + `.monospacedDigit()` verified |
| VAC-3 | Yes, `VStack(alignment: .center, spacing: 1)` (cited :102, actual :103) | Target `spacing: 0` measured 23.0 pt height |
| VAC-4 | Yes, network `VStack(alignment: .leading, spacing: 1)` (cited :142, actual :143) | Target `spacing: 0` measured 22.0 pt height |
| VAC-5 | Yes, block frame (cited :121, actual :120) | 34.0 pinned, clearance 2.7778 >= 2.5, no truncation |
| VAC-6 | Yes, label HStack (cited :103-115, actual :104-114) | All rows single-line, clearances verified |
| VAC-7 | Yes, both rate font modifiers (cited :152/:165, actual :153/:167) | Token unchanged: `size: 9, weight: .regular` + `.monospacedDigit()` |
| VAC-8 | Yes, network frame (cited :170, actual :172) | 50.0 pinned, clearance 1.8916 >= 1.8, no truncation |
| VAC-9 | Yes, all three types | PASS now and stays PASS: ripgrep for `.animation` or `contentTransition` on `MenuBarStackedItemView.swift` returns only doc-comment mentions (:14, :15, :138) |
| VAC-10 | Yes, `MenuBarLayout.length(showCPU:showRAM:showGPU:showNetwork:)` | All eight combos verified live (§4) |

---

## 6. Appendix A: four production edits — content PASS, lines FAIL

Each "Current Code" quote matches `MenuBarStackedItemView.swift` at `cd03d01`
character for character. Each target token matches the corresponding VAC invariant.
The Part 2 skeletons equal "current source plus the four edits", with no other drift.

Line-number corrections (file has 192 lines at HEAD):

| Edit | Cited line | Holds at cited line | Correct line |
|---|---|---|---|
| 1, block VStack `spacing: 1` | 102 | `var body: some View {` | **103** |
| 2, label font `size: 8` | 113 | `.foregroundStyle(.secondary)` | Text **111**, font **112** |
| 3, value font `size: 10.5` | 117 | `.foregroundStyle(valueColor)` | Text **115**, font **116** |
| 4, network VStack `spacing: 1` | 142 | `var body: some View {` | **143** |

Also: Part 2 line ranges are wrong. `MenuBarBlockView` spans **99-131** (not 99-137);
`MenuBarNetworkBlockView` spans **139-192** (not 139-193). Part 4 §3 cites
`.accessibilityHidden(true)` at :51; the actual line is **45**.

---

## 7. Appendix B: test-file check

Target file `StatsLiteTests/MenuBarValueTypographyTests.swift` at HEAD. Verified:

- `expectedValueFont` (:28) carries `size:10.5`; `expectedLabelFont` (:30) carries
  `size:8`. Appendix B item 1 targets the right constants.
- `testClearanceForWidestValueAtRegularMeetsThreeAndAHalfPoints` (:270) exists.
  Appendix B item 2 describes its current assertions correctly (3.5 pt threshold,
  29.93 pt width, 4.07 pt clearance, all live-verified) and the rename target is unambiguous.
- `testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints` (:307) exists. Its current
  constants (8 pt, MEM 8.6406, CPU 16.6836, GPU 16.4375) match live values, and the
  Appendix B targets (7 pt, 10.9067 / 18.6943 / 18.4790) match live values. The
  >= 3.5 pt and >= 16.0 pt thresholds continue to pass.
- IC-10 and IC-12 identifiers exist and are the network-font and network-clearance
  tests. IC-12 numbers match live (42.1084 / 1.8916).

**B1, the blocking gap**: `testNetworkFontsAreNinePointRegularAndValueStaysSizeTenAndAHalf`
(:222) contains a hardcoded guard at :231:

```swift
XCTAssertTrue(
    blockValueToken.contains("size:10.5"),
    "IC-10: the MenuBarBlockView value line must keep size 10.5; ..."
```

Appendix A Edit 3 moves the value font to `size: 11`. That guard then fails, and the
test name ("ValueStaysSizeTenAndAHalf") turns false. Appendix B item 4 states that
"IC-10 and IC-12 pass unchanged". That is wrong for IC-10. Appendix B must add a step
that updates the :231 assertion to `contains("size:11")` (and its message), and
renames the test. Without that step, the plan produces a red test suite.

---

## 8. Required corrections (exact)

1. **B1**: in Appendix B, add a fifth item under "Network Block Tests" (or extend
   item 4): in `MenuBarValueTypographyTests.swift`, update the IC-10 value-size
   guard at :231 from `size:10.5` to `size:11`, fix the failure message text
   "must keep size 10.5", and rename
   `testNetworkFontsAreNinePointRegularAndValueStaysSizeTenAndAHalf` to a name
   that matches the new contract (for example
   `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven`).
2. **B2**: fix every cited line number to the values in §6. Replace the claim
   "All line numbers verified at HEAD (commits bc861a4 / cd03d01)" with the
   corrected set, or drop line numbers and cite selectors only. The VAC citations
   to fix: VAC-1 :112 (font; Text :111), VAC-2 :116 (font; Text :115), VAC-3 :103,
   VAC-4 :143, VAC-5 :120, VAC-6 :104-114, VAC-7 :153 and :167, VAC-8 :172.
   Part 2 ranges: 99-131 and 139-192. Part 4 §3: :45.
3. **B3**: in Part 4 §3, delete the claim that the controller calls
   `setAccessibilityValue(...)`. Live check: `updateAccessibility()`
   (`StatusItemController.swift:192-196`) sets only `setAccessibilityElement(true)`,
   `setAccessibilityTitle("StatsLite")`, and `setAccessibilityLabel(compositeLabel)`.
   `rg setAccessibilityValue` over `StatsLite/` returns zero hits. The correct
   statement: all metric text rides in the composite accessibility label; the
   typography edits change no accessibility strings, which preserves the invariant
   the section wants.

---

## 9. Non-blocking observations

- **N1 (stale production comment)**: `MenuBarBlockModel.swift:56-58` still says the
  widest rate "999 MB/s" is 42.91 pt with 1.09 pt clearance and cites "appendix B §1".
  Live: 42.91 pt is the width at 9 pt **medium** (42.908494, clearance 1.091506) —
  the pre-flip token. At 9 pt regular it is 42.1084 pt with 1.8916 pt clearance, which
  is what the blueprint and IC-12 use. Recommend updating that comment in a separate
  docs commit; it is not one of the four Appendix A edits.
- **N2 (test names go stale but stay green)**: after Appendix B item 1, FM1's
  `testValueFontIsTenAndAHalfPointRegularMonospacedDigit` (:148) passes on the
  updated constant but keeps a "TenAndAHalf" name; IC-4's
  `testLabelFontIsEightPointRegularSecondary` (:187) likewise says "EightPoint" and
  its message says "must be 8 pt". Recommend renaming both with the B1 fix.
- **N3 (130 pt row)**: the Part 3 §2 table lists the two-standard-plus-network row
  (130 pt); VAC-10 does not. `MenuBarLayout.length` evaluates 130.0000 live, and the
  92/54/4 pt rows have unit tests (`testCPUPlusNetworkTotal92`, `testNetworkOnlyTotal54`,
  `testAllMetricsOffIsPaddingOnly4`), but no test pins 130. Add
  `testCPURAMPlusNetworkTotal130` to `MenuBarLayoutTests.swift` or drop the 130 row
  from Part 3 so the contract and the suite agree.
- **N4 (stale test header)**: `MenuBarValueTypographyTests.swift:6-9` still describes
  the red phase (":112 carries .bold", ":153 and :167 carry .medium"). Those lines and
  their numbers are correct; the weights were fixed in 8a82730. Refresh the comment
  when Appendix B lands.

---

## 10. Screenshot check (check-only, standing waiver)

- `reference-stats.png` attributes confirmed with `sips`: 386x64 px, 144 DPI,
  Display P3, which is 193.0x32.0 pt at 2x. Matches the blueprint.
- Visual inspection is consistent with the blueprint's read: small category labels
  above prominent monospaced-digit values, compact label-to-value stack, network rows
  with a leading red/blue dot column and trailing rate text. No layout claim in the
  blueprint depends on the screenshot alone; every numeric claim has a live
  measurement in §3-§4.

---

## 11. Reproduction

```bash
# widths.swift, heights.swift: /tmp/gate-measure/ (AppKit + SwiftUI scripts)
swiftc -O widths.swift -o widths && ./widths
swiftc -O heights.swift -o heights && ./heights
# real MenuBarLayout.length from HEAD:
swiftc -O <repo>/StatsLite/{MenuBarBlockModel,MetricTypes,MetricFormatters,MetricMath,DesignTokens}.swift main.swift -o layout-main && ./layout-main
```

`xcodebuild` is unavailable on this machine (only CommandLineTools), so the XCTest
suite itself did not run; the source-token and arithmetic assertions above were
reproduced with equivalent standalone compilations of the same production sources.

---

**Final verdict: BLOCKED.** Fix B1, B2, and B3 in the blueprint text, then this
blueprint passes without a new measurement round. All design tokens, all measurements,
and both user decision records stand as verified.
