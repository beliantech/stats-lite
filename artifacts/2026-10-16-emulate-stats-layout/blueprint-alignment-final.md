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