# Design Gate Report: Label 8 pt + Row-Alignment Blueprint Revision

- Gate target: the re-issued "Design Blueprint: Menu Bar Typography & Row-Alignment
  Update", final assistant message of designer session
  `2026-10-16T21-53-41-438Z_9890de98-3563953b-092b8604-8ffc.jsonl` (37,596
  characters; extracted verbatim to `/tmp/designer-final.txt` for this gate).
- Re-gate target (round 2): the corrected re-issue, final assistant message of
  designer session
  `2026-10-16T22-57-39-267Z_9be74fe6-4f01a574-23769475-eba2.jsonl` (40,554
  characters incl. the correction summary; extracted verbatim to
  `/tmp/designer-final-regate.txt`). Sections 1-9 record round 1; section 10
  records the re-gate of C1-C6.
- Baseline: PASSed blueprint `blueprint-final.md` and gate report `gate-report.md`
  in this directory (merged at `bf9973e`). This gate covers the delta plus ripple
  effects. `gate-report.md` is not modified.
- HEAD pin: `main` = **5c67c21** ("docs(menubar): record emulate-stats layout plan
  receipts and merge SHA"). The designer cites `7f966dc` / `5c67c21`: `7f966dc` is
  the tip of `ci/github-actions-dmg-build` (the branch checked out in the main
  worktree) and it *contains* main. `git diff 5c67c21 7f966dc -- StatsLite
  StatsLiteTests` is empty, so the two cites are equivalent for source
  verification. All Appendix A checks below run against source at `5c67c21`.
- Method: trial implementation. This gate applied Appendix A and Appendix B
  verbatim in a throwaway worktree on `5c67c21`
  (`worktrees/2026-10-16-emulate-stats-layout-gate-align-verify`), added one
  temporary probe test file, and ran the full suite twice: once at unmodified
  HEAD (pre-edit), once on the trial implementation (post-edit). The worktree
  and its branch are deleted after the run; probe output is reproduced in §8.
- Reference image `reference-stats.png`: **check-only** (standing screenshot
  waiver, user authority 2026-10-16, no Screen Recording permission). All
  screenshot checks in this gate are check-only; none is claimed as captured.
- Gate date: 2026-10-17.
- Verdict: **PASS** (re-gate, round 2, §10). Round 1 was **BLOCKED** on six
  corrections C1–C6 (§1, §9). The designer applied all six plus N1/N4/N5. The
  re-gate re-verified C1–C6 with targeted proofs and found no regression.

---

## 1. Verdict summary (round-1 state; re-gate results in §10)

| ID | Defect | Evidence | Status |
|---|---|---|---|
| C1 | Appendix B §4 `testRowFramesUseRowHeightConstantInBothBlocks` fails on its `netScope` assertion even with correct production code | Trial run: `XCTAssertTrue failed - VAC-12: MenuBarNetworkBlockView must use .frame(height: MenuBarLayout.rowHeight)` at `MenuBarValueTypographyTests.swift:521`. Root cause: `squashed(_:)` truncates the fragment at the first `//`, which is `// Line 1: Upload rate` (netScope offset 156); both frame tokens sit later (offset 625), so `squashed(netScope)` never sees them. `squashed(blockScope)` passes, which is why only the network half fails | **BLOCK** |
| C2 | Appendix B §4 uses `NSHostingView` but adds no `import SwiftUI` | Trial build: `error: cannot find 'NSHostingView' in scope` at `MenuBarValueTypographyTests.swift:487` and `:488`. The file imports only AppKit and XCTest. The blueprint's test set does not compile as specified | **BLOCK** |
| C3 | Key Findings claim "Row 1 font baselines match at `y = 8.00 pt` in both blocks" is false | Live probe on the trial implementation: std row1 (8 pt "CPU") ink bottom 9.00 pt, net row1 (9 pt "999") ink bottom 9.25 pt at 4x supersample; 16x threshold sweep: std 9.1875 / 8.8125, net 9.4375 / 9.0625 / 8.9375; font-metric model from measured Text ideal heights (10 / 14 / 11 pt): 8.5234 vs 8.9014, delta 0.378. Probe assertions failed at `GateAlignmentProbeTests.swift:403-405`: 9.0 != 8.0 (+/-0.1), 9.25 != 8.0 (+/-0.1), delta 0.25 not < 0.05. Neither baseline is 8.00; they are not equal | **BLOCK** |
| C4 | VAC-7 and VAC-8 selectors carry wrong line numbers | Faithful post-edit line map: upload rate font at **:155** (VAC-7 says `:156`), download rate font at **:170** (VAC-7 says `:171`), network container frame at **:176** (VAC-8 says `:178`). VAC-1 :112, VAC-2 :117, VAC-3 :103, VAC-4 :145, VAC-5 :122, VAC-6 :104-115 are all correct | **BLOCK** |
| C5 | Appendix A Edit 3 "Current Code" quote does not exist at HEAD | The quote carries `.font(.system(size: 8, weight: .regular))`; HEAD has `size: 7` at :112. Substituting `size: 7` makes the quote match HEAD, so the size token is the only delta. The quote matches the post-Edit-2 state, not HEAD as the label claims | **BLOCK** |
| C6 | Part 4 §2 cites `StatusItemController.swift:76-85` but the quoted block includes `button.addSubview(hostingView)` at **:86** | Source: :76 creation, :82 sizingOptions, :83 translatesAutoresizingMask, :84 autoresizingMask, :85 frame, :86 addSubview. Cited range must be :76-86. Same citation class as round-2 defect R2 | **BLOCK** |

Exact corrections are in §9.

---

## 2. Binding user instructions: implemented and verified

### Instruction 1: category labels 7 -> 8 pt, override retired

- Appendix A Edit 2 sets `MenuBarStackedItemView.swift:112` to
  `.font(.system(size: 8, weight: .regular))` with `.foregroundStyle(.secondary)`
  unchanged on the next line. Verified: location :112 (Text at :111) correct at
  HEAD; Current Code matches HEAD character for character (whitespace-agnostic
  match; the markdown renders it de-indented, relative structure intact).
- The old 7 pt legibility override record is retired inside the revision:
  Summary item 1, the supersede statement ("The design tokens in this blueprint
  supersede previous menu bar typography specifications"), and Part 4 §1
  "Retirement of 7 pt Legibility User Override" (cap height now 5.64 pt at 8 pt).
- Measured: `NSFont.systemFont(ofSize: 8).capHeight` = **5.6367** (blueprint
  claim 5.64, within the stated 0.02 tolerance). Preceding record 4.93 at 7 pt
  confirmed as capHeight7 = 4.9321.
- Follow-up (planner, not a blueprint defect): the tracked plan
  `plans/2026-10-16-emulate-stats-layout.md` still adopts the 7 pt override
  (title line, lines 49-51, :130, :244, and the 7 pt state matrix). Retire those
  when the plan is revised against the new blueprint.

### Instruction 2: row alignment via shared `MenuBarLayout.rowHeight = 11`

- Appendix A Edit 1 inserts the constant at line 60, between `networkBlockWidth`
  (:59) and the `gap` comment. Added Code matches the applied insertion exactly.
- Trial implementation measurements (post-edit, real production views, not
  replicas):

| Claim | Expected | Measured | Result |
|---|---|---|---|
| `MenuBarBlockView` fitting height | 22.00 pt | 22.0000 | pass |
| `MenuBarNetworkBlockView` fitting height | 22.00 pt | 22.0000 | pass |
| Fitting-height delta | 0.00 pt | 0.0000 | pass |
| Row 1 / Row 2 extents | [0,11] / [11,22] | forced by `rowHeight = 11` + `spacing: 0` + fitting 22.0000 | pass (construction) |
| Row centers 5.50 / 16.50 | arithmetic corollary | 11/2, 11+11/2 | pass (construction) |
| Row 1 baselines match at 8.00 | 8.00 / 8.00, delta 0.00 | 9.00 / 9.25 ink (4x); model 8.5234 / 8.9014 | **FAIL (C3)** |
| Zero clipping vs thickness 22 | 0.00 pt overflow | thickness 22.0, button bounds 168x22, std block ink 3.00..21.25, net ink 2.00..22.00 (slash touches exactly 22.00) | pass |
| Value-change jitter | zero | fitting stays 22.0000 for "100%", "0%", "--%", "999 MB/s", "-- KB/s", "5 KB/s" | pass |

- Pre-edit state (blueprint's "before" numbers), measured at unmodified HEAD:
  std **23.0000**, net **22.0000**, delta 1.0; unconstrained 8 pt label without
  row frames std **24.0000**. All three claims confirmed.
- Method note: `NSHostingView` exposes no NSView subviews for the SwiftUI rows
  (the tree dump returns only `NSHostingView<MenuBarBlockView>` itself), so row
  centers are verified by construction plus the measured fitting height, and
  baselines by ink rendering. See observation N6.

---

## 3. Live measurement record (state-independent numbers)

All values reproduced on this machine in the trial run; `testProbeA` and
`testProbeB` passed against the blueprint's measurement table:

| Element | Measured | Blueprint claim | Threshold | Result |
|---|---|---|---|---|
| "CPU" at 8 pt regular | 17.3164 | 17.3164 | clearance 16.6836 >= 16.0 | pass |
| "MEM" row (4+2+19.3594) | 25.3594 | 25.3594 | clearance 8.6406 >= 3.5 | pass |
| "GPU" at 8 pt regular | 17.5625 | 17.5625 | clearance 16.4375 >= 16.0 | pass |
| "100%" at 11 pt mono | 31.2222 | 31.2222 | clearance 2.7778 >= 2.5 (relaxed, user Option 1) | pass |
| "0%" / "5%" at 11 pt | 17.2358 | 17.2358 | clearance 16.7642 | pass |
| "--%" at 11 pt | 20.7485 | 20.7485 | clearance 13.2515 | pass |
| "999 MB/s" at 9 pt mono | 42.1084 | 42.1084 | clearance 1.8916 >= 1.8 | pass |
| cap height at 8 pt | 5.6367 | 5.64 | +/-0.02 | pass |
| `NSStatusBar.system.thickness` | 22.0 | 22.0 | +/-0.01 | pass |
| `NSStatusBarButton.bounds.height` | 22.0 | 22.0 | +/-0.01 | pass |

---

## 4. Appendix A verification at HEAD (5c67c21)

Locations (all pre-edit line numbers, all correct):

| Edit | Cited location | HEAD evidence | Result |
|---|---|---|---|
| 1, rowHeight constant | insert at line 60, between networkBlockWidth and gap | :59 `static let networkBlockWidth`, :60 `/// Gap between adjacent blocks.` | pass |
| 2, label font | line 112 (Text at 111) | :111 `Text(block.label)`, :112 `size: 7` | pass |
| 3, row 1 frame | line 114 (HStack close) | :114 `}` | pass |
| 4, row 2 frame | line 118 (after `.lineLimit(1)`) | :118 `.lineLimit(1)` | pass |
| 5, network line 1 frame | line 156 (upload HStack close) | :156 `}` | pass |
| 6, network line 2 frame | line 170 (download HStack close) | :170 `}` | pass |

Quotes (whitespace-agnostic, character check):

- Edit 2 Current Code: matches HEAD. Edit 4, 5, 6 Current Code: match HEAD.
- Edit 3 Current Code: does **not** match HEAD; it carries `size: 8` (C5).
  With `size: 7` substituted it matches, so this is the only delta.
- All four Target Code blocks and Edit 1 Added Code: match the trial
  implementation byte for byte (the applied edits reproduce the blueprint).
- Edits overlap (Edit 3's region contains Edit 2's lines). As a sequence this is
  self-consistent; C5 is about the "Current Code" label only.

---

## 5. Appendix B walk plus trial-suite results

Citations checked against `StatsLiteTests/MenuBarValueTypographyTests.swift`
(451 lines at HEAD):

| Appendix B item | Citation | HEAD evidence | Result |
|---|---|---|---|
| 1, expectedLabelFont | 29-30 | comment :29, literal :30 | pass |
| 2, IC-4 method range | 187-219 | method :187, close :219 (next MARK :220) | pass |
| 2, IC-4 MARK | 185 | `label flips to 7 pt regular secondary` | pass |
| 2, IC-4 message phrase | 206 | `must be 7 pt` at :206 | pass |
| 3, IC-11 method range | 307-368 | method :307, close :368 | pass |
| 3, IC-11 MARK | 305 | `label-row clearance at 7 pt regular` | pass |
| 3, font definition | 308 | `ofSize: 7.0` at :308 | pass |
| 3, MEM message | 326 | `"MEM" at 7 pt regular` at :326 | pass |
| 3, expected clearances | 332 / 348 / 364 | `10.9067,` / `18.6943,` / `18.4790,` | pass |
| 4, new tests | added, no citations | see C1, C2 | **fail** |

Coverage against what the production edits force:

- Label 7 -> 8 forces `expectedLabelFont` (:30), the IC-4 region assertion, and
  the whole IC-11 measurement block. All are enumerated (items 1-3). After the
  edits, no stale 7 pt token remains: `rg 'SevenPoint|size:7|ofSize: 7|7 pt'`
  over the updated test file is empty.
- The renames restore the exact pre-T2 names: `git show 92c28ca` shows T2
  created `SevenPoint` variants from `testLabelFontIsEightPointRegularSecondary`
  and `testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints`. "Back to" is
  accurate.
- The rowHeight edit forces the three new tests (item 4). Item 4 does not list
  the required `import SwiftUI` (C2), and its third test cannot pass (C1).
- Trial run, full suite on the trial implementation: **235 tests, 4 failures**.
  One failure is C1 (the blueprint's own test). Three failures are this gate's
  probe asserting the falsified 8.00 baseline claim (C3). Every other test
  passes, including all 227 baseline tests at their updated expectations.
- Before edits, the suite at HEAD ran **227 tests, 0 failures, TEST SUCCEEDED**.

---

## 6. Ripple checks vs the merged baseline (all pass)

| Check | Evidence | Result |
|---|---|---|
| Network fonts stay 9 pt regular mono | source :155 / :170 post-edit; IC-10 test green in trial | pass |
| Value stays 11 pt mono | source :117; FM1, IC-2 green | pass |
| Spacing-0 stacks intact | VAC-3 (`:103`), VAC-4 (`:145`) tests green; row frames add no gap (VStack spacing unchanged at 0) | pass |
| Zero `.animation` / `.contentTransition` on status item path | `rg` over StatsLite finds them only in comments; churn tests green in both runs | pass |
| Hosting contract | `StatusItemController` :82 `sizingOptions = []`, :84 `autoresizingMask = [.width, .height]`, :85 `frame = button.bounds`, :86 `addSubview`; probe measured hosting frame == button bounds (168x22) | pass (C6 is the citation range only) |
| Accessibility untouched | `.accessibilityHidden(true)` at :45; `updateAccessibility()` :192-196; both citations correct | pass |
| `MenuBarLayout.length` unchanged by rowHeight | Edit 1 adds a `static let` only; function at :69-82 untouched. Probe evaluated all 16 combinations post-edit: 168/114/76/38, 4, 54, 92, 130 and singles exact; `MenuBarLayoutTests` green | pass |
| Part 2 skeleton ranges | `99-133` and `141-196` correct against the post-edit file (196 lines) | pass |

---

## 7. Non-blocking observations

- **N1 (carried)**: `MenuBarBlockModel.swift:56-58` still says "999 MB/s"
  (42.91 pt) / 1.09 pt clearance from the 9 pt medium era; live values are
  42.1084 / 1.8916. The blueprint now embeds this stale comment inside its
  Part 2 §1 skeleton quote while its own table says 42.1084 / 1.8916. Fix the
  production comment in a docs commit; then the skeleton quote stays true.
- **N4 (carried)**: test-file header lines 5-14 still narrate the Phase-2 red
  state. Refresh with Appendix B.
- **N5 (carried, extended)**: after item 3, failure messages at :334, :350,
  :366 still say "expected 10.9067 / 18.6943 / 18.4790" while the assertions
  now expect 8.6406 / 16.6836 / 16.4375. Line references inside other messages
  drift post-edit: FM1 ":115-116" -> 116-117, IC-10 ":153/:167" -> 155/170,
  VAC-4 ":143" -> 145. Tests stay green; update the strings while editing.
- **N6 (new)**: VAC-12's selector "Subview frames inside MenuBarBlockView and
  MenuBarNetworkBlockView" cannot be read from `NSHostingView`: SwiftUI rows
  are not NSView children. Reword VAC-12 to the testable form (fitting heights
  plus frame tokens), which is what Appendix B §4 actually checks.
- **N7 (carried N3)**: the 130 pt length row has no repo test. Add
  `testCPURAMPlusNetworkTotal130` to `MenuBarLayoutTests.swift` or drop the row.
- Probe files and the trial worktree are deleted; only this report is new.

---

## 8. Reproduction

```bash
# HEAD pin and equivalence of the designer's two cites
git -C . log --oneline -1 main                      # 5c67c21
git diff --stat 5c67c21 7f966dc -- StatsLite StatsLiteTests   # empty

# Appendix A locations at HEAD
rg -n 'system\(size|frame\(width: block' StatsLite/MenuBarStackedItemView.swift
sed -n '56,64p' StatsLite/MenuBarBlockModel.swift

# VAC selectors on a faithful post-edit copy (apply the six edits, then)
rg -n 'system\(size|VStack\(|frame\(height: MenuBarLayout|frame\(width: block' \
    StatsLite/MenuBarStackedItemView.swift
# expected: :112 :117 :103 :145 :122, frames at :115 :120 :159 :174,
#           rate fonts :155 :170 (VAC-7 says 156/171), network frame :176 (VAC-8 says 178)

# Appendix B citations
rg -n 'MARK:|func test|size:7|ofSize: 7|10.9067|18.6943|18.4790' \
    StatsLiteTests/MenuBarValueTypographyTests.swift

# Suite states
# HEAD baseline: 227 tests, 0 failures, TEST SUCCEEDED (log: /tmp/gate-test-baseline2.log)
# Trial implementation: 235 tests, 4 failures = C1 (typography tests, :521)
#   + 3 probe assertions for the falsified 8.00 baseline claim
#   (log: /tmp/gate-test-post.log; probe output: /tmp/gate-probe-out.txt)

# C1 root cause (Python check on the post-edit source): squashed(netScope)
# truncates at '// Line 1: Upload rate' (offset 156) before the frame tokens
# (offset 625), so '.frame(height:MenuBarLayout.rowHeight)' is never seen.
```

---

## 9. Exact corrections

1. **C1**: in Appendix B §4, replace the `netScope` half of
   `testRowFramesUseRowHeightConstantInBothBlocks`. Do not run `squashed(_:)`
   over the whole scope: it cuts at the first `//`. Either strip comments
   line-wise before searching, or locate the two frame lines with
   `sourceLine(containing: ".frame(height")` style lookups inside the network
   scope, or assert the two occurrences of
   `.frame(height:MenuBarLayout.rowHeight)` in raw scope order. Keep the
   `blockScope` assertion as written; it passes.
2. **C2**: Appendix B must add `import SwiftUI` to
   `StatsLiteTests/MenuBarValueTypographyTests.swift` (the file's header
   imports AppKit and XCTest only). List it as an edit in the enumeration.
3. **C3**: delete or rewrite the Key Findings claim
   "Row 1 font baselines match at `y = 8.00 pt` in both blocks." True values on
   the trial implementation: std row1 baseline 8.52 pt, net row1 baseline
   8.90 pt (font-metric model; ink sweep 8.81..9.19 and 9.06..9.44 including
   antialias). Delta about 0.38 pt, not 0.00: an 8 pt label and a 9 pt rate in
   equal-height rows cannot share a baseline. Row tops, centers, and bottoms
   (0.00 / 5.50 / 16.50 / 22.00) are unaffected and verified. Remove the
   baseline sentence from the row-positions list; the acceptance checklist
   (VAC-12) never depended on it.
4. **C4**: VAC-7 selectors: `:156` -> **:155**, `:171` -> **:170**. VAC-8
   selector: `:178` -> **:176**. All other VAC and Part 2 selectors verify as
   written (post-edit basis: `99-133`, `141-196` are correct).
5. **C5**: Edit 3 "Current Code" must show `.font(.system(size: 7, weight:
   .regular))` to match HEAD, or be relabeled "Current Code (after Edit 2)".
   The Target Code is correct as written.
6. **C6**: Part 4 §2 citation `StatusItemController.swift:76-85` ->
   **:76-86** (the quoted `button.addSubview(hostingView)` is at :86). The
   other occurrence (line 70, `hostingView.frame = button.bounds` at :85) is
   inside :76-85 and stays.

---

**Round-1 final verdict: BLOCKED.** (Superseded by the re-gate verdict in §10.)
The binding user instructions are implemented in
the revision and every layout number they depend on measured clean: 8 pt label
clearances 16.6836 / 8.6406 / 16.4375, 11 pt value 31.2222 / 2.7778 above the
relaxed 2.5 pt threshold, both blocks 22.0000 pt fitting height with 0.0000
delta against a 22 pt status bar, zero jitter, all `MenuBarLayout.length`
combinations unchanged (114 / 168 / 76 / 38 exact), and no regression in
network fonts, spacing-0 stacks, or the zero-animation rule. The block is the
blueprint's own apparatus: one acceptance test cannot pass as written (C1), its
test set does not compile without a missing import (C2), one measurement claim
is falsified (C3), and three citations are wrong (C4-C6). Apply the six
corrections in section 9; a re-gate can then re-verify citations only, because
all measurement evidence in sections 2, 3, and 6 stands. Screenshot checks
remain check-only under the standing waiver.

---

## 10. Re-gate (round 2): C1–C6 re-verified

- Re-gate target: the final assistant message of designer session
  `2026-10-16T22-57-39-267Z_9be74fe6-4f01a574-23769475-eba2.jsonl`, extracted
  verbatim to `/tmp/designer-final-regate.txt` (40,554 characters: a "Summary of
  Accomplishments" that lists the six fixes, then the re-issued blueprint).
- HEAD unchanged: `main` = **5c67c21**. All proofs run against
  `git show 5c67c21:<path>` copies in `/tmp/regate-scratch`.
- Method: full text diff against the round-1 blueprint (`/tmp/designer-final.txt`),
  237 diff lines, every hunk reviewed, plus the targeted proofs below. No test
  suite run this round: sections 2, 3, and 6 stand, and the timebox allows
  source-level proofs for the apparatus changes.
- Verdict: **PASS**. All six corrections re-verify. The spot-check found no
  regression.

| ID | Re-verification | Result |
|---|---|---|
| C1 | New Appendix B §5 network half: `netScope.range(of: "Upload rate")`, then `sourceLine(containing: ".frame(height", in: netScope[section.upperBound...])`, then `squashed(line) == expectedFrame`; same for download; `blockScope` half unchanged. Proof (targeted, source-level): the helpers exist at HEAD with matching signatures — `declarationScope` :66 returns `Substring`, `sourceLine(containing:in:)` :85 takes `Substring`, `squashed` :101 takes `some StringProtocol` — so the test compiles. Simulated that exact logic on the faithful six-edit post-edit source: both sections found, both frame lines resolve to `.frame(height: MenuBarLayout.rowHeight)`, squashed output equals `.frame(height:MenuBarLayout.rowHeight)`, and `squashed(blockScope).contains(expected)` holds. The old `squashed(netScope).contains(expected)` on the same source returns false (cuts at `// Line 1: Upload rate`), reproducing the round-1 failure and confirming the stated root cause. The new test cannot hit the truncation: it never runs `squashed` over comment-bearing scope, and each frame line carries no `//`. Circle's `.frame(width: 6, height: 6)` does not match the `.frame(height` needle. | **PASS** |
| C2 | Appendix B item 0 adds `import SwiftUI` to `MenuBarValueTypographyTests.swift`; the code block shows the exact result (AppKit / SwiftUI / XCTest / `@testable`). Targeted proof: `swiftc -typecheck` of an AppKit+SwiftUI+`NSHostingView` snippet passes, and AppKit's `NSFont` stays unambiguous. Round-1 trial history: the missing import was the only compile blocker. Not a full build this round. Location nit: item 0 says "Lines 18–21"; the imports are :19–21 (:18 blank) — see N8. | **PASS** |
| C3 | The falsified sentence is gone: `rg '8.00\|baselines match'` over the re-issue hits only the summary line that records the removal. New invariant text matches the round-1 measurements exactly: font-metric model 8.5234 / 8.9014 → "~8.52 pt" / "~8.90 pt", delta 0.378 → "~0.38 pt", 4x ink bottoms 9.00 / 9.25, row extents [0.00, 11.00] / [11.00, 22.00], centers 5.50 / 16.50, fitting height 22.00. VAC-12 is now frame-based (rowHeight token, four frame tokens, 22.00 pt fitting heights, extents); no baseline-matching criterion remains. | **PASS** |
| C4 | Faithful post-edit line map: VAC-7 rate fonts at **:155** / **:170** ✓, VAC-8 container frame at **:176** ✓. Re-verified unchanged selectors: VAC-1 :112, VAC-2 :117, VAC-3 :103, VAC-4 :145, VAC-5 :122, VAC-6 :104–115. New VAC-12 selector frames **:115, :120, :159, :174** ✓ — all correct. | **PASS** |
| C5 | Edit 3 "Current Code" now carries `size: 7` and equals HEAD lines 104–114 line for line (whitespace-agnostic). The Target Code is unchanged and still correct. | **PASS** |
| C6 | Part 4 §2 (and the Live Measurement §2 occurrence) cite `StatusItemController.swift:76-86`. Source: :76 creation, :82 sizingOptions, :83 translatesAutoresizing, :84 autoresizingMask, :85 frame, :86 addSubview. Every quoted line matches the source; every quoted line falls inside the cited range. | **PASS** |

### Regression spot-check vs the round-1 trial-implemented version

- Full old→new diff (237 lines) reviewed hunk by hunk. Changes are confined to
  the summary preamble, the C1–C6 fixes, the N1/N4/N5 additions, the VAC-12
  rewrite, the Appendix B renumbering, and the verdict line. The measurement
  sections (Live Measurement table, Part 1–Part 3 numbers) are byte-identical.
- No residual wrong tokens: `76-85`, `:178`, `:171`, `size: 8` inside Edit 3
  Current Code, and the 8.00 baseline claim are all absent.
- Appendix B anchors re-checked at HEAD: items 2–4 at lines 29–30, 185, 187, 206,
  305, 307, 308, 326, 332, 334, 348, 350, 364, 366 — all exact. Item 6: IC-10 at
  :251 / :258 / :259 exact, VAC-4 at :446 exact.
- Round-1 record nit (text unchanged, non-blocking): the IC-4 method closes at
  :218 (:219 is the blank before the next MARK), not :219 as §5 states. The
  cited range 187–219 still contains the whole method, so the PASSed citation
  stands.
- N1 source note (`MenuBarBlockModel.swift:56-58`, 42.91 pt / 1.09 pt from the
  9 pt medium era) is accurate against source.

### Non-blocking observations (round 2)

- **N8**: Appendix B item 0 says "Lines 18–21"; the import lines are :19–21
  (:18 is a blank line). The code block gives the exact result, so the edit
  cannot go wrong. Correct the range while editing.
- **N9**: Appendix B item 6 cites "FM1 line 161"; the
  `MenuBarStackedItemView.swift:115-116` string sits at test line :160 (HEAD
  basis, the basis of the two exact sibling citations in the same item). The
  before→after arrow makes the edit unambiguous. Correct the anchor while editing.
- **N10**: item 0 inserts one line, so every later Appendix B line reference
  shifts +1 when items apply in order. Apply items by content, not by line number.
- Carried: N1 and N4 are now folded into Appendix B (N1's source-comment fix is
  explicitly deferred to a docs commit); N5's message updates (:334, :350, :366)
  and drift notes verify; N6 is resolved by the VAC-12 rewrite; N7 (130 pt length
  row test) stays open and non-blocking.

**Re-gate verdict: PASS.** All six round-1 blocking defects (C1–C6) are fixed and
re-verified by targeted proof; the spot-check found no regression. The three new
observation anchors (N8–N10) are edit hints with unambiguous content, not check
targets, so they do not block plan authoring. The binding instructions and every
number they depend on stand as measured in sections 2, 3, and 6. Screenshot
checks remain check-only under the standing waiver.
