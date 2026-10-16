# Plan: Menu Bar Status Item Typography — Value Font `.medium` → `.regular`

Date: 2026-10-16
Plan name: `2026-10-16-menu-bar-regular-weight`
Risk class: **R2** (UI work — zero-tolerance visual policy applies; visual defects are blocking).
Status: Design gate **PASS** (`artifacts/01a143cf-718b-7279-886c-fadd0072d585/design-gate-report-menu-bar-font-2026-10-16.md`, re-gate on 2026-10-16). Clarity adjustment pass applied 2026-10-16 after `run_plan` (wording and procedure only — ISC checks, Design Blueprint, scope, and tasks unchanged). Awaiting `[plan-review]`.
**Scope change 2026-10-16 (user authority):** all menu bar strip / screenshot captures
waived — this session has no Screen Recording permission; user waived visual capture and
ordered proceed to merge + app launch. Test-based ISC checks remain binding.
Repo HEAD at authoring: `c25d66d`, clean (untracked `worktrees/` only); main now `108494f`
(logo SVG assets only, unrelated).
Worktree: `worktrees/menu-bar-regular-weight`, branch `feat/2026-10-16-menu-bar-regular-weight` (non-base).

## Intent

Current state: the CPU/MEM/GPU value text in the status item renders with
`Font.system(size: 10.5, weight: .medium).monospacedDigit()`
(`StatsLite/MenuBarStackedItemView.swift:116`). At 10.5 pt on Retina displays the
`.medium` stroke is visibly heavier than adjacent menu bar text such as the system clock.

Target state: the same value text renders with `weight: .regular` at size 10.5 and keeps
`.monospacedDigit()`. Every other token stays unchanged: labels 8 pt bold `.secondary`,
network rate values 9 pt `.medium`, block width 34.0 pt, pinned item lengths, state tints,
zero animation. Values must not look bold next to system menu bar text.

## Evidence

- Design gate re-gate **PASS**: VAC-1 … VAC-8 all PASS at HEAD `c25d66d`; corrections C1–C4 and advisory C5 applied; no blocking defect. Advisory A1 (Normal-row display range wording) has no gate impact and needs no plan action.
- Gate re-measurement (with `NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight:)`, cited in the gate report — measurements, not priors): `"100%"` at `.medium` = 30.83 pt → 3.17 pt total clearance (fails the 3.5 pt rule); at `.regular` = 29.93 pt → 4.07 pt total (passes).
- Gate test run at this HEAD: full suite 198/198 (first gate); `MenuBarRedrawChurnTests` + `MenuBarLayoutTests` 17/17 (re-gate).
- Band-aid scan at authoring: `rg 'TODO|FIXME|HACK'` over `MenuBarStackedItemView.swift`, `MenuBarBlockModel.swift`, `StatusItemController.swift` — no hits. No refactor debt in scope.

## ISC — binary checks (every item is yes/no)

> **Waiver (user authority, 2026-10-16):** menu bar strip captures and all screenshot-based
> visual checks are SKIPPED. Reason: this session has no macOS Screen Recording permission
> (`screencapture` rect/window capture of other processes fails with exit 1; TCC grants only
> `com.apple.Terminal` / `com.apple.screensharing.agent`). The user authorized the waiver.
> Visual ICs (render checks, IC-7 clock comparison) are marked *waived*; test-based ICs
> (typography token, monospaced digits, clearance, scope, zero animation, suite green) remain
> binding and must pass.

Citation rule: a bare `:N` in the ISC and tasks means `StatsLite/MenuBarStackedItemView.swift:N`
unless another file is named beside it.

Width applicability (gate report, section `Width applicability (768 reference)`): the status
item renders in `NSStatusBar`, not in a viewport. **Render checks run at 1440 px + Retina**,
dark and light — that is where render evidence exists. **768 px and 375 px are check-only**:
no render environment exists there, so verify from code that the pinned lengths hold and that
no layout rule reads the screen width. The width rules are identical at 375, 768, and 1440.
Each IC states its own case in a trailing `Widths:` line.

