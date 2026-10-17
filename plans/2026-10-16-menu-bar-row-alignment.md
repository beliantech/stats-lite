# Plan: Menu Bar Row Alignment — 8 pt Labels + 11 pt Row Height (both blocks 22.00 pt)

Date: 2026-10-16
Plan name: `2026-10-16-menu-bar-row-alignment`
Risk class: **R2** (UI work — zero-tolerance visual policy applies; visual defects are blocking).
Status: Design gate **PASS** (`artifacts/2026-10-16-emulate-stats-layout/gate-report-alignment.md`,
re-gate round 2, §10). The gate report is committed as `ee4ef04` on
`ci/github-actions-dmg-build` only; **T5 cherry-picks it onto `main`**. Plan authored
2026-10-16. Post-`run_plan` clarity pass applied 2026-10-16: wording and procedure only
— ISC semantics, the blueprint, scope, the task list, and the constant-folding
adaptation (Approach item 3) are unchanged. No `[plan-review]` verdict is recorded in
this file; do not invent one. Ready for execution: T1 → T5.
**Complete 2026-10-17:** T1 waiver carry-over (`0e37f3d`, no new probe — basis unrefuted);
red `f2b4671` (229 tests, 3 failing tests / 4 assertion events per derivation); green
`38bb8c4` (six production edits, 229/0); ledger `e0873e0` (14 pass, 1 waived); reviewer
GO via `subagent_done` (`cf1748e1`); gate report cherry-picked from ci as `7914cf8`;
rebased and merged fast-forward to `main` at `e0873e0`; worktree and branch removed.
Documented adaptations: @MainActor on the hosting test (Swift 6); the rowHeight
constant-fold into the frame-token guard.
Baseline suite: **227 tests, 0 failures** at `main` tip **5c67c21** (gate §5 measured;
authoring scan `rg -c 'func test' StatsLiteTests/` = 227). The `ci` branch (`ee4ef04`)
contains `main`, and `git diff 5c67c21 ee4ef04 -- StatsLite StatsLiteTests` is empty, so
the workdir tree verifies every Swift citation below identically. `main` advanced two
docs-only commits after `5c67c21` (`4b35430` blueprint archive, `f40041d` plan;
`git diff 5c67c21 f40041d -- StatsLite StatsLiteTests` empty at the clarity pass), so
the 227-test baseline and every Swift citation hold at the current tip.
Screenshot waiver: `artifacts/2026-10-16-emulate-stats-layout/waiver-note.md` (user
authority, three recorded exit-1 probes). T1 records the carry-over for this plan;
**no new probe** — the basis is unrefuted and this plan adds no new capture surface.
Worktree: `<repo>/worktrees/menu-bar-row-alignment`, branch
`feat/2026-10-16-menu-bar-row-alignment` (non-base).
Repo-state hazards (both encoded in T5): (a) the main repo workdir sits on
`ci/github-actions-dmg-build` (parallel DMG-CI work; the gate report `ee4ef04` lives
there) — every merge operation runs from a verified `main` checkout, never from the ci
branch, and the ci branch's own commits are never disturbed; (b) `main` advances in
parallel — rebase before the ff-only merge.
Blueprint archive: `artifacts/2026-10-16-emulate-stats-layout/blueprint-alignment-final.md`
(commit `4b35430`, verbatim final re-issue from designer session `9be74fe6`), embedded
below.

## Intent

Current state at `main` 5c67c21 (`StatsLite/MenuBarStackedItemView.swift`): the category
label renders `.font(.system(size: 7, weight: .regular))` with `.foregroundStyle(.secondary)`
(`:111-113`); neither block pins row heights, so with `VStack(spacing: 0)` the standard
block fits **23.0 pt** and the network block **22.0 pt** — a 1.0 pt misalignment
(measured, gate §2 pre-edit); `MenuBarLayout` (`StatsLite/MenuBarBlockModel.swift:52-63`)
has no `rowHeight` constant.

Target state (blueprint Appendix A, gate-verified against `5c67c21`): label `:112` flips
to `size: 8` (weight `.regular`, `.secondary` unchanged — the 7 pt override is retired);
`MenuBarLayout.rowHeight: CGFloat = 11` is inserted at
`MenuBarBlockModel.swift:60` (between `networkBlockWidth` at `:59` and the `gap` comment
at `:60`); all four row containers gain `.frame(height: MenuBarLayout.rowHeight)` —
standard row 1 `HStack` after `:114`, standard row 2 value `Text` after `:118`, network
upload `HStack` after `:156`, network download `HStack` after `:170`. Both blocks then
fit exactly **22.00 pt** with a fitting-height delta of **0.00 pt** against
`NSStatusBar.system.thickness` 22.0 pt — zero clipping (measured on the gate's trial
implementation, §2).

Alignment invariant — stated honestly (gate C3, §10): the invariant is **frame-based**.
Row frames and block edges align exactly in both blocks — top 0.00 pt, row boundary
11.00 pt, bottom 22.00 pt, row extents [0, 11] and [11, 22]. Ink baselines do **not**
coincide: the 8 pt label baseline sits at ~8.52 pt and the 9 pt network rate baseline at
~8.90 pt (font-metric model; delta ~0.38 pt). No test, ledger row, or claim in this plan
asserts baseline equality; the ledger records the 0.38 pt font-metric delta as measured.

Six production edits across two files, one green commit. Nothing else moves: values stay
11 pt regular mono, network rates stay 9 pt regular mono, `blockWidth` 34.0 /
`networkBlockWidth` 50.0 / lengths / tints stay, and no `.animation` or
`.contentTransition` modifier enters the status item path.

## Evidence

- Design gate **PASS** (re-gate round 2): `artifacts/2026-10-16-emulate-stats-layout/gate-report-alignment.md`
  (commit `ee4ef04`, ci branch; cherry-picked to `main` in T5). Round 1 blocked on C1–C6;
  the designer's re-issue fixed all six plus N1/N4/N5; §10 re-verified each with targeted
  proofs and found no regression. Notes **N8** (Appendix B item 0 cites "lines 18–21"; the
  imports are `:19–21`), **N9** (item 6 cites "FM1 line 161"; the string sits at test
  `:160`), and **N10** (item 0's `import SwiftUI` shifts later line refs +1 — apply
  Appendix B items by content, not by line number) are edit hints this plan encodes in T2.
- Blueprint archived verbatim: `artifacts/2026-10-16-emulate-stats-layout/blueprint-alignment-final.md`
  (commit `4b35430`; 40,581 bytes; the same extraction `/tmp/designer-final-regate.txt`
  the gate verified). Embedded below.
- Gate measurements (live, not priors; gate §2/§3): 8 pt label widths CPU 17.3164 /
  GPU 17.5625 / MEM row 25.3594 → clearances **16.6836 / 16.4375 / 8.6406**; post-edit
  fitting heights std 22.0000 / net 22.0000, delta 0.0000; pre-edit (7 pt, no frames)
  std 23.0000 / net 22.0000; `NSStatusBar.system.thickness` 22.0; fitting height stable
  across "100%" / "0%" / "--%" / "999 MB/s" / "-- KB/s" / "5 KB/s" (zero jitter).
- Trial-implementation suite receipt (gate §5): the full Appendix A + Appendix B applied
  on a throwaway worktree at `5c67c21` built and ran; the only failures were the gate's
  own C1 test defect and 3 probe assertions for the falsified baseline claim — every one
  of the 227 baseline tests passed at the updated expectations. The re-gate (§10, C1 row)
  simulated the corrected `testRowFramesUseRowHeightConstantInBothBlocks` logic on the
  faithful post-edit source: both network frame lines resolve and both `squashed` outputs
  equal `.frame(height:MenuBarLayout.rowHeight)`.
- Test evidence (authoring): `StatsLiteTests/MenuBarValueTypographyTests.swift` (451 lines,
  9 tests) at `5c67c21` pins the 7 pt state — `expectedLabelFont` `size:7` (`:30`),
  IC-4 `testLabelFontIsSevenPointRegularSecondary` (`:187`, message `must be 7 pt` at
  `:206`), IC-11 clearance constants 10.9067/18.6943/18.4790 at font 7.0 (`:308`, `:332`,
  `:348`, `:364`). **No test pins the pre-alignment fitting heights or any row height**
  (authoring scan `rg 'fittingSize|fittingHeight|rowHeight|22\.0|23\.0' StatsLiteTests/`
  — zero hits); `MenuBarRedrawChurnTests` pins the hosting frame to `button.bounds`,
  which the controller sets and this plan does not touch. Every Appendix B citation above
  re-verified against the current file at authoring (N8/N9/N10 adjustments applied).
- Citation check at authoring (`nl -ba` / `rg` at the workdir tree = `5c67c21` tree):
  `MenuBarStackedItemView.swift` `:103` VStack, `:111-113` label, `:114` HStack close,
  `:118` `.lineLimit(1)`, `:153`/`:167` rate fonts, `:156`/`:170` HStack closes, `:172`
  network width frame; `MenuBarBlockModel.swift` `:59` `networkBlockWidth`, `:60` gap
  comment — all exact.
- Zero-animation scan at authoring (re-verified at the clarity pass): `rg -n
  '\.animation|\.contentTransition'` over the status-item files
  (`StatsLite/MenuBarStackedItemView.swift`, `MenuBarBlockModel.swift`,
  `StatusItemController.swift`, `MenuBarAccessibility.swift`) — comment-only hits
  (`MenuBarStackedItemView.swift:14`, `:15`, `:138`); never a modifier.
  `StatsLite/PopoverContentView.swift:64-66` carries `.animation` modifiers on the
  popover path — pre-existing, outside the VAC-9 selector, untouched by this plan. A
  directory-wide scan hits those popover lines, so IC-9 and the T4 ledger row scan the
  four status-item files.

## ISC — binary checks (every item is yes/no)

> **Screenshot waiver (user authority, carried over 2026-10-16):** every screenshot-based
> visual check in this plan is SKIPPED (menu bar strip captures, dark/light renders,
> visual blend inspection). Reason: no macOS Screen Recording permission;
> `screencapture` of other processes fails with exit 1 (recorded three times in
> `artifacts/2026-10-16-emulate-stats-layout/waiver-note.md`). T1 records the carry-over;
> no new probe runs. Visual ICs get a `waived` ledger row; test-based ICs stay binding.

