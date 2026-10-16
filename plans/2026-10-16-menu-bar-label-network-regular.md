# Plan: Menu Bar Status Item Typography — Label `.bold` → `.regular` and Network `.medium` → `.regular`

Date: 2026-10-16
Plan name: `2026-10-16-menu-bar-label-network-regular`
Risk class: **R2** (UI work — zero-tolerance visual policy applies; visual defects are blocking).
Status: Design gate **PASS** (`artifacts/2026-10-16-menu-bar-label-network-regular/gate-report.md`,
commit `3e36d88`). Plan authored 2026-10-16. Clarity adjustment pass applied 2026-10-16 after `run_plan`
(wording and procedure only — ISC checks, Design Blueprint, scope, and tasks unchanged).
Awaiting `[plan-review]`.
**Complete 2026-10-16:** T1 waiver probe exit 1 (`8b0ce41`); red `98cc6fb` (225 tests,
2 failures on both production tokens); green `8a82730` (three tokens, 225/0); ledger
`bc861a4` (12 pass, 2 waived); reviewer verdict GO (`subagent_done`, `23c4579d`); no rebase
needed (main did not advance); merged fast-forward to `main` at `bc861a4`; worktree and
branch removed.
Repo HEAD at authoring: `3e36d88`, clean (untracked `worktrees/` only).
Baseline suite: 223 tests, 0 failures (gate report §5 at `9e9e9f2`; the three commits
since — `253100b`, `3e36d88`, `e30cef8` — are docs-only, so no `StatsLite/` or
`StatsLiteTests/` change landed after `9e9e9f2` and the baseline stands at HEAD).
Screenshot waiver: carried over from plan `2026-10-16-menu-bar-regular-weight` — user
authority, no Screen Recording permission. All screenshot and strip captures stay waived;
the waiver is recorded in the ISC preamble now and on disk in T1's waiver note; the ledger
gets pass/waived rows.
Worktree: `<repo>/worktrees/menu-bar-label-network-regular`, branch
`feat/2026-10-16-menu-bar-label-network-regular` (non-base). main advances in parallel —
expect to rebase before the ff-only merge, as last time.

## Intent

Current state: the CPU/MEM/GPU category labels render `.font(.system(size: 8, weight: .bold))`
with `.foregroundStyle(.secondary)` (`StatsLite/MenuBarStackedItemView.swift:111-113`). The
network upload and download rate values render `.font(.system(size: 9, weight: .medium).monospacedDigit())`
(`:152-153`, `:166-167`). The bold label strokes and the medium rate strokes read heavier
than adjacent menu bar text such as the system clock.

Target state: labels render `.font(.system(size: 8, weight: .regular))` and keep
`.foregroundStyle(.secondary)` (`:111-113`). Both network rate lines render
`.font(.system(size: 9, weight: .regular).monospacedDigit())` (`:153`, `:167`).
Everything else stays unchanged: the value font at `:116` keeps
`.system(size: 10.5, weight: .regular).monospacedDigit()` (landed in plan
`2026-10-16-menu-bar-regular-weight`), block widths stay 34.0 pt / 50.0 pt, pinned item
lengths stay, state tints stay, zero animation stays. Two token kinds change on three
source lines, in one green commit.

## Evidence

- Design gate **PASS**: `artifacts/2026-10-16-menu-bar-label-network-regular/gate-report.md`
  at commit `3e36d88`. Corrections C1–C5 verify against source and live measurement. The
  previously passing VACs, approved tokens, and measurements are unchanged. Screenshot
  checks stay check-only under the user waiver.
- Gate measurements (live AppKit `NSFont` APIs, re-run at the re-gate — measurements, not
  priors): labels at 8 pt regular — CPU `17.3164`, GPU `17.5625`, MEM `19.3594`, MEM row
  `25.3594`, clearance `8.6406`. Network at 9 pt — `"999 MB/s"` medium `42.9085`, regular
  `42.1084`, regular spacer `1.8916`. Value `"100%"` at 10.5 regular `29.9260`, clearance
  `4.0740`.
- Test evidence (gate §5): suite 223/223 at `9e9e9f2`; `MenuBarValueTypographyTests` 5/5 at
  `253100b`. The suite still asserts the current `.bold` / `.medium` state
  (`StatsLiteTests/MenuBarValueTypographyTests.swift:27`, `:31`, `:184`, `:218`). The
  blueprint's two "add a test" items (label-row clearance, network-block clearance) are
  real gaps.
- Band-aid scan at authoring: `rg 'TODO|FIXME|HACK'` over `MenuBarStackedItemView.swift`,
  `MenuBarBlockModel.swift`, `StatusItemController.swift`, `MenuBarValueTypographyTests.swift`
  — no hits. No refactor debt in scope.

## ISC — binary checks (every item is yes/no)

> **Screenshot waiver (user authority, carried over 2026-10-16):** every screenshot-based
> visual check in this plan is SKIPPED: menu bar strip captures, popover captures, dark/light
> renders, and visual blend inspection. Reason: this session has no macOS Screen Recording
> permission; `screencapture` of other processes fails with exit 1. The user waived visual
> capture on their authority (plan `2026-10-16-menu-bar-regular-weight`). T1 records the
> waiver note with a fresh probe instead of baseline captures. Visual ICs get a `waived`
> row in the ledger. Test-based ICs stay binding and must pass.

Citation rule: a bare `:N` in the ISC and tasks means `StatsLite/MenuBarStackedItemView.swift:N`
unless another file is named beside it.

Widths (blueprint, gate C5): 768 px is the reference width. 375 px, 1440 px, and Retina are
check-only. Block widths are pinned (34.0 pt standard, 50.0 pt network), so geometry measured
at the reference holds at every width. Under the waiver no render environment exists, so
layout claims verify from test evidence. Each IC ends with a `Widths:` line.

- [ ] **IC-1 (VAC-1, value font retained)** — the value `Text` font token stays
  `.font(.system(size: 10.5, weight: .regular).monospacedDigit())` (`:115-116`). The guard
  `testValueFontIsTenAndAHalfPointRegularMonospacedDigit` passes at red and at green.
  Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-2 (VAC-2, monospaced digits)** — `.monospacedDigit()` stays on the value font
  (`:116`); the guard `testValueFontKeepsMonospacedDigit` passes at red and at green.
  Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-3 (VAC-3, block width and value clearance)** — `MenuBarLayout.blockWidth` stays
  34.0 pt; `"100%"` fits one line with total clearance ≥ 3.5 pt (gate measurement
  29.9260 pt width → 4.0740 pt clearance); the guard
  `testClearanceForWidestValueAtRegularMeetsThreeAndAHalfPoints` passes at red and at green.
  Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-4 (VAC-4, category labels — FLIPPED)** — labels render
  `.font(.system(size: 8, weight: .regular))` with `.foregroundStyle(.secondary)`
  (`:111-113`); no `.bold` weight on CPU/MEM/GPU labels. The guard
  `testLabelFontIsEightPointRegularSecondary` (renamed from `testLabelFontStaysBoldSecondary`,
  expectation flipped from `.bold` to `.regular`) **fails at red** while `:112` carries
  `.bold`, and passes at green. Falsification: the guard moves fail → pass only when `:112`
  flips to `.regular`; any other edit leaves it red. Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-5 (VAC-8, zero animation)** — `rg -n '\.animation|\.contentTransition'` over
  `MenuBarStackedItemView.swift`, `MenuBarBlockModel.swift`, `StatusItemController.swift`,
  `MenuBarAccessibility.swift` finds comment-only hits at `MenuBarStackedItemView.swift:14`,
  `:15`, `:138` (gate-verified) and never a modifier; `MenuBarRedrawChurnTests` passes.
  Widths: all runtimes, all widths.
- [ ] **IC-6 (VAC-9, state colors retained)** — CPU/GPU tint follows the raw fraction:
  `≥0.95` red, `≥0.80` orange, else `.primary`, nil → tertiary (`MenuBarBlockModel.swift:172-176`,
  valueColor map `:125-128`). MEM value renders `.primary` at every pressure state; the 4 pt
  dot carries `MemoryPressureState.levelColor` (`MenuBarBlockModel.swift:130`,
  `DesignTokens.swift:16-23`, commit `d985784`). Network dots stay red (`:147`) and blue
  (`:161`). Thresholds act on the raw fraction (`MetricFormatters.swift:15-19`). Widths:
  768 reference; 375/1440/Retina check-only (visual rows waived).