- [ ] **IC-1 (VAC-1, value font weight)** — the value `Text` font descriptor is `Font.system(size: 10.5, weight: .regular).monospacedDigit()` (`MenuBarStackedItemView.swift:115-116`). No `.medium` or `.bold` on CPU/MEM/GPU values. An automated test exists that fails at HEAD and passes after the change. Widths: 1440 render; 768/375 check-only.
- [ ] **IC-2 (VAC-2, monospaced digits)** — `.monospacedDigit()` retained at `:116`; no horizontal block shift or jitter when values change digit count (frame pin at `:120`, `lineLimit(1)` at `:118`). Widths: 1440 render; 768/375 check-only.
- [ ] **IC-3 (VAC-3, block width and clearance)** — block width stays 34.0 pt (`MenuBarLayout.blockWidth`); `"100%"` renders complete on one line with no truncation ellipsis; total horizontal clearance = 34.0 pt − measured text width ≥ 3.5 pt. Gate re-measurement at HEAD with the target font (measurement): `.regular` → 29.93 pt text width, 4.07 pt total clearance (2.03 pt per side); re-verify the same numbers after the change. VAC-3 passes only after the IC-1 change lands. Widths: 1440 render at dark and light; 768/375 check-only.
- [ ] **IC-4 (VAC-4, category labels)** — `CPU`/`MEM`/`GPU` labels stay `.system(size: 8, weight: .bold)` with `.foregroundStyle(.secondary)` (`:111-113`). Widths: 1440 render; 768/375 check-only.
- [ ] **IC-5 (VAC-5, zero animation)** — `rg -n '\.animation|\.contentTransition' StatsLite/MenuBarStackedItemView.swift StatsLite/MenuBarBlockModel.swift StatsLite/StatusItemController.swift StatsLite/MenuBarAccessibility.swift` finds hits in comments only (`MenuBarStackedItemView.swift:14`, `:15`, `:138` are the only allowed lines) and never as a modifier; `MenuBarRedrawChurnTests` passes. Widths: all runtimes, all widths.
- [ ] **IC-6 (VAC-6, state colors)** — CPU/GPU tint follows the raw fraction: `≥0.95` red, `≥0.80` orange, else `.primary`, nil → tertiary (`MenuBarBlockModel.swift:172-176`, valueColor map `:125-128`). MEM value renders `.primary` at every pressure state; the 4 pt dot carries `MemoryPressureState.levelColor` (`MenuBarBlockModel.swift:130`, `DesignTokens.swift:16-23`, commit `d985784`). Thresholds act on the raw fraction: 0.946 displays `"95%"` with orange tint (`MetricFormatters.swift:15-19`). Widths: 1440 dark + light render; 768/375 check-only.
- [ ] **IC-7 (VAC-7, visual blend)** — in the same dark and light captures, the value text stroke weight matches standard menu bar text (system clock digits); values must not stand out as bold. Visual check against screenshot evidence. Widths: 1440 dark + light render; 768/375 check-only.
- [ ] **IC-8 (VAC-8, pinned length)** — `statusItem.length` stays 114 pt (3 metrics), 168 pt (with network), 76 pt (2 metrics), 38 pt (1 metric); value changes never resize the item; `MenuBarLayoutTests` passes. Widths: 1440 render; 768/375 check-only.
- [ ] **IC-9 (suite)** — full test suite green at the green commit; no existing test weakened or deleted. Baseline at HEAD: 198/198.
- [ ] **IC-10 (scope)** — only the value-font token changes plus new test files; network rate values stay 9 pt `.medium` (`:153`, `:167`); no other font, layout, or tint token changes.

Plan-scoped failure modes:

- **FM1** — value weight is not `.regular` (or a later edit reverts it) → IC-1 fails. Red test must fail at HEAD for this mode.
- **FM2** — `"100%"` clips, ellipsizes, or shifts the block → IC-2/IC-3 fail.
- **FM3** — the edit touches a token outside the value font (network weight, label, tint, width, length) → IC-4/IC-6/IC-8/IC-10 fail.
- **FM4** — `.animation` / `.contentTransition` re-enters the status item path → IC-5 fails.

## Approach

1. One-token implementation: change `weight: .medium` to `weight: .regular` at
   `StatsLite/MenuBarStackedItemView.swift:116`. Size 10.5 and `.monospacedDigit()` stay.
   No other production line changes (IC-10).
2. TDD: red spawn authors the failing FM1 test (plus non-vacuous guards for IC-2, IC-4,
   IC-10), green spawn applies the token change. Red and green are two sequential coder
   spawns in one worktree.
3. Baseline capture before the first code edit (T1): dark and light popover captures plus
   dark and light menu bar strip captures, run before the red spawn creates any file.
   Artifact dir: `artifacts/2026-10-16-menu-bar-regular-weight/`.
4. Verification: automated checks for IC-1 … IC-6, IC-8 … IC-10; screenshot ledger for
   IC-7 (and visual confirmation of IC-1 … IC-4, IC-6) in dark and light at 1440 px with
   the system clock in frame.
5. Merge after reviewer GO: `git merge --ff-only` or `git merge --squash` with the literal
   branch name; then remove the worktree.

### Design Blueprint (verbatim)

The corrected Design Blueprint from designer session `567a8acf` follows. It is the
authority for every visual requirement in this plan; the ISC mirrors its VAC list.

# Design Blueprint: Menu Bar Status Item Typography (Corrected)