Citation rule: a bare `:N` means `StatsLite/MenuBarStackedItemView.swift:N`; a test-file
citation names the file. Production line numbers are as-at-`main` 5c67c21 (workdir tree
verified identical). Test-file citations are as-at the test file at the worktree base
(current `main`); the red commit shifts test-file lines, so T2 applies its steps in the
listed top-to-bottom order and each citation stays valid at the step that uses it.
Widths: block widths are pinned (34.0 / 50.0 pt), so every geometry claim holds at all
widths; under the waiver, layout claims verify from test evidence. Each IC ends with a
`Widths:` line.

- [ ] **IC-1 (VAC-1, category labels → 8 pt — FLIPPED)** — `:112` reads
  `.font(.system(size: 8, weight: .regular))` with `.foregroundStyle(.secondary)`
  (`:111-113`); no `size: 7`. The guard
  `testLabelFontIsEightPointRegularSecondary` (renamed back from
  `testLabelFontIsSevenPointRegularSecondary`, `expectedLabelFont` flipped `size:7` →
  `size:8`) **fails at red** while `:112` carries `size: 7`, and passes at green.
  Falsification: fail → pass only when `:112` flips to `size: 8`; any other edit leaves
  it red. Widths: all (pinned block).
- [ ] **IC-2 (VAC-2, values stay 11 pt)** — `:116` stays
  `.font(.system(size: 11, weight: .regular).monospacedDigit())`; guards FM1 (`:148`),
  IC-2 (`:169`), and the IC-10 value-size guard (`:231`) pass at red and at green
  (regression guards; the blueprint does not touch them). Widths: all.
- [ ] **IC-3 (VAC-3, metric stack spacing stays 0)** — `:103` stays
  `VStack(alignment: .center, spacing: 0)`; existing guard
  `testMetricBlockStackUsesZeroVerticalSpacing` passes red and green. Widths: all.
- [ ] **IC-4 (VAC-4, network stack spacing stays 0)** — `:143` stays
  `VStack(alignment: .leading, spacing: 0)`; existing guard
  `testNetworkBlockStackUsesZeroRowSpacing` passes red and green. Widths: all.
- [ ] **IC-5 (VAC-5, widest-value clearance)** — `blockWidth` stays 34.0; "100%" at 11 pt
  regular mono leaves 2.7778 pt ≥ 2.5 (binding Option 1 from the previous plan, unchanged);
  guard passes red and green. Widths: all.
- [ ] **IC-6 (VAC-6, label-row clearance at 8 pt)** — the label row fits the 34.0 pt
  block on one line: MEM row 25.3594 → clearance **8.6406** ≥ 3.5; CPU **16.6836** ≥ 16.0;
  GPU **16.4375** ≥ 16.0 (gate-measured). The guard
  `testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints` (renamed back; font `7.0` →
  `8.0`; constants → 8.6406/16.6836/16.4375) measures its own font, so it passes at red
  and at green. Widths: all.
- [ ] **IC-7 (VAC-7, network rate fonts retained)** — upload `:153` and download `:167`
  stay `.font(.system(size: 9, weight: .regular).monospacedDigit())`; the compound IC-10
  network assertion passes red and green. Widths: all.
- [ ] **IC-8 (VAC-8, network clearance retained)** — `networkBlockWidth` stays 50.0
  (`:172` frame); "999 MB/s" leaves 1.8916 pt ≥ 1.8; guard passes red and green.
  Widths: all.
- [ ] **IC-9 (VAC-9, zero animation)** — `rg -n '\.animation|\.contentTransition'` over
  the status-item files (`StatsLite/MenuBarStackedItemView.swift`,
  `MenuBarBlockModel.swift`, `StatusItemController.swift`, `MenuBarAccessibility.swift`)
  finds comment-only hits (`:14`, `:15`, `:138`) and never a modifier; the popover
  `.animation` at `PopoverContentView.swift:64-66` is outside the VAC-9 selector and
  stays untouched; `MenuBarRedrawChurnTests` passes. Widths: all runtimes.
- [ ] **IC-10 (VAC-10, length contract)** — `MenuBarLayout.length` stays 168/114/92/76/54/38/4;
  Edit 1 adds a `static let` only, so `length(...)` is untouched; `MenuBarLayoutTests`
  passes. The 130 pt row stays unpinned (gate N7, recorded deferral). Widths: all.
- [ ] **IC-11 (VAC-11, fitting-height equality — NEW guard)** —
    `NSHostingView(rootView: MenuBarBlockView(...)).fittingSize.height` and the network
  equivalent both measure exactly **22.00 pt** (accuracy 0.01) and
  `abs(std − net) < 0.01 pt`. The new guard
  `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness` **fails at red** (std fits
  23.00 pt, net 22.00 pt — gate-measured pre-edit state) and passes at green
  (22.0000/22.0000, delta 0.0000 — gate-measured post-edit). Falsification: fail → pass
  only when both blocks fit 22.00 pt. Widths: all.
- [ ] **IC-12 (VAC-12, row-height constant + row-frame tokens — NEW guard)** —
  `MenuBarLayout.rowHeight` exists as `static let rowHeight: CGFloat = 11` in
  `MenuBarBlockModel.swift`, and all four row containers carry
  `.frame(height: MenuBarLayout.rowHeight)` (post-edit lines `:115`, `:120`, `:159`,
  `:174` — gate-verified map). Frame extents follow by construction: [0, 11] and
  [11, 22] in both blocks; edges and boundaries align exactly. Ink baselines differ
  ~0.38 pt by font metrics — recorded, not asserted equal. The new guard
  `testRowFramesUseRowHeightConstantInBothBlocks` **fails at red** (constant absent,
  no frame tokens) and passes at green. Falsification: fail → pass only when the
  constant and all four frame lines exist. Widths: all.
- [ ] **IC-13 (suite counts)** — the red run executes **229 tests with exactly 3
  failures** (derivation below); the green run executes **229 tests with 0 failures**.
  No test is deleted. Widths: n/a.
- [ ] **IC-14 (scope)** — the production diff against `main` contains exactly the six
  Appendix A edits: `MenuBarBlockModel.swift` +4 lines (constant + 3 doc lines) and
  `MenuBarStackedItemView.swift` `:112` flipped plus 4 inserted frame lines. No width,
  length, tint, network/value font, `.monospacedDigit()`, or comment changes; no
  modifier additions. `git diff main...HEAD -- StatsLite/` shows only those; every other
  change lives in `StatsLiteTests/` or `artifacts/`. Widths: n/a.

Red-count derivation (from the current test file, not guessed — `main` 5c67c21,
`MenuBarValueTypographyTests.swift` 451 lines, 9 tests; suite 227 tests / 0 failures
per gate §5):

- Red adds exactly **2** tests (IC-11 guard, IC-12 guard) → **229 tests**.
- Red fails **exactly 3** guards:
  1. `testLabelFontIsEightPointRegularSecondary` — expected token `size:8`, production
     `:112` carries `size:7`;
  2. `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness` (new) — std fitting
     23.00 pt ≠ 22.00 pt (and std ≠ net);
  3. `testRowFramesUseRowHeightConstantInBothBlocks` (new) — `rowHeight` constant absent
     from `MenuBarBlockModel.swift`; no `.frame(height` lines in either network section
     (XCTUnwrap fails, never vacuous).
- Nothing else can fail: the rewritten IC-11 clearance guard measures its own 8 pt font
  with gate-verified constants (passes at red); FM1, IC-2, IC-3, IC-10 (both its guards),
  IC-12 clearance, and both spacing guards pin tokens this plan does not change;
  `MenuBarLayoutTests`, `MenuBarRedrawChurnTests`, `MenuBarBlockBuilderTests`, and every
  other file pin no label font, no fitting height, and no row height (authoring scan
  above). If any red-expected guard passes at HEAD, it is not coupled to its token:
  fix the guard in the red commit; do not start green.

Plan-scoped failure modes:

- **FM1** — the label token stays (or reverts to) `size: 7` → IC-1 fails. Red proves it.
- **FM2** — `rowHeight` is missing or ≠ 11 → IC-12 fails (constant token) and IC-11 fails
  (2 × rowHeight ≠ 22.00). Red proves the missing case.
- **FM3** — any of the four row-frame tokens is missing → IC-12 fails (red proves both
  network sections and the standard block independently).
- **FM4** — the blocks do not both fit 22.00 pt → IC-11 fails. Red proves it (23 vs 22).
- **FM5** — the edit escapes the six Appendix A edits (widths, lengths, value/rate fonts,
  `.monospacedDigit()`, tints, comments) → IC-5 / IC-7 / IC-8 / IC-10 / IC-14 fail.
- **FM6** — `.animation` or `.contentTransition` enters the status item path → IC-9 fails.

## Approach

1. One green commit with the six Appendix A edits: the `rowHeight` constant in
   `MenuBarBlockModel.swift`, the label token `7` → `8` at `:112`, and four
   `.frame(height: MenuBarLayout.rowHeight)` lines — two in `MenuBarBlockView`, two in
   `MenuBarNetworkBlockView`. No other production line changes (IC-14).
2. TDD with the existing source-token mechanism: the red commit first rewrites the
   label-token and label-clearance guards to the 8 pt expectations and adds the two new
   alignment guards (fitting heights; frame tokens + constant), then fails on exactly
   three guards. The green commit flips the production tokens. Red and green are two
   sequential coder spawns in one worktree.
3. One documented adaptation of blueprint Appendix B §5: the blueprint lists three new
   tests, including a compiled assertion `MenuBarLayout.rowHeight == 11.0`. A compiled
   reference to a constant that does not exist yet cannot fail at red — it prevents the
   whole test target from building. T2 therefore folds the constant check into the
   frame-token guard as a source-token assertion on `MenuBarBlockModel.swift`
   (`sourceLine(containing: "rowHeight")` squashed equals
   `staticletrowHeight:CGFloat=11`) and keeps the blueprint's fitting-height test and its
   C1-corrected frame-token test verbatim. The invariant set is identical: constant token,
   four frame tokens, 22.00 pt fitting heights. The reviewer checks this adaptation.
4. T1 records the screenshot-waiver carry-over instead of captures; the ledger gets
   pass rows for every test-based IC and one `waived` row for the capture set.
5. Verification: automated checks for IC-1 … IC-14. Evidence per IC: green/red test
   names, `rg` output for IC-9, recorded gate measurements for IC-5 / IC-6 / IC-8 /
   IC-11 / IC-12, diff stat for IC-14.
