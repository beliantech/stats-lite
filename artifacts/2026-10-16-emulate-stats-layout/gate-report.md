# Design Gate Report (Final Re-Gate R3): Menu Bar Typography & Spacing Blueprint

- Gate target: "Design Blueprint: Menu Bar Typography & Spacing Update (Emulate Stats
  App Look)", re-issued with R1-R3 corrections. The designer session
  `2026-10-16T19-41-13-459Z_a25226b8-5e05fae3-1fbea6cc-378a.jsonl` produced the
  corrected document as `/tmp/new_blueprint.md` and delivered the complete
  `diff -u` of the change plus a summary; the temp file was deleted at session end.
  This gate reconstructed the re-issued blueprint by applying that captured diff
  (6 hunks, 20 changed lines) to the round-2 blueprint (final message of designer
  session `ae6d7794`, extracted verbatim). `patch` applied with zero fuzz, which
  confirms the round-2 base copy was byte-identical. See §7.
- Prior gates: round 1 `cd03d01` BLOCKED on B1/B2/B3 (git history at `4697230`);
  round 2 `4697230` BLOCKED on R1/R2/R3 (git history at `6049af5`).
- Gated against: `main` at `6049af5`. Docs-only commits since `4697230`; production
  source is byte-identical to the round-1 gate checkout.
- Reference: `artifacts/2026-10-16-emulate-stats-layout/reference-stats.png`
  (check-only, standing screenshot waiver).
- Gate date: 2026-10-17.
- Verdict: **PASS**. R1, R2, and all 17 R3 corrections are applied and each
  corrected citation verifies against source at HEAD. The diff contains no other
  change: the four Appendix A edits, all measurements, and both user decision
  records are byte-identical to the round-2-verified document, and Appendix A
  "Current Code" quotes match HEAD character for character (re-verified this
  round, §6).

---

## 1. Verdict summary

| ID | Round-2 defect | Round-3 result |
|---|---|---|
| R1 | VAC-7 invariant cited the download rate Text at "line 165"; HEAD has it at :166 (:165 blank) | **PASS**. Re-issue reads "download rate text (line 166)" at reconstructed line 352. HEAD: upload Text :152, download Text :166, :165 blank. Verified. See §2. |
| R2 | Part 4 §3 and summary cited `StatusItemController.swift:191-196`; function spans 192-196 | **PASS**. Both occurrences now read `:192-196` (summary item 3 and Part 4 §3). HEAD: `func updateAccessibility()` :192, closing brace :196, :191 is the last doc-comment line. Verified. See §3. |
| R3 | 17 Appendix B test-file citations did not hold at HEAD | **PASS**. All 17 entries carry the §9 round-2 correction-table values, no stale citation remains, and every corrected citation was re-verified against `StatsLiteTests/MenuBarValueTypographyTests.swift` at HEAD this round. See §4. |

The full delta between the round-2 and round-3 documents is 20 changed lines:
2 (R2) + 1 (R1) + 17 (R3). The captured `diff -u` shows no other change. The
Appendix A edit set, every measurement, both user decision records, and the
verification-claim narrowing (round-2 §9 item 4, already present in round 2)
are untouched. See §5-§6.

---

## 2. R1 verification (PASS)

- Re-issued VAC-7 invariant: "Upload rate text (line 152) and download rate text
  (line 166) must remain `.font(.system(size: 9, weight: .regular).monospacedDigit())`."
- HEAD `StatsLite/MenuBarStackedItemView.swift`: :152 `Text(block.valueText)`
  (upload), :166 `Text(block.secondaryValueText ?? "-- KB/s")` (download), :165
  blank. Both parentheticals now correct.
- VAC-7 selector (:153, :167) unchanged and still correct.
- `rg 'line 165'` over the re-issued document: zero hits.

---

## 3. R2 verification (PASS)

- Both corrected occurrences read `StatsLite/StatusItemController.swift:192-196`.
- HEAD: doc comment ends at :191, `func updateAccessibility()` at :192,
  `button?.setAccessibilityElement(true)` :193, `setAccessibilityTitle` :194,
  `setAccessibilityLabel(compositeLabel)` :195, closing brace :196.