This design blueprint specifies the typography update for the macOS menu bar status item in `StatsLite`. It changes the metric value font weight from `.medium` to `.regular`. This adjustment removes visual heaviness and allows the status item values to blend naturally with adjacent macOS menu bar controls.

---

## Visual Evidence Pass Summary

The live menu bar status item was inspected across appearance modes via screen captures:
- Live menu bar state: `/tmp/designer_menubar.png`
- Dark mode menu bar: `/tmp/designer_menubar_dark.png`
- Light mode menu bar: `/tmp/designer_menubar_light.png`

### Visual Analysis Findings
1. The system clock (`Fri 16 Oct 4:27 PM`) and standard menu bar items render in regular weight system typography.
2. The current metric value text in `StatsLite` (`12%`, `17%`, `0%`) uses `size: 10.5, weight: .medium`. At this scale on Retina displays, `.medium` produces noticeable stroke density that visually overpowers adjacent system items.
3. Category labels (`CPU`, `MEM`, `GPU`) render at 8 pt bold in `.secondary` opacity. This secondary opacity balances the uppercase micro-label.
4. Setting the value text font weight to `.regular` reduces the optical stroke width to match standard macOS menu bar text.
5. In regular weight at 10.5 pt, the widest metric string (`100%`) measures 29.93 pt. This leaves 4.07 pt of clearance inside the 34 pt pinned block width (`MenuBarLayout.blockWidth`).

---

## Design System Tokens & Reference Rules

- Project `DESIGN.md`: File does not exist at project root. Design tokens and layout metrics derive directly from `StatsLite/MenuBarBlockModel.swift`, `StatsLite/DesignTokens.swift`, and `StatsLite/MenuBarStackedItemView.swift`.
- Architectural constraint: Status item views must not use `.animation` or `.contentTransition`. Transitions must stay discrete to prevent `RenderBox` glyph re-rasterization churn.
- Single source of truth for layout: `MenuBarLayout.blockWidth` (34 pt), `MenuBarLayout.gap` (4 pt), and `MenuBarLayout.padding` (2 pt).
- Scope decision: Network rate values stay at 9 pt `.medium` (`MenuBarStackedItemView.swift:153`, `:167`). The issue covers CPU, MEM, and GPU values in `MenuBarBlockView`. Dedicated upload and download sub-blocks in `MenuBarNetworkBlockView` remain unchanged as a deliberate scope decision.

---

## Part 1: Visual Hierarchy & ASCII Wireframe

### Menu Bar Status Item Layout Wireframe

```
+----------------------------------------------------------------------------------------------------------------+
| macOS System Menu Bar (Height: ~30 pt)                                                                          |
| ... [App Menus]                                 [StatsLite Item]        [System Icons]       [System Clock]    |
+----------------------------------------------------------------------------------------------------------------+

StatsLite Status Item Detail:
|<------------------------------------------ Total Item Width: 114 pt (3 metrics) ------------------------------>|
|  pad: 2pt                                                                                             pad: 2pt  |
|  +--+   +-------------------+   +--+   +-------------------+   +--+   +-------------------+   +--+             |
|  |  |   | CPU Block (34 pt) |   |  |   | MEM Block (34 pt) |   |  |   | GPU Block (34 pt) |   |  |             |
|  |  |   |                   |   |  |   |                   |   |  |   |                   |   |  |             |
|  |  |   | Line 1:  "CPU"    |   |  |   | Line 1:  o "MEM"  |   |  |   | Line 1:  "GPU"    |   |  |             |
|  |  |   | (8pt Bold, .sec)  |   |g |   | (4pt dot + 8pt B) |   |g |   | (8pt Bold, .sec)  |   |  |             |
|  |  |   |                   |   |a |   |                   |   |a |   |                   |   |  |             |
|  |  |   | Line 2:  "22%"    |   |p |   | Line 2:  "17%"    |   |p |   | Line 2:  "15%"    |   |  |             |
|  |  |   | (10.5pt Regular,  |   |4 |   | (10.5pt Regular,  |   |4 |   | (10.5pt Regular,  |   |  |             |
|  |  |   |  monospacedDigit) |   |pt|   |  monospacedDigit) |   |pt|   |  monospacedDigit) |   |  |             |
|  +--+   +-------------------+   +--+   +-------------------+   +--+   +-------------------+   +--+             |
+----------------------------------------------------------------------------------------------------------------+

With Optional Network Block Appended:
|<------------------------------------------ Total Item Width: 168 pt (4 metrics) ----------------------------------------------------->|
| ... | gap 4 pt | +--------------------------------------------------+ | pad: 2pt |
|     |          | NET Block (50 pt)                                  | |          |
|     |          | Line 1: [Red Dot 6pt]   [Spacer]    "368 KB/s"     | |          |
|     |          | Line 2: [Blue Dot 6pt]  [Spacer]     "14 KB/s"     | |          |
|     |          | (9pt Medium, monospacedDigit)                      | |          |
|     |          +----------------------------------------------------+ |          |
+---------------------------------------------------------------------------------------------------------------------------------------+
```