6. Merge after reviewer GO under hazard (a): the gate report `ee4ef04` is cherry-picked
   onto `main` first, every merge step runs only from a checkout verified to be on
   `main`, and the ci branch is never checked out, reset, or merged. Under hazard (b):
   rebase onto `main` before the ff-only merge.

### Design Blueprint (verbatim)

The gate-PASS Design Blueprint (final re-issue, designer session `9be74fe6`, corrections
C1–C6 and notes N1/N4/N5 incorporated) follows. Source:
`artifacts/2026-10-16-emulate-stats-layout/blueprint-alignment-final.md` (commit
`4b35430`). It is the authority for every visual requirement in this plan; the ISC
mirrors its VAC list. Deviations are limited to the single documented adaptation in
Approach item 3.

# Summary of Accomplishments

This re-issued Design Blueprint resolves all six gate blocking defects (C1–C6) and incorporates the non-blocking notes (N1, N4, N5).

### Resolution of Gate Blocking Defects (C1–C6)
1. **C1 (Test Design Fix for `testRowFramesUseRowHeightConstantInBothBlocks`)**:
   - The previous test design called `squashed(netScope)`. That helper truncated the network block scope at `// Line 1: Upload rate` before the frame tokens.
   - The test design now uses `sourceLine(containing: ".frame(height", in: netScope[section.upperBound...])` for both upload and download sections.
   - It verifies each line individually with `squashed(line) == ".frame(height:MenuBarLayout.rowHeight)"`.
   - The `blockScope` assertion remains unchanged as verified.
2. **C2 (SwiftUI Import in Test File)**:
   - Added `import SwiftUI` to `StatsLiteTests/MenuBarValueTypographyTests.swift`.
   - This import provides `NSHostingView` in the test file scope.
3. **C3 (Honest Alignment Invariants vs Falsified Baseline Claim)**:
   - Removed the falsified claim that row-1 font baselines match at 8.00 pt.
   - Live measurements confirm that frame edges and row extents align exactly across both blocks (`[0.00 pt, 11.00 pt]` and `[11.00 pt, 22.00 pt]`).
   - Recorded the measured font-metric baseline variance: ~8.52 pt for 8 pt standard label versus ~8.90 pt for 9 pt network rate (delta ~0.38 pt).
   - Restated VAC-12 as a frame-based, testable invariant based on fitting heights and `.frame(height: MenuBarLayout.rowHeight)` tokens.
4. **C4 (Post-Edit Line Numbers for VAC-7 and VAC-8)**:
   - Corrected VAC-7 selectors to lines `:155` (upload rate font) and `:170` (download rate font).
   - Corrected VAC-8 selector to line `:176` (network container frame).
5. **C5 (Edit 3 Current Code Quote Alignment with HEAD)**:
   - Corrected Appendix A Edit 3 "Current Code" quote to show `.font(.system(size: 7, weight: .regular))` at line `:112` matching HEAD.
6. **C6 (Part 4 §2 Citation Range)**:
   - Corrected the citation range to `StatusItemController.swift:76-86` to include `button.addSubview(hostingView)` at line `:86`.

### Integration of Non-Blocking Notes (N1, N4, N5)
- **N1**: Documented that the 42.91 pt text width in `MenuBarBlockModel.swift:56-58` is a pre-existing source comment from the 9 pt medium era. Documented that refreshing this comment is deferred to an out-of-scope documentation commit.
- **N4**: Added an item in Appendix B to refresh the file header narrative in `MenuBarValueTypographyTests.swift:5-16`.
- **N5**: Updated clearance failure message strings in Appendix B §3 to match the new targets (8.6406 pt, 16.6836 pt, 16.4375 pt). Documented line reference shifts in test failure messages for FM1, IC-10, and VAC-4.

---

# Design Blueprint: Menu Bar Typography & Row-Alignment Update

This design blueprint specifies typography and row-alignment updates for the macOS menu bar status item in `StatsLite`.
The design tokens in this blueprint supersede previous menu bar typography specifications.

The project repository does not contain a `DESIGN.md` file at the repository root.
All design tokens and dimensions ground in macOS AppKit system APIs, SwiftUI primitives, and existing constants in `StatsLite`.

---

## Live Measurement Findings & Visual Reference Analysis

### 1. Visual Reference Inspection (`reference-stats.png`)
The reference artifact at `artifacts/2026-10-16-emulate-stats-layout/reference-stats.png` measures `386x64 px` (`193.0x32.0 pt` at 2x Retina scale).
Analysis of pixel coordinates in the reference image reveals:
- The standard metric block (`CPU` above `5%`), temperature block (`45°` above `45°`), and network block (`5 KB/s` above `16 KB/s`) share identical top and bottom visual bounds.
- Line 1 across all blocks sits in the upper half of the menu bar height.
- Line 2 across all blocks sits in the lower half of the menu bar height.
- In the network block, the red and blue indicator dots sit vertically aligned with the respective rate text strings.

### 2. Fitting Heights & Clipping Analysis Against `NSStatusBar`
- `NSStatusBar.system.thickness` measures **22.0 pt**.
- In `StatusItemController.swift:76-86`, `hostingView.frame = button.bounds` configures `hostingView` to match the button frame (`height: 22.0 pt`).
- Before alignment (at HEAD with 7 pt label):
  - `MenuBarBlockView` fitting height: **23.0 pt**.
  - `MenuBarNetworkBlockView` fitting height: **22.0 pt**.
  - Height difference: **1.0 pt**. Standard blocks extend 0.5 pt beyond top and bottom edges.
- Unconstrained 8 pt label without alignment frames:
  - `MenuBarBlockView` fitting height: **24.0 pt** (row 1 is 10.0 pt, row 2 is 14.0 pt).
  - `MenuBarNetworkBlockView` fitting height: **22.0 pt** (row 1 is 11.0 pt, row 2 is 11.0 pt).
  - Height difference: **2.0 pt**. Standard blocks extend 1.0 pt above and 1.0 pt below network blocks.
- After alignment edit (`MenuBarLayout.rowHeight = 11 pt`):
  - `MenuBarBlockView` fitting height: **22.0 pt** (`2 * 11.0 pt`).
  - `MenuBarNetworkBlockView` fitting height: **22.0 pt** (`2 * 11.0 pt`).
  - Fitting height delta: **0.00 pt**.
  - Row 1 extents: `[0.00 pt, 11.00 pt]` in both blocks (center at `5.50 pt`).
  - Row 2 extents: `[11.00 pt, 22.00 pt]` in both blocks (center at `16.50 pt`).
  - Overflow against `NSStatusBar.system.thickness`: **0.00 pt**.
  - Clipping risk: **zero**.
- Font-Metric Baseline Behavior:
  - Text baselines inside 11 pt row frames depend on font metrics.
  - Standard block line 1 (8 pt regular "CPU") baseline sits at ~8.52 pt (font-metric model; ink bottom ~9.00 pt at 4x).
  - Network block line 1 (9 pt regular "999") baseline sits at ~8.90 pt (font-metric model; ink bottom ~9.25 pt at 4x).
  - The baseline delta is ~0.38 pt. Because row frame heights and centers match exactly, this small font-metric variance preserves optical balance.

### 3. Font Metrics and Clearance Measurements
All measurements derive from live `NSFont` and `NSHostingView` evaluations on macOS 14+.

| Element | Font Spec | Measured Text Width | Block Width | Total Clearance | Margin Per Side | Threshold | Status |
|---|---|---|---|---|---|---|---|
| `CPU` label | 8 pt `.regular` | 17.3164 pt | 34.0 pt | 16.6836 pt | 8.3418 pt | `>= 16.0 pt` | Pass |
| `MEM` label + dot | 8 pt `.regular` (+ 4 pt dot + 2 pt gap) | 25.3594 pt | 34.0 pt | 8.6406 pt | 4.3203 pt | `>= 3.5 pt` | Pass |
| `GPU` label | 8 pt `.regular` | 17.5625 pt | 34.0 pt | 16.4375 pt | 8.2188 pt | `>= 16.0 pt` | Pass |
| `"100%"` value | 11 pt `.regular.monospacedDigit()` | 31.2222 pt | 34.0 pt | 2.7778 pt | 1.3889 pt | `>= 2.5 pt` (relaxed) | Pass |
| `"0%"` / `"5%"` value | 11 pt `.regular.monospacedDigit()` | 17.2358 pt | 34.0 pt | 16.7642 pt | 8.3821 pt | `>= 2.5 pt` | Pass |
| `"--%"` placeholder | 11 pt `.regular.monospacedDigit()` | 20.7485 pt | 34.0 pt | 13.2515 pt | 6.6257 pt | `>= 2.5 pt` | Pass |
| `"999 MB/s"` network | 9 pt `.regular.monospacedDigit()` (+ 6 pt dot) | 48.1084 pt | 50.0 pt | 1.8916 pt | N/A (Spacer) | `>= 1.8 pt` | Pass |

---

## Part 1: Visual Hierarchy & ASCII Wireframe

### ASCII Wireframe (Menu Bar Status Item at 168 pt Total Length)

```
+-----------------------------------------------------------------------------------------------------------------------------------+
| Outer Leading Padding: 2 pt                                                                           Outer Trailing Padding: 2 pt|
|                                                                                                                                   |
| +--------------------+   Gap   +--------------------+   Gap   +--------------------+   Gap   +----------------------------------+ |
| |   CPU Block (34)   |   4 pt  |   RAM Block (34)   |   4 pt  |   GPU Block (34)   |   4 pt  |        Network Block (50)        | |
| |                    |         |                    |         |                    |         |                                  | |
| |     [  CPU  ]      |         |   (o) [  MEM  ]    |         |     [  GPU  ]      |         |  (*) Upload       [   5 KB/s ]   | |
| |  8 pt Reg (h: 11)  |         | 4pt 8 pt Reg(h: 11)|         |  8 pt Reg (h: 11)  |         |  6pt Red          9 pt Reg Mono  | |
| |                    |         |                    |         |                    |         |                     (row h: 11)  | |
| |     [  5%   ]      |         |     [ 45%  ]       |         |     [  0%   ]      |         |  (*) Download     [  16 KB/s ]   | |
| | 11 pt Mono (h: 11) |         | 11 pt Mono (h: 11) |         | 11 pt Mono (h: 11) |         |  6pt Blue         9 pt Reg Mono  | |
| |                    |         |                    |         |                    |         |                     (row h: 11)  | |
| +--------------------+         +--------------------+         +--------------------+         +----------------------------------+ |
+-----------------------------------------------------------------------------------------------------------------------------------+
```

