# Design Gate Report (Re-Gate): Menu Bar Typography & Spacing Blueprint

- Gate target: "Design Blueprint: Menu Bar Typography & Spacing Update (Emulate Stats
  App Look)", final message of designer session
  `2026-10-16T19-17-58-695Z_ae6d7794-a3531d23-bb51a684-b894.jsonl` (the corrected
  re-issue that applies B1-B3 from the first gate).
- Prior gate: `main` at `cd03d01`, verdict BLOCKED on B1/B2/B3
  (see git history of this file at commit `4697230`).
- Gated against: `main` at `4697230`. This commit is docs-only; production source is
  byte-identical to `cd03d01` (`git diff cd03d01..HEAD` touches only
  `artifacts/2026-10-16-emulate-stats-layout/`).
- Reference: `artifacts/2026-10-16-emulate-stats-layout/reference-stats.png`
  (check-only, standing screenshot waiver).
- Gate date: 2026-10-17.
- Verdict: **BLOCKED** (three residual line-citation defects, all text-only; B1
  substance, B3 substance, every design token, every measurement, and both user
  decision records re-verified correct).

All measurements below were reproduced live on this Mac with the gate harness
binaries in `/tmp/gate-measure/` (AppKit `NSString.size`, SwiftUI
`NSHostingView.fittingSize`), compiled from the gate checkout.

---

## 1. Verdict summary

The three original blockers are substantively resolved:

| ID | Prior defect | Re-gate result |
|---|---|---|
| B1 | Appendix B omitted the IC-10 test update; plan left the suite red | **PASS**. Full walk of `MenuBarValueTypographyTests.swift` at HEAD confirms every hardcoded size assertion the four edits force is enumerated, including the IC-10 `size:11` update at :231 with message and rename. See §2. |
| B2 | 10 of 11 line citations wrong while the blueprint claimed verification at HEAD | **The ten mandated citations are now all correct** (§3). Two further citation defects remain (R1, R2), and Appendix B carries ~17 imprecise test-file line numbers (R3). See §4-§5. |
| B3 | Blueprint claimed the controller calls `setAccessibilityValue(...)` | **PASS**. The corrected description matches `StatusItemController` at HEAD; `rg setAccessibilityValue` over `StatsLite/` and `StatsLiteTests/` returns zero hits. See §6. |

Spot-checks pass: the four Appendix A "Current Code" quotes match HEAD character for
character, every measurement in the re-issue equals the value the first gate verified
live (re-run this round, §7), and both binding user decision records are unchanged
(§8).