- [ ] **IC-7 (VAC-10, visual blend)** — labels, values, and rate lines render in regular
  weight; nothing in the status item looks heavier than the system clock. **waived** —
  user authority 2026-10-16, no Screen Recording permission; no capture exists.
  Widths: check-only per waiver.
- [ ] **IC-8 (VAC-11, pinned length)** — `statusItem.length` stays 114 pt (3 metrics),
  168 pt (with network), 76 pt (2 metrics), 38 pt (1 metric); value or label changes never
  resize the item; `MenuBarLayoutTests` passes. Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-9 (suite)** — red run executes baseline + 2 new tests (223 + 2 = 225 at the red
  run's HEAD) with **exactly 2 failures**: the flipped IC-4 guard and the flipped IC-10 guard.
  Green run executes the same count with 0 failures. No test is deleted. Baseline 223/223
  at `3e36d88`; recompute per the Test-count drift risk if main lands tests first. Widths: n/a.
- [ ] **IC-10 (VAC-6, network rate typography — FLIPPED)** — both rate fonts render
  `.font(.system(size: 9, weight: .regular).monospacedDigit())` at `:153` (upload) and
  `:167` (download); neither line carries `.medium` or `.bold`; the value line keeps size
  10.5. The guard
  `testNetworkFontsAreNinePointRegularAndValueStaysSizeTenAndAHalf` (renamed from
  `testNetworkFontsStayMediumAndValueStaysSizeTenAndAHalf`, expectation flipped from
  `.medium` to `.regular`) **fails at red** for both lines and passes at green.
  Falsification: the guard moves fail → pass only when `:153` and `:167` both flip.
  Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-11 (VAC-5, label-row clearance — NEW guard)** — the label row fits the 34.0 pt
  block on one line with total clearance ≥ 3.5 pt. Guard
  `testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints`: MEM row = 4.0 pt dot + 2.0 pt
  gap + `width("MEM" @ 8 pt regular)` 19.3594 = 25.3594 → clearance 8.6406 ≥ 3.5;
  CPU clearance ≥ 16.0 (16.6836); GPU clearance ≥ 16.0 (16.4375). The guard measures the
  target font through `NSFont`, so it passes at red and at green (regression guard).
  Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-12 (VAC-7, network-block clearance — NEW guard)** — the container stays pinned
  at 50.0 pt (`MenuBarLayout.networkBlockWidth`, frame at `:172`); the widest formatted
  rate string `"999 MB/s"` plus the 6.0 pt dot leaves ≥ 1.8 pt for `Spacer(minLength: 1)`.
  Guard `testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum`:
  50.0 − 6.0 − `width("999 MB/s" @ 9 pt regular mono)` = 50.0 − 6.0 − 42.1084 = 1.8916 ≥ 1.8
  (the VAC-7 threshold; it subsumes the appendix's ≥ 1.0 pt spacer minimum). The guard
  passes at red and at green (regression guard). Widths: 768 reference; 375/1440/Retina check-only.
- [ ] **IC-13 (scope)** — the production diff against `main` contains exactly three weight
  tokens: `:112` `.bold` → `.regular`, `:153` `.medium` → `.regular`, `:167` `.medium` →
  `.regular`. `:116` untouched. No tint, width, length, comment, or modifier changes.
  `git diff main...HEAD -- StatsLite/` shows only those three lines; every other change
  lives in `StatsLiteTests/`. Widths: n/a.

Plan-scoped failure modes:

- **FM1** — the label token stays (or reverts to) `.bold` → IC-4 fails. Red proves it: the
  flipped guard fails at HEAD while `:112` reads `.bold`.
- **FM2** — either network token stays (or reverts to) `.medium` → IC-10 fails. Red proves
  it: the flipped guard fails at HEAD for upload and download.
- **FM3** — the edit escapes the three lines (value font `:116`, tints, widths, lengths,
  comments) → IC-1 / IC-3 / IC-6 / IC-8 / IC-13 fail.
- **FM4** — `.animation` or `.contentTransition` enters the status item path → IC-5 fails.
- **FM5** — clearance regresses: the label row or the network block overflows, truncates,
  or ellipsizes → IC-11 / IC-12 fail.

Red-phase falsification rule: if a flipped token guard passes at HEAD, the guard is not
coupled to its production token. Fix the guard in the red commit; do not start green.

## Approach

1. Two-token implementation in one green commit: at
   `StatsLite/MenuBarStackedItemView.swift:112` change `weight: .bold` to `weight: .regular`
   (line 113 keeps `.foregroundStyle(.secondary)`); at `:153` and `:167` change
   `weight: .medium` to `weight: .regular` (both lines keep `.monospacedDigit()`). No other
   production line changes; `:116` stays `weight: .regular` 10.5 mono (IC-13).
2. TDD with the existing source-token mechanism: the red commit first rewrites the two
   existing guards (`MenuBarValueTypographyTests.swift:27`, `:31`, method names at `:184`,
   `:218`) to the blueprint expectations and adds the two blueprint clearance guards, then
   fails on both production tokens. The green commit flips the two tokens. Red and green
   are two sequential coder spawns in one worktree.
3. T1 records the screenshot waiver instead of baseline captures (user authority, no
   Screen Recording permission). Visual ICs are waived rows in the ledger; test-based ICs
   are binding.
4. Verification: automated checks for IC-1 … IC-6, IC-8 … IC-13; IC-7 waived. Evidence per
   IC: green test names, `rg` output for IC-5, recorded measurements for IC-3 / IC-11 / IC-12.
5. Merge after reviewer GO: rebase onto main if main advanced, then `git merge --ff-only`
   with the literal branch name (or `--squash` with its own conventional commit); then
   remove the worktree and branch.
6. One variable per red guard: each production token (label, network) has its own failing
   guard, so the green commit attributes each flip to its own line even though both land
   in one commit (PM scope ruling).

### Design Blueprint (verbatim)

The re-issued Design Blueprint follows. Source:
`artifacts/2026-10-16-menu-bar-label-network-regular/blueprint-reissued.md` (commit `3e36d88`).
It is the authority for every visual requirement in this plan; the ISC mirrors its VAC list.

# Design Blueprint: Menu Bar Status Item Typography — Label Options & Network Weight Update (Re-issued)

This design blueprint re-issues the typography specification for the macOS menu bar status item in `StatsLite`.
It applies corrections C1 through C5 from the Design Gate report (`artifacts/2026-10-16-menu-bar-label-network-regular/gate-report.md`).
It incorporates two scope updates:
1. **Network rate value font weight**: Dedicated upload and download rate lines in `MenuBarNetworkBlockView` update from `.system(size: 9, weight: .medium).monospacedDigit()` to `.system(size: 9, weight: .regular).monospacedDigit()`.
2. **Category label font weight evaluation**: This document evaluates three options: (a) 8 pt `.regular`, (b) 7 pt `.regular`, and (c) 8 pt `.light`. Each option pairs with `.secondary`. It provides AppKit measurements, contrast calculations, and one recommended token.

On `main` at commit `9e9e9f2` (and named baseline `6000441` / `a75fd9e`), standard metric values already render in `weight: .regular` at 10.5 pt (`MenuBarStackedItemView.swift:116`).
Values remain `.regular` in this specification.

---

## Visual Evidence Pass Summary

### Capture Status & Available Visual Assets
1. Live screen capture with `screencapture -x` fails in this headless terminal session with the error `could not create image from display` (exit status 1). The macOS host system does not grant macOS Screen Recording permissions to this terminal session. The user waived screenshot checks under user authority. Visual screenshot checks remain check-only.
2. Verified visual evidence exists in previously captured repository artifacts:
   - Menu bar baseline capture: `/tmp/menubar_test.png`
   - Popover baseline captures: `artifacts/2026-10-16-menu-bar-regular-weight/baseline/dark.png` and `artifacts/2026-10-16-menu-bar-regular-weight/baseline/light.png`
3. Inspection of `/tmp/menubar_test.png` confirms the visual defects:
   - Line 1 category micro-labels (`CPU`) render with heavy bold strokes.
   - The heavy bold stroke visually dominates the status item relative to the adjacent system clock (`Thu 15 Oct 2:22 PM`) and system icons.
   - Network rate lines render with medium weight (`.medium`), which produces thicker glyph strokes than regular menu bar text.
4. AppKit font measurement APIs (`NSFont`) supply exact geometric measurements for all candidate label tokens and network rate strings at the 768 px reference width.

---

## Label Option Comparison

The user evaluates three label tokens for `MenuBarBlockView` Line 1:
- **Option (a)**: `.font(.system(size: 8, weight: .regular))` with `.foregroundStyle(.secondary)`
- **Option (b)**: `.font(.system(size: 7, weight: .regular))` with `.foregroundStyle(.secondary)`
- **Option (c)**: `.font(.system(size: 8, weight: .light))` with `.foregroundStyle(.secondary)`

### 1. Measured Text Widths vs Pinned Block Width (34.0 pt)

Measurements use `NSFont` APIs directly via AppKit.
The pinned block width is `34.0 pt` (`MenuBarLayout.blockWidth`).
The `MEM` row includes a 4.0 pt status indicator dot, a 2.0 pt spacing gap, and the `"MEM"` label text.

| Measurement Dimension | Current (8 pt Bold) | Option (a) (8 pt Regular) | Option (b) (7 pt Regular) | Option (c) (8 pt Light) |
|---|---|---|---|---|
| `"CPU"` Text Width | 18.0098 pt | 17.3164 pt | 15.3057 pt | 17.0580 pt |
| `"GPU"` Text Width | 18.1621 pt | 17.5625 pt | 15.5210 pt | 17.2561 pt |
| `"MEM"` Text Width | 20.0879 pt | 19.3594 pt | 17.0933 pt | 19.0407 pt |
| `MEM` Row Total (Dot + Gap + Text) | 26.0879 pt | 25.3594 pt | 23.0933 pt | 25.0407 pt |
| `MEM` Row Total Clearance (34.0 pt − width) | 7.9121 pt | 8.6406 pt | 10.9067 pt | 8.9593 pt |
| `MEM` Row Clearance Margin (per side) | 3.9560 pt | 4.3203 pt | 5.4533 pt | 4.4796 pt |
| Clearance Requirement (≥ 3.5 pt total) | PASS | PASS | PASS | PASS |

All three options satisfy the 3.5 pt clearance rule inside the 34.0 pt pinned block.
Option (b) yields 2.27 pt more clearance than Option (a).
Option (c) yields 0.32 pt more clearance than Option (a).

### 2. Legibility Assessment at Menu Bar Scale

Menu bar typography renders at micro-scale (vertical container thickness 24 pt to 30 pt).

- **Retina Displays (2x scale, 1 pt = 2 physical pixels, check-only)**:
  - **Option (a) (8 pt Regular)**: Cap height measures 5.64 pt (11.28 physical pixels). Stem thickness measures approximately 0.8 pt (1.6 physical pixels). Glyphs remain distinct and sharp in both Dark Mode and Light Mode.
  - **Option (b) (7 pt Regular)**: Cap height measures 4.93 pt (9.86 physical pixels). Stem thickness measures approximately 0.7 pt (1.4 physical pixels). Glyphs remain legible on Retina screens, but capital letters approach the lower limit of comfortable visual recognition.
  - **Option (c) (8 pt Light)**: Cap height measures 5.64 pt (11.28 physical pixels). The `.light` weight value claim is `-0.40` (unverified prior). Stem thickness drops to approximately 0.5 pt (1.0 physical pixel). Thin stems combined with secondary opacity cause low contrast. Glyphs appear washed out under ambient light or glare.

- **Non-Retina Displays (1x scale, 1 pt = 1 physical pixel, check-only)**:
  - **Option (a) (8 pt Regular)**: Cap height is ~5.6 pixels. Stem width is ~0.8 to 1.0 pixel. Sub-pixel anti-aliasing preserves stroke integrity without stem dropout.
  - **Option (b) (7 pt Regular)**: Cap height is < 5.0 physical pixels. Uppercase bars of `"E"` and joints of `"M"` blur together. Five vertical pixels cannot resolve three strokes and two spaces cleanly.
  - **Option (c) (8 pt Light)**: Stem thickness drops below 1.0 physical pixel (~0.5 pixel). At 50% opacity, anti-aliasing leaves faint, broken trails. Letterforms experience severe stroke dropout and fail visual recognition.

### 3. WCAG 1.4.3 Contrast Analysis of `.secondary`

In macOS AppKit, `NSColor.secondaryLabelColor` resolves to:
- Light Mode (`NSAppearanceNameAqua`): Black (`#000000`) at alpha `0.498039` (~50%).
- Dark Mode (`NSAppearanceNameDarkAqua`): White (`#FFFFFF`) at alpha `0.54902` (~55%).

Measured WCAG 2.1 / 2.2 contrast ratios against typical menu bar surfaces:
- **Dark Mode (menu bar background #1E1E1E)**: Composited text produces `r=153.525, g=153.525, b=153.525`. Measured contrast ratio is **5.89:1**. This passes WCAG AA 1.4.3 (≥ 4.5:1).
- **Light Mode (menu bar background #EBEBEB)**: Composited text produces `r=117.97, g=117.97, b=117.97`. Measured contrast ratio is **3.81:1**.
  *(Reference note: Standard text requires 4.5:1 for WCAG AA. 3.81:1 falls below 4.5:1, but passes the 3:1 threshold for large text. In native macOS conventions, `.secondary` serves as secondary metadata. The primary metric value provides high contrast (> 12:1), and VoiceOver announces full composite labels).*
- **Interaction with Stroke Weight**: When strokes become thinner, human visual contrast sensitivity drops. Option (c) (`.light`) reduces optical stroke density, which exacerbates the 3.81:1 contrast deficit in Light Mode. Option (a) (`.regular`) maintains standard stroke density, which maximizes legibility for `.secondary`.

*(Marked verification: Popover text contrast ratios > 10:1 in Dark Mode and > 12:1 in Light Mode are unverified priors).*

### 4. Typographical Hierarchy vs 10.5 pt Regular Values

The value text renders with `Font.system(size: 10.5, weight: .regular).monospacedDigit()`.
Cap height for the value text is 7.40 pt (`NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)`).

- **Option (a) (8 pt Regular)**:
  - Establishes hierarchy through three distinct cues:
    1. Size scale: 8 pt label (5.64 pt cap height) vs 10.5 pt value (7.40 pt cap height). This delta yields a 23.8% optical height and point-size difference.
    2. Style and opacity: `.secondary` opacity vs `.primary` / semantic state colors (`systemOrange`, `systemRed`).
    3. Case and tracking: Uppercase alphabetical tracking (`CPU`, `MEM`, `GPU`) vs tabular monospaced numerals (`0%` to `100%`).
  - Preserves a consistent 1.5 pt step scale across the status item: 8 pt (labels) → 9 pt (network rates) → 10.5 pt (standard values).
- **Option (b) (7 pt Regular)**:
  - Emphasizes the size delta (7 pt vs 10.5 pt, a 33.3% point-size delta).
  - Disrupts typographic consistency by introducing a fourth font size (7 pt, 8 pt, 9 pt, 10.5 pt) into a compact status item.
- **Option (c) (8 pt Light)**:
  - Attempts hierarchy via stroke weight difference (light vs regular).
  - Creates an unnatural, delicate texture that looks mismatched beside the system clock and menu bar icons.

### Single Measured Recommendation

**Select Option (a): `.font(.system(size: 8, weight: .regular))` with `.foregroundStyle(.secondary)`**.

Justification:
1. Option (a) avoids the severe stroke dropout of Option (c) on non-Retina displays and under low-contrast Light Mode backgrounds.
2. Option (a) avoids the illegible glyph compression of Option (b) on 1x displays (< 5 pixel cap height).
3. Option (a) preserves clean visual hierarchy via size (8 pt vs 10.5 pt), opacity (`.secondary` vs `.primary`), and case (uppercase vs numerals).
4. Option (a) maintains typographic scale harmony (8 pt, 9 pt, 10.5 pt).
5. Option (a) leaves 8.64 pt of clearance inside the 34.0 pt block, exceeding the 3.5 pt clearance requirement.

---

## Design System Tokens & Reference Rules

- **Project `DESIGN.md`**: The repository root does not contain a `DESIGN.md` file. Design tokens and layout rules derive directly from `StatsLite/MenuBarBlockModel.swift`, `StatsLite/DesignTokens.swift`, and `StatsLite/MenuBarStackedItemView.swift`.
- **Architectural Constraint**: Status item views must not use `.animation` or `.contentTransition`. Transitions must stay discrete to prevent `RenderBox` glyph re-rasterization churn.
- **Single Source of Truth for Layout Constants**:
  - `MenuBarLayout.blockWidth` = `34.0 pt`
  - `MenuBarLayout.networkBlockWidth` = `50.0 pt`
  - `MenuBarLayout.gap` = `4.0 pt`
  - `MenuBarLayout.padding` = `2.0 pt`
  - Status item lengths: 114 pt (3 standard metrics), 168 pt (4 metrics with network), 76 pt (2 standard metrics), 38 pt (1 metric).
- **Confirmed Scope Decisions**:
  - Category labels (`CPU`, `MEM`, `GPU`) update from `.bold` to `.regular` at 8 pt (`StatsLite/MenuBarStackedItemView.swift:111-113`).
  - Standard metric values retain 10.5 pt `.regular` with monospaced digits (`MenuBarStackedItemView.swift:116`).
  - **Scope Addition**: Network rate values update to 9 pt `.regular` monospaced. Update upload font at line 153 and download font at line 167 (`StatsLite/MenuBarStackedItemView.swift`). Text declarations sit at lines 152 and 166.

---

## Part 1: Visual Hierarchy & ASCII Wireframe

### Menu Bar Status Item Layout Wireframe

```
+----------------------------------------------------------------------------------------------------------------+
| macOS System Menu Bar (Height: ~24 - 30 pt)                                                                    |
| ... [App Menus]                                 [StatsLite Item]        [System Icons]       [System Clock]    |
+----------------------------------------------------------------------------------------------------------------+

StatsLite Status Item Detail (3 Standard Metrics):
|<------------------------------------------ Total Item Width: 114 pt ------------------------------------------>|
|  pad: 2pt                                                                                             pad: 2pt  |
|  +--+   +-------------------+   +--+   +-------------------+   +--+   +-------------------+   +--+             |
|  |  |   | CPU Block (34 pt) |   |  |   | MEM Block (34 pt) |   |  |   | GPU Block (34 pt) |   |  |             |
|  |  |   |                   |   |  |   |                   |   |  |   |                   |   |  |             |
|  |  |   | Line 1:  "CPU"    |   |  |   | Line 1:  o "MEM"  |   |  |   | Line 1:  "GPU"    |   |  |             |
|  |  |   | (8pt Regular,     |   |g |   | (4pt dot + 8pt    |   |g |   | (8pt Regular,     |   |  |             |
|  |  |   |  .secondary)      |   |a |   |  Regular, .sec)   |   |a |   |  .secondary)      |   |  |             |
|  |  |   |                   |   |p |   |                   |   |p |   |                   |   |  |             |
|  |  |   | Line 2:  "22%"    |   |4 |   | Line 2:  "17%"    |   |4 |   | Line 2:  "15%"    |   |  |             |
|  |  |   | (10.5pt Regular,  |   |pt|   | (10.5pt Regular,  |   |pt|   | (10.5pt Regular,  |   |  |             |
|  |  |   |  monospacedDigit) |   |  |   |  monospacedDigit) |   |  |   |  monospacedDigit) |   |  |             |
|  +--+   +-------------------+   +--+   +-------------------+   +--+   +-------------------+   +--+             |
+----------------------------------------------------------------------------------------------------------------+

With Dedicated Network Block Appended (4 Metrics):
|<------------------------------------------ Total Item Width: 168 pt ------------------------------------------------------------------->|
| ... | gap 4 pt | +--------------------------------------------------+ | pad: 2pt |
|     |          | NET Block (50 pt pinned width)                     | |          |
|     |          | Line 1: [Red Dot 6pt]   [Spacer]    "368 KB/s"     | |          |
|     |          | Line 2: [Blue Dot 6pt]  [Spacer]     "14 KB/s"     | |          |
|     |          | (9pt Regular, monospacedDigit)                     | |          |
|     |          +----------------------------------------------------+ |          |
+---------------------------------------------------------------------------------------------------------------------------------------+
```

### Visual Weight & Layout Alignments
1. **Vertical Alignment**:
   - `MenuBarBlockView`: `VStack(alignment: .center, spacing: 1)`.
   - `MenuBarNetworkBlockView`: `VStack(alignment: .leading, spacing: 1)`.
2. **Horizontal Alignment**:
   - Labels and standard values center inside each 34.0 pt block.
   - For `MEM`, the 4.0 pt circular indicator dot sits leading of `"MEM"` with 2.0 pt spacing. It carries a vertical offset of `-0.5 pt` to align with the visual center of capital letters.
   - For Network, the 6.0 pt dot sits leading. A flexible `Spacer(minLength: 1)` absorbs width. The rate text pins trailing to align rate digits and unit labels.
3. **Typographic Rhythm**:
   - All text across the status item renders in regular weight (`.regular`).
   - Stroke thickness matches the adjacent system clock digits. No element stands out with bold or medium weight.

---

## Part 2: Template / Component Skeleton

The update targets `StatsLite/MenuBarStackedItemView.swift`.

### 1. Standard Metric Block Skeleton (`MenuBarBlockView`)

Target implementation spans lines 103–121:

```swift
struct MenuBarBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            HStack(alignment: .center, spacing: 2) {
                if let dotState = block.dotState {
                    Circle()
                        .fill(dotState.levelColor)
                        .frame(width: 4, height: 4)
                        .offset(y: -0.5)
                }
                Text(block.label)
                    .font(.system(size: 8, weight: .regular)) // <-- TARGET: .regular (line 112)
                    .foregroundStyle(.secondary)
            }
            Text(block.valueText)
                .font(.system(size: 10.5, weight: .regular).monospacedDigit()) // <-- RETAINED: .regular (line 116)
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

Exact line ranges in `StatsLite/MenuBarStackedItemView.swift`:
- `var body` property spans lines 142–173.
- Component skeleton as shown (body and computed color properties) spans lines 142–191.
- Full `MenuBarNetworkBlockView` struct declaration spans lines 139–192.

```swift
struct MenuBarNetworkBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Line 1: Upload rate
            HStack(alignment: .center, spacing: 0) {
                Circle()
                    .fill(Color(nsColor: .systemRed))
                    .frame(width: 6, height: 6)

                Spacer(minLength: 1)

                Text(block.valueText)
                    .font(.system(size: 9, weight: .regular).monospacedDigit()) // <-- TARGET: .regular (line 153)
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
                    .font(.system(size: 9, weight: .regular).monospacedDigit()) // <-- TARGET: .regular (line 167)
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

### Verbatim Design Tokens
- Standard Category Label Font: `.font(.system(size: 8, weight: .regular))`
- Standard Category Label Color: `.foregroundStyle(.secondary)`
- Standard Metric Value Font: `.font(.system(size: 10.5, weight: .regular).monospacedDigit())`
- Standard Metric Value Colors: `.primary`, `Color(nsColor: .systemOrange)`, `Color(nsColor: .systemRed)`, `Color(nsColor: .tertiaryLabelColor)`
- Network Rate Value Font: `.font(.system(size: 9, weight: .regular).monospacedDigit())`
- Network Value Colors: `Color.primary`, `Color(nsColor: .tertiaryLabelColor)`
- Pinned Block Dimensions: `blockWidth = 34.0 pt`, `networkBlockWidth = 50.0 pt`
- Prohibited Modifiers: `.animation`, `.contentTransition`

---

## Part 3: Complete State & Responsive Matrix

### Typography and Value Tint Matrix

| UI Component | Metric State | Label Typography | Value Text | Value Typography | Value Foreground Style | Optical Appearance |
|---|---|---|---|---|---|---|
| Standard Block | CPU / GPU Normal (< 0.80 raw fraction) | 8 pt regular `.secondary` | `"0%"` ... `"79%"` | 10.5 pt regular monospaced | `.primary` | Subdued secondary title over clean regular numerals |
| Standard Block | CPU / GPU Warning (0.80 <= raw < 0.95) | 8 pt regular `.secondary` | `"80%"` ... `"95%"` | 10.5 pt regular monospaced | `Color(nsColor: .systemOrange)` | Subdued secondary title over orange numerals |
| Standard Block | CPU / GPU Critical (raw >= 0.95) | 8 pt regular `.secondary` | `"95%"` ... `"100%"` | 10.5 pt regular monospaced | `Color(nsColor: .systemRed)` | Subdued secondary title over red numerals |
| Standard Block | MEM (All pressure states) | 8 pt regular `.secondary` + 4 pt dot | `"0%"` ... `"100%"` | 10.5 pt regular monospaced | `.primary` | 4 pt dot carries state color. Numerals stay `.primary` |
| Standard Block | Unavailable (raw fraction nil) | 8 pt regular `.secondary` | `"--%"` | 10.5 pt regular monospaced | `Color(nsColor: .tertiaryLabelColor)` | Subdued secondary title over placeholder gray |
| Network Block | Line 1 Active Upload | N/A (6 pt red dot) | `"0 KB/s"` ... `"999 GB/s"` | 9 pt regular monospaced | `.primary` | Red indicator dot leading. Regular numerals trailing |
| Network Block | Line 2 Active Download | N/A (6 pt blue dot) | `"0 KB/s"` ... `"999 GB/s"` | 9 pt regular monospaced | `.primary` | Blue indicator dot leading. Regular numerals trailing |
| Network Block | Line 1 / 2 Missing Rate | N/A (6 pt dot) | `"-- KB/s"` | 9 pt regular monospaced | `Color(nsColor: .tertiaryLabelColor)` | Dot leading. Placeholder gray text trailing |
| Any Block | Active Popover / Highlight | 8 pt regular `.secondary` | Active value | Regular monospaced | Inherited highlight contrast | Vibrant white contrast over selection background |

### Network Rate Row Widths and Frame Containment (50.0 pt Pinned Block)

The layout row is `HStack(spacing: 0)` with `Circle().frame(width: 6, height: 6)`, `Spacer(minLength: 1)`, and `Text()`.
Total row width constraint is `50.0 pt` (`MenuBarLayout.networkBlockWidth`).
The available spacer width equals `50.0 pt − 6.0 pt (dot) − text width`.
The available spacer must be ≥ 1.0 pt to satisfy `Spacer(minLength: 1)`.

Live AppKit measurements compare `.medium` against `.regular` at 9 pt:

| Rate String | Category / Formatter Branch | Text Width (.medium) | Avail Spacer (.medium) | Text Width (.regular) | Avail Spacer (.regular) | Spacer Delta | Pass / Fail (Spacer ≥ 1.0 pt) |
|---|---|---|---|---|---|---|---|
| `0 KB/s` | Idle rate | 29.0843 pt | 14.9157 pt | **28.4985 pt** | **15.5015 pt** | +0.5858 pt | PASS |
| `10 KB/s` | Typical low upload | 35.0572 pt | 8.9428 pt | **34.3345 pt** | **9.6655 pt** | +0.7227 pt | PASS |
| `720 KB/s` | Reference download | 41.0301 pt | 2.9699 pt | **40.1704 pt** | **3.8296 pt** | +0.8597 pt | PASS |
| `999 KB/s` | Maximum KB string | 41.0301 pt | 2.9699 pt | **40.1704 pt** | **3.8296 pt** | +0.8597 pt | PASS |
| `1.0 MB/s` | Minimum 1-decimal MB | 39.9420 pt | 4.0580 pt | **39.1113 pt** | **4.8887 pt** | +0.8307 pt | PASS |
| `9.9 MB/s` | Maximum 1-decimal MB | 39.9420 pt | 4.0580 pt | **39.1113 pt** | **4.8887 pt** | +0.8307 pt | PASS |
| `10 MB/s` | Integer MB (truncated from 10.0) | 36.9356 pt | 7.0644 pt | **36.2725 pt** | **7.7275 pt** | +0.6631 pt | PASS |
| `95 MB/s` | Integer MB | 36.9356 pt | 7.0644 pt | **36.2725 pt** | **7.7275 pt** | +0.6631 pt | PASS |
| `100 MB/s` | Integer MB (3 digits) | 42.9085 pt | 1.0915 pt | **42.1084 pt** | **1.8916 pt** | +0.8001 pt | PASS |
| `999 MB/s` | **Worst-case valid formatted string** | 42.9085 pt | 1.0915 pt | **42.1084 pt** | **1.8916 pt** | +0.8001 pt | PASS |
| `1.0 GB/s` | Minimum 1-decimal GB | 38.7330 pt | 5.2670 pt | **37.9644 pt** | **6.0356 pt** | +0.7687 pt | PASS |
| `10 GB/s` | Integer GB | 35.7266 pt | 8.2734 pt | **35.1255 pt** | **8.8745 pt** | +0.6011 pt | PASS |
| `999 GB/s` | Maximum 3-digit GB | 41.6995 pt | 2.3005 pt | **40.9614 pt** | **3.0386 pt** | +0.7381 pt | PASS |
| `-- KB/s` | Missing / fallback string | 32.0194 pt | 11.9806 pt | **31.4868 pt** | **12.5132 pt** | +0.5326 pt | PASS |
| *`1024 KB/s`* | *Hypothetical unformatted string (unreachable)* | 47.0030 pt | −3.0030 pt | **46.0063 pt** | **−2.0063 pt** | +0.9967 pt | UNREACHABLE (BLOCKED if raw) |

#### Formatter Max String Boundary Rule
`MetricFormatters.networkRate` switches to `"1.0 MB/s"` at 1000 KB/s and `"10 MB/s"` at 9.95 MB/s. It switches to `"1.0 GB/s"` at 1000 MB/s and `"10 GB/s"` at 9.95 GB/s (`StatsLite/MetricFormatters.swift:44-64`).
Decimals drop once values reach double digits.
The mantissa never exceeds three characters.
Therefore, strings like `"1024 KB/s"` or `"1000 KB/s"` cannot be emitted by the formatter.
The live measurement of `"1024 KB/s"` (regular width 46.0063 pt, spacer −2.0063 pt) proves that a 4-digit KB string overflows the 50 pt block. This confirms why the formatter boundary rule at lines 44–64 is a necessary design invariant.
The absolute worst-case formatted rate string is `"999 MB/s"` (width **42.1084 pt**).
Changing from `.medium` to `.regular` expands the minimum available spacer margin from `1.0915 pt` to `1.8916 pt` (+73% margin).
This prevents text clipping and avoids truncation ellipses.

### Standard Block Width and Clearance Verification (34.0 pt Pinned Block)

| Element Row | Content | Component Elements | Total Row Width | Total Clearance (34.0 pt − width) | Clearance Margin (per side) | Pass / Fail (≥ 3.5 pt) |
|---|---|---|---|---|---|---|
| Line 1 (CPU Label) | `"CPU"` | Text (17.32 pt) | 17.32 pt | 16.68 pt | 8.34 pt | PASS |
| Line 1 (GPU Label) | `"GPU"` | Text (17.56 pt) | 17.56 pt | 16.44 pt | 8.22 pt | PASS |
| Line 1 (MEM Label with Dot) | Dot + `"MEM"` | 4 pt dot + 2 pt gap + 19.36 pt text | 25.36 pt | 8.64 pt | 4.32 pt | PASS |
| Line 2 (Widest Value) | `"100%"` | Text (29.93 pt) | 29.93 pt | 4.07 pt | 2.03 pt | PASS |
| Line 2 (Two-Digit Value) | `"99%"` | Text (23.22 pt) | 23.22 pt | 10.78 pt | 5.39 pt | PASS |
| Line 2 (Single-Digit Value) | `"0%"` | Text (16.51 pt) | 16.51 pt | 17.49 pt | 8.74 pt | PASS |
| Line 2 (Placeholder) | `"--%"` | Text (19.90 pt) | 19.90 pt | 14.10 pt | 7.05 pt | PASS |

### Viewport and Mode Applicability

| Environment | Applicability | Invariant Behavior |
|---|---|---|
| Tablet (768 px) | Reference Width | Standing reference width for geometric measurements. Status item blocks use pinned widths (34.0 pt standard, 50.0 pt network), so geometry verified here holds across all display resolutions. |
| Mobile (375 px) | Check-only | Native macOS status items do not run on mobile viewports. Layout math verified via test assertions. |
| Desktop (1440 px standard) | Check-only | Standard desktop viewport. Labels render at 8 pt regular weight. Network values render at 9 pt regular weight. Geometry verified via pinned layout rules. |
| Desktop (Retina 2x display) | Check-only | High-density display. Regular strokes render sharp without bold or medium density. |
| Dark Mode Appearance | Check-only (Visual) / Applicable (Tokens) | Visual appearance waived by user authority. Token hierarchy verified in source: labels resolve to secondary opacity, values resolve to primary or semantic tint. |
| Light Mode Appearance | Check-only (Visual) / Applicable (Tokens) | Visual appearance waived by user authority. Token hierarchy verified in source: labels resolve to secondary opacity, values resolve to primary or semantic tint. |
| Metric Permutations | Applicable | Status item length pins to 114 pt (3 metrics), 168 pt (4 metrics with network), 76 pt (2 metrics), 38 pt (1 metric). |

---

## Part 4: Accessibility (WCAG 2.2) & Interaction Contracts

### WCAG 2.2 Success Criteria Compliance
- **Criterion 1.4.3 Contrast (Minimum - Level AA ≥ 4.5:1)**:
  - In Dark Mode, `.primary` menu bar text renders at `#FFFFFF` against dark surfaces with contrast ratio > 10:1 (passes AAA. Unverified prior).
  - In Light Mode, `.primary` menu bar text renders near black with contrast ratio > 12:1 (passes AAA. Unverified prior).
  - In Dark Mode, `.secondary` label text produces a measured contrast ratio of **5.89:1** against `#1E1E1E`, passing WCAG AA.
  - In Light Mode, `.secondary` label text produces a measured contrast ratio of **3.81:1** against `#EBEBEB`. This serves as secondary metadata alongside high-contrast primary values (> 12:1) and complete VoiceOver announcements.
  - Warning tint (`systemOrange`) and Critical tint (`systemRed`) provide color coding backed by VoiceOver speech.
- **Criterion 2.5.8 Target Size (Minimum - Level AA ≥ 24x24 px)**:
  - The status item hit target matches `NSStatusBar.system.thickness` (24 pt to 30 pt) by pinned block length (minimum 38 pt, maximum 168 pt. Unverified prior).

### VoiceOver & Screen Reader Contract
- `MenuBarStackedItemView` declares `.accessibilityHidden(true)`. The hosting view passes clicks to `NSStatusBarButton`.
- `StatusItemController.updateAccessibility()` configures the parent `NSStatusBarButton`:
  - `setAccessibilityElement(true)`
  - `setAccessibilityTitle("StatsLite")`
  - `setAccessibilityLabel(compositeLabel)`
- Dynamic composite label format:
  `"StatsLite: CPU <percent> percent, Memory Pressure <state> at <percent> percent, GPU <percent> percent, Network Upload <rate>, Download <rate>"`.
- Changing label and network value font weights does not alter VoiceOver output or accessibility tree hierarchy.

### Interaction & Animation Contract
- Clicks on the status item toggle the popover.
- If the popover is open, `button.isHighlighted` remains `true`.
- Zero animation rule: No `.animation()` or `.contentTransition()` modifiers exist anywhere in `MenuBarBlockView`, `MenuBarNetworkBlockView`, or `MenuBarStackedItemView`. Metric updates transition discretely between sampling intervals.

---

## Part 5: Numbered Visual Acceptance Checklist (VAC)

- **VAC-1 (Standard Value Font Weight - Retained)**:
  - Selector: `MenuBarBlockView` value `Text` view (`StatsLite/MenuBarStackedItemView.swift:115-116`)
  - Target Environment: macOS Menu Bar (768 px reference width, 375 px, 1440 px, and Retina check-only)
  - Invariant: Metric value text font weight must remain `.regular`. The font descriptor must match `Font.system(size: 10.5, weight: .regular).monospacedDigit()`. No `.medium` or `.bold` weight applies to CPU, MEM, or GPU metric values.

- **VAC-2 (Value Digit Alignment - Retained)**:
  - Selector: `MenuBarBlockView` value `Text` view
  - Target Environment: macOS Menu Bar (768 px reference width, 375 px, 1440 px, and Retina check-only)
  - Invariant: Metric digits must render using monospaced digits (`.monospacedDigit()`). When values change between single, double, or triple digits, digits must not cause horizontal block shift or jitter.

- **VAC-3 (Block Width and Value Text Clearance - Retained)**:
  - Selector: `MenuBarBlockView` container frame (`StatsLite/MenuBarStackedItemView.swift:120`)
  - Target Environment: macOS Menu Bar (768 px reference width, 375 px, 1440 px, Retina check-only, visual check-only per waiver)
  - Invariant: Width must remain pinned to 34.0 pt (`MenuBarLayout.blockWidth`). The widest value string (`"100%"`) must render completely on a single line with zero truncation ellipsis. Total horizontal clearance must be at least 3.5 pt. Pinned 34.0 pt width minus 29.93 pt text width leaves 4.07 pt clearance.

- **VAC-4 (Category Label Typography - Revised)**:
  - Selector: `MenuBarBlockView` category label `Text` view (`StatsLite/MenuBarStackedItemView.swift:111-113`)
  - Target Environment: macOS Menu Bar (768 px reference width, 375 px, 1440 px, Retina check-only, visual check-only per waiver)
  - Invariant: Category labels (`CPU`, `MEM`, `GPU`) must render at 8 pt regular weight (`.font(.system(size: 8, weight: .regular))`) with `.foregroundStyle(.secondary)`. Category labels must not render with `.bold` weight.

- **VAC-5 (Category Label Row Clearance and Containment - Retained)**:
  - Selector: `MenuBarBlockView` category label `HStack` container (`StatsLite/MenuBarStackedItemView.swift:104-114`)
  - Target Environment: macOS Menu Bar (768 px reference width, 375 px, 1440 px, Retina check-only, visual check-only per waiver)
  - Invariant: The category label row must fit on a single line inside the 34.0 pt block width with zero truncation ellipsis. Total clearance must be at least 3.5 pt. For `MEM` with the 4 pt dot and 2 pt spacing, row width is 25.36 pt. This leaves 8.64 pt total clearance (4.32 pt margin per side). For `CPU` (17.32 pt) and `GPU` (17.56 pt), total clearance must exceed 16.0 pt.

- **VAC-6 (Network Rate Value Font Weight - Scope Addition)**:
  - Selector: `MenuBarNetworkBlockView` rate `Text` font modifiers at lines 153 and 167 (with `Text` declarations at lines 152 and 166, `StatsLite/MenuBarStackedItemView.swift:152-153`, `:166-167`)
  - Target Environment: macOS Menu Bar (768 px reference width, 375 px, 1440 px, and Retina check-only)
  - Invariant: Both the upload rate text (line 153) and download rate text (line 167) must render with regular font weight: `.font(.system(size: 9, weight: .regular).monospacedDigit())`. Neither rate text line can use `.medium` or `.bold` weight.

- **VAC-7 (Network Block Clearance and Containment - Scope Addition)**:
  - Selector: `MenuBarNetworkBlockView` container frame (`StatsLite/MenuBarStackedItemView.swift:172`)
  - Target Environment: macOS Menu Bar (768 px reference width, 375 px, 1440 px, Retina check-only, visual check-only per waiver)
  - Invariant: Container width must remain pinned to 50.0 pt (`MenuBarLayout.networkBlockWidth`). The widest formatted rate string (`"999 MB/s"`, 42.11 pt) plus 6.0 pt dot must leave at least 1.8 pt width for `Spacer(minLength: 1)`. Rate strings must render completely on one line with zero truncation ellipsis.

- **VAC-8 (Discrete Rendering / Zero Animation - Retained)**:
  - Selector: `MenuBarStackedItemView`, `MenuBarBlockView`, `MenuBarNetworkBlockView`
  - Target Environment: All macOS runtimes
  - Invariant: The view body tree must contain zero `.animation` or `.contentTransition` modifiers. `MenuBarRedrawChurnTests` must pass without failures.

- **VAC-9 (State Color and Dot Preservation - Retained)**:
  - Selector: `MenuBarBlockView` and `MenuBarNetworkBlockView` foreground styles
  - Target Environment: macOS Menu Bar (Dark Mode and Light Mode, token verification applicable, visual appearance check-only per waiver)
  - Invariant:
    1. CPU and GPU usage values: tint follows the raw metric fraction. `x >= 0.95` renders `Color(nsColor: .systemRed)`. `x >= 0.80` renders `Color(nsColor: .systemOrange)`. All lower values render `.primary`. A nil metric fraction renders `Color(nsColor: .tertiaryLabelColor)`.
    2. MEM value: renders `.primary` at every pressure state. The 4 pt dot carries the state color through `MemoryPressureState.levelColor` (green, yellow, red, gray). Only a nil pressure percent renders `Color(nsColor: .tertiaryLabelColor)`.
    3. Network dots: upload indicator circle carries `Color(nsColor: .systemRed)`. Download indicator circle carries `Color(nsColor: .systemBlue)`.
    4. Thresholds act on the raw fraction, not the displayed rounded string.

- **VAC-10 (Visual Blend with Adjacent Menu Bar Items - Revised)**:
  - Selector: Menu bar status item
  - Target Environment: macOS Menu Bar (Check-only per user screenshot waiver, holds after weight changes land)
  - Invariant: Category labels (Line 1), metric values (Line 2), and network rates (Lines 1 and 2) must render in regular weight. No text in the status item can display heavier stroke weight than standard macOS menu bar text items or the system clock.

- **VAC-11 (Total Status Item Pinned Length - Retained)**:
  - Selector: `StatusItemController.statusItem.length`
  - Target Environment: macOS Menu Bar (768 px reference width, 375 px, 1440 px, and Retina check-only)
  - Invariant: Menu bar item length must remain pinned to `MenuBarLayout.length`. The length is 114 pt for three metrics (CPU, MEM, GPU) and 168 pt with Network enabled. The length is 76 pt for two metrics and 38 pt for one metric. Changing values or label text must never resize the status item.

---

## Appendix A: Developer Implementation Instructions

1. Open `StatsLite/MenuBarStackedItemView.swift`.
   - Update comment citations at lines 137–138 from `(VAC-N1)` and `(VAC-9)` to `(VAC-7)` and `(VAC-8)` to match this blueprint.
2. Locate line 112 in `MenuBarBlockView`:
   ```swift
   Text(block.label)
       .font(.system(size: 8, weight: .bold))
   ```
3. Replace `weight: .bold` with `weight: .regular`:
   ```swift
   Text(block.label)
       .font(.system(size: 8, weight: .regular))
   ```
4. Locate line 153 in `MenuBarNetworkBlockView` (upload rate text font modifier):
   ```swift
   Text(block.valueText)
       .font(.system(size: 9, weight: .medium).monospacedDigit())
   ```
5. Replace `weight: .medium` with `weight: .regular`:
   ```swift
   Text(block.valueText)
       .font(.system(size: 9, weight: .regular).monospacedDigit())
   ```
6. Locate line 167 in `MenuBarNetworkBlockView` (download rate text font modifier):
   ```swift
   Text(block.secondaryValueText ?? "-- KB/s")
       .font(.system(size: 9, weight: .medium).monospacedDigit())
   ```
7. Replace `weight: .medium` with `weight: .regular`:
   ```swift
   Text(block.secondaryValueText ?? "-- KB/s")
       .font(.system(size: 9, weight: .regular).monospacedDigit())
   ```
8. Update unit test `StatsLiteTests/MenuBarValueTypographyTests.swift`:
   - Change `expectedLabelFont` to `".font(.system(size:8,weight:.regular))"`.
   - Change `expectedNetworkFont` to `".font(.system(size:9,weight:.regular).monospacedDigit())"`.
   - Update test method `testLabelFontStaysBoldSecondary` to `testLabelFontIsEightPointRegularSecondary`.
   - Update test method `testNetworkFontsStayMediumAndValueStaysSizeTenAndAHalf` to verify that upload and download lines use `weight: .regular`.
   - Add a clearance test for `"999 MB/s"`: `50.0 - 6.0 - textWidth >= 1.0 pt`.
   - Add a clearance test for `MEM`: `34.0 - (4.0 + 2.0 + memWidth) >= 3.5 pt`.
9. Make sure that no `.animation` or `.contentTransition` modifiers exist in `StatsLite/MenuBarStackedItemView.swift`.
10. Run the test suite:
    ```bash
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Debug -derivedDataPath .derivedData test -destination 'platform=macOS'
    ```

---

## Refactors

None. The band-aid scan at authoring found no `TODO`/`FIXME`/`HACK` in the touched files.
The change is two font tokens on three lines; no helper masks it and no test suppresses it.

## Notation

```text
Plan -> Phase (`## Phase N — <name>`) -> Task (`T1` … unique; `FM*` = failure modes)
     -> Receipts (waiver note / red SHA / green SHA / VAC ledger / review verdict / merge SHA — verify each in git or on disk, record it on the task line)
```

Git receipt commands run with cwd = the worktree when they carry no `-C`; a
`git -C worktrees/…` path is relative to the repo root, so run those from the main repo.

- [x] **T1** — waiver note, no code edit. DONE: probe exit 1, note at artifacts/2026-10-16-menu-bar-label-network-regular/waiver-note.md (`8b0ce41`).
- [x] **T2** — red: flip IC-4 / IC-10 guards, add IC-11 / IC-12 guards (marker `[red]`). red PASS (`98cc6fb`, 225/2) · review GO
- [x] **T3** — green: three tokens on three lines. red n/a · green PASS (`8a82730`, 225/0) · review GO
- [x] **T4** — VAC ledger, tests only; pass/waived rows. DONE: 12 pass / 2 waived (`bc861a4`).
- [x] **T5** — reviewer `[code-review]`, rebase, ff-only merge, cleanup. review GO · merge ff to `main` = `bc861a4`

## Phase 1 — Waiver record (before the first code edit)

Worktree: `<repo>/worktrees/menu-bar-label-network-regular`, branch
`feat/2026-10-16-menu-bar-label-network-regular`. Create the worktree before the T2 spawn;
set the spawn `cwd` to it.

- [x] **T1** — planner, main repo, no code edit. Probe the waiver basis:
  `screencapture -x /tmp/waiver_probe_label_network.png`; record the exit status.
  Then write `artifacts/2026-10-16-menu-bar-label-network-regular/waiver-note.md` with:
  the carried-over user waiver (plan `2026-10-16-menu-bar-regular-weight`), its reason
  (no macOS Screen Recording permission), the probe exit status, and the scope (all
  screenshot and strip captures SKIPPED; test-based ICs binding; visual ICs waived).
  If the probe exits 0, stop: the waiver basis is falsified — report to the user before
  any spawn. No baseline captures run: the change targets status item tokens and every
  visual check is waived. Commit the note on `main` (`docs(waiver): …`; MD file, exempt
  from the worktree rule).
- Receipts: `waiver-note.md` on disk with the probe exit status, commit confirmed with
  `git log --oneline -1`.

## Phase 2 — Red (test only, worktree)

Create the worktree from fresh `main` before the spawn (idempotent `-B`):

```bash
MAIN_REPO="$(git -C /Users/jonathan/beliantech/stats-lite-macos rev-parse --show-toplevel)"
git -C "${MAIN_REPO}" worktree list    # pre-check for name collisions
git -C "${MAIN_REPO}" worktree add -B feat/2026-10-16-menu-bar-label-network-regular \
  "${MAIN_REPO}/worktrees/menu-bar-label-network-regular" main
```

- [x] **T2** — `T2: [red]` Rewrite the guards in
  `StatsLiteTests/MenuBarValueTypographyTests.swift` first, then run the suite. Test-only
  diff: touch no application code.
  1. Update the file header comment to plan `2026-10-16-menu-bar-label-network-regular`;
     state that the red run fails on both production tokens (label `.bold`, network `.medium`).
  2. Flip `expectedLabelFont` (`:27`) to `".font(.system(size:8,weight:.regular))"`.
  3. Flip `expectedNetworkFont` (`:31`) to
     `".font(.system(size:9,weight:.regular).monospacedDigit())"`.
  4. Rename `testLabelFontStaysBoldSecondary` (`:184`) to
     `testLabelFontIsEightPointRegularSecondary`; assertion text: labels are 8 pt
     `.regular` with `.secondary`, no `.bold` (IC-4 flip, Blueprint Appendix A step 8).
  5. Rename `testNetworkFontsStayMediumAndValueStaysSizeTenAndAHalf` (`:218`) to
     `testNetworkFontsAreNinePointRegularAndValueStaysSizeTenAndAHalf`; it asserts the
     upload token at `:153` and the download token at `:167` against the flipped
     `expectedNetworkFont` and keeps the value-line `size:10.5` assertion (IC-10 flip).
  6. Add `testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints` (IC-11): `NSFont`
     measurement on the pattern of the existing IC-3 test
     (`testClearanceForWidestValueAtRegularMeetsThreeAndAHalfPoints`,
     `MenuBarValueTypographyTests.swift:268`) — MEM row `4.0 + 2.0 + width("MEM" @ 8 pt
     regular)` → clearance ≥ 3.5 pt (expect 8.6406 ± 0.05); CPU clearance ≥ 16.0
     (expect 16.6836 ± 0.05); GPU clearance ≥ 16.0 (expect 16.4375 ± 0.05);
     `MenuBarLayout.blockWidth` = 34.0.
  7. Add `testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum` (IC-12):
     `NSFont` measurement — `width("999 MB/s" @ 9 pt regular mono)` = 42.1084 ± 0.05;
     `MenuBarLayout.networkBlockWidth` = 50.0; `50.0 − 6.0 − width ≥ 1.8` pt
     (expect 1.8916 ± 0.05).
  8. Mechanism stays the existing source-token check anchored on the view source through
     `#filePath`; it compares the literal token the compiler builds, so the flipped guards
     cannot pass while `:112` / `:153` / `:167` carry `.bold` / `.medium`.
  9. Run:
     `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Debug -derivedDataPath .derivedData test -destination 'platform=macOS' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`
  - Red expectation: **225 tests, exactly 2 failures** —
    `testLabelFontIsEightPointRegularSecondary` (label token `.bold` ≠ `.regular`) and
    `testNetworkFontsAreNinePointRegularAndValueStaysSizeTenAndAHalf` (upload and download
    `.medium` ≠ `.regular`). All other tests pass, including both new clearance guards:
    they measure the target font, so they pass at HEAD as regression guards. If a flipped
    guard passes at HEAD, fix the red phase; do not start green.
- Receipts: red SHA; `git -C worktrees/menu-bar-label-network-regular diff main...HEAD --stat`
  shows only `StatsLiteTests/`; failing-test output with BOTH token failures visible.

## Phase 3 — Green (implementation, same worktree)

- [x] **T3** — Apply Blueprint Appendix A steps 3, 5, 7 in one commit:
  `StatsLite/MenuBarStackedItemView.swift:112` `weight: .bold` → `weight: .regular`;
  `:153` and `:167` `weight: .medium` → `weight: .regular`. Nothing else in production
  code: `:116` untouched, no comment edits (the `:137-138` VAC citation refresh is a
  recorded deferral — Risks), no tint/width/length changes, and no `.animation` or
  `.contentTransition` modifiers. Do not weaken or delete the red tests. Then run the full
  suite with the T2 command; all tests green (IC-9).
- Receipts: green SHA; suite output `225 tests, 0 failures`;
  `git diff main...HEAD -- StatsLite/` limited to the three token lines;
  `git diff main...HEAD --stat` = the T2 test file + `MenuBarStackedItemView.swift`.

## Phase 4 — VAC ledger (tests only)

- [x] **T4** — coder self-verify, same worktree, tests only (no captures); the pass evidence
  is the T3 green run under the T2 xcodebuild command. Write
  `artifacts/2026-10-16-menu-bar-label-network-regular/vac-ledger.md` with one row per IC:
  IC-1 … IC-6 and IC-8 … IC-13 read `pass` with evidence (green test name, `rg` output
  for IC-5, recorded measurements for IC-3 / IC-11 / IC-12: 29.93/4.07, 25.36/8.64,
  42.11/1.89). IC-7 reads `waived (user authority, 2026-10-16, no Screen Recording
  permission)`. Add one `waived` row for screenshot and strip captures with the same
  reason. Every test-based row must read `pass`. Commit on the branch
  (`docs(menubar): record label and network typography VAC ledger`).
- Receipts: `vac-ledger.md` on disk with pass/waived rows, committed on the branch.

## Phase 5 — Review, merge, cleanup

- [x] **T5** — Spawn `reviewer` with `[code-review]`, plan name
  `2026-10-16-menu-bar-label-network-regular`, `cwd` = the worktree, against
  `git -C worktrees/menu-bar-label-network-regular diff main...HEAD`. Checks: the red
  commit is test-only and fails on BOTH production tokens (label `.bold`, network
  `.medium`); the IC-4 / IC-10 guard rewrites and the two new clearance guards match
  Blueprint Appendix A step 8; the green commit changes exactly the three weight tokens
  (`:112`, `:153`, `:167`) and nothing else (`:116` untouched, no comment edits); the
  ledger has complete pass/waived rows; the zero-animation rule is intact; the green
  suite count is red count with 0 failures. Max two NO GO cycles, then escalate.
  On GO: main advances in parallel, so rebase first —
  `git -C worktrees/menu-bar-label-network-regular rebase main` (if the rebase touches
  `StatsLite/` files, re-run the T2 suite command after the rebase) — then from `main`
  in the main repo run `git merge --ff-only feat/2026-10-16-menu-bar-label-network-regular`
  (or `--squash` with its own conventional commit). Then remove the worktree and branch,
  then mark every task `[x]` with receipts and report the merge SHA.
- Receipts: review verdict; rebase note; merge SHA confirmed by `git log --oneline -1`
  on `main`; worktree removed (`git worktree prune`, `git branch -d …`, orphaned-dir
  sweep per the `git-worktree` skill).

## Verification and spawn matrix

| Task | Agent | cwd | Timeout | Marker |
| --- | --- | --- | --- | --- |
| T1 | planner (bash) | main repo | — | — |
| T2 | `coder` | worktree | 1800 s | `[red]`, plan `2026-10-16-menu-bar-label-network-regular` |
| T3 | `coder` | same worktree | 1800 s | plan `2026-10-16-menu-bar-label-network-regular` |
| T4 | `coder` self-verify | same worktree | 1800 s | plan `2026-10-16-menu-bar-label-network-regular` |
| T5 | `reviewer` | worktree | 600 s | `[code-review]`, plan `2026-10-16-menu-bar-label-network-regular` |

Sequencing: T1 → T2 → T3 → T4 → T5 strictly sequential; red and green never parallel.
No simulator concurrency: the xcodebuild serial flags in T2/T3 are mandatory
(`-parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`).

## Docs

- `ARCHITECTURE.md` / `DESIGN.md`: absent at this project root; nothing to update.
- `AGENTS.md`: the zero-animation rule and evidence rules already cover this change;
  no edit needed.
- Result: **No doc updates needed.**

## Risks and open items

- **Parallel main**: main advances during execution (as last time). T5 rebases before the
  ff-only merge; if the rebase moves `StatsLite/` files, re-run the suite before merging.
- **Pre-existing open worktree** `worktrees/2026-10-15-stats-lite-view-weight` (branch
  `feat/2026-10-15-stats-lite-view-weight`) belongs to plan
  `2026-10-15-stats-lite-view-weight`, not this plan; leave it untouched.
- **Comment citations deferred**: Blueprint Appendix A step 1 (gate note N2) asks to update
  the stale `(VAC-N1)` / `(VAC-9)` citations at `:137-138` to `(VAC-7)` / `(VAC-8)`. This
  plan's scope (PM ruling) covers the three weight tokens only, so the comment edit is a
  recorded deferral: comment-only, no test or gate impact, rides the next typography pass.
- **IC-12 margin**: expected clearance 1.8916 pt against the 1.8 pt threshold — a 0.09 pt
  margin. The gate measured `width("999 MB/s")` = 42.1084 twice with identical results. A
  future change that widens the string past 1.8916 pt fails the guard; that failure is
  correct behavior, not noise.
- **Test-count drift**: red expects 225 tests (223 baseline + 2 new). If main lands tests
  before T2, recompute: red = current baseline + 2, with exactly 2 failures.
- **Threshold wording in the blueprint**: VAC-7 states ≥ 1.8 pt, Appendix A step 8 states
  ≥ 1.0 pt for the same spacer. IC-12 asserts 1.8 pt — the stricter rule, which subsumes
  the 1.0 pt spacer minimum.
- **Human-judgment visual checks (VAC-10 blend = IC-7)** are waived, not approximated: the
  ledger records `waived`, never `pass`, for them. The numeric clearance checks (VAC-5 /
  VAC-7 = IC-11 / IC-12) stay binding.