### Visual Weight & Alignment Invariants
1. **Vertical Alignment**:
   - `MenuBarBlockView` and `MenuBarNetworkBlockView` use `VStack(spacing: 0)`.
   - Every line in both blocks specifies `.frame(height: MenuBarLayout.rowHeight)`.
   - The shared constant `MenuBarLayout.rowHeight = 11 pt` makes both blocks exactly **22.0 pt** high.
   - Top edges of `MenuBarBlockView` and `MenuBarNetworkBlockView` sit at `y = 0.00 pt`.
   - Bottom edges of `MenuBarBlockView` and `MenuBarNetworkBlockView` sit at `y = 22.00 pt`.
   - The boundary between row 1 and row 2 in both blocks sits at `y = 11.00 pt`.
   - Row 1 centers sit at `y = 5.50 pt` and Row 2 centers sit at `y = 16.50 pt`.
   - Text baselines differ by ~0.38 pt due to font metrics between 8 pt regular and 9 pt monospaced regular.
2. **Horizontal Alignment**:
   - Category labels and percentage values center horizontally within each 34.0 pt block.
   - In `MEM`, the 4.0 pt indicator dot sits leading of `"MEM"` with 2.0 pt spacing and `-0.5 pt` vertical offset.
   - In Network, the 6.0 pt circular dots form a leading column. Rate strings align to the trailing edge. A flexible `Spacer(minLength: 1)` absorbs horizontal slack within the 50.0 pt block.

---

## Part 2: Template / Component Skeleton

### 1. Layout Constants Extension (`MenuBarBlockModel.swift`)

Location in `StatsLite/MenuBarBlockModel.swift`: line 60.

```swift
enum MenuBarLayout {
    /// Pinned width of every block. "100%" at the value font fits
    /// with clearance.
    static let blockWidth: CGFloat = 34
    /// Pinned width of the two-line network block. Fits the widest
    /// truncated rate string "999 MB/s" (42.91 pt) plus the 6 pt dot
    /// with 1.09 pt clearance (appendix B §1).
    static let networkBlockWidth: CGFloat = 50
    /// Pinned height of each line within a block. Two 11 pt rows yield
    /// a 22 pt block height that matches NSStatusBar.system.thickness
    /// and aligns line 1 and line 2 across standard and network blocks.
    static let rowHeight: CGFloat = 11
    /// Gap between adjacent blocks.
    static let gap: CGFloat = 4
    /// Outer padding: leading 2 pt plus trailing 2 pt.
    static let padding: CGFloat = 2

    // length(...) remains unchanged
}
```

*(Note: The comment above `networkBlockWidth` referencing 42.91 pt and 1.09 pt clearance is a pre-existing source comment in `StatsLite/MenuBarBlockModel.swift:56-58` from the earlier 9 pt medium era. Live measured values at 9 pt regular are 42.1084 pt and 1.8916 pt clearance. Updating this historical source comment is deferred to an out-of-scope documentation cleanup commit.)*

### 2. Standard Metric Block Skeleton (`MenuBarBlockView`)

Location in `StatsLite/MenuBarStackedItemView.swift`: lines 99–133.

```swift
/// One metric block: category label on line 1, value on line 2.
/// Width pins to block.width so text changes never resize the item.
/// Line heights pin to MenuBarLayout.rowHeight to align with network blocks.
/// Internal so redraw-churn tests can walk its body tree.
struct MenuBarBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                if let dotState = block.dotState {
                    Circle()
                        .fill(dotState.levelColor)
                        .frame(width: 4, height: 4)
                        .offset(y: -0.5)
                }
                Text(block.label)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(height: MenuBarLayout.rowHeight)

            Text(block.valueText)
                .font(.system(size: 11, weight: .regular).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .frame(height: MenuBarLayout.rowHeight)
        }
        .frame(width: block.width)
    }

    private var valueColor: Color {
        switch block.valueTint {
        case .primary: .primary
        case .tertiary: Color(nsColor: .tertiaryLabelColor)
        case .warning: Color(nsColor: .systemOrange)
        case .critical: Color(nsColor: .systemRed)
        }
    }
}
```

### 3. Network Speed Block Skeleton (`MenuBarNetworkBlockView`)

Location in `StatsLite/MenuBarStackedItemView.swift`: lines 141–196.

```swift
/// Dedicated two-line network speed monitor block:
/// line 1 carries a 6 pt red indicator dot and the upload rate.
/// line 2 carries a 6 pt blue indicator dot and the download rate.
/// Width pins to block.width (50 pt), so rate string changes never
/// resize the item (VAC-N1). Line heights pin to MenuBarLayout.rowHeight
/// to align with metric blocks. Transitions stay discrete: no
/// .animation and no .contentTransition modifiers (VAC-9).
struct MenuBarNetworkBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Line 1: Upload rate
            HStack(alignment: .center, spacing: 0) {
                Circle()
                    .fill(Color(nsColor: .systemRed))
                    .frame(width: 6, height: 6)

                Spacer(minLength: 1)

                Text(block.valueText)
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)

            // Line 2: Download rate
            HStack(alignment: .center, spacing: 0) {
                Circle()
                    .fill(Color(nsColor: .systemBlue))
                    .frame(width: 6, height: 6)

                Spacer(minLength: 1)

                Text(block.secondaryValueText ?? "-- KB/s")
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(secondaryValueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)
        }
        .frame(width: block.width)
    }

    private var valueColor: Color {
        switch block.valueTint {
        case .primary, .warning, .critical:
            Color.primary
        case .tertiary:
            Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var secondaryValueColor: Color {
        switch block.secondaryValueTint ?? block.valueTint {
        case .primary, .warning, .critical:
            Color.primary
        case .tertiary:
            Color(nsColor: .tertiaryLabelColor)
        }
    }
}
```

---

## Part 3: Complete State & Responsive Matrix

### 1. State Matrix (Color, Typography, and Framing)

| State / Metric | Line 1 Label (Height: 11 pt) | Line 2 Value (Height: 11 pt) | Indicator Dot | Container Dimensions |
|---|---|---|---|---|
| **CPU Normal** (`< 80%`) | 8 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.primary` | None | Pinned 34.0 x 22.0 pt |
| **CPU Warning** (`80%...94%`) | 8 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.systemOrange` | None | Pinned 34.0 x 22.0 pt |
| **CPU Critical** (`>= 95%`) | 8 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.systemRed` | None | Pinned 34.0 x 22.0 pt |
| **CPU Unavailable** (nil) | 8 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.tertiaryLabelColor` (`"--%"`) | None | Pinned 34.0 x 22.0 pt |
| **RAM Normal** (`pressure < 60%`) | 8 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.primary` | 4 pt `.systemGreen` | Pinned 34.0 x 22.0 pt |
| **RAM Warning** (`60%...80%`) | 8 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.primary` | 4 pt `.systemYellow` | Pinned 34.0 x 22.0 pt |
| **RAM Critical** (`pressure > 80%`) | 8 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.primary` | 4 pt `.systemRed` | Pinned 34.0 x 22.0 pt |
| **RAM Unavailable** (nil) | 8 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.tertiaryLabelColor` (`"--%"`) | 4 pt `.systemGray` | Pinned 34.0 x 22.0 pt |
| **GPU Normal / High** | 8 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, per threshold | None | Pinned 34.0 x 22.0 pt |
| **Network Active** | 9 pt `.regular.monospacedDigit()`, `.primary` | 9 pt `.regular.monospacedDigit()`, `.primary` | Upload: 6 pt Red, Download: 6 pt Blue | Pinned 50.0 x 22.0 pt |
| **Network Idle / Nil** | 9 pt `.regular.monospacedDigit()`, `.tertiaryLabelColor` (`"-- KB/s"`) | 9 pt `.regular.monospacedDigit()`, `.tertiaryLabelColor` (`"-- KB/s"`) | Upload: 6 pt Red, Download: 6 pt Blue | Pinned 50.0 x 22.0 pt |

### 2. Responsive & Dynamic Length Adaptation (Status Item Invariant)

Status item length adapts to preference combinations through `MenuBarLayout.length(showCPU:showRAM:showGPU:showNetwork:)`.
The length remains invariant to data changes. Block height remains 22.0 pt for all configurations.

| Enabled Metric Configuration | Number of Blocks | Mathematical Formulation | Fixed Item Dimensions (Width x Height) |
|---|---|---|---|
| **All Four Metrics** (CPU + RAM + GPU + NET) | 4 | `2*2 + 3*34 + 1*50 + 3*4` | **168.0 x 22.0 pt** |
| **All Three Standard Metrics** (CPU + RAM + GPU) | 3 | `2*2 + 3*34 + 2*4` | **114.0 x 22.0 pt** |
| **Any Two Standard Metrics** (for example CPU + RAM) | 2 | `2*2 + 2*34 + 1*4` | **76.0 x 22.0 pt** |
| **One Standard Metric + Network** | 2 | `2*2 + 1*34 + 1*50 + 1*4` | **92.0 x 22.0 pt** |
| **Two Standard Metrics + Network** | 3 | `2*2 + 2*34 + 1*50 + 2*4` | **130.0 x 22.0 pt** |
| **Network Only** | 1 | `2*2 + 1*50 + 0` | **54.0 x 22.0 pt** |
| **Single Standard Metric** (CPU, RAM, or GPU) | 1 | `2*2 + 1*34 + 0` | **38.0 x 22.0 pt** |
| **All Metrics Disabled** | 0 | `2*2 + 0` | **4.0 x 22.0 pt** (padding only) |

---

## Part 4: Accessibility (WCAG 2.2) & Interaction Contracts

### 1. Retirement of 7 pt Legibility User Override
- The previous 7 pt label legibility user-override record is retired.
- Category labels restore to **8 pt `.regular`**.
- At 8 pt, `NSFont.systemFont(ofSize: 8.0, weight: .regular)` provides a cap height of **5.64 pt** (11.28 physical pixels on 2x Retina displays).
- This point size avoids crossbar blurring in `"E"` and leg collision in `"M"`.
- Paired with 11 pt regular values and `.secondary` foreground style, visual hierarchy remains clear without requiring bold weights.

