# Plan: Menu Bar Typography & Spacing Update — Emulate Stats App Look (7 pt label, 11 pt value, spacing 0)

Date: 2026-10-16
Plan name: `2026-10-16-emulate-stats-layout`
Risk class: **R2** (UI work — zero-tolerance visual policy applies; visual defects are blocking).
Status: Design gate **PASS** (`artifacts/2026-10-16-emulate-stats-layout/gate-report.md`,
commit `0b11573`, gate date 2026-10-17). Plan authored 2026-10-16. Clarity adjustment pass
applied 2026-10-16 after `run_plan` (wording and procedure only — ISC checks, Design
Blueprint, scope, and tasks unchanged). Ready for execution: T1 → T5.
**Complete 2026-10-17:** T1 waiver probe exit 1 (`0b84d4a`); red `92c28ca` (227 tests,
exactly 5 failures per derivation); green `ff61edf` (four tokens, 227/0); ledger `bf9973e`
(12 pass, 1 waived); reviewer GO via `subagent_done` (`10824a25`); no rebase needed;
merged fast-forward to `main` at `bf9973e`; worktree and branch removed.
Repo HEAD at authoring: `e32f26e` (`0b11573` + the blueprint archive commit), clean
(untracked `worktrees/` only).
Baseline suite: **225 tests, 0 failures** (previous plan `2026-10-16-menu-bar-label-network-regular`
green run at `8a82730`; the six commits since `bc861a4` — `cd03d01`, `4697230`, `6049af5`,
`0b11573`, `e32f26e`, `5897efb` — are docs-only, so `git diff bc861a4..HEAD -- StatsLite
StatsLiteTests` is empty and the baseline stands at HEAD).
Screenshot waiver: carried over from plan `2026-10-16-menu-bar-regular-weight` — user
authority, no Screen Recording permission. Probe already proven exit 1 twice (designer
session probes, gate §Visual Evidence Pass; waiver note `8b0ce41`). T1 records the waiver
with a fresh probe; no new capture runs. The ledger gets pass/waived rows.
Worktree: `<repo>/worktrees/emulate-stats-layout`, branch
`feat/2026-10-16-emulate-stats-layout` (non-base). main advances in parallel —
expect to rebase before the ff-only merge, as last time.

## Intent

Current state: in `StatsLite/MenuBarStackedItemView.swift` the `MenuBarBlockView` stacks its
label row and value line with `VStack(alignment: .center, spacing: 1)` (`:103`); the
category labels render `.font(.system(size: 8, weight: .regular))` with
`.foregroundStyle(.secondary)` (`:111-113`); the values render
`.font(.system(size: 10.5, weight: .regular).monospacedDigit())` (`:115-116`); the
`MenuBarNetworkBlockView` stacks its two rate rows with
`VStack(alignment: .leading, spacing: 1)` (`:143`).

Target state (blueprint Appendix A — the complete production edit set):
`:103` → `VStack(alignment: .center, spacing: 0)`; `:112` label font size `8` → `7`
(weight `.regular`, style `.secondary` unchanged); `:116` value font size `10.5` → `11`
(weight `.regular`, `.monospacedDigit()` unchanged); `:143` →
`VStack(alignment: .leading, spacing: 0)`. Four tokens on four lines, one green commit.
Everything else stays unchanged: network rate fonts stay 9 pt regular mono (`:153`, `:167`),
`MenuBarLayout.blockWidth` stays 34.0 pt, `networkBlockWidth` stays 50.0 pt, item lengths
stay 114/168/76/38 (plus 92/130/54/4 rows), tints stay, zero animation stays.

Two binding user decisions are already recorded in the blueprint (Part 4 §1, Clearance
Decision) and govern the test constants:
1. **7 pt label override** — the legibility finding (cap height 4.93 pt; light-mode
   `.secondary` contrast 3.81:1 below the 4.5:1 AA text threshold) is on record; the user
   ordered 7 pt `.regular` anyway. The plan adopts the token verbatim.
2. **Option 1 clearance** — the clearance guard threshold relaxes 3.5 → 2.5 pt because the
   11 pt value measures 31.2222 pt wide (clearance 2.7778 pt) inside the pinned 34.0 pt
   block. `blockWidth` and the length contract stay unchanged.

## Evidence