- `rg '191-196'` over the re-issued document: zero hits. The substantive B3
  description is unchanged and remains accurate (verified in round 2, §6).

---

## 4. R3 verification: all 17 Appendix B citations (PASS)

Each corrected citation was checked against
`StatsLiteTests/MenuBarValueTypographyTests.swift` (408 lines) at HEAD:

| Appendix B item | Re-issue citation | HEAD evidence | Status |
|---|---|---|---|
| item 2, FM1 method range | 148-165 | method :148, close brace :165 | ✓ |
| item 3, IC-2 method range | 169-183 | method :169, close brace :183 | ✓ |
| item 4, IC-4 MARK | 185 | `// MARK: - IC-4: label flips to 8 pt...` :185 | ✓ |
| item 4, IC-4 message | 205-210 (phrase at 206) | message literal :205-210; "must be 8 pt" :206 | ✓ |
| item 5, IC-10 method range | 222-266 | method :222, close brace :266 | ✓ |
| item 5, compound assertion | 254-265 (250-253 comment lines) | `XCTAssertEqual(` :254, `)` :265, comments :250-253 | ✓ |
| item 6, IC-3 method range | 270-303 | method :270, close brace :303 | ✓ |
| item 6, IC-3 threshold message | 286-289 | literal :286-289 | ✓ |
| item 6, IC-3 width constant | 293 | `29.93,` :293 | ✓ |
| item 6, IC-3 clearance constant | 299 | `4.07,` :299 | ✓ |
| item 7, IC-11 MARK | 305 | `// MARK: - IC-11: label-row clearance...` :305 | ✓ |
| item 7, IC-11 method range | 307-368 | method :307, close brace :368 | ✓ |
| item 7, IC-11 MEM message | 324-328 (phrase at 326) | literal :324-328; `"MEM" at 8 pt regular` :326 | ✓ |
| item 7, IC-11 MEM clearance constant | 332 | `8.6406,` :332 | ✓ |
| item 7, IC-11 CPU clearance constant | 348 | `16.6836,` :348 | ✓ |
| item 7, IC-11 GPU clearance constant | 364 | `16.4375,` :364 | ✓ |
| item 8, IC-12 method range | 372-407 | method :372, close brace :407 | ✓ |

The 19 Appendix B citations that round 2 marked correct (:27, :28, :29, :30, :32,
:34, :146, :148 start, :161, :220, :222 start, :231, :233-235, :268, :270 start,
:271, :283, :307 start, :308) are unchanged in the diff and were re-confirmed
correct during this round's line walk. No stale value from the round-2 correction
table remains anywhere in the document.

---

## 5. Delta completeness: nothing else changed (PASS)

The designer session's captured `diff -u` (`/tmp/prev_blueprint.md` vs
`/tmp/new_blueprint.md`, tool result at session index 54) contains exactly six
hunks and 20 changed line pairs:

- 2 pairs: R2 (summary item 3, Part 4 §3).
- 1 pair: R1 (VAC-7 invariant).
- 17 pairs: R3 (Appendix B items 2, 3, 4×2, 5×2, 6×4, 7×5, 8).

The diff ends at the Appendix B item-8 hunk (with the file's no-trailing-newline
marker). No Appendix A, measurement, decision-record, or other section appears in
the diff. Because the base document is the round-2-verified blueprint, those
sections are byte-identical by construction; the diff is the authoritative record.

Reconstruction receipt: applying the captured diff to the round-2 blueprint
(final assistant message of session `ae6d7794`, 31,682 bytes) yields a 31,763-byte
document. `patch` reported no fuzz and no offsets, so the base copy matched the
designer's `/tmp/prev_blueprint.md` byte for byte.

---

## 6. Spot-check: Appendix A edits, measurements, decision records (PASS)

- **Appendix A**: all four "Current Code" quotes re-verified against HEAD this
  round, character for character: :103 `VStack(alignment: .center, spacing: 1) {`;
  :111-113 label block with `.font(.system(size: 8, weight: .regular))`;
  :115-116 value block with `size: 10.5`; :143
  `VStack(alignment: .leading, spacing: 1) {`. Target tokens unchanged from the
  round-1-approved edit set (spacing 1→0, label 8→7, value 10.5→11).