### 2. Status Item Button Hosting View Contract
- `StatusItemController.swift:76-86` configures `hostingView`:
  ```swift
  let hostingView = PassthroughHostingView(rootView: rootView)
  hostingView.sizingOptions = []
  hostingView.translatesAutoresizingMaskIntoConstraints = true
  hostingView.autoresizingMask = [.width, .height]
  hostingView.frame = button.bounds
  button.addSubview(hostingView)
  ```
- With `MenuBarLayout.rowHeight = 11 pt`, both block views measure exactly 22.0 pt fitting height.
- The view bounds match `button.bounds` (`height: 22.0 pt`) exactly.
- The layout introduces zero vertical overflow beyond the status bar bounds.

### 3. VoiceOver & Accessibility Tree Contract
- The SwiftUI root view declares `.accessibilityHidden(true)` at `MenuBarStackedItemView.swift:45`.
- Accessibility is managed by `StatusItemController.updateAccessibility()` (`StatsLite/StatusItemController.swift:192-196`).
- The controller configures `statusItem.button`:
  - `button?.setAccessibilityElement(true)`
  - `button?.setAccessibilityTitle("StatsLite")`
  - `button?.setAccessibilityLabel(compositeLabel)`
- Metric values and labels ride in `compositeLabel`, constructed via `MenuBarAccessibility.compositeLabel(...)`.
- The typography and row-height edits introduce zero changes to accessibility labels or VoiceOver strings.

### 4. Interaction & Animation Contract
- Clicks on `statusItem.button` toggle the popover via `#selector(togglePopover(_:))`.
- If the popover is open, `button.isHighlighted` remains `true`.
- **Zero Animation Rule**: Zero `.animation()` or `.contentTransition()` modifiers exist anywhere in `MenuBarBlockView`, `MenuBarNetworkBlockView`, or `MenuBarStackedItemView`. Metric transitions remain discrete.

---

## Part 5: Numbered Visual Acceptance Checklist (VAC)

- **VAC-1 (Category Label Font Size and Weight)**:
  - Selector: `MenuBarBlockView` Line 1 category label `Text(block.label)` font modifier (`StatsLite/MenuBarStackedItemView.swift:112`)
  - Target Viewport: macOS Menu Bar
  - Invariant: The font modifier must be `.font(.system(size: 8, weight: .regular))`. The font must not use size 7 or weight `.bold`.

- **VAC-2 (Value Font Size and Weight)**:
  - Selector: `MenuBarBlockView` Line 2 value `Text(block.valueText)` font modifier (`StatsLite/MenuBarStackedItemView.swift:117`)
  - Target Viewport: macOS Menu Bar
  - Invariant: The font modifier must remain `.font(.system(size: 11, weight: .regular).monospacedDigit())`.

- **VAC-3 (Metric Block Vertical Stack Spacing)**:
  - Selector: `MenuBarBlockView` `VStack` declaration (`StatsLite/MenuBarStackedItemView.swift:103`)
  - Target Viewport: macOS Menu Bar
  - Invariant: The `VStack` must specify `alignment: .center, spacing: 0`.

- **VAC-4 (Network Block Vertical Row Spacing)**:
  - Selector: `MenuBarNetworkBlockView` `VStack` declaration (`StatsLite/MenuBarStackedItemView.swift:145`)
  - Target Viewport: macOS Menu Bar
  - Invariant: The `VStack` must specify `alignment: .leading, spacing: 0`.

- **VAC-5 (Widest Value Clearance Invariant under Relaxed Threshold)**:
  - Selector: `MenuBarBlockView` value container frame (`StatsLite/MenuBarStackedItemView.swift:122`)
  - Target Viewport: macOS Menu Bar
  - Invariant: Container width must remain pinned to 34.0 pt (`MenuBarLayout.blockWidth`). The widest formatted percentage value (`"100%"`) at 11 pt regular monospacedDigit (measured width 31.2222 pt) must leave at least 2.5 pt total clearance (measured: 2.7778 pt total clearance, 1.3889 pt margin per side) with zero text truncation.

- **VAC-6 (Label Row Clearance Invariant at 8 pt Regular)**:
  - Selector: `MenuBarBlockView` category label `HStack` container (`StatsLite/MenuBarStackedItemView.swift:104-115`)
  - Target Viewport: macOS Menu Bar
  - Invariant: All category labels (`CPU`, `MEM`, `GPU`) must render on a single line inside the 34.0 pt block width with zero truncation. For `MEM` with the 4.0 pt dot and 2.0 pt spacing, total row width must measure 25.3594 pt, leaving 8.6406 pt total clearance (4.3203 pt margin per side, satisfying the `>= 3.5 pt` rule). For `CPU` (17.3164 pt) and `GPU` (17.5625 pt), total clearance must exceed 16.0 pt.

- **VAC-7 (Network Rate Value Font Invariant)**:
  - Selector: `MenuBarNetworkBlockView` rate `Text` font modifiers (`StatsLite/MenuBarStackedItemView.swift:155`, `:170`)
  - Target Viewport: macOS Menu Bar
  - Invariant: Upload rate text and download rate text must remain `.font(.system(size: 9, weight: .regular).monospacedDigit())`. Neither line can use `.medium` or `.bold`.

- **VAC-8 (Network Block Clearance & Containment Invariant)**:
  - Selector: `MenuBarNetworkBlockView` container frame (`StatsLite/MenuBarStackedItemView.swift:176`)
  - Target Viewport: macOS Menu Bar
  - Invariant: Container width must remain pinned to 50.0 pt (`MenuBarLayout.networkBlockWidth`). The widest formatted rate string (`"999 MB/s"`, width 42.1084 pt) plus 6.0 pt indicator dot must leave at least 1.8 pt width for `Spacer(minLength: 1)` (measured clearance: 1.8916 pt). Both rate strings must render on a single line with zero truncation ellipsis.

- **VAC-9 (Discrete Rendering / Zero Animation Invariant)**:
  - Selector: `MenuBarStackedItemView`, `MenuBarBlockView`, `MenuBarNetworkBlockView`
  - Target Viewport: All macOS runtimes
  - Invariant: View body trees must contain zero `.animation` or `.contentTransition` modifiers.

- **VAC-10 (Layout Length Contract Invariants)**:
  - Selector: `MenuBarLayout.length(showCPU:showRAM:showGPU:showNetwork:)`
  - Target Viewport: All macOS runtimes
  - Invariant: Fixed item lengths must evaluate to:
    - All four metrics enabled: **168.0 pt**
    - All three standard metrics enabled: **114.0 pt**
    - Any two standard metrics enabled: **76.0 pt**
    - Single standard metric enabled: **38.0 pt**
    - Network metric only enabled: **54.0 pt**
    - All metrics disabled: **4.0 pt**

- **VAC-11 (Block Fitting Height Equality Across Block Types)**:
  - Selector: `NSHostingView(rootView: MenuBarBlockView(...)).fittingSize.height` and `NSHostingView(rootView: MenuBarNetworkBlockView(...)).fittingSize.height`
  - Target Viewport: macOS Menu Bar
  - Invariant: Both block types must produce identical fitting heights of exactly 22.00 pt. The absolute difference between standard block fitting height and network block fitting height must be strictly less than 0.01 pt (`abs(stdFittingHeight - netFittingHeight) < 0.01 pt`).

- **VAC-12 (Row Frame Height and Alignment Invariants Across Block Types)**:
  - Selector: `MenuBarLayout.rowHeight` constant declaration and `.frame(height: MenuBarLayout.rowHeight)` modifiers on all four row containers in `MenuBarStackedItemView.swift` (`:115, :120, :159, :174`) plus block fitting heights
  - Target Viewport: macOS Menu Bar
  - Invariant:
    - `MenuBarLayout.rowHeight` must equal `11.0 pt` (`accuracy: 0.0001`).
    - All four row containers (metric block row 1 HStack, metric block row 2 Text, network block line 1 upload HStack, and network block line 2 download HStack) must declare `.frame(height: MenuBarLayout.rowHeight)`.
    - With `VStack(spacing: 0)`, both `MenuBarBlockView` and `MenuBarNetworkBlockView` evaluate to exactly `22.00 pt` fitting height (`accuracy: 0.01 pt`).
    - Row 1 extents sit at `[0.00 pt, 11.00 pt]` and Row 2 extents sit at `[11.00 pt, 22.00 pt]` in both blocks, ensuring top edges align at `0.00 pt`, row boundaries align at `11.00 pt`, and bottom edges align at `22.00 pt`.

---

## Appendix A: Exact Token Edits in Production Source

All line numbers verified at `HEAD` (commits `7f966dc` / `5c67c21`).

### Target File 1: `StatsLite/MenuBarBlockModel.swift`

**Edit 1: Add `MenuBarLayout.rowHeight` constant**
- Location: Insert at line 60 (between `networkBlockWidth` and `gap`)
- Added Code:
  ```swift
    /// Pinned height of each line within a block. Two 11 pt rows yield
    /// a 22 pt block height that matches NSStatusBar.system.thickness
    /// and aligns line 1 and line 2 across standard and network blocks.
    static let rowHeight: CGFloat = 11
  ```

### Target File 2: `StatsLite/MenuBarStackedItemView.swift`

**Edit 2: `MenuBarBlockView` Label font size**
- Location: Line 112 (Text at line 111)
- Current Code:
  ```swift
  Text(block.label)
      .font(.system(size: 7, weight: .regular))
      .foregroundStyle(.secondary)
  ```
- Target Code:
  ```swift
  Text(block.label)
      .font(.system(size: 8, weight: .regular))
      .foregroundStyle(.secondary)
  ```

**Edit 3: `MenuBarBlockView` Row 1 frame height**
- Location: Line 114 (closing brace of Line 1 `HStack`)
- Current Code:
  ```swift
              HStack(alignment: .center, spacing: 2) {
                  if let dotState = block.dotState {
                      Circle()
                          .fill(dotState.levelColor)
                          .frame(width: 4, height: 4)
                          .offset(y: -0.5)
                  }
                  Text(block.label)
                      .font(.system(size: 7, weight: .regular))
                      .foregroundStyle(.secondary)
              }
  ```
