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