- Design gate **PASS**: `artifacts/2026-10-16-emulate-stats-layout/gate-report.md` at commit
  `0b11573`. R1, R2, and all 17 R3 corrections verify against source at HEAD; every
  Appendix A "Current Code" quote matches HEAD character for character. The gate's §7
  reconstruction receipt and this plan's archive commit `e32f26e` describe the same
  reconstruction: two independent methods (captured `diff -u` applied by `patch`, and the
  designer's own R1/R2/R3 replacement script) produce the same 31,776-byte document, archived
  at `artifacts/2026-10-16-emulate-stats-layout/blueprint-final.md`.
- Gate measurements (live AppKit `NSFont` APIs, measured not priors): value `"100%"` at
  11 pt regular mono `31.2222` → clearance `2.7778` (vs 10.5 pt `29.9260` → `4.0740`);
  labels at 7 pt regular — CPU `15.3057`, GPU `15.5210`, MEM `17.0933`, MEM row `23.0933`
  → clearances `18.6943` / `18.4790` / `10.9067`; network `"999 MB/s"` at 9 pt regular
  `42.1084` → spacer `1.8916`. Heights with spacing 0: block fitting height `23.0` pt
  (from 24.0), network `22.0` pt (from 23.0), baseline distance `12.11` pt (from 13.11),
  descender-to-cap gap `2.88` pt; `NSStatusBar.system.thickness` `22.0` pt.
- Test evidence (authoring measurement): the suite has 225 tests, 0 failures since the
  previous plan's green run `8a82730`; `git diff bc861a4..HEAD -- StatsLite StatsLiteTests`
  is empty. `MenuBarValueTypographyTests.swift` (408 lines) still asserts the current
  tokens: `expectedValueFont` size:10.5 (`:28`), `expectedLabelFont` size:8 (`:30`), the
  IC-10 `contains("size:10.5")` guard (`:231`), the 10.5 pt font in IC-3 (`:271`), the 8 pt
  font in IC-11 (`:308`), and the 3.5 pt IC-3 threshold (`:283`, literal `3.5` at `:285`).
  No test pins either VStack spacing — that is the gap the red phase closes with two new
  guards.
- Citation check at authoring: every Appendix B line citation in the blueprint verifies
  against the current test file (FM1 `148-165` / MARK `:146` / message `:161`; IC-4 MARK
  `:185` / method `187-219` / message `205-210` phrase `:206`; IC-10 MARK `:220` / method
  `222-266` / guard `:231` / message `233-235` / compound `254-265`; IC-3 MARK `:268` /
  method `270-303` / font `:271` / width `:293` / clearance `:299`; IC-11 MARK `:305` /
  method `307-368` / font `:308` / `324-328` phrase `:326` / constants `:332` `:348` `:364`;
  IC-12 method `372-407`). Appendix A quotes verify against
  `MenuBarStackedItemView.swift` at HEAD (`nl -ba` at authoring): `:103`, `:111-113`,
  `:115-116`, `:143`.
- Zero-animation scan at authoring: `rg '\.animation|\.contentTransition'` over
  `MenuBarStackedItemView.swift`, `MenuBarBlockModel.swift`, `StatusItemController.swift`,
  `MenuBarAccessibility.swift` — comment-only hits at `MenuBarStackedItemView.swift:14`,
  `:15`, `:138`; never a modifier.
- Band-aid scan at authoring: `rg 'TODO|FIXME|HACK'` over
  `MenuBarStackedItemView.swift`, `MenuBarBlockModel.swift`,
  `MenuBarValueTypographyTests.swift` — no hits. No refactor debt in scope.

## ISC — binary checks (every item is yes/no)

> **Screenshot waiver (user authority, carried over 2026-10-16):** every screenshot-based
> visual check in this plan is SKIPPED: menu bar strip captures, popover captures, dark/light
> renders, and visual blend inspection. Reason: this session has no macOS Screen Recording
> permission; `screencapture` of other processes fails with exit 1 (proven twice: the
> designer session probes and the `8b0ce41` waiver note). The user waived visual capture on
> their authority (plan `2026-10-16-menu-bar-regular-weight`). T1 records the waiver note
> with a fresh probe instead of baseline captures. Visual ICs get a `waived` row in the
> ledger. Test-based ICs stay binding and must pass.

Citation rule: a bare `:N` in the ISC and tasks means `StatsLite/MenuBarStackedItemView.swift:N`
unless another file is named beside it. An `IC-N` / `FM-N` inside a test-method name or MARK
comment (for example the blueprint's "IC-10 guard") is the test file's own label; the plan's
IC-1 … IC-12 list above is the authority, and tasks annotate the mapping as "plan IC-N".
Line numbers are as-at-HEAD (`0b11573`); the two
commits since (`e32f26e`, `5897efb`) are docs-only, so every Swift line citation still
resolves at execution HEAD. The red commit shifts test-file lines, so test-file citations
in the tasks are as-at-HEAD too.

Widths (blueprint, gate C5 pattern): 768 px is the reference width. 375 px, 1440 px, and
Retina are check-only. Block widths are pinned (34.0 pt standard, 50.0 pt network), so
geometry measured at the reference holds at every width. Under the waiver no render
environment exists, so layout claims verify from test evidence. Each IC ends with a
`Widths:` line.

- [ ] **IC-1 (VAC-1, category labels → 7 pt — FLIPPED)** — labels render
  `.font(.system(size: 7, weight: .regular))` with `.foregroundStyle(.secondary)`
  (`:111-113`); no `size: 8`. The guard
  `testLabelFontIsSevenPointRegularSecondary` (renamed from
  `testLabelFontIsEightPointRegularSecondary`, expectation flipped from `size:8` to
  `size:7`) **fails at red** while `:112` carries `size: 8`, and passes at green.
  Falsification: the guard moves fail → pass only when `:112` flips to `size: 7`; any other
  edit leaves it red. The 7 pt legibility override is recorded (blueprint Part 4 §1).
  Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-2 (VAC-2, metric values → 11 pt — FLIPPED)** — value font stays
  `.font(.system(size: 11, weight: .regular).monospacedDigit())` (`:116`); no `size: 10.5`.
  Two guards **fail at red** and pass at green, because the current test file pins the
  value token in two places: `testValueFontIsElevenPointRegularMonospacedDigit` (FM1,
  renamed from `testValueFontIsTenAndAHalfPointRegularMonospacedDigit`, expectation flipped
  from `size:10.5` to `size:11`) and the value-size assertion inside
  `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven` (IC-10, renamed; its
  `contains("size:10.5")` guard flips to `contains("size:11")`). Both move fail → pass only
  when `:116` flips to `size: 11`. Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-3 (VAC-3, metric block stack spacing → 0 — NEW guard)** — `:103` reads
  `VStack(alignment: .center, spacing: 0)`; the standard block never carries `spacing: 1`.
  The new guard `testMetricBlockStackUsesZeroVerticalSpacing` (source-token line check on
  the existing `#filePath` mechanism: `declarationScope(of: "MenuBarBlockView")` +
  `sourceLine(containing: "VStack(")` + `squashed`) **fails at red** while `:103` carries
  `spacing: 1`, and passes at green. Falsification: fail → pass only when `:103` flips.
  Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-4 (VAC-4, network block row spacing → 0 — NEW guard)** — `:143` reads
  `VStack(alignment: .leading, spacing: 0)`; the network block never carries `spacing: 1`.
  The new guard `testNetworkBlockStackUsesZeroRowSpacing` (same mechanism inside
  `MenuBarNetworkBlockView`) **fails at red** while `:143` carries `spacing: 1`, and passes
  at green. Falsification: fail → pass only when `:143` flips. Widths: 768 reference;
  375/1440/Retina check-only.
- [ ] **IC-5 (VAC-5, widest-value clearance under Option 1)** — `MenuBarLayout.blockWidth`
  stays 34.0 pt (`:120` frame); `"100%"` at 11 pt regular mono measures `31.2222` pt and
  leaves `2.7778` pt total clearance, ≥ the **2.5 pt** threshold (binding user decision
  Option 1; the guard threshold relaxes 3.5 → 2.5). The guard
  `testClearanceForWidestValueAtElevenPointRegularMeetsRelaxedThreshold` (renamed from
  `testClearanceForWidestValueAtRegularMeetsThreeAndAHalfPoints`; font `10.5` → `11.0`,
  threshold `3.5` → `2.5`, constants `29.93` → `31.22` and `4.07` → `2.78`) measures the
  target font through `NSFont`, so it passes at red and at green (regression guard).
  Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-6 (VAC-6, label-row clearance at 7 pt)** — the label row fits the 34.0 pt block
  on one line: MEM row = 4.0 pt dot + 2.0 pt gap + `width("MEM" @ 7 pt regular)` 17.0933 =
  23.0933 → clearance `10.9067` ≥ 3.5; CPU clearance `18.6943` > 18.0; GPU clearance
  `18.4790` > 18.0. The guard
  `testLabelRowClearanceForMemRowAtSevenPointRegularMeetsThreeAndAHalfPoints` (renamed from
  `testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints`; font `8` → `7.0`, constants
  `8.6406`/`16.6836`/`16.4375` → `10.9067`/`18.6943`/`18.4790`) measures the target font,
  so it passes at red and at green. Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-7 (VAC-7, network rate fonts retained)** — upload `:153` and download `:167`
  stay `.font(.system(size: 9, weight: .regular).monospacedDigit())`; no `.medium` or
  `.bold`; `expectedNetworkFont` (`:34`) unchanged. The compound network assertion inside
  `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven` (`:254-265`) passes at red
  and at green. Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-8 (VAC-8, network-block clearance retained)** — `MenuBarLayout.networkBlockWidth`
  stays 50.0 pt (`:172` frame); `"999 MB/s"` at 9 pt regular mono `42.1084` plus the 6.0 pt
  dot leaves `1.8916` pt ≥ 1.8 for `Spacer(minLength: 1)`. Guard
  `testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum` passes unchanged at red
  and at green. Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-9 (VAC-9, zero animation)** — `rg -n '\.animation|\.contentTransition'` over
  `MenuBarStackedItemView.swift`, `MenuBarBlockModel.swift`, `StatusItemController.swift`,
  `MenuBarAccessibility.swift` finds comment-only hits at `MenuBarStackedItemView.swift:14`,
  `:15`, `:138` (authoring-verified) and never a modifier; `MenuBarRedrawChurnTests` passes.
  Widths: all runtimes, all widths.
- [ ] **IC-10 (VAC-10, length contract)** — `MenuBarLayout.length` stays 168 pt (4 blocks),
  114 pt (3), 92 pt (1 standard + network), 76 pt (2), 54 pt (network only), 38 pt (1),
  4 pt (all off); `blockWidth` 34.0, `networkBlockWidth` 50.0, `gap` 4.0, `padding` 2.0
  (`MenuBarBlockModel.swift:55-81`) unchanged; `MenuBarLayoutTests` passes. The 130 pt row
  stays unpinned (gate note N3, recorded deferral). Widths: 768 reference; 375/1440/Retina
  check-only.
- [ ] **IC-11 (suite)** — the red run executes baseline + 2 new tests (225 + 2 = 227) with
  **exactly 5 failures**, enumerated from the current test file:
  1. `testValueFontIsElevenPointRegularMonospacedDigit` — production token `size:10.5` ≠
     `size:11` (`:116`);
  2. `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven` — its value-size guard
     reads `size:10.5` (`:231`) while the token must be `size:11` (the network compound
     assertion stays green);
  3. `testLabelFontIsSevenPointRegularSecondary` — production token `size:8` ≠ `size:7`
     (`:112`);
  4. `testMetricBlockStackUsesZeroVerticalSpacing` (new) — `:103` carries `spacing: 1`;
  5. `testNetworkBlockStackUsesZeroRowSpacing` (new) — `:143` carries `spacing: 1`.

  Nothing else fails: IC-2, IC-5, IC-6, IC-8 measure target fonts and pass at red; IC-7's
  network tokens are already green; `MenuBarLayoutTests`, `MenuBarRedrawChurnTests`, and
  every other file pin none of the four tokens (authoring scan:
  `rg 'size:|spacing|systemFont' StatsLiteTests` outside this file — no hits). The green run
  executes 227 tests with 0 failures. No test is deleted. Recompute per the Test-count drift
  risk if main lands tests first. Widths: n/a.
- [ ] **IC-12 (scope)** — the production diff against `main` contains exactly four lines:
  `:103` `spacing: 1` → `spacing: 0`; `:112` `size: 8` → `size: 7`; `:116` `size: 10.5` →
  `size: 11`; `:143` `spacing: 1` → `spacing: 0`. No width, length, tint, network font,
  comment, or modifier changes (`:137-138` VAC-citation refresh stays deferred — Risks).
  `git diff main...HEAD -- StatsLite/` shows only those four lines; every other change lives
  in `StatsLiteTests/`. Widths: n/a.

Plan-scoped failure modes:

- **FM1** — the value token stays (or reverts to) `size: 10.5` → IC-2 fails (both guards).
  Red proves it: both flipped guards fail at HEAD while `:116` reads `size: 10.5`.
- **FM2** — the label token stays (or reverts to) `size: 8` → IC-1 fails. Red proves it.
- **FM3** — the block stack keeps (or reverts to) `spacing: 1` → IC-3 fails. Red proves it.
- **FM4** — the network stack keeps (or reverts to) `spacing: 1` → IC-4 fails. Red proves it.
- **FM5** — the edit escapes the four lines (blockWidth, lengths, network fonts,
  `.monospacedDigit()`, tints, comments) → IC-5 / IC-7 / IC-8 / IC-10 / IC-12 fail.
- **FM6** — `.animation` or `.contentTransition` enters the status item path → IC-9 fails.

Red-phase falsification rule: if a flipped or new guard passes at HEAD, the guard is not
coupled to its production token. Fix the guard in the red commit; do not start green.

## Approach

1. Four-token implementation in one green commit: at
   `StatsLite/MenuBarStackedItemView.swift:103` change `spacing: 1` to `spacing: 0`; at
   `:112` change `size: 8` to `size: 7`; at `:116` change `size: 10.5` to `size: 11`; at
   `:143` change `spacing: 1` to `spacing: 0`. No other production line changes (IC-12).
2. TDD with the existing source-token mechanism: the red commit first rewrites the affected
   guards in `StatsLiteTests/MenuBarValueTypographyTests.swift` to the blueprint
   expectations and adds the two new spacing guards, then fails on all four production
   tokens. The green commit flips the four tokens. Red and green are two sequential coder
   spawns in one worktree.
3. T1 records the screenshot waiver instead of baseline captures (user authority, no Screen
   Recording permission). Every IC is test-based and binding; the ledger records one
   `waived` row for the capture set (including the recorded 7 pt visual override).
4. Verification: automated checks for IC-1 … IC-12. Evidence per IC: green test names, `rg`
   output for IC-9, recorded measurements for IC-5 / IC-6 / IC-8, diff stat for IC-12.
5. Merge after reviewer GO: rebase onto main if main advanced, then `git merge --ff-only`
   with the literal branch name (or `--squash` with its own conventional commit); then
   remove the worktree and branch.
6. One variable per red guard: each production token has its own failing guard. The value
   token has two failing guards because the current file pins it in two places (FM1 and the
   IC-10 value-size assertion); both flip with the single `:116` edit, so the variable stays
   one (PM scope ruling).

### Design Blueprint (verbatim)

The gate-PASS Design Blueprint follows. Source:
`artifacts/2026-10-16-emulate-stats-layout/blueprint-final.md` (commit `e32f26e`).
It is the authority for every visual requirement in this plan; the ISC mirrors its VAC list.

# Summary of Accomplishments

The Design Blueprint for the Menu Bar Typography & Spacing Update has been re-issued with all three gate blockers (B1, B2, B3) resolved:

1. **B1 Resolved (Appendix B Complete Test-File Enumeration)**:
   - Walked `StatsLiteTests/MenuBarValueTypographyTests.swift` at HEAD.
   - Added the IC-10 guard update forced by Edit 3: the hardcoded assertion `blockValueToken.contains("size:10.5")` updates to `contains("size:11")`, the failure message text updates to `"must keep size 11"`, and the test method is renamed to `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven`.
   - Enumerated every test token and assertion affected by the four production edits: `expectedValueFont`, `expectedLabelFont`, FM1 value font assertion and rename, IC-4 label font assertion and rename, IC-10 value guard and rename, IC-3 value clearance threshold relaxation to 2.5 pt and width/clearance targets, and IC-11 label row clearance constants at 7 pt. Verified that IC-2 monospaced digit assertion and IC-12 network block clearance pass unchanged.

2. **B2 Resolved (Line-Number Citations Corrected)**:
   - Verified every citation against source at HEAD (`StatsLite/MenuBarStackedItemView.swift`):
     - `MenuBarBlockView` line range: lines 99–131.
     - `MenuBarNetworkBlockView` line range: lines 139–192.
     - Root view `.accessibilityHidden(true)`: line 45.
     - VAC-1: line 112 (Text at line 111).
     - VAC-2: line 116 (Text at line 115).
     - VAC-3: line 103.
     - VAC-4: line 143.
     - VAC-5: line 120.
     - VAC-6: lines 104–114.
     - VAC-7: lines 153 and 167.
     - VAC-8: line 172.
     - Appendix A Edit locations: Edit 1 at line 103, Edit 2 at line 112 (Text at line 111), Edit 3 at line 116 (Text at line 115), and Edit 4 at line 143.

3. **B3 Resolved (Accessibility Contract Corrected)**:
   - Removed the claim in Part 4 §3 that `StatusItemController` calls `setAccessibilityValue(...)`.
   - Documented the verified HEAD implementation in `StatusItemController.swift:192-196`: `updateAccessibility()` configures `button?.setAccessibilityElement(true)`, `button?.setAccessibilityTitle("StatsLite")`, and `button?.setAccessibilityLabel(compositeLabel)`. All metric text rides in the composite accessibility label. The typography and spacing edits introduce zero changes to accessibility strings.

4. **Invariants Preserved**:
   - The four Appendix A code edits, all layout and clearance measurements, and both binding user decision records (7 pt label override, Option 1 clearance threshold relaxation to 2.5 pt) remain byte-identical.

---

# Design Blueprint: Menu Bar Typography & Spacing Update (Emulate Stats App Look)

This design blueprint specifies typography and layout updates for the macOS menu bar status item in `StatsLite`.
The user approved this direction to emulate the visual appearance of the macOS `Stats` application.
The design tokens in this blueprint supersede previous menu bar typography specifications.

The project does not contain a `DESIGN.md` file at the repository root.
All design tokens and dimensions ground directly in macOS AppKit system APIs, SwiftUI primitives, and existing constants in `StatsLite`.

---

## Visual Evidence Pass Summary

### Capture Status & Visual Reference
1. **Live display capture block**:
   Live screen capture with `screencapture -x /tmp/designer_probe.png` fails in this terminal session.
   Command output: `could not create image from display` (exit status 1).
   The macOS host system does not grant Screen Recording permissions to this terminal process.
   Per user authority and test waiver, live visual screenshot captures remain check-only.
2. **Visual reference artifact**:
   The user reference screenshot was copied from clipboard cache to `artifacts/2026-10-16-emulate-stats-layout/reference-stats.png`.
   Image attributes (via `sips`): `386x64 px` (Retina 2x scale, `193.0x32.0 pt`), 144 DPI, Display P3.
   Visual inspection of the reference image confirms:
   - Category labels render at small scale (7 pt optical height, ~6 pt cap-to-baseline).
   - Values render prominently with monospaced digits.
   - The vertical stack spacing between label and value is compact (3 px / 1.5 pt optical gap).
   - Network upload and download rows sit close together vertically (0 pt row margin, 3 pt vertical dot gap).
   - Network rate text aligns to the trailing edge. The indicator dots form an aligned leading column.
3. **Measurement verification**:
   All font dimensions and layout bounds below derive from live AppKit `NSFont` and SwiftUI `NSHostingView` measurements on macOS 14+.

---

## Layout Math & Clearance Findings: 11 pt Value vs 34.0 pt Block Width

### 1. Value "100%" at 11 pt Live Measurements
- **Target font**: `NSFont.monospacedDigitSystemFont(ofSize: 11.0, weight: .regular)`
- **Measured width of widest value (`"100%"`)**: **31.2222 pt** (31.22 pt rounded)
- **Container block width (`MenuBarLayout.blockWidth`)**: **34.0000 pt**
- **Calculated total clearance**: `34.0000 pt − 31.2222 pt` = **2.7778 pt** (~2.78 pt)
- **Clearance margin per side**: `2.7778 pt / 2` = **1.3889 pt** (~1.39 pt)

### 2. Comparison with 10.5 pt Value (Current Main)
| Metric Value String | 10.5 pt Value Width | 10.5 pt Clearance | 11.0 pt Value Width | 11.0 pt Clearance | Margin Per Side (11 pt) |
|---|---|---|---|---|---|
| `"0%"` / `"5%"` | 16.5139 pt | 17.4861 pt | 17.2358 pt | 16.7642 pt | 8.3821 pt |
| `"50%"` / `"99%"` | 23.2200 pt | 10.7800 pt | 24.2290 pt | 9.7710 pt | 4.8855 pt |
| `"100%"` (Widest) | 29.9260 pt | 4.0740 pt | **31.2222 pt** | **2.7778 pt** | **1.3889 pt** |
| `"--%"` (Nil/Tertiary) | 19.8977 pt | 14.1023 pt | 20.7485 pt | 13.2515 pt | 6.6257 pt |

### 3. Clearance Rule Evaluation & Required User Decision Flag
- **Truncation Check**: The text does **NOT** truncate. The 31.22 pt width is strictly smaller than the 34.00 pt container frame. A positive margin of 1.39 pt remains on each side.
- **Clearance Rule Violation**: The 2.78 pt total clearance violates the previous 3.5 pt clearance threshold (`IC-3` in `MenuBarValueTypographyTests.swift`).
- **Options for Resolution**:
  - **Option 1 (Recommended user decision)**: Update the clearance invariant threshold from 3.5 pt to 2.5 pt (or 2.7 pt) specifically for the 11.0 pt value in the 34.0 pt block.
    *Benefit*: Preserves `MenuBarLayout.blockWidth = 34.0 pt`. Keeps the exact item length contract: **114 pt** (3 metrics), **168 pt** (4 metrics), **76 pt** (2 metrics), and **38 pt** (1 metric).
  - **Option 2 (Container expansion)**: Expand `MenuBarLayout.blockWidth` from 34.0 pt to 35.0 pt.
    *Drawback*: Breaks the fixed layout contract. Item lengths shift to 117 pt, 171 pt, 78 pt, and 39 pt.
  - **Option 3 (Per-metric asymmetric frames)**: Assign unequal block widths across metrics.
    *Drawback*: Breaks visual balance and increases layout complexity.

**Clearance Decision Flag**: The planner must confirm Option 1 with the user. Option 1 allows the 11 pt value to fit cleanly inside the established 34 pt block.

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
| |     7 pt Reg Sec   |         |  4pt  7 pt Reg Sec |         |     7 pt Reg Sec   |         |  6pt Red          9 pt Reg Mono  | |
| |                    |         |                    |         |                    |         |                                  | |
| |     [  5%   ]      |         |     [ 45%  ]       |         |     [  0%   ]      |         |  (*) Download     [  16 KB/s ]   | |
| |    11 pt Reg Mono  |         |    11 pt Reg Mono  |         |    11 pt Reg Mono  |         |  6pt Blue         9 pt Reg Mono  | |
| +--------------------+         +--------------------+         +--------------------+         +----------------------------------+ |
+-----------------------------------------------------------------------------------------------------------------------------------+
```

### Visual Weight & Layout Alignments
1. **Vertical Alignment**:
   - `MenuBarBlockView`: `VStack(alignment: .center, spacing: 0)`.
   - `MenuBarNetworkBlockView`: `VStack(alignment: .leading, spacing: 0)`.
2. **Horizontal Alignment**:
   - Standard metrics (CPU, RAM, GPU) center their label row and value row inside each 34.0 pt block.
   - For `MEM`, the 4.0 pt indicator dot sits leading of `"MEM"` with 2.0 pt spacing. It carries an offset of `-0.5 pt` to align with the visual center of capital letters.
   - For Network, the 6.0 pt circular dots align in a leading vertical column. The upload and download rate texts align to the trailing edge. The flexible `Spacer(minLength: 1)` absorbs the remaining horizontal room inside the 50.0 pt block.
3. **Vertical Stacking & Fitting Height vs Status Bar Thickness**:
   - `NSStatusBar.system.thickness` measures **22.0 pt**.
   - With `VStack(spacing: 0)`:
     - `MenuBarBlockView` fitting height is **23.0 pt** (down from 24.0 pt).
     - `MenuBarNetworkBlockView` fitting height is **22.0 pt** (down from 23.0 pt, matching menu bar thickness).
   - Baseline-to-baseline distance between label and value drops from 13.11 pt (at spacing 1) to **12.11 pt** (at spacing 0).
   - The visual gap from label descender to value cap top drops to **2.88 pt**, producing a cohesive unit that emulates the reference screenshot.

---

## Part 2: Template / Component Skeleton

### 1. Standard Metric Block Skeleton (`MenuBarBlockView`)

Exact line ranges in `StatsLite/MenuBarStackedItemView.swift`: lines 99–131.

```swift
/// One metric block: category label on line 1, value on line 2.
/// Width pins to block.width so text changes never resize the item.
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
                    .font(.system(size: 7, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Text(block.valueText)
                .font(.system(size: 11, weight: .regular).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
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

### 2. Network Speed Block Skeleton (`MenuBarNetworkBlockView`)

Exact line ranges in `StatsLite/MenuBarStackedItemView.swift`: lines 139–192.

```swift
/// Dedicated two-line network speed monitor block:
/// line 1 carries a 6 pt red indicator dot and the upload rate.
/// line 2 carries a 6 pt blue indicator dot and the download rate.
/// Width pins to block.width (50 pt), so rate string changes never
/// resize the item (VAC-N1). Transitions stay discrete: no
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

| State / Metric | Label Font & Style | Value / Rate Font & Style | Indicator Dot | Container Frame Width |
|---|---|---|---|---|
| **CPU Normal** (`< 80%`) | 7 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.primary` | None | Pinned 34.0 pt |
| **CPU Warning** (`80%...94%`) | 7 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.systemOrange` | None | Pinned 34.0 pt |
| **CPU Critical** (`>= 95%`) | 7 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.systemRed` | None | Pinned 34.0 pt |
| **CPU Unavailable** (nil) | 7 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.tertiaryLabelColor` (`"--%"`) | None | Pinned 34.0 pt |
| **RAM Normal** (`pressure < 60%`) | 7 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.primary` | 4 pt `.systemGreen` | Pinned 34.0 pt |
| **RAM Warning** (`60%...80%`) | 7 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.primary` | 4 pt `.systemYellow` | Pinned 34.0 pt |
| **RAM Critical** (`pressure > 80%`) | 7 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.primary` | 4 pt `.systemRed` | Pinned 34.0 pt |
| **RAM Unavailable** (nil) | 7 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, `.tertiaryLabelColor` (`"--%"`) | 4 pt `.systemGray` | Pinned 34.0 pt |
| **GPU Normal / High** | 7 pt `.regular`, `.secondary` | 11 pt `.regular.monospacedDigit()`, per threshold | None | Pinned 34.0 pt |
| **Network Active** | Dedicated rows | 9 pt `.regular.monospacedDigit()`, `.primary` | Upload: 6 pt Red, Download: 6 pt Blue | Pinned 50.0 pt |
| **Network Idle / Nil** | Dedicated rows | 9 pt `.regular.monospacedDigit()`, `.tertiaryLabelColor` (`"-- KB/s"`) | Upload: 6 pt Red, Download: 6 pt Blue | Pinned 50.0 pt |

### 2. Responsive & Dynamic Length Adaptation (Status Item Invariant)

Status item width adapts dynamically to preference combinations through `MenuBarLayout.length(showCPU:showRAM:showGPU:showNetwork:)`.
The width remains invariant to data changes.

| Enabled Metric Configuration | Number of Blocks | Mathematical Formulation | Fixed Item Length |
|---|---|---|---|
| **All Four Metrics** (CPU + RAM + GPU + NET) | 4 | `2*2 + 3*34 + 1*50 + 3*4` | **168.0 pt** |
| **All Three Standard Metrics** (CPU + RAM + GPU) | 3 | `2*2 + 3*34 + 2*4` | **114.0 pt** |
| **Any Two Standard Metrics** (for example CPU + RAM) | 2 | `2*2 + 2*34 + 1*4` | **76.0 pt** |
| **One Standard Metric + Network** | 2 | `2*2 + 1*34 + 1*50 + 1*4` | **92.0 pt** |
| **Two Standard Metrics + Network** | 3 | `2*2 + 2*34 + 1*50 + 2*4` | **130.0 pt** |
| **Network Only** | 1 | `2*2 + 1*50 + 0` | **54.0 pt** |
| **Single Standard Metric** (CPU, RAM, or GPU) | 1 | `2*2 + 1*34 + 0` | **38.0 pt** |
| **All Metrics Disabled** | 0 | `2*2 + 0` | **4.0 pt** (padding only) |

---

## Part 4: Accessibility (WCAG 2.2) & Interaction Contracts

### 1. User Override Record: 7 pt Category Label Legibility
- **Prior Finding**: In earlier evaluations, the designer noted that a 7 pt font yields a cap height of 4.93 pt (9.86 physical pixels on 2x Retina, < 5.0 physical pixels on 1x non-Retina displays). On standard non-Retina displays, letterform joints in `"M"` and uppercase crossbars in `"E"` blur together. Light Mode contrast for `NSColor.secondaryLabelColor` on typical light menu bar backgrounds (#EBEBEB) measures 3.81:1, falling below the WCAG 1.4.3 AA 4.5:1 standard text threshold.
- **User Override Decision**: The user reviewed the finding and issued an explicit override to enforce 7 pt `.regular` for Line 1 category labels (`CPU`, `MEM`, `GPU`).
- **Design Resolution**: The 7 pt token is adopted verbatim per user authority. Visual hierarchy relies on `.secondary` opacity paired with 11 pt `.regular` primary values. VoiceOver accessibility provides non-visual access to all metrics.

### 2. Network Block Tightening & Fitting Invariant
- **Row Spacing**: `VStack(spacing: 0)` lowers the network container height to **22.0 pt**, matching `NSStatusBar.system.thickness` (22.0 pt) and eliminating vertical clipping risk.
- **Indicator Dots**: Upload indicator circle uses `Color(nsColor: .systemRed)` at `6x6 pt`. Download indicator circle uses `Color(nsColor: .systemBlue)` at `6x6 pt`. Vertical gap between the dots measures **5.0 pt** (reduced from 6.0 pt).
- **Dot-to-Text Clearance**: Inside the 50.0 pt pinned block, the widest formatted rate (`"999 MB/s"`, width 42.11 pt) leaves **1.89 pt** clearance for `Spacer(minLength: 1)`. The rate string renders on a single line without truncation.
- **Single-Digit & Double-Digit Snugness**: For standard rates (`"5 KB/s"`, width 28.50 pt, and `"16 KB/s"`, width 34.33 pt), the spacer preserves right-alignment of units and digits. This matches the reference Stats application layout.

### 3. VoiceOver & Accessibility Tree Contract
- The SwiftUI status view hierarchy declares `.accessibilityHidden(true)` at the root container (`MenuBarStackedItemView.swift:45`).
- Accessibility is managed by `StatusItemController.updateAccessibility()` (`StatsLite/StatusItemController.swift:192-196`).
- The controller configures `statusItem.button`:
  - `button?.setAccessibilityElement(true)`
  - `button?.setAccessibilityTitle("StatsLite")`
  - `button?.setAccessibilityLabel(compositeLabel)`
- The codebase contains no calls to `setAccessibilityValue(...)`. All metric text rides in the composite accessibility label (`compositeLabel`), constructed via `MenuBarAccessibility.compositeLabel(...)`.
- Updating font point sizes and vertical spacing introduces zero changes to VoiceOver accessibility strings or accessibility tree nodes.

### 4. Interaction & Animation Contract
- Clicks on the status item toggle the popover via `button.action = #selector(togglePopover(_:))`.
- If the popover is open, `button.isHighlighted` remains `true`.
- **Zero Animation Rule**: Zero `.animation()` or `.contentTransition()` modifiers exist anywhere in `MenuBarBlockView`, `MenuBarNetworkBlockView`, or `MenuBarStackedItemView`. Metric updates transition discretely between sampling intervals.

---

## Part 5: Numbered Visual Acceptance Checklist (VAC)

- **VAC-1 (Label Font Size and Weight Update)**:
  - Selector: `MenuBarBlockView` Line 1 category label `Text(block.label)` font modifier (`StatsLite/MenuBarStackedItemView.swift:112` (Text at line 111))
  - Target Environment: macOS Menu Bar (all viewports and resolutions)
  - Invariant: The font modifier must be `.font(.system(size: 7, weight: .regular))`. The font must not use size 8 or weight `.bold`.

- **VAC-2 (Value Font Size and Weight Update)**:
  - Selector: `MenuBarBlockView` Line 2 value `Text(block.valueText)` font modifier (`StatsLite/MenuBarStackedItemView.swift:116` (Text at line 115))
  - Target Environment: macOS Menu Bar (all viewports and resolutions)
  - Invariant: The font modifier must be `.font(.system(size: 11, weight: .regular).monospacedDigit())`. The font must not use size 10.5.

- **VAC-3 (Metric Block Vertical Stack Spacing Update)**:
  - Selector: `MenuBarBlockView` `VStack` declaration (`StatsLite/MenuBarStackedItemView.swift:103`)
  - Target Environment: macOS Menu Bar
  - Invariant: The `VStack` must specify `alignment: .center, spacing: 0`. It must not use `spacing: 1`.

- **VAC-4 (Network Block Vertical Row Spacing Update)**:
  - Selector: `MenuBarNetworkBlockView` `VStack` declaration (`StatsLite/MenuBarStackedItemView.swift:143`)
  - Target Environment: macOS Menu Bar
  - Invariant: The `VStack` must specify `alignment: .leading, spacing: 0`. It must not use `spacing: 1`.

- **VAC-5 (Widest Value Clearance Invariant under User Decision)**:
  - Selector: `MenuBarBlockView` value container frame (`StatsLite/MenuBarStackedItemView.swift:120`)
  - Target Environment: macOS Menu Bar
  - Invariant: Container width must remain pinned to 34.0 pt (`MenuBarLayout.blockWidth`). The widest formatted percentage value (`"100%"`) at 11 pt regular monospacedDigit (measured width 31.2222 pt) must leave at least 2.5 pt total clearance (measured: 2.7778 pt total clearance, 1.3889 pt margin per side) with zero text truncation.

- **VAC-6 (Label Row Clearance Invariant at 7 pt Regular)**:
  - Selector: `MenuBarBlockView` category label `HStack` container (`StatsLite/MenuBarStackedItemView.swift:104-114`)
  - Target Environment: macOS Menu Bar
  - Invariant: All category labels (`CPU`, `MEM`, `GPU`) must render on a single line inside the 34.0 pt block width with zero truncation. For `MEM` with the 4.0 pt dot and 2.0 pt spacing, total row width must measure 23.0933 pt, leaving 10.9067 pt total clearance (5.4534 pt margin per side, satisfying the >= 3.5 pt rule). For `CPU` (15.3057 pt) and `GPU` (15.5210 pt), total clearance must exceed 18.0 pt.

- **VAC-7 (Network Rate Value Font Invariant)**:
  - Selector: `MenuBarNetworkBlockView` rate `Text` font modifiers (`StatsLite/MenuBarStackedItemView.swift:153`, `:167`)
  - Target Environment: macOS Menu Bar
  - Invariant: Upload rate text (line 152) and download rate text (line 166) must remain `.font(.system(size: 9, weight: .regular).monospacedDigit())`. Neither line can use `.medium` or `.bold`.

- **VAC-8 (Network Block Clearance & Containment Invariant)**:
  - Selector: `MenuBarNetworkBlockView` container frame (`StatsLite/MenuBarStackedItemView.swift:172`)
  - Target Environment: macOS Menu Bar
  - Invariant: Container width must remain pinned to 50.0 pt (`MenuBarLayout.networkBlockWidth`). The widest formatted rate string (`"999 MB/s"`, width 42.1084 pt) plus 6.0 pt indicator dot must leave at least 1.8 pt width for `Spacer(minLength: 1)` (measured clearance: 1.8916 pt). Both rate strings must render on a single line with zero truncation ellipsis.

- **VAC-9 (Discrete Rendering / Zero Animation Invariant)**:
  - Selector: `MenuBarStackedItemView`, `MenuBarBlockView`, `MenuBarNetworkBlockView`
  - Target Environment: All macOS runtimes
  - Invariant: View body trees must contain zero `.animation` or `.contentTransition` modifiers.

- **VAC-10 (Layout Length Contract Invariants)**:
  - Selector: `MenuBarLayout.length(showCPU:showRAM:showGPU:showNetwork:)`
  - Target Environment: All macOS runtimes
  - Invariant: Fixed item lengths must evaluate to:
    - All four metrics enabled: **168.0 pt**
    - All three standard metrics enabled: **114.0 pt**
    - Any two standard metrics enabled: **76.0 pt**
    - Single standard metric enabled: **38.0 pt**
    - Network metric only enabled: **54.0 pt**
    - All metrics disabled: **4.0 pt**

---

## Appendix A: Exact Token Edits in Production Source

All line numbers verified at `HEAD` (commits `bc861a4` / `cd03d01` / `4697230`).

### Target File: `StatsLite/MenuBarStackedItemView.swift`

1. **Edit 1: `MenuBarBlockView` VStack spacing**
   - Location: Line 103
   - Current Code:
     ```swift
     VStack(alignment: .center, spacing: 1) {
     ```
   - Target Code:
     ```swift
     VStack(alignment: .center, spacing: 0) {
     ```

2. **Edit 2: `MenuBarBlockView` Label font size**
   - Location: Line 112 (Text at line 111)
   - Current Code:
     ```swift
     Text(block.label)
         .font(.system(size: 8, weight: .regular))
         .foregroundStyle(.secondary)
     ```
   - Target Code:
     ```swift
     Text(block.label)
         .font(.system(size: 7, weight: .regular))
         .foregroundStyle(.secondary)
     ```

3. **Edit 3: `MenuBarBlockView` Value font size**
   - Location: Line 116 (Text at line 115)
   - Current Code:
     ```swift
     Text(block.valueText)
         .font(.system(size: 10.5, weight: .regular).monospacedDigit())
     ```
   - Target Code:
     ```swift
     Text(block.valueText)
         .font(.system(size: 11, weight: .regular).monospacedDigit())
     ```

4. **Edit 4: `MenuBarNetworkBlockView` VStack spacing**
   - Location: Line 143
   - Current Code:
     ```swift
     VStack(alignment: .leading, spacing: 1) {
     ```
   - Target Code:
     ```swift
     VStack(alignment: .leading, spacing: 0) {
     ```

---

## Appendix B: Required Test Assertions Updates

### Target File: `StatsLiteTests/MenuBarValueTypographyTests.swift`

This section enumerates every test-file token and assertion that the four production edits force.

1. **Expected Source Tokens (`expectedValueFont`, `expectedLabelFont`)**:
   - `expectedValueFont` (line 28): Edit 3 forces updating the normalized string literal from `".font(.system(size:10.5,weight:.regular).monospacedDigit())"` to `".font(.system(size:11,weight:.regular).monospacedDigit())"`. Update doc comment at line 27 to reference `size: 11`.
   - `expectedLabelFont` (line 30): Edit 2 forces updating the normalized string literal from `".font(.system(size:8,weight:.regular))"` to `".font(.system(size:7,weight:.regular))"`. Update doc comment at line 29 to reference `size: 7`.
   - `expectedLabelStyle` (line 32) and `expectedNetworkFont` (line 34) remain unchanged.

2. **Value Font Source Token Test (`FM1`)**:
   - Target Method: `testValueFontIsTenAndAHalfPointRegularMonospacedDigit()` (lines 148-165).
   - Edit 3 forces renaming method to `testValueFontIsElevenPointRegularMonospacedDigit()`.
   - Update MARK comment at line 146 to `// MARK: - FM1: value font is 11 pt regular monospacedDigit`.
   - Update failure message at line 161 from `Font.system(size: 10.5, weight: .regular).monospacedDigit()` to `Font.system(size: 11, weight: .regular).monospacedDigit()`.
   - Assertion `XCTAssertEqual(token, expectedValueFont)` tests line 116 against updated 11 pt token.

3. **Value Monospaced Digit Guard (`IC-2`)**:
   - Target Method: `testValueFontKeepsMonospacedDigit()` (lines 169-183).
   - Assertion `XCTAssertTrue(token.contains(".monospacedDigit()"))` passes unchanged because Edit 3 preserves `.monospacedDigit()`.

4. **Label Font Source Token Test (`IC-4`)**:
   - Target Method: `testLabelFontIsEightPointRegularSecondary()` (lines 187-219).
   - Edit 2 forces renaming method to `testLabelFontIsSevenPointRegularSecondary()`.
   - Update MARK comment at line 185 to `// MARK: - IC-4: label flips to 7 pt regular secondary`.
   - Update failure message at lines 205-210 (phrase at line 206) from `must be 8 pt` to `must be 7 pt`.
   - Assertion `region.contains(expectedLabelFont)` tests line 112 against updated 7 pt token.
   - Secondary style assertion (`expectedLabelStyle`) passes unchanged.

5. **Network Fonts & Value Size Guard Test (`IC-10`)**:
   - Target Method: `testNetworkFontsAreNinePointRegularAndValueStaysSizeTenAndAHalf()` (lines 222-266).
   - Edit 3 forces updating the value-size guard assertion at line 231 from `blockValueToken.contains("size:10.5")` to `blockValueToken.contains("size:11")`.
   - Update guard failure message at lines 233-235 from `must keep size 10.5` to `must keep size 11`.
   - Edit 3 forces renaming method to `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven()`.
   - Update MARK comment at line 220 to `// MARK: - IC-10: network flips to 9 pt regular, value size stays 11`.
   - Network rate font assertions (`[uploadToken, downloadToken] == [expectedNetworkFont, expectedNetworkFont]`) at lines 254-265 (lines 250-253 are comment lines) pass unchanged.

6. **Widest Value Clearance Test (`IC-3`)**:
   - Target Method: `testClearanceForWidestValueAtRegularMeetsThreeAndAHalfPoints()` (lines 270-303).
   - Edit 3 forces updating font definition at line 271 from `NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)` to `NSFont.monospacedDigitSystemFont(ofSize: 11.0, weight: .regular)`.
   - Update threshold assertion at line 283 from `XCTAssertGreaterThanOrEqual(clearance, 3.5)` to `XCTAssertGreaterThanOrEqual(clearance, 2.5)` under binding user decision Option 1.
   - Update failure message at lines 286-289 from `must be at least 3.5 pt` to `must be at least 2.5 pt`.
   - Update expected width assertion at line 293 from `29.93 pt` to `31.22 pt` (measured 31.2222 pt, accuracy `0.05`).
   - Update expected clearance assertion at line 299 from `4.07 pt` to `2.78 pt` (measured 2.7778 pt, accuracy `0.05`).
   - Rename method to `testClearanceForWidestValueAtElevenPointRegularMeetsRelaxedThreshold()`.
   - Update MARK comment at line 268 to `// MARK: - IC-3: clearance for "100%" at 11 pt regular`.

7. **Label Row Clearance Test (`IC-11`)**:
   - Target Method: `testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints()` (lines 307-368).
   - Edit 2 forces updating font definition at line 308 from `NSFont.systemFont(ofSize: 8, weight: .regular)` to `NSFont.systemFont(ofSize: 7.0, weight: .regular)`.
   - Update MEM failure message at lines 324-328 (phrase at line 326) from `"MEM" at 8 pt regular` to `"MEM" at 7 pt regular`.
   - Update expected MEM clearance assertion at line 332 from `8.6406 pt` to `10.9067 pt` (accuracy `0.05`).
   - Update expected CPU clearance assertion at line 348 from `16.6836 pt` to `18.6943 pt` (accuracy `0.05`).
   - Update expected GPU clearance assertion at line 364 from `16.4375 pt` to `18.4790 pt` (accuracy `0.05`).
   - Minimum threshold assertions (`>= 3.5 pt` for MEM, `>= 16.0 pt` for CPU/GPU) continue to pass.
   - Rename method to `testLabelRowClearanceForMemRowAtSevenPointRegularMeetsThreeAndAHalfPoints()`.
   - Update MARK comment at line 305 to `// MARK: - IC-11: label-row clearance at 7 pt regular`.

8. **Network Block Clearance Test (`IC-12`)**:
   - Target Method: `testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum()` (lines 372-407).
   - Network rate fonts remain `size: 9, weight: .regular` and network block width remains 50.0 pt.
   - Measured text width `42.1084 pt` and total clearance `1.8916 pt >= 1.8 pt` pass unchanged.

---

## Refactors

None. The band-aid scan at authoring found no `TODO`/`FIXME`/`HACK` in the touched files.
The change is four tokens on four lines; no helper masks it and no test suppresses it.

## Notation

```text
Plan -> Phase (`## Phase N — <name>`) -> Task (`T1` … unique; `FM*` = failure modes)
     -> Receipts (waiver note / red SHA / green SHA / VAC ledger / review verdict / merge SHA — verify each in git or on disk, record it on the task line)
```

Git receipt commands run with cwd = the worktree when they carry no `-C`; a
`git -C worktrees/…` path is relative to the repo root, so run those from the main repo.

- [x] **T1** — waiver note, no code edit. DONE: probe exit 1 (`0b84d4a`).
- [x] **T2** — red: flip the three token guards, add the two spacing guards (marker `[red]`). red PASS (`92c28ca`, 227/5) · review GO
- [x] **T3** — green: four tokens on four lines. green PASS (`ff61edf`, 227/0) · review GO
- [x] **T4** — VAC ledger, tests only; pass/waived rows. DONE (`bf9973e`, 12 pass / 1 waived).
- [x] **T5** — reviewer `[code-review]`, rebase, ff-only merge, cleanup. review GO · merge ff to `main` = `bf9973e`

## Phase 1 — Waiver record (before the first code edit)

Worktree: `<repo>/worktrees/emulate-stats-layout`, branch
`feat/2026-10-16-emulate-stats-layout`. Create the worktree before the T2 spawn;
set the spawn `cwd` to it.

- [x] **T1** — planner, main repo, no code edit. Probe the waiver basis once for the record:
  `screencapture -x /tmp/waiver_probe_emulate_stats.png`; record the exit status. The waiver
  was already proven exit 1 twice (designer session probes; `8b0ce41`), so this probe is a
  formality, not a new measurement. Then write
  `artifacts/2026-10-16-emulate-stats-layout/waiver-note.md` with: the carried-over user
  waiver (plan `2026-10-16-menu-bar-regular-weight`), its reason (no macOS Screen Recording
  permission), the prior probe receipts (`8b0ce41`, designer session), the fresh probe exit
  status, and the scope (all screenshot and strip captures SKIPPED; test-based ICs binding;
  visual checks waived, including the recorded 7 pt legibility override). If the probe exits
  0, stop: the waiver basis is falsified — report to the user before any spawn. No baseline
  captures run: the change targets status item tokens and every visual check is waived.
  Commit the note on `main` (`docs(waiver): …`; MD file, exempt from the worktree rule).
- Receipts: `waiver-note.md` on disk with the probe exit status, commit confirmed with
  `git log --oneline -1`.

## Phase 2 — Red (test only, worktree)

Create the worktree from fresh `main` before the spawn (idempotent `-B`):

```bash
MAIN_REPO="$(git -C /Users/jonathan/beliantech/stats-lite-macos rev-parse --show-toplevel)"
git -C "${MAIN_REPO}" worktree list    # pre-check for name collisions
git -C "${MAIN_REPO}" worktree add -B feat/2026-10-16-emulate-stats-layout \
  "${MAIN_REPO}/worktrees/emulate-stats-layout" main
```

- [x] **T2** — `T2: [red]` Rewrite the guards in
  `StatsLiteTests/MenuBarValueTypographyTests.swift` first, then run the suite. Test-only
  diff: touch no application code. All test-file line numbers below are as-at-HEAD
  (`0b11573`); the edit order below keeps each citation valid when it is used.
  1. Update the file header comment to plan `2026-10-16-emulate-stats-layout`; state that
     the red run fails on all four production tokens (label `size: 8` at `:112`, value
     `size: 10.5` at `:116`, block `spacing: 1` at `:103`, network `spacing: 1` at `:143`).
  2. `expectedValueFont` (`:28`) →
     `".font(.system(size:11,weight:.regular).monospacedDigit())"`; doc comment (`:27`) →
     `size: 11`.
  3. `expectedLabelFont` (`:30`) → `".font(.system(size:7,weight:.regular))"`; doc comment
     (`:29`) → `size: 7`. `expectedLabelStyle` (`:32`) and `expectedNetworkFont` (`:34`)
     unchanged.
  4. FM1 (`:148-165`): MARK (`:146`) → `// MARK: - FM1: value font is 11 pt regular
     monospacedDigit`; rename to `testValueFontIsElevenPointRegularMonospacedDigit`;
     failure message (`:161`) → `Font.system(size: 11, weight: .regular).monospacedDigit()`.
     (Plan IC-2, first of its two flipped guards; the blueprint Appendix B calls this
     guard FM1.)
  5. IC-4 (`:187-219`): MARK (`:185`) → `// MARK: - IC-4: label flips to 7 pt regular
     secondary`; rename to `testLabelFontIsSevenPointRegularSecondary`; failure message
     (`:205-210`, phrase at `:206`) `must be 8 pt` → `must be 7 pt` (plan IC-1).
  6. IC-10 (`:222-266`): MARK (`:220`) → `// MARK: - IC-10: network flips to 9 pt regular,
     value size stays 11`; rename to
     `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven`; value-size guard (`:231`)
     `contains("size:10.5")` → `contains("size:11")`; guard message (`:233-235`)
     `must keep size 10.5` → `must keep size 11`. The compound network assertion
     (`:254-265`) and its message stay unchanged (plan IC-7 regression guard).
  7. IC-3 (`:270-303`): MARK (`:268`) → `// MARK: - IC-3: clearance for "100%" at 11 pt
     regular`; font (`:271`) `ofSize: 10.5` → `ofSize: 11.0`; threshold assertion (`:283`,
     literal `3.5` at `:285`) → `2.5`; message (`:286-289`) `at least 3.5 pt` → `at least
     2.5 pt`; width constant (`:293`, message `:295`) `29.93` → `31.22`; clearance constant
     (`:299`, message `:301`) `4.07` → `2.78`; rename to
     `testClearanceForWidestValueAtElevenPointRegularMeetsRelaxedThreshold` (plan IC-5,
     binding user decision Option 1).
  8. IC-11 (`:307-368`): MARK (`:305`) → `// MARK: - IC-11: label-row clearance at 7 pt
     regular`; font (`:308`) `ofSize: 8` → `ofSize: 7.0`; MEM message (`:324-328`, phrase
     at `:326`) `"MEM" at 8 pt regular` → `"MEM" at 7 pt regular`; MEM clearance constant
     (`:332`, message `:334`) `8.6406` → `10.9067`; CPU (`:348`, message `:350`)
     `16.6836` → `18.6943`; GPU (`:364`, message `:366`) `16.4375` → `18.4790`; rename to
     `testLabelRowClearanceForMemRowAtSevenPointRegularMeetsThreeAndAHalfPoints`. The
     minimum thresholds (`>= 3.5` MEM, `>= 16.0` CPU/GPU) stay (plan IC-6).
  9. Add `testMetricBlockStackUsesZeroVerticalSpacing` (plan IC-3 / VAC-3): source-token
     line check on the existing mechanism — `declarationScope(of: "MenuBarBlockView")`,
     `sourceLine(containing: "VStack(", in:)`, `squashed`; assert the line equals
     `VStack(alignment:.center,spacing:0){`. Fails at red while `:103` carries
     `spacing: 1`. Failure message quotes the found line.
  10. Add `testNetworkBlockStackUsesZeroRowSpacing` (plan IC-4 / VAC-4): same mechanism
      inside `MenuBarNetworkBlockView`; assert the line equals
      `VStack(alignment:.leading,spacing:0){`. Fails at red while `:143` carries
      `spacing: 1`. Failure message quotes the found line.
  11. Leave the helpers (`loadSource`, `declarationScope`, `sourceLine`, `squashed`,
      `fontToken`) untouched: a missing anchor or `VStack(` line must `XCTUnwrap`-fail the
      test, never pass vacuously. IC-2 (`:169-183`) and IC-12 (`:372-407`) stay untouched.
  12. Run:
      `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Debug -derivedDataPath .derivedData test -destination 'platform=macOS' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`
  - Red expectation: **227 tests, exactly 5 failures** —
    `testValueFontIsElevenPointRegularMonospacedDigit`,
    `testNetworkFontsAreNinePointRegularAndValueStaysSizeEleven` (its value-size guard
    only), `testLabelFontIsSevenPointRegularSecondary`,
    `testMetricBlockStackUsesZeroVerticalSpacing`,
    `testNetworkBlockStackUsesZeroRowSpacing`. The three renamed clearance guards
    (IC-3/IC-5, IC-11/IC-6, IC-12/IC-8) and IC-2 pass at red: they measure the target
    font or the retained tokens. If a flipped or new guard passes at HEAD, fix the red
    phase; do not start green.
- Receipts: red SHA; `git -C worktrees/emulate-stats-layout diff main...HEAD --stat` shows
  only `StatsLiteTests/`; failing-test output with all five failures visible (the two
  spacing guards and the three token guards).

## Phase 3 — Green (implementation, same worktree)

- [x] **T3** — Apply Blueprint Appendix A edits 1-4 in one commit:
  `StatsLite/MenuBarStackedItemView.swift:103` `spacing: 1` → `spacing: 0`;
  `:112` `size: 8` → `size: 7`; `:116` `size: 10.5` → `size: 11`; `:143` `spacing: 1` →
  `spacing: 0`. Nothing else in production code: `:153`/`:167` untouched, no comment edits
  (the `:137-138` VAC citation refresh stays a recorded deferral — Risks), no
  width/length/tint changes, and no `.animation` or `.contentTransition` modifiers. Do not
  weaken or delete the red tests. Then run the full suite with the T2 command; all tests
  green (IC-11).
- Receipts: green SHA; suite output `227 tests, 0 failures`;
  `git diff main...HEAD -- StatsLite/` limited to the four token lines;
  `git diff main...HEAD --stat` = the T2 test file + `MenuBarStackedItemView.swift`.

## Phase 4 — VAC ledger (tests only)

- [x] **T4** — coder self-verify, same worktree, tests only (no captures); the pass evidence
  is the T3 green run under the T2 xcodebuild command. Write
  `artifacts/2026-10-16-emulate-stats-layout/vac-ledger.md` with one row per IC: IC-1 …
  IC-12 read `pass` with evidence (green test names; `rg` output for IC-9; recorded
  measurements for IC-5 `31.22/2.78`, IC-6 `23.09/10.91`, IC-8 `42.11/1.89`; diff stat for
  IC-12). Add one `waived` row for screenshot and strip captures: user authority, no Screen
  Recording permission (`8b0ce41` + T1 probe), with the 7 pt visual legibility override
  noted. Every test-based row must read `pass`. Commit on the branch
  (`docs(menubar): record emulate stats layout VAC ledger`).
- Receipts: `vac-ledger.md` on disk with pass/waived rows, committed on the branch.

## Phase 5 — Review, merge, cleanup

- [x] **T5** — Spawn `reviewer` with `[code-review]`, plan name
  `2026-10-16-emulate-stats-layout`, `cwd` = the worktree, against
  `git -C worktrees/emulate-stats-layout diff main...HEAD`. Checks: the red commit is
  test-only and fails on ALL FOUR production tokens (label `size:8`, value `size:10.5` in
  both guards, block `spacing:1`, network `spacing:1`) with the five enumerated test names
  and 227 total; the guard rewrites and the two new spacing guards match Blueprint
  Appendix A / Appendix B; the IC-3 threshold and constants match the binding user decision
  (2.5 / 31.22 / 2.78) and the IC-11 constants match the blueprint (10.9067 / 18.6943 /
  18.4790); the green commit changes exactly the four tokens (`:103`, `:112`, `:116`,
  `:143`) and nothing else in `StatsLite/`; the ledger has complete pass/waived rows; the
  zero-animation rule is intact; the green suite count is the red count with 0 failures.
  Max two NO GO cycles, then escalate. On GO: main advances in parallel, so rebase first —
  `git -C worktrees/emulate-stats-layout rebase main` (if the rebase touches `StatsLite/`
  files, re-run the T2 suite command after the rebase) — then from `main` in the main repo
  run `git merge --ff-only feat/2026-10-16-emulate-stats-layout` (or `--squash` with its
  own conventional commit). Then remove the worktree and branch, then mark every task `[x]`
  with receipts and report the merge SHA.
- Receipts: review verdict; rebase note; merge SHA confirmed by `git log --oneline -1` on
  `main`; worktree removed (`git worktree prune`, `git branch -d …`, orphaned-dir sweep per
  the `git-worktree` skill).

## Verification and spawn matrix

| Task | Agent | cwd | Timeout | Marker |
| --- | --- | --- | --- | --- |
| T1 | planner (bash) | main repo | — | — |
| T2 | `coder` | worktree | 1800 s | `[red]`, plan `2026-10-16-emulate-stats-layout` |
| T3 | `coder` | same worktree | 1800 s | plan `2026-10-16-emulate-stats-layout` |
| T4 | `coder` self-verify | same worktree | 1800 s | plan `2026-10-16-emulate-stats-layout` |
| T5 | `reviewer` | worktree | 600 s | `[code-review]`, plan `2026-10-16-emulate-stats-layout` |

Sequencing: T1 → T2 → T3 → T4 → T5 strictly sequential; red and green never parallel.
No simulator concurrency: the xcodebuild serial flags in T2/T3 are mandatory
(`-parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`).

## Docs

- `ARCHITECTURE.md` / `DESIGN.md`: absent at this project root; nothing to update.
- `AGENTS.md`: the zero-animation rule and evidence rules already cover this change;
  no edit needed.
- Result: **No doc updates needed.**

## Risks and open items

- **PM line-number discrepancy (recorded)**: the PM message cited the four token lines as
  `:102` / `:113` / `:117` / `:142`. HEAD (`nl -ba` at authoring) and the gate-verified
  blueprint Appendix A put them at `:103` / `:112` (Text at `:111`) / `:116` (Text at
  `:115`) / `:143`. The blueprint governs (the gate re-verified every Appendix A quote
  character for character at `0b11573`); T2/T3 use the blueprint citations. The substance
  of the PM scope — the same four tokens, one green commit — is unaffected.
- **Parallel main**: main advances during execution (as last time). T5 rebases before the
  ff-only merge; if the rebase moves `StatsLite/` files, re-run the suite before merging.
- **Pre-existing open worktree** `worktrees/2026-10-15-stats-lite-view-weight` (branch
  `feat/2026-10-15-stats-lite-view-weight`) belongs to plan
  `2026-10-15-stats-lite-view-weight`, not this plan; leave it untouched.
- **IC-5 threshold margin**: expected clearance 2.7778 pt against the 2.5 pt threshold — a
  0.28 pt margin inside the pinned 34.0 pt block. This is the recorded Option 1 decision:
  `blockWidth` and the length contract stay unchanged; the guard encodes the relaxed
  threshold. A future change that widens the value past 2.5 pt clearance fails the guard;
  that failure is correct behavior, not noise.
- **7 pt legibility override**: cap height 4.93 pt and 3.81:1 light-mode contrast are on
  record (blueprint Part 4 §1). The token ships per user authority; the ledger waived row
  notes it. No agent re-litigates it.
- **Deferred comment citations (gate note N1)**: `MenuBarBlockModel.swift:56-58` still
  states 42.91 pt / 1.09 pt clearance for `"999 MB/s"` (the 9 pt medium numbers). At 9 pt
  regular the values are 42.1084 / 1.8916 (blueprint VAC-8, IC-8). Comment-only, outside
  the four-token scope; rides the next docs pass.
- **Deferred VAC-citation refresh**: `:137-138` still cites `(VAC-N1)` / `(VAC-9)` from an
  older VAC numbering. The previous plan deferred it; this plan's Appendix A does not
  include it. Comment-only; rides the next typography pass.
- **Deferred 130 pt row (gate note N3)**: blueprint Part 3 §2 lists the 130 pt row; no test
  pins it. Add `testCPURAMPlusNetworkTotal130` to `MenuBarLayoutTests.swift` or drop the
  row in a follow-up. Not a four-token change.
- **Test-count drift**: red expects 227 tests (225 baseline + 2 new spacing guards). If
  main lands tests before T2, recompute: red = current baseline + 2, with exactly the five
  enumerated failures (re-derive from the then-current test file; do not copy this list
  blindly).
- **Red-count discipline**: the five-failure expectation is derived from the current test
  file, not guessed: three token-coupled guards exist today (FM1 `:148`, IC-4 `:187`, the
  IC-10 value-size guard `:231`), four guards measure target fonts and pass at red
  (IC-2/IC-3/IC-11/IC-12), and no other file pins any of the four tokens (authoring scan).
  The two new spacing guards close the only gap.