### Element Relationships and Alignments
- Vertical alignment: Each metric block stacks vertically via `VStack(alignment: .center, spacing: 1)`.
- Line 1 (Labels): Center-aligned horizontally. For `MEM`, a 4 pt circular dot sits 2 pt leading of `MEM`. It has a `-0.5 pt` vertical offset to maintain baseline alignment with capital letters.
- Line 2 (Values): Center-aligned horizontally directly beneath the label. Pinned block width prevents horizontal jitter.
- Spacing: 1 pt vertical spacing between label and value line. 4 pt horizontal gap between metric blocks.

---

## Part 2: Template / Component Skeleton

The update targets `StatsLite/MenuBarStackedItemView.swift` at line 116.

### Existing Implementation (`StatsLite/MenuBarStackedItemView.swift:99-121`)

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
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            Text(block.valueText)
                .font(.system(size: 10.5, weight: .medium).monospacedDigit()) // <-- CURRENT: .medium (line 116)
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .frame(width: block.width)
    }
...
```

### Target Implementation (`StatsLite/MenuBarStackedItemView.swift:99-121`)

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
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            Text(block.valueText)
                .font(.system(size: 10.5, weight: .regular).monospacedDigit()) // <-- TARGET: .regular (line 116)
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .frame(width: block.width)
    }
```

### Exact Code Tokens
- Label font: `.system(size: 8, weight: .bold)`
- Value font: `.system(size: 10.5, weight: .regular).monospacedDigit()`
- Block frame width: `block.width` (evaluates to `MenuBarLayout.blockWidth` = `34.0`)
- Block stack spacing: `1.0` pt
- Animation modifiers: None (`.animation` and `.contentTransition` remain prohibited)

---

## Part 3: Complete State & Responsive Matrix

### Typography and Value Tint Matrix

| Metric State | Value Text | Font Token | Foreground Style Token | Optical Appearance |
|---|---|---|---|---|
| CPU / GPU Normal (< 0.80 raw fraction) | `"0%"` ... `"79%"` | `10.5 pt regular monospacedDigit` | `.primary` | Clean regular system font, adapts to appearance mode |
| CPU / GPU Warning (0.80 <= raw < 0.95) | `"80%"` ... `"95%"` (rounded from < 0.95) | `10.5 pt regular monospacedDigit` | `Color(nsColor: .systemOrange)` | High-visibility orange at regular weight |
| CPU / GPU Critical (raw >= 0.95) | `"95%"` ... `"100%"` | `10.5 pt regular monospacedDigit` | `Color(nsColor: .systemRed)` | High-visibility red at regular weight |
| MEM (All pressure states: normal, warning, critical) | `"0%"` ... `"100%"` | `10.5 pt regular monospacedDigit` | `.primary` | Text remains `.primary` at all pressure levels (`MenuBarBlockModel.swift:130`, commit `d985784`). Dot carries state color (`DesignTokens.swift:16-23`). |
| Unavailable / Missing (raw fraction nil) | `"--%"` | `10.5 pt regular monospacedDigit` | `Color(nsColor: .tertiaryLabelColor)` | Subdued placeholder gray |
| Active Popover / Highlight | Any active value | `10.5 pt regular monospacedDigit` | Inherited button highlight vibrant text | White vibrant contrast over blue selection background |

### Text Width and Frame Containment Verification

The values below show computed text widths with `NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)`:
- `"100%"`: 29.93 pt width. Frame clearance: 4.07 pt inside 34.0 pt block.
- `"99%"`: 23.22 pt width. Frame clearance: 10.78 pt inside 34.0 pt block.
- `"0%"`: 16.51 pt width. Frame clearance: 17.49 pt inside 34.0 pt block.
- `"--%"`: 19.90 pt width. Frame clearance: 14.10 pt inside 34.0 pt block.

### Viewport and Mode Applicability

The macOS status item is a native desktop control hosted in `NSStatusBar`. It does not render in web viewports (375 px mobile or 768 px tablet do not host macOS AppKit status items). The table below states the applicable display modes and desktop widths:

| Viewport / Environment | Applicability | Invariant Behavior |
|---|---|---|
| Mobile (375 px) | Not applicable | Native macOS status items do not run on mobile viewports. |
| Tablet (768 px) | Not applicable | Native macOS status items do not run on tablet viewports. |
| Desktop (1440 px standard) | Applicable | Status item sits in top menu bar. Font renders at 10.5 pt regular weight. |
| Desktop (Retina 2x display) | Applicable | Font renders sharp regular stroke without medium weight density. |
| Dark Mode Appearance | Applicable | Text foreground resolves to vibrant white/primary against dark translucent menu bar. |
| Light Mode Appearance | Applicable | Text foreground resolves to vibrant dark/primary against light translucent menu bar. |
| Metric Permutations | Applicable | Total width pins to 114 pt (3 metrics), 168 pt (4 metrics), 76 pt (2 metrics), 38 pt (1 metric). |