- Target Code:
  ```swift
              HStack(alignment: .center, spacing: 2) {
                  if let dotState = block.dotState {
                      Circle()
                          .fill(dotState.levelColor)
                          .frame(width: 4, height: 4)
                          .offset(y: -0.5)
                  }
                  Text(block.label)
                      .font(.system(size: 8, weight: .regular))
                      .foregroundStyle(.secondary)
              }
              .frame(height: MenuBarLayout.rowHeight)
  ```

**Edit 4: `MenuBarBlockView` Row 2 frame height**
- Location: Line 118 (after `.lineLimit(1)` on `Text(block.valueText)`)
- Current Code:
  ```swift
              Text(block.valueText)
                  .font(.system(size: 11, weight: .regular).monospacedDigit())
                  .foregroundStyle(valueColor)
                  .lineLimit(1)
  ```
- Target Code:
  ```swift
              Text(block.valueText)
                  .font(.system(size: 11, weight: .regular).monospacedDigit())
                  .foregroundStyle(valueColor)
                  .lineLimit(1)
                  .frame(height: MenuBarLayout.rowHeight)
  ```

**Edit 5: `MenuBarNetworkBlockView` Line 1 frame height**
- Location: Line 156 (closing brace of Line 1 upload `HStack`)
- Current Code:
  ```swift
              // Line 1: Upload rate
              HStack(alignment: .center, spacing: 0) {
                  Circle()
                      .fill(Color(nsColor: .systemRed))
                      .frame(width: 6, height: 6)

                  Spacer(minLength: 1)

                  Text(block.valueText)
                      .font(.system(size: 9, weight: .regular).monospacedDigit())
                      .foregroundStyle(valueColor)
                      .lineLimit(1)
              }
  ```
- Target Code:
  ```swift
              // Line 1: Upload rate
              HStack(alignment: .center, spacing: 0) {
                  Circle()
                      .fill(Color(nsColor: .systemRed))
                      .frame(width: 6, height: 6)

                  Spacer(minLength: 1)

                  Text(block.valueText)
                      .font(.system(size: 9, weight: .regular).monospacedDigit())
                      .foregroundStyle(valueColor)
                      .lineLimit(1)
              }
              .frame(height: MenuBarLayout.rowHeight)
  ```

**Edit 6: `MenuBarNetworkBlockView` Line 2 frame height**
- Location: Line 170 (closing brace of Line 2 download `HStack`)
- Current Code:
  ```swift
              // Line 2: Download rate
              HStack(alignment: .center, spacing: 0) {
                  Circle()
                      .fill(Color(nsColor: .systemBlue))
                      .frame(width: 6, height: 6)

                  Spacer(minLength: 1)

                  Text(block.secondaryValueText ?? "-- KB/s")
                      .font(.system(size: 9, weight: .regular).monospacedDigit())
                      .foregroundStyle(secondaryValueColor)
                      .lineLimit(1)
              }
  ```
- Target Code:
  ```swift
              // Line 2: Download rate
              HStack(alignment: .center, spacing: 0) {
                  Circle()
                      .fill(Color(nsColor: .systemBlue))
                      .frame(width: 6, height: 6)

                  Spacer(minLength: 1)

                  Text(block.secondaryValueText ?? "-- KB/s")
                      .font(.system(size: 9, weight: .regular).monospacedDigit())
                      .foregroundStyle(secondaryValueColor)
                      .lineLimit(1)
              }
              .frame(height: MenuBarLayout.rowHeight)
  ```

---

## Appendix B: Required Test Assertions Updates

### Target File: `StatsLiteTests/MenuBarValueTypographyTests.swift`

This section enumerates every test token, method name, import, and assertion updated or added.

0. **Module Imports (C2)**:
   - Location: Lines 18–21
   - Add `import SwiftUI` after `import AppKit` and `import XCTest`:
     ```swift
     import AppKit
     import SwiftUI
     import XCTest
     @testable import StatsLite
     ```

1. **Test Header Narrative Refresh (N4)**:
   - Location: Lines 5–16
   - Refresh header comment to narrate the green test suite state for 8 pt labels, 11 pt values, 9 pt network rates, and the 11 pt row height alignment invariant.

2. **Expected Source Token (`expectedLabelFont`)**:
   - Location: Lines 29–30
   - Update comment at line 29 to reference `size: 8`.
   - Update literal at line 30 from `".font(.system(size:7,weight:.regular))"` to `".font(.system(size:8,weight:.regular))"`.
   - `expectedValueFont`, `expectedLabelStyle`, and `expectedNetworkFont` remain unchanged.

3. **Label Font Source Token Test (`IC-4` / `VAC-1`)**:
   - Location: Lines 187–219
   - Rename test method from `testLabelFontIsSevenPointRegularSecondary()` back to `testLabelFontIsEightPointRegularSecondary()`.
   - Update MARK comment at line 185 to `// MARK: - IC-4: label flips to 8 pt regular secondary`.
   - Update failure message phrase at line 206 from `must be 7 pt` to `must be 8 pt`.
   - Assertion `region.contains(expectedLabelFont)` tests line 112 against the updated 8 pt token.

4. **Label Row Clearance Test (`IC-11` / `VAC-6` & N5)**:
   - Location: Lines 307–368
   - Update font definition at line 308 from `NSFont.systemFont(ofSize: 7.0, weight: .regular)` to `NSFont.systemFont(ofSize: 8.0, weight: .regular)`.
   - Rename method from `testLabelRowClearanceForMemRowAtSevenPointRegularMeetsThreeAndAHalfPoints()` back to `testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints()`.
   - Update MARK comment at line 305 to `// MARK: - IC-11: label-row clearance at 8 pt regular`.
   - Update MEM failure message phrase at line 326 from `"MEM" at 7 pt regular` to `"MEM" at 8 pt regular`.
   - Update expected MEM clearance assertion at line 332 from `10.9067 pt` to `8.6406 pt` (accuracy `0.05`), and failure message at line 334 to `expected 8.6406 pt total clearance for the MEM label row`.
   - Update expected CPU clearance assertion at line 348 from `18.6943 pt` to `16.6836 pt` (accuracy `0.05`), and failure message at line 350 to `expected 16.6836 pt total clearance for the CPU label`.
   - Update expected GPU clearance assertion at line 364 from `18.4790 pt` to `16.4375 pt` (accuracy `0.05`), and failure message at line 366 to `expected 16.4375 pt total clearance for the GPU label`.
   - Threshold assertions (`>= 3.5 pt` for MEM, `>= 16.0 pt` for CPU/GPU) continue to pass cleanly.

5. **Row Height Constant & Alignment Invariants Guard (`VAC-11`, `VAC-12` & C1)**:
   - Add new test methods to `MenuBarValueTypographyTests.swift`:
     ```swift
     // MARK: - VAC-11/VAC-12: row height constant and block alignment invariants

     func testMenuBarLayoutRowHeightIsElevenPoints() {
         XCTAssertEqual(
             MenuBarLayout.rowHeight,
             11.0,
             accuracy: 0.0001,
             "VAC-12: MenuBarLayout.rowHeight must be 11.0 pt"
         )
     }

     func testBlockFittingHeightsAreEqualAndMatchStatusBarThickness() {
         let standardBlock = MenuBarBlockView(
             block: MenuBarBlock(
                 kind: .cpu,
                 label: "CPU",
                 dotState: nil,
                 valueText: "100%",
                 valueTint: .primary,
                 width: MenuBarLayout.blockWidth
             )
         )
         let networkBlock = MenuBarNetworkBlockView(
             block: MenuBarBlock(
                 kind: .network,
                 label: "",
                 dotState: nil,
                 valueText: "999 MB/s",
                 valueTint: .primary,
                 width: MenuBarLayout.networkBlockWidth,
                 secondaryValueText: "999 MB/s",
                 secondaryValueTint: .primary
             )
         )

         let stdHeight = NSHostingView(rootView: standardBlock).fittingSize.height
         let netHeight = NSHostingView(rootView: networkBlock).fittingSize.height

         XCTAssertEqual(
             stdHeight,
             22.0,
             accuracy: 0.01,
             "VAC-11: MenuBarBlockView fitting height must be 22.0 pt"
         )
         XCTAssertEqual(
             netHeight,
             22.0,
             accuracy: 0.01,
             "VAC-11: MenuBarNetworkBlockView fitting height must be 22.0 pt"
         )
         XCTAssertEqual(
             stdHeight,
             netHeight,
             accuracy: 0.01,
             "VAC-11: both block types must have equal fitting height within 0.01 pt"
         )
     }

     func testRowFramesUseRowHeightConstantInBothBlocks() throws {
         let source = try loadSource()
         let blockScope = try declarationScope(of: "MenuBarBlockView", in: source)
         let netScope = try declarationScope(of: "MenuBarNetworkBlockView", in: source)

         let expectedFrame = ".frame(height:MenuBarLayout.rowHeight)"
         XCTAssertTrue(
             squashed(blockScope).contains(expectedFrame),
             "VAC-12: MenuBarBlockView must use .frame(height: MenuBarLayout.rowHeight)"
         )

         let uploadSection = try XCTUnwrap(
             netScope.range(of: "Upload rate"),
             "Upload rate section not found in MenuBarNetworkBlockView"
         )
         let uploadFrameLine = try XCTUnwrap(
             sourceLine(containing: ".frame(height", in: netScope[uploadSection.upperBound...]),
             "no .frame(height line found in upload rate section"
         )
         XCTAssertEqual(
             squashed(uploadFrameLine),
             expectedFrame,
             "VAC-12: MenuBarNetworkBlockView line 1 must use .frame(height: MenuBarLayout.rowHeight)"
         )

         let downloadSection = try XCTUnwrap(
             netScope.range(of: "Download rate"),
             "Download rate section not found in MenuBarNetworkBlockView"
         )
         let downloadFrameLine = try XCTUnwrap(
             sourceLine(containing: ".frame(height", in: netScope[downloadSection.upperBound...]),
             "no .frame(height line found in download rate section"
         )
         XCTAssertEqual(
             squashed(downloadFrameLine),
             expectedFrame,
             "VAC-12: MenuBarNetworkBlockView line 2 must use .frame(height: MenuBarLayout.rowHeight)"
         )
     }
     ```

6. **Post-Edit Test Line Reference Updates (N5)**:
   - Line reference updates in test failure messages to maintain documentation consistency:
     - FM1 line 161: `MenuBarStackedItemView.swift:115-116` -> `116-117`
     - IC-10 lines 251, 258, 259: `:153` and `:167` -> `:155` and `:170`
     - VAC-4 line 446: `:143` -> `:145`