- **Measurements**: the re-issued document carries every round-2-verified value
  unchanged (spot-checked 32 quantities, including 31.2222 / 2.7778, the 10.5 pt
  width set, the 7 pt MEM/CPU/GPU clearances 10.9067 / 18.6943 / 18.4790, the
  8 pt clearances 8.6406 / 16.6836 / 16.4375, 42.1084 / 1.8916, cap height 4.93,
  and the length contract 168/114/76/92/130/54/38). The diff touches no number.
  The round-1 and round-2 gates verified these live; no new measurement round is
  required for a text-only correction.
- **User decision 1 (7 pt label override)**: unchanged. Part 4 §1 still records
  cap height 4.93 pt and light-mode contrast 3.81:1 with the explicit override.
- **User decision 2 (Option 1 clearance threshold)**: unchanged. Clearance
  Decision section, VAC-5, and Appendix B item 6 still record the 2.5 pt
  threshold against the measured 2.7778 pt, with `blockWidth` 34.0 and item
  lengths 114/168/76/38.

---

## 7. Non-blocking observations (carried forward)

- **N1 (stale production comment)**: `MenuBarBlockModel.swift:56-58` still states
  42.91 pt / 1.09 pt clearance for "999 MB/s" (9 pt medium numbers). At 9 pt
  regular the values are 42.1084 / 1.8916, which the blueprint and IC-12 use.
  Fix in a separate docs commit; not one of the four Appendix A edits.
- **N3 (130 pt row)**: Part 3 §2 still lists the 130 pt
  (two-standard-plus-network) row; no test pins it. Add
  `testCPURAMPlusNetworkTotal130` to `MenuBarLayoutTests.swift` or drop the row.
- **N4 (stale test header)**: `MenuBarValueTypographyTests.swift:6-9` still
  describes the red phase. Refresh when Appendix B lands.
- **N5 (stale failure messages Appendix B does not list)**: after the listed
  updates, IC-3's message still says "at 10.5 pt regular" (:287), "expected
  29.93 pt" (:295), "expected 4.07 pt" (:301), and IC-11's messages still say
  "expected 8.6406 / 16.6836 / 16.4375" (:334, :350, :366). Tests stay green;
  update the strings while editing the adjacent assertions.

The round-2 note N2 is resolved (Appendix B items 2 and 4 rename the stale test
names and refresh their messages). No new non-blocking observations this round.

---

## 8. Reproduction

```bash
# R1/R2 citations at HEAD (repo root, HEAD = 6049af5):
sed -n '150,170p' StatsLite/MenuBarStackedItemView.swift | nl -ba -v 150   # :152 upload, :166 download
sed -n '188,198p' StatsLite/StatusItemController.swift | nl -ba -v 188     # func :192, close :196
# R3 citations at HEAD:
sed -n '145,149p;168,184p;220,236p;250,266p;268,303p;305,368p;370,374p' \
    StatsLiteTests/MenuBarValueTypographyTests.swift | nl -ba
# Appendix A current-code quotes at HEAD:
sed -n '103p;111,116p;143p' StatsLite/MenuBarStackedItemView.swift | nl -ba
# stale-citation sweeps over the re-issued document:
rg 'line 165|191-196|\(lines 148-164\)|\(lines 168-184\)|\(lines 222-267\)|\(lines 270-305\)|\(lines 307-372\)|\(lines 374-407\)' \
    <re-issued blueprint>   # zero hits
```

---

**Final verdict: PASS.** R1, R2, and all 17 R3 corrections are applied and
verified against source at HEAD. The complete delta is 20 citation-only lines;
the four Appendix A edits, all measurements, and both user decision records are
byte-identical to the round-2-verified document, and Appendix A "Current Code"
quotes match HEAD character for character. No new measurement round is required.
The blueprint is cleared for plan authoring. Non-blocking notes N1, N3, N4, N5
do not gate.