---

## Part 4: Accessibility (WCAG 2.2) & Interaction Contracts

### WCAG 2.2 Success Criteria Compliance
- Criterion 1.4.3 Contrast (Minimum - Level AA >= 4.5:1) & 1.4.6 Contrast (Enhanced - Level AAA >= 7:1):
  - In Dark Mode, `.primary` menu bar text renders at `#FFFFFF` against menu bar surface with contrast ratio > 10:1 (unverified prior, passes AAA).
  - In Light Mode, `.primary` menu bar text renders at `#000000` (or near-black vibrant) with contrast ratio > 12:1 (unverified prior, passes AAA).
  - Warning tint (`systemOrange`) and Critical tint (`systemRed`) provide distinct color coding backed by VoiceOver text announcements.
- Criterion 2.5.8 Target Size (Minimum - Level AA >= 24x24 px):
  - The status item button provides a hit target matching `NSStatusBar.system.thickness` (24 pt to 30 pt height, unverified prior) by the pinned length (minimum 38 pt width for one metric, 114 pt for three metrics).

### Screen Reader and VoiceOver Accessibility Contract
- `MenuBarStackedItemView` sets `.accessibilityHidden(true)`. The SwiftUI hosting view lets clicks pass through to `NSStatusBarButton`.
- `StatusItemController.updateAccessibility()` configures the parent `NSStatusBarButton` directly:
  - `setAccessibilityElement(true)`
  - `setAccessibilityTitle("StatsLite")`
  - `setAccessibilityLabel(compositeLabel)`
- Dynamic label format: `"StatsLite: CPU <percent> percent, Memory Pressure <state> at <percent> percent, GPU <percent> percent"`.
- Typography weight changes do not modify the VoiceOver label output or accessibility tree hierarchy.

### Interaction and Transition Contracts
- Clicks on the status item open or close the transient `NSPopover`.
- While the popover is open, `button.isHighlighted` remains `true`.
- Zero animation rule: No `.animation()` or `.contentTransition()` modifiers exist anywhere in `MenuBarBlockView` or `MenuBarStackedItemView`. Digit updates transition discretely between sampling intervals.

---

## Part 5: Numbered Visual Acceptance Checklist (VAC)

- **VAC-1 (Value Font Weight)**:
  - Selector: `MenuBarBlockView` value `Text` view (`StatsLite/MenuBarStackedItemView.swift:115-116`)
  - Target Environment: macOS Menu Bar (Desktop 1440 px and Retina displays)
  - Invariant: Value text font weight must be `.regular`. The font descriptor must match `Font.system(size: 10.5, weight: .regular).monospacedDigit()`. Do not apply `.medium` or `.bold` weight to CPU, MEM, or GPU metric values.

- **VAC-2 (Value Digit Alignment)**:
  - Selector: `MenuBarBlockView` value `Text` view
  - Target Environment: macOS Menu Bar (Desktop 1440 px and Retina displays)
  - Invariant: Metric digits must render using monospaced digits (`.monospacedDigit()`). Digits must not cause horizontal block shift or jitter when values change between single, double, or triple digits.

- **VAC-3 (Block Width and Text Clearance)**:
  - Selector: `MenuBarBlockView` container frame (`StatsLite/MenuBarStackedItemView.swift:120`)
  - Target Environment: macOS Menu Bar (Desktop 1440 px, Dark and Light modes)
  - Invariant: Width must remain pinned to 34.0 pt (`MenuBarLayout.blockWidth`). The widest value string (`"100%"`) must render completely on a single line with zero truncation ellipsis. It must leave at least 3.5 pt of total horizontal clearance, measured as 34.0 pt block width minus the measured text width. At `.medium` the string "100%" measures 30.83 pt and leaves 3.17 pt total clearance. VAC-3 passes only after the VAC-1 weight change lands. At `.regular` it measures 29.93 pt and leaves 4.07 pt total clearance (2.03 pt per side).

- **VAC-4 (Category Label Typography)**:
  - Selector: `MenuBarBlockView` category label `Text` view (`StatsLite/MenuBarStackedItemView.swift:111-113`)
  - Target Environment: macOS Menu Bar (Desktop 1440 px)
  - Invariant: Category labels (`CPU`, `MEM`, `GPU`) must remain 8 pt bold (`.system(size: 8, weight: .bold)`) with `.secondary` foreground style.