Three defects still block, all of the same class as the original B2 (line numbers
wrong under the blueprint's own claim "All line numbers verified at HEAD"):

| ID | Defect | Class |
|---|---|---|
| R1 | VAC-7 invariant text cites the download rate Text at "line 165"; the actual line is 166 (:165 is blank). | Blocking |
| R2 | Part 4 §3 cites `StatusItemController.swift:191-196` for `updateAccessibility()`; the function spans 192-196. Line 191 is a doc-comment line. The first gate verified 192-196. | Blocking |
| R3 | Appendix B cites ~17 test-file line numbers that do not hold at HEAD (targets remain unambiguous via quoted symbols and values). Full correction table: §5. | Blocking |

None of R1-R3 changes a design token, a test change, or a measurement. No new
measurement round is needed. After the text corrections in §9, this blueprint passes.

---

## 2. B1 re-verification: test-file sweep is complete (PASS)

Walked `StatsLiteTests/MenuBarValueTypographyTests.swift` (408 lines) at HEAD line by
line. The four production edits force changes to the assertions below; every one
appears in Appendix B (item numbers refer to the re-issued Appendix B):

| Forced change | HEAD line | Appendix B item |
|---|---|---|
| `expectedValueFont` `size:10.5` → `size:11` | :28 (doc comment :27) | item 1 ✓ |
| `expectedLabelFont` `size:8` → `size:7` | :30 (doc comment :29) | item 1 ✓ |
| FM1 message "size: 10.5" → "size: 11", method + MARK rename | :161, :148, :146 | item 2 ✓ |
| IC-2 `.monospacedDigit()` guard passes unchanged | :169-183 | item 3 ✓ (correct) |
| IC-4 message "8 pt" → "7 pt", method + MARK rename | :206, :187, :185 | item 4 ✓ |
| **IC-10 guard `contains("size:10.5")` → `contains("size:11")`** | **:231** | **item 5 ✓** |
| IC-10 message "must keep size 10.5" → "must keep size 11" | :233-235 | item 5 ✓ |
| IC-10 method rename + MARK "value size stays 10.5" → "stays 11" | :222, :220 | item 5 ✓ |
| IC-10 network compound assertion passes unchanged | :254-265 | item 5 ✓ (correct) |
| IC-3 font `ofSize: 10.5` → `11.0` | :271 | item 6 ✓ |
| IC-3 threshold `>= 3.5` → `>= 2.5` (Option 1) | :283-289 | item 6 ✓ |
| IC-3 width `29.93` → `31.22` | :293 | item 6 ✓ |
| IC-3 clearance `4.07` → `2.78` | :299 | item 6 ✓ |
| IC-11 font `ofSize: 8` → `7.0` | :308 | item 7 ✓ |
| IC-11 MEM clearance `8.6406` → `10.9067` | :332 | item 7 ✓ |
| IC-11 CPU clearance `16.6836` → `18.6943` | :348 | item 7 ✓ |
| IC-11 GPU clearance `16.4375` → `18.4790` | :364 | item 7 ✓ |
| IC-11 MEM message "at 8 pt" → "at 7 pt" | :326 | item 7 ✓ |
| IC-12 network numbers pass unchanged (42.1084 / 1.8916 / 1.8) | :372-407 | item 8 ✓ (correct) |

Additional completeness checks:

- `MenuBarValueTypographyTests.swift` contains no hardcoded VStack spacing
  assertion (`rg spacing` → zero hits), so Edits 1 and 4 force no test change.
- No other file under `StatsLiteTests/` pins the affected font sizes or spacings
  (`rg 'size: ?(8|10\.5)|spacing: ?1|10\.5'` outside this file → zero hits).
  `MenuBarRedrawChurnTests.swift` walks body trees for `.animation` /
  `.contentTransition` only; it is unaffected.

B1 is resolved: without the prior B1 fix the suite would end red at the IC-10 guard;
the re-issued Appendix B now changes that guard.

---

## 3. B2 re-verification: the ten mandated citations (PASS)

Checked against `StatsLite/MenuBarStackedItemView.swift` (192 lines) at HEAD:

| Citation | Re-issue | HEAD | Status |
|---|---|---|---|
| VAC-1 label font (Text :111) | :112 | :112 | ✓ |
| VAC-2 value font (Text :115) | :116 | :116 | ✓ |
| VAC-3 block VStack | :103 | :103 | ✓ |
| VAC-4 network VStack | :143 | :143 | ✓ |
| VAC-5 block frame | :120 | :120 | ✓ |
| VAC-6 label HStack | :104-114 | :104 (open) to :114 (close) | ✓ |
| VAC-7 rate font modifiers | :153, :167 | :153, :167 | ✓ |
| VAC-8 network frame | :172 | :172 | ✓ |
| Part 2 range, `MenuBarBlockView` | 99-131 | 99 (struct) to 131 (close) | ✓ |
| Part 2 range, `MenuBarNetworkBlockView` | 139-192 | 139 (struct) to 192 (last line) | ✓ |
| Part 4 §3 `.accessibilityHidden(true)` | :45 | :45 | ✓ |
| Appendix A Edit locations | 103 / 112+111 / 116+115 / 143 | all match | ✓ |

The ten VAC line citations and the Part 2 / Part 4 / Appendix A citations above are
correct at HEAD. The residuals R1-R2 are separate citations the correction round did
not fix; they are in §4.

---

## 4. Residual citation defects R1 and R2

- **R1 (VAC-7 invariant text)**: the re-issued invariant reads "Upload rate text
  (line 152) and download rate text (line 165)". At HEAD the upload Text is at :152
  (correct) but the download Text `Text(block.secondaryValueText ?? "-- KB/s")` is at
  **:166**; :165 is a blank line. Correct the parenthetical to "(line 166)".
  The VAC-7 selector (:153/:167) is correct; only the invariant parenthetical is wrong.
- **R2 (Part 4 §3, accessibility controller range)**: the re-issue cites
  `StatusItemController.swift:191-196` for `updateAccessibility()`. At HEAD the
  declaration is at **:192** and the closing brace at :196; :191 is the last line of
  the doc comment ("/// MenuBarItemView used."). Correct the range to **192-196**,
  the value the first gate verified live. The substantive B3 description (three
  configuration calls, composite label) is accurate and needs no change.

---

## 5. Residual citation defects R3: Appendix B line numbers

Every Appendix B target is unambiguous by quoted symbol and old/new value, so no
wrong edit can result; but the line numbers below do not hold at HEAD. Correction
table (cited → actual):

| Appendix B item | Cited | Actual at HEAD |
|---|---|---|
| item 2, FM1 method range | 148-164 | 148-165 |
| item 3, IC-2 method range | 168-184 | 169-183 |
| item 4, IC-4 MARK | 186 | 185 |
| item 4, IC-4 "must be 8 pt" message | 208-210 | 205-210 (phrase at 206) |
| item 5, IC-10 method range | 222-267 | 222-266 |
| item 5, IC-10 compound assertion | 252-266 | 254-265 (250-253 are comment lines) |
| item 6, IC-3 method range | 270-305 | 270-303 |
| item 6, IC-3 threshold message | 285-288 | 286-289 |
| item 6, IC-3 width constant | 292 | 293 |
| item 6, IC-3 clearance constant | 298 | 299 |
| item 7, IC-11 MARK | 306 | 305 |
| item 7, IC-11 method range | 307-372 | 307-368 |
| item 7, IC-11 MEM message | 323 | 326 (message block 324-328) |
| item 7, IC-11 MEM clearance constant | 327 | 332 |
| item 7, IC-11 CPU clearance constant | 344 | 348 |
| item 7, IC-11 GPU clearance constant | 360 | 364 |
| item 8, IC-12 method range | 374-407 | 372-407 |

Appendix B citations that are correct and need no change: :27, :28, :29, :30, :32,
:34, :146, :148 (start), :161, :220, :222 (start), :231, :233-235, :268, :270 (start),
:271, :283 (assertion call start), :307 (start), :308.

Alternatively, Appendix B may drop line numbers entirely and cite method names plus
quoted old values; every item already carries both.

---

## 6. B3 re-verification: accessibility description (PASS)

- `rg setAccessibilityValue` over `StatsLite/` and `StatsLiteTests/` → zero hits at
  HEAD. The corrected blueprint states this explicitly.
- `StatusItemController.updateAccessibility()` at HEAD (:192-196) sets exactly:
  `button?.setAccessibilityElement(true)`, `button?.setAccessibilityTitle("StatsLite")`,
  `button?.setAccessibilityLabel(compositeLabel)`. The blueprint lists the same three
  calls in the same order.
- The claim that typography edits change no accessibility strings holds: all metric
  text rides in the composite label, which the four edits do not touch.

Only the range citation in that section is wrong (R2, §4); the description itself
matches HEAD.

---

## 7. Measurement spot-check (all PASS, unchanged from the first gate)

Re-ran `/tmp/gate-measure/widths` this round. Every number in the re-issue equals the
first gate's verified live value:

| Quantity | Blueprint | Live re-run |
|---|---|---|
| "100%" @11 pt width / clearance | 31.2222 / 2.7778 | 31.222168 / 2.777832 |
| "0%"/"5%" @11 pt | 17.2358 | 17.235840 |
| "50%"/"99%" @11 pt | 24.2290 | 24.229004 |
| "--%" @11 pt | 20.7485 | 20.748535 |
| 10.5 pt widths (0%/50%/100%/--%) | 16.5139 / 23.2200 / 29.9260 / 19.8977 | 16.513916 / 23.219971 / 29.926025 / 19.897705 |
| "CPU"/"GPU" @7 pt, MEM row | 15.3057 / 15.5210 / 23.0933 | 15.305664 / 15.520996 / 23.093262 |
| MEM/CPU/GPU clearances @7 pt | 10.9067 / 18.6943 / 18.4790 | 10.906738 / 18.694336 / 18.479004 |
| 8 pt clearances (current) | 8.6406 / 16.6836 / 16.4375 | 8.640625 / 16.683594 / 16.437500 |
| "999 MB/s" @9 pt, clearance | 42.1084 / 1.8916 | 42.108398 / 1.891602 |
| "5 KB/s" / "16 KB/s" @9 pt | 28.50 / 34.33 | 28.498535 / 34.334473 |
| 7 pt cap height | 4.93 pt | 4.9321 pt |
| Baseline-to-baseline spacing 1 → 0 | 13.11 → 12.11 | 13.1113 → 12.1113 |
| Label-descender to value-cap @0 | 2.88 | 2.8843 |
| Status bar thickness | 22.0 | 22.0 |

Heights and length-contract numbers are unchanged from the first gate's live
verification (23.0/22.0 pt fitting heights; 168/114/76/92/130/54/38/4 pt); the
re-issue carries them verbatim.

---

## 8. Spot-check: edits, decisions, and unchanged content (PASS)

- **Appendix A**: all four "Current Code" quotes match HEAD character for character
  (:103 `VStack(alignment: .center, spacing: 1)`, :111-113 label block with
  `size: 8`, :115-116 value block with `size: 10.5`, :143 network
  `VStack(alignment: .leading, spacing: 1)`). Target tokens match the VAC invariants
  and the Part 2 skeletons. No drift from the first gate's approved edit set.
- **User decision 1 (7 pt override)**: recorded in Part 4 §1 with the quoted prior
  finding (cap height 4.93 pt; light-mode contrast 3.81:1) and the explicit override.
  Live cap height 4.9321 pt confirms the quoted figure.
- **User decision 2 (Option 1, 2.5 pt threshold)**: recorded in the Clearance Decision
  section, VAC-5, and Appendix B item 6. `blockWidth` stays 34.0, item lengths stay
  114/168/76/38, and the IC-3 threshold relaxes to 2.5 pt against the measured
  2.7778 pt. Unchanged from the first gate.
- The re-issue summary claims ("byte-identical" edits, "zero changes to
  accessibility strings") hold under this spot-check, except for the citation
  defects R1-R3.

---

## 9. Required corrections (exact, text-only)

1. **R1**: in VAC-7's invariant, change "download rate text (line 165)" to
   "download rate text (line 166)".
2. **R2**: in Part 4 §3, change `StatusItemController.swift:191-196` to
   `StatusItemController.swift:192-196`.
3. **R3**: apply the §5 correction table to Appendix B (17 entries), or drop line
   numbers from Appendix B and cite method names plus quoted old values only.
4. Optionally narrow the Appendix A verification claim to list the verified commits
   per citation set; `4697230` is docs-only and changes no cited line.

After these corrections the blueprint passes without a new measurement round.

---

## 10. Non-blocking observations (carried forward)

- **N1 (stale production comment)**: `MenuBarBlockModel.swift:56-58` still states
  42.91 pt / 1.09 pt clearance for "999 MB/s" — the 9 pt *medium* numbers
  (re-confirmed live this round: 42.908494 / 1.091506). At 9 pt regular the values
  are 42.1084 / 1.8916, which the blueprint and IC-12 use. Fix in a separate docs
  commit; not one of the four Appendix A edits.
- **N2 (resolved)**: the re-issue's Appendix B items 2 and 4 rename the stale
  "TenAndAHalf"/"EightPoint" test names and refresh their messages. No action left.
- **N3 (130 pt row)**: the Part 3 §2 table still lists the 130 pt
  (two-standard-plus-network) row; no test pins it. Add
  `testCPURAMPlusNetworkTotal130` to `MenuBarLayoutTests.swift` or drop the row.
- **N4 (stale test header)**: `MenuBarValueTypographyTests.swift:6-9` still describes
  the red phase ("label ... carries .bold", rate fonts "carry .medium"). Refresh when
  Appendix B lands.
- **N5 (stale failure messages Appendix B does not list)**: after the listed updates,
  IC-3's message still says "at 10.5 pt regular" (:287), "expected 29.93 pt" (:295),
  "expected 4.07 pt" (:301), and IC-11's messages still say "expected 8.6406 /
  16.6836 / 16.4375" (:334, :350, :366). Tests stay green; update the strings while
  editing the adjacent assertions.

---

## 11. Reproduction

```bash
# citation checks (from repo root, HEAD = 4697230):
rg -n 'struct MenuBarBlockView|struct MenuBarNetworkBlockView|VStack\(alignment|\.font\(\.system|\.frame\(width: block\.width\)|accessibilityHidden' StatsLite/MenuBarStackedItemView.swift
rg -n 'setAccessibility' StatsLite/StatusItemController.swift   # function at :192
rg -n 'size:10\.5|ofSize: 10\.5|ofSize: 8|8\.6406|16\.6836|16\.4375' StatsLiteTests/MenuBarValueTypographyTests.swift
rg 'setAccessibilityValue' StatsLite/ StatsLiteTests/           # zero hits
# measurement re-runs:
/tmp/gate-measure/widths && /tmp/gate-measure/heights
```

---

**Final verdict: BLOCKED.** B1, B3, all ten mandated B2 citations, the four Appendix
A edits, every measurement, and both user decision records are verified correct.
Three residual citation defects (R1, R2, R3) block under the same standard that made
B2 blocking in the first gate: the blueprint again claims all line numbers were
verified at HEAD, and a handful do not hold. All corrections are text-only; none
requires a new measurement round. Apply §9, and the blueprint passes.