7. **Existing Typography Tests Passing Unchanged**:
   - `testValueFontIsElevenPointRegularMonospacedDigit()` (`FM1`): passes unchanged at 11 pt.
   - `testValueFontKeepsMonospacedDigit()` (`IC-2`): passes unchanged.
   - `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven()` (`IC-10`): passes unchanged with 9 pt network rates and 11 pt value guard.
   - `testClearanceForWidestValueAtElevenPointRegularMeetsRelaxedThreshold()` (`IC-3`): passes unchanged with 31.22 pt width and 2.78 pt clearance (`>= 2.5 pt`).
   - `testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum()` (`IC-12`): passes unchanged with 42.11 pt text and 1.89 pt clearance (`>= 1.8 pt`).
   - `testMetricBlockStackUsesZeroVerticalSpacing()` (`VAC-3`): passes unchanged with `spacing: 0`.
   - `testNetworkBlockStackUsesZeroRowSpacing()` (`VAC-4`): passes unchanged with `spacing: 0`.

---

## Verdict
**GO** — Design Blueprint re-issued with all six corrections (C1–C6) and non-blocking notes (N1, N4, N5) incorporated. The specification is grounded in live AppKit measurements, verified with zero clipping against `NSStatusBar.system.thickness` (22 pt), and ready for implementation.
---

## Notation

```text
Plan -> Phase (`## Phase N — <name>`) -> Task (`T1` … unique; `FM*` = failure modes)
     -> Receipts (waiver note / red SHA / green SHA / VAC ledger / review verdict / merge SHA — verify each in git or on disk, record it on the task line)
```

Git receipt commands run with cwd = the worktree when they carry no `-C`; a
`git -C worktrees/…` path is relative to the repo root, so run those from the main repo.
The main repo workdir stays on `ci/github-actions-dmg-build` for the whole plan; the
steps that need a `main` checkout create short-lived worktrees and verify
`git branch --show-current` prints `main` before any commit or merge (hazard (a)).

## Phase 1 — Waiver record (before the first code edit)

Worktree for T2–T4: `<repo>/worktrees/menu-bar-row-alignment`, branch
`feat/2026-10-16-menu-bar-row-alignment`. Create it before the T2 spawn (below).

- [x] **T1** — planner, no code edit. The screenshot waiver already exists for this
  artifacts dir (`artifacts/2026-10-16-emulate-stats-layout/waiver-note.md`, three
  recorded exit-1 probes, user authority). **No new probe**: the basis is unrefuted and
  this plan adds no new capture surface. Append a carry-over section to the note naming
  plan `2026-10-16-menu-bar-row-alignment`, its date, the no-new-probe judgment, and the
  scope (all screenshot and strip captures SKIPPED; test-based ICs binding; the ledger
  gets one waived row). Commit the note on `main` (MD file, exempt from the worktree
  rule): the main repo workdir is on the ci branch, so create a short-lived worktree —
  `git -C <repo> worktree add <repo>/worktrees/planner-docs-2026-10-16-t1 main` — verify
  it prints `main` from `git branch --show-current`, apply the edit and commit there
  (`docs(waiver): carry screenshot waiver to menu bar row alignment plan`), then remove
  the worktree (`git worktree remove`, `git worktree prune`). If `git worktree list`
  shows `main` already checked out anywhere, STOP and report. The ci branch and its
  commits (`e430c3d`, `7f966dc`, `ee4ef04`) stay untouched.
- Receipts: appended section in `waiver-note.md` on disk; commit confirmed with
  `git log --oneline -1 main`.

## Phase 2 — Red (test only, worktree)

Create the worktree from fresh `main` before the spawn (idempotent `-B`):

```bash
MAIN_REPO="$(git -C /Users/jonathan/beliantech/stats-lite-macos rev-parse --show-toplevel)"
git -C "${MAIN_REPO}" worktree list    # pre-check: main must not be checked out elsewhere
git -C "${MAIN_REPO}" worktree add -B feat/2026-10-16-menu-bar-row-alignment \
  "${MAIN_REPO}/worktrees/menu-bar-row-alignment" main
```

- [x] **T2** — `T2: [red]` Rewrite the guards in
  `StatsLiteTests/MenuBarValueTypographyTests.swift` first, then run the suite.
  Test-only diff: touch no application code. All test-file citations are as-at the test
  file at the worktree base (current `main`);
  the order below keeps each citation valid when it is used; apply the Appendix B items
  **by content** (gate note N10: the `import SwiftUI` insertion shifts later line
  references +1).
  1. Header comment (`:5-16`): rewrite per blueprint Appendix B item 1 — narrate the
     green target state (8 pt labels, 11 pt values, 9 pt network rates, the 11 pt row
     height alignment invariant), and state that this red commit flips the label token
     and adds the two alignment guards. (Gate note N4.)
  2. Item 0 (C2, N8): add `import SwiftUI` after `import AppKit` (imports at `:19-21`;
     the blueprint's "18–21" includes a blank line).
  3. Item 2: `expectedLabelFont` (`:30`) →
     `".font(.system(size:8,weight:.regular))"`; doc comment (`:29`) → `size: 8`.
     `expectedValueFont`, `expectedLabelStyle`, `expectedNetworkFont` unchanged.
  4. Item 3 (plan IC-1): IC-4 (`:185` MARK, method `:187-218`): MARK →
     `// MARK: - IC-4: label flips to 8 pt regular secondary`; rename to
     `testLabelFontIsEightPointRegularSecondary`; failure-message phrase (`:206`)
     `must be 7 pt` → `must be 8 pt`.
  5. Item 4 (plan IC-6): IC-11 (`:305` MARK, method `:307-368`): font (`:308`)
     `ofSize: 7.0` → `ofSize: 8.0`; MARK → `// MARK: - IC-11: label-row clearance at
     8 pt regular`; MEM phrase (`:326`) `"MEM" at 7 pt regular` → `"MEM" at 8 pt
     regular`; MEM clearance (`:332`, message `:334`) `10.9067` → `8.6406`; CPU
     (`:348`, message `:350`) `18.6943` → `16.6836`; GPU (`:364`, message `:366`)
     `18.4790` → `16.4375`; rename to
     `testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints`. Minimum thresholds
     (`>= 3.5` MEM, `>= 16.0` CPU/GPU) stay (gate-measured constants, §2/§3).
  6. Item 6 (N5, N9): message-only production-line references — FM1 string at test
     `:160` (not 161): `MenuBarStackedItemView.swift:115-116` → `116-117`; IC-10
     comment `:251` and messages `:258`/`:259`: `:153`/`:167` → `:155`/`:170`; the
     plan IC-4 spacing message `:446`: `:143` → `:145`. These describe the post-green
     line map (gate-verified).
  7. Add a second source loader next to the existing `stackedItemViewURL` /
     `loadSource()` pair: `blockModelURL` + `loadLayoutSource()` reading
     `StatsLite/MenuBarBlockModel.swift` via the same `#filePath`-relative pattern;
     a read error must `XCTUnwrap`-fail, never pass vacuously.
  8. Add `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness` (plan IC-11 /
     VAC-11) verbatim from blueprint Appendix B item 5: builds `MenuBarBlockView`
     (kind `.cpu`, label "CPU", valueText "100%", width `MenuBarLayout.blockWidth`)
     and `MenuBarNetworkBlockView` (kind `.network`, valueText and
     secondaryValueText "999 MB/s", width `MenuBarLayout.networkBlockWidth`) inside
     `NSHostingView`, asserts std 22.0 (accuracy 0.01), net 22.0 (accuracy 0.01), and
     `abs(std − net) < 0.01`. **Fails at red**: std fits 23.00 pt (gate-measured).
  9. Add `testRowFramesUseRowHeightConstantInBothBlocks` (plan IC-12 / VAC-12) from
     blueprint Appendix B item 5 as corrected for gate C1, plus the documented constant
     folding (Approach item 3):
     - first assertion (the folding): `sourceLine(containing: "rowHeight", in:
       Substring(try loadLayoutSource()))`, squashed, equals
       `staticletrowHeight:CGFloat=11` — fails at red (no such line);
     - `squashed(blockScope).contains(".frame(height:MenuBarLayout.rowHeight)")` —
       fails at red;
     - network upload section: `netScope.range(of: "Upload rate")`, then
       `sourceLine(containing: ".frame(height", in: netScope[uploadSection.upperBound...])`,
       then `squashed(line) == ".frame(height:MenuBarLayout.rowHeight)"`
       (XCTUnwrap-fails at red — no `.frame(height` line exists);
     - network download section: the same pattern after `"Download rate"`.
     Do **not** run `squashed(_:)` over the whole network scope (gate C1: it truncates
     at the `// Line 1: Upload rate` comment before the frame tokens).
  10. Leave the existing helpers, FM1, IC-2, IC-3, IC-12 clearance, and both spacing
      guards untouched (all pass at red).
  11. Run:
      `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Debug -derivedDataPath .derivedData test -destination 'platform=macOS' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`
  - Red expectation (IC-13): **229 tests, exactly 3 failures** —
    `testLabelFontIsEightPointRegularSecondary`,
    `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness`,
    `testRowFramesUseRowHeightConstantInBothBlocks`. If a different set or count fails,
    re-derive from the then-current test file (Test-count drift risk) and fix the red
    phase; do not start green.
- Receipts: red SHA; `git -C worktrees/menu-bar-row-alignment diff main...HEAD --stat`
  shows only `StatsLiteTests/`; failing-test output with all three failures visible.

## Phase 3 — Green (implementation, same worktree)