- **VAC-5 (Discrete Rendering / Zero Animation)**:
  - Selector: `MenuBarStackedItemView`, `MenuBarBlockView`
  - Target Environment: All macOS runtimes
  - Invariant: The view body tree must contain zero `.animation` or `.contentTransition` modifiers. `MenuBarRedrawChurnTests` must pass without failures.

- **VAC-6 (State Color Preservation)**:
  - Selector: `MenuBarBlockView` value `foregroundStyle` (`StatsLite/MenuBarStackedItemView.swift:117`, `123-130`)
  - Target Environment: macOS Menu Bar (Dark Mode and Light Mode)
  - Invariant:
    1. CPU and GPU usage values: tint follows the raw metric fraction. `x >= 0.95` renders `Color(nsColor: .systemRed)`. `x >= 0.80` renders `Color(nsColor: .systemOrange)`. All lower values render `.primary`. A nil metric fraction renders `Color(nsColor: .tertiaryLabelColor)`. Source: `StatsLite/MenuBarBlockModel.swift:172-176`.
    2. MEM value: renders `.primary` at every pressure state. The 4 pt dot carries the state color through `MemoryPressureState.levelColor` (green, yellow, red, gray at `StatsLite/DesignTokens.swift:16-23`). Only a nil pressure percent renders `Color(nsColor: .tertiaryLabelColor)` (`StatsLite/MenuBarBlockModel.swift:130`). Commit `d985784` preserves this behavior.
    3. The thresholds act on the raw fraction, not the displayed rounded string. A fraction of 0.946 displays `"95%"` with an orange tint, because `MetricFormatters.percent` rounds at display (`StatsLite/MetricFormatters.swift:15-19`) while `usageTint` splits at 0.95. The verification check input is the raw metric fraction.

- **VAC-7 (Visual Blend with Adjacent Menu Bar Items)**:
  - Selector: Menu bar status item
  - Target Environment: macOS Menu Bar (Desktop 1440 px, Dark Mode and Light Mode)
  - Invariant: Metric value text stroke thickness must visually match the stroke thickness of standard macOS menu bar text items (for example, the system clock digits). Metric values must not stand out as bold.

- **VAC-8 (Total Status Item Pinned Length)**:
  - Selector: `StatusItemController.statusItem.length`
  - Target Environment: macOS Menu Bar (Desktop 1440 px)
  - Invariant: Menu bar item length must remain pinned to `MenuBarLayout.length`. The length is 114 pt for three standard metrics (CPU, MEM, GPU), 168 pt when Network is enabled, 76 pt for two standard metrics, and 38 pt for one metric. Changing values must not resize the status item.

---

## Appendix A: Developer Implementation Instructions

1. Open `StatsLite/MenuBarStackedItemView.swift`.
2. Locate line 116 in `MenuBarBlockView`:
   ```swift
   Text(block.valueText)
       .font(.system(size: 10.5, weight: .medium).monospacedDigit())
   ```
3. Replace `.weight: .medium` with `.weight: .regular`:
   ```swift
   Text(block.valueText)
       .font(.system(size: 10.5, weight: .regular).monospacedDigit())
   ```
4. Do not add `.animation` or `.contentTransition`.
5. Run test suite: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Debug -derivedDataPath .derivedData test`. Verify that all tests pass.

---

## Accomplishment Summary

Applied corrections C1 through C4 (incorporating advisory C5) from the PM Design Gate Report:
- **C1 Applied**: Corrected all line citations for the value text font modifier to line 116 (selector in VAC-1, Part 2 section headers/text, Appendix A step 2).
- **C2 Applied**: Corrected category label selector citation in VAC-4 to `StatsLite/MenuBarStackedItemView.swift:111-113`.
- **C3 Applied**: Stated the clearance basis unambiguously in VAC-3 ("at least 3.5 pt of total horizontal clearance, measured as 34.0 pt block width minus the measured text width") and documented the ordering relationship (VAC-3 passes only after the VAC-1 weight change lands).
- **C4 Applied**: Split VAC-6 into rules for CPU/GPU usage values (raw metric fraction thresholds 0.95 and 0.80) and MEM value (`.primary` at every pressure state per `MenuBarBlockModel.swift:130` and commit `d985784`, with dot carrying state colors). Clarified the raw-fraction vs rounded-display threshold handling. Mirrored this distinction in the Part 3 State Matrix.
- **C5 Recorded**: Marked unverified contrast and target-size figures as `(unverified prior)` in Part 4. Recorded the intentional scope decision to keep network rate values at 9 pt `.medium`.
- Conformed all procedural and descriptive phrasing to Simplified Technical English rules.

---

## Refactors

None. The band-aid scan at authoring found no `TODO`/`FIXME`/`HACK` in the touched files.
The change is one font token; no helper masks it and no test suppresses it.

## Notation

```text
Plan -> Phase (`## Phase N — <name>`) -> Task (`T1` … unique; `FM*` = failure modes)
     -> Receipts (baseline / red SHA / green SHA / VAC ledger / review verdict — verify each in git or on disk, record it on the task line)
```

- [x] **T1** — baseline captures. DONE (popover dark+light captured; strip captures waived by user 2026-10-16).
- [x] **T2** — red typography test (marker `[red]`). red PASS (SHA `5e2a97c`, only FM1 fails) · green n/a · review ⏳
- [x] **T3** — green one-token change. red n/a · green PASS (SHA `b1e27cc`, 203/203) · review ⏳
- [x] **T4** — VAC ledger: test ICs pass, visual ICs waived (user authority). ledger DONE (`artifacts/2026-10-16-menu-bar-regular-weight/vac-ledger.md`).
- [ ] **T5** — reviewer code review, merge, worktree cleanup. review ⏳ · merge ⏳

## Phase 1 — Baseline (before the first code edit)

- [x] **T1** — In the main repo at HEAD `c25d66d` (pre-edit state), run:
  1. `scripts/capture_baseline.sh --out-dir artifacts/2026-10-16-menu-bar-regular-weight/baseline --hold 20`
     → writes `dark.png` and `light.png` (popover captures; gate requirement: make both
     before the first code edit). The script kills the app and restores the original
     appearance on exit, and it leaves a Release build at
     `.derivedData/Build/Products/Release/StatsLite.app`.
  2. Menu bar strip captures into the same directory. The script records the popover window
     only; VAC-7 needs the menu bar pixels, so both capture sets are required. The script
     kills the app on exit, so relaunch it. For each of the two appearances:
     - launch `.derivedData/Build/Products/Release/StatsLite.app/Contents/MacOS/StatsLite`
       so the status item is on screen,
     - switch appearance with
       `osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'`
       (use `false` for the light capture),
     - capture one frame that spans the StatsLite status item and the system clock:
       `screencapture -x -R<x,y,w,h> artifacts/2026-10-16-menu-bar-regular-weight/baseline/<file>.png`
       — pick `<x,y,w,h>` at run time; use `<file>` = `menubar_dark`, then `menubar_light`,
     - quit the app (`pkill -x StatsLite`) and restore the original appearance.
- **Step 2 SKIPPED — user waiver (2026-10-16):** no Screen Recording permission in this
  session; `screencapture -R` and cross-process `-l` capture both fail. The user waived the
  menu bar strip captures on their authority.
- Receipts: `artifacts/2026-10-16-menu-bar-regular-weight/baseline/dark.png` and
  `light.png` recorded on the T1 line (strip captures waived).
- Owner: planner runs T1 in bash (shell script execution, no code edit).

## Phase 2 — Red (test only, worktree)

Worktree: `<repo>/worktrees/menu-bar-regular-weight`, branch
`feat/2026-10-16-menu-bar-regular-weight`. Create the worktree before the spawn; set the
spawn `cwd` to it.

- [x] **T2** — `T2: [red]` Author `StatsLiteTests/MenuBarValueTypographyTests.swift`.
  RECEIPTS: red SHA `5e2a97c` (test-only diff); FM1 fails at HEAD (`.medium` vs expected `.regular` token); IC-2/3/4/10 guards green; suite `203 tests, 1 failure` (only FM1). Mechanism: source-token check via `#filePath`.
  One failing test per failure mode; touch no application code.
  - **FM1 (must fail at HEAD):** the value font of `MenuBarBlockView` is
    `Font.system(size: 10.5, weight: .regular).monospacedDigit()`. Mechanism: the coder's
    choice — a Mirror walk of the view body to the font modifier, or a source-token check
    anchored on the value `Text` at `MenuBarStackedItemView.swift:115-116` via `#filePath`.
    State which mechanism is used and why it cannot pass while the weight is `.medium`.
  - **IC-2 guard:** `.monospacedDigit()` present on the value font.
  - **IC-4 guard:** label font stays `.system(size: 8, weight: .bold)` + `.secondary`
    (`:111-113`).
  - **IC-10 scope guard:** network value lines keep `.system(size: 9, weight: .medium)`
    (`:153`, `:167`); the value line carries size 10.5.
  - **IC-3 clearance guard:** total clearance `34.0 − width("100%" @ 10.5 .regular
    monospacedDigit)` ≥ 3.5 pt (expected 4.07 pt). The coupling that keeps this check
    non-vacuous is documented: IC-1 pins the weight the code uses; this test pins the
    geometry consequence.
  - Run:
    `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Debug -derivedDataPath .derivedData test -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1`
  - Report red output with the FM1 failure visible. IC-4/IC-10/IC-3 guards may already pass
    at HEAD (they are regression guards); only FM1 defines red.