- [x] **T3** — Apply blueprint Appendix A edits 1–6 in one commit. Every production line
  the mechanism touches, enumerated (production citations as-at the T3 base — the red
  commit is test-only, so the production tree is still the `5c67c21` tree; the gate
  re-verified each "Current Code" quote character for character at `5c67c21`):
  1. `StatsLite/MenuBarBlockModel.swift` — Edit 1: insert at `:60` (between
     `networkBlockWidth` at `:59` and the `/// Gap between adjacent blocks.` comment):
     ```swift
             /// Pinned height of each line within a block. Two 11 pt rows yield
             /// a 22 pt block height that matches NSStatusBar.system.thickness
             /// and aligns line 1 and line 2 across standard and network blocks.
             static let rowHeight: CGFloat = 11
     ```
  2. `StatsLite/MenuBarStackedItemView.swift:112` — Edit 2: `size: 7` → `size: 8`
     (weight `.regular` and `.foregroundStyle(.secondary)` unchanged).
  3. After `:114` (closing brace of the label `HStack`) — Edit 3: insert
     `.frame(height: MenuBarLayout.rowHeight)` (post-edit line `:115`).
  4. After `:118` (`.lineLimit(1)` on `Text(block.valueText)`) — Edit 4: insert
     `.frame(height: MenuBarLayout.rowHeight)` (post-edit line `:120`).
  5. After `:156` (closing brace of the upload `HStack`) — Edit 5: insert
     `.frame(height: MenuBarLayout.rowHeight)` (post-edit line `:159`).
  6. After `:170` (closing brace of the download `HStack`) — Edit 6: insert
     `.frame(height: MenuBarLayout.rowHeight)` (post-edit line `:174`).
  Nothing else in production code: `:153`/`:167` rate fonts untouched, value font
  `:116` untouched, no comment edits, no width/length/tint changes, and no
  `.animation` or `.contentTransition` modifiers. Do not weaken or delete the red
  tests. Then run the full suite with the T2 command; all tests green (IC-13).
  Post-edit line map for later citation (gate-verified): label font `:112`, value font
  `:117`, frames `:115`/`:120`/`:159`/`:174`, rate fonts `:155`/`:170`, network width
  frame `:176`.
- Receipts: green SHA; suite output `229 tests, 0 failures`;
  `git diff main...HEAD -- StatsLite/` limited to the two files and six edits above;
  `git diff main...HEAD --stat` = the T2 test file + the two production files.

## Phase 4 — VAC ledger (tests only)

- [x] **T4** — coder self-verify, same worktree, tests only (no captures); the pass
  evidence is the T3 green run under the T2 xcodebuild command. Write
  `artifacts/2026-10-16-emulate-stats-layout/vac-ledger-alignment.md` (new file — do not
  overwrite the previous plan's `vac-ledger.md`) with one row per plan IC: IC-1 … IC-14
  read `pass` with evidence (green test names; `rg` output for IC-9; gate-recorded
  measurements for IC-5 `31.22/2.78`, IC-6 `8.64/16.68/16.44`, IC-8 `42.11/1.89`,
  IC-11 `22.0000/22.0000` delta `0.0000`, IC-12 frame tokens `:115/:120/:159/:174`;
  diff stat for IC-14). The IC-12 row states the honest alignment invariant: frame edges
  and row frames exact (0.00 / 11.00 / 22.00), ink baselines differ ~0.38 pt by font
  metrics — no baseline-equality claim anywhere. Add one `waived` row for screenshot and
  strip captures: user authority, no Screen Recording permission (waiver-note.md, three
  exit-1 probes, no new probe this plan). Every test-based row must read `pass`. Commit
  on the branch (`docs(menubar): record menu bar row alignment VAC ledger`).
- Receipts: `vac-ledger-alignment.md` on disk with pass/waived rows, committed on the
  branch.

## Phase 5 — Review, merge, cleanup

- [x] **T5** — Spawn `reviewer` with `[code-review]`, plan name
  `2026-10-16-menu-bar-row-alignment`, `cwd` = the worktree, against
  `git -C worktrees/menu-bar-row-alignment diff main...HEAD`. The gate report lives only
  on the ci branch at review time; the reviewer reads it with
  `git show ee4ef04:artifacts/2026-10-16-emulate-stats-layout/gate-report-alignment.md`
  or from the main repo workdir file. Checks: the red commit is test-only and fails on
  exactly the three enumerated guards with 229 total; the rewrites and the two new
  guards match blueprint Appendix B (C1-corrected frame logic, C2 import, N8/N9/N10
  adjustments) and the single documented constant-folding adaptation (Approach item 3)
  preserves the full VAC-12 invariant; the IC-6 constants are 8.6406 / 16.6836 / 16.4375;
  the green commit changes exactly the six Appendix A edits in the two files and nothing
  else in `StatsLite/`; the green suite count is 229 with 0 failures; the ledger has
  complete pass/waived rows and makes no baseline-equality claim; the zero-animation rule
  is intact. Max two NO GO cycles, then escalate. On GO, merge under both hazards:

  **Hazard (a) — the ci branch owns the main workdir; the gate report rides `ee4ef04`:**
  1. `git -C <repo> worktree list` — verify `main` is not checked out anywhere. If it
     is, STOP and report.
  2. `git -C <repo> worktree add <repo>/worktrees/main-merge main`, then verify
     `git -C <repo>/worktrees/main-merge branch --show-current` prints **`main`** —
     this verification is mandatory before every commit or merge step below. All merge
     steps run in this worktree; the main repo workdir stays on the ci branch
     throughout, and the ci branch is never checked out, reset, or merged (its commits
     `e430c3d`, `7f966dc`, `ee4ef04` stay intact on the branch).
  3. Cherry-pick the gate report onto main:
     `git merge-base --is-ancestor ee4ef04 main` → if true, skip (already present);
     else `git -C <repo>/worktrees/main-merge cherry-pick ee4ef04` (adds
     `gate-report-alignment.md` only; no path overlap with the plan/blueprint commits,
     so it must apply clean — on conflict, STOP and report).

  **Hazard (b) — main advances in parallel:**
  4. Rebase the feature branch onto main:
     `git -C <repo>/worktrees/menu-bar-row-alignment rebase main`. If the rebase moved
     any file under `StatsLite/` or `StatsLiteTests/`
     (`git diff --name-only <pre-rebase-sha> HEAD -- StatsLite StatsLiteTests`), re-run
     the T2 suite command in the worktree; expect 229/0 again.
  5. From the verified main checkout:
     `git merge --ff-only feat/2026-10-16-menu-bar-row-alignment` (literal branch name;
     `--no-ff` and merge commits forbidden; `--squash` with its own conventional commit
     only if ff is impossible and the reason is recorded).
  6. Remove `worktrees/main-merge` (`git worktree remove`, `git worktree prune`), then
     remove the feature worktree and branch (`git worktree remove --force
     worktrees/menu-bar-row-alignment`, `git worktree prune`, orphaned-dir sweep per the
     `git-worktree` skill, `git branch -d feat/2026-10-16-menu-bar-row-alignment`).
     Leave `worktrees/2026-10-15-stats-lite-view-weight` untouched (foreign plan).
  7. Mark every task `[x]` with receipts and report the merge SHA.
- Receipts: review verdict; rebase note; cherry-pick receipt (or skip receipt); merge SHA
  confirmed by `git log --oneline -1 main`; both worktrees removed; feature branch
  deleted.

## Verification and spawn matrix

| Task | Agent | cwd | Timeout | Marker |
| --- | --- | --- | --- | --- |
| T1 | planner (bash) | main repo / short-lived main worktree | — | — |
| T2 | `coder` | `<repo>/worktrees/menu-bar-row-alignment` | 1800 s | `[red]`, plan `2026-10-16-menu-bar-row-alignment` |
| T3 | `coder` | same worktree | 1800 s | plan `2026-10-16-menu-bar-row-alignment` |
| T4 | `coder` self-verify | same worktree | 1800 s | plan `2026-10-16-menu-bar-row-alignment` |
| T5 | `reviewer` | worktree | 600 s | `[code-review]`, plan `2026-10-16-menu-bar-row-alignment` |

Sequencing: T1 → T2 → T3 → T4 → T5 strictly sequential; red and green never parallel.
No simulator concurrency: the xcodebuild serial flags in T2/T3 are mandatory
(`-parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`).

## Docs

- `ARCHITECTURE.md` / `DESIGN.md`: absent at this project root; nothing to update.
- `AGENTS.md`: the no-animation rule and the evidence rules already cover this change;
  no edit needed.
- Deferred by record (not this plan): the stale `MenuBarBlockModel.swift:56-58` comment
  (gate N1 — 42.91 pt / 1.09 pt from the 9 pt medium era) rides the next docs commit;
  the 130 pt length row stays unpinned (gate N7).
- Result: **No doc updates needed.**

## Risks and open items

- **Ci-branch workdir hazard (a)**: the main repo workdir stays on
  `ci/github-actions-dmg-build` for the whole plan. Every merge-side operation runs in a
  short-lived worktree verified to be on `main`; the ci branch is never checked out,
  reset, or merged, and its three commits stay intact. If the cherry-pick of `ee4ef04`
  conflicts or `main` is found checked out elsewhere, the task STOPs and reports.
- **Parallel main (b)**: `main` advances during execution. T5 rebases before the ff-only
  merge and re-runs the suite if the rebase touches `StatsLite/` or `StatsLiteTests/`.
- **Constant-folding adaptation (documented)**: blueprint Appendix B item 5 lists three
  new tests; T2 adds two, folding the compiled `MenuBarLayout.rowHeight == 11.0`
  assertion into the frame-token guard as an exact source-token check (a compiled
  reference cannot fail at red — it breaks the build). Invariant coverage is identical;
  the reviewer verifies the fold. Recorded deviation, not a gate defect.
- **Honest-alignment discipline**: the 0.38 pt ink-baseline delta is measured and
  recorded (gate C3). No test, ledger row, or report may claim baseline equality;
  VAC-12 is frame-based by design. A future claim of pixel-coincident baselines is a
  falsified-claim defect, not a pass.
- **Test-count drift**: red expects 229 tests (227 baseline + 2 new). If `main` lands
  tests before T2, recompute: red = then-current baseline + 2 with the same three
  failure classes, re-derived from the then-current test file — do not copy this list
  blindly.
- **Red-count discipline**: the 3-failure expectation is derived from the current test
  file: one existing guard pins the label token (IC-4 `:187`); one existing clearance
  guard measures its own font and passes at red (IC-11); no test pins fitting heights or
  row heights (authoring scan); the two new guards close the gap and both fail on the
  pre-alignment state (23.00 vs 22.00 pt; tokens absent).
- **Pre-existing orphaned dir** `worktrees/2026-10-15-stats-lite-view-weight` (branch
  `feat/2026-10-15-stats-lite-view-weight`, plan `2026-10-15-stats-lite-view-weight`) is
  not registered in `git worktree list` and belongs to a foreign plan; leave it untouched.
- **Zero-tolerance visual policy stays active** for any defect the user reports by eye;
  the waiver covers capture mechanics, not acceptance.