- Receipts: test-only diff (`git -C worktrees/menu-bar-regular-weight diff --stat main...HEAD`
  shows no `StatsLite/` changes), red SHA, failing-test output.

## Phase 3 — Green (implementation, same worktree)

- [x] **T3** — `T3:` Apply the Blueprint Appendix A step 3: at
  RECEIPTS: green SHA `b1e27cc`, one token at `:116` only (`.medium` → `.regular`); suite `203 tests, 0 failures`; `git diff main...HEAD --stat` = test file + 1-line source change.
  `StatsLite/MenuBarStackedItemView.swift:116` replace `weight: .medium` with
  `weight: .regular`. Nothing else in production code. Do not add `.animation` or
  `.contentTransition`. Do not weaken or delete red tests. Then run the full suite with the
  command from T2; all tests green (IC-9).
- Receipts: green SHA, suite output, `git diff main...HEAD` limited to the one token plus
  the T2 test file.

## Phase 4 — VAC ledger (screenshots + tests)

- [x] **T4** — `T4:` Run the green worktree build so the status item shows `.regular`
  RECEIPTS: `artifacts/2026-10-16-menu-bar-regular-weight/vac-ledger.md` — VAC-1..6 and VAC-8 pass with test evidence; VAC-7 + strip captures waived (user authority, no Screen Recording permission).
  values, then capture and record the evidence:
  1. App binary: the T2/T3 test runs build it at
     `worktrees/menu-bar-regular-weight/.derivedData/Build/Products/Debug/StatsLite.app`
     (`TEST_HOST` = the app). If it is missing, run the T2 xcodebuild command with
     `build` instead of `test`.
  2. Strip captures SKIPPED — user waiver (2026-10-16), same reason as T1 step 2.
  3. Write the VAC ledger to
     `artifacts/2026-10-16-menu-bar-regular-weight/vac-ledger.md`: test-based ICs marked
     pass/fail with their evidence (test name, `rg` output, recorded measurement — IC-3
     expects 29.93 pt, 4.07 pt total). Screenshot-based ICs marked `waived (user
     authority, 2026-10-16)`. Every test-based IC must be pass.
- Receipts: `vac-ledger.md` with each IC pass or waived, recorded on the T4 line.

## Phase 5 — Review, merge, cleanup

- [ ] **T5** — Spawn `reviewer` with `[code-review]`, plan name
  `2026-10-16-menu-bar-regular-weight`, `cwd` = worktree, against
  `git -C worktrees/menu-bar-regular-weight diff main...HEAD`. Checks: red commit is
  test-only, green commit implements the Blueprint token, no scope tokens changed,
  ledger complete, zero-animation rule intact. Max two NO GO cycles, then escalate.
  On GO: `git merge --ff-only feat/2026-10-16-menu-bar-regular-weight` (or `--squash`
  with its own conventional commit) from `main`, then remove the worktree and branch,
  then mark every task `[x]` with receipts.
- Receipts: review verdict, merge SHA confirmed by `git log --oneline -1` on `main`,
  worktree removed.

## Verification and spawn matrix

| Task | Agent | cwd | Timeout | Marker |
| --- | --- | --- | --- | --- |
| T1 | planner (bash) | main repo | — | — |
| T2 | `coder` | worktree | 1800 s | `[red]`, plan `2026-10-16-menu-bar-regular-weight` |
| T3 | `coder` | same worktree | 1800 s | plan `2026-10-16-menu-bar-regular-weight` |
| T4 | `coder` self-verify | same worktree | 1800 s | plan `2026-10-16-menu-bar-regular-weight` |
| T5 | `reviewer` | worktree | 600 s | `[code-review]`, plan `2026-10-16-menu-bar-regular-weight` |

Sequencing: T1 → T2 → T3 → T4 → T5 strictly sequential; red and green never parallel.
No simulator concurrency: the xcodebuild flags in T2/T3 are mandatory.

## Docs

- `ARCHITECTURE.md` / `DESIGN.md`: absent at this project root; nothing to update.
- `AGENTS.md`: the zero-animation rule and evidence rules already cover this change;
  no edit needed.
- Result: **No doc updates needed.**

## Risks and open items

- Pre-existing open worktree `worktrees/2026-10-15-stats-lite-view-weight` (branch
  `feat/2026-10-15-stats-lite-view-weight`) belongs to plan
  `2026-10-15-stats-lite-view-weight`, not this plan; leave it untouched here.
- VAC-7 is a human-judgment visual check; the ledger records it against captures, not a
  numeric threshold (stroke matching is engine-dependent — a pixel-exact rule would fail
  on rendering noise).
- Network blocks deliberately keep 9 pt `.medium` (Blueprint scope decision). If a follow-up
  wants them regular-weight, that is a new designer pass, not this plan.
