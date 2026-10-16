# Appendix A — Design Fix Blueprint: Network Block Color/Role Swap (designer, 2026-10-16, verbatim)

## Executive Summary

This blueprint specifies the role swap for the network block in StatsLite.
The project does not contain a root `DESIGN.md` file.
All design tokens ground directly in `StatsLite/DesignTokens.swift` and `StatsLite/MenuBarStackedItemView.swift`.

In the current release, Line 1 displays the download rate and Line 2 displays the upload rate.
The user corrects this role mapping:
- Line 1 (top line, red dot) must display the upload rate.
- Line 2 (bottom line, blue dot) must display the download rate.

Geometry, font sizes, line heights, block width (58 pt), and indicator dot colors do not change.
Visual evidence from the live menu bar capture `/tmp/designer/menubar-network-focus2.png` confirms the current baseline.

---

## 1. Visual Hierarchy & ASCII Wireframe

Visual evidence anchor: `/tmp/designer/menubar-network-focus2.png` shows the active two-line block in the macOS menu bar.

```
+-------------------------------------------------------------+
| Menu Bar Item (Total width: 176 pt with all metrics active) |
|                                                             |
| [CPU 34pt]  [MEM 34pt]  [GPU 34pt]  [NET 58pt]              |
|                                                             |
| +---------------------------------------------------------+ |
| | Network Block (Width: 58 pt, Height: ~22 pt)            | |
| |                                                         | |
| | Line 1:  (R)  [Spacer]                         10 KB/s  | |  <-- Upload Rate (systemRed dot)
| | Line 2:  (B)  [Spacer]                        720 KB/s  | |  <-- Download Rate (systemBlue dot)
| +---------------------------------------------------------+ |
+-------------------------------------------------------------+

Legend:
- (R): 6.0 pt circular indicator dot in Color(nsColor: .systemRed) (Upload indicator)
- (B): 6.0 pt circular indicator dot in Color(nsColor: .systemBlue) (Download indicator)
- Spacing: 1.0 pt vertical gap between lines; 3.0 pt gap after indicator dots
- Alignment: Dots align on the leading boundary. Numerical rate text aligns to the trailing boundary.
```

---

## 2. Template / Component Skeleton

### 2.1 View Hierarchy (`StatsLite/MenuBarStackedItemView.swift`)

The component tree in `MenuBarNetworkBlockView` remains unchanged in structure.
The comments and bound properties reflect the swapped roles:

```swift
/// Dedicated two-line network speed monitor block:
/// line 1 carries a 6 pt red indicator dot and the upload rate.
/// line 2 carries a 6 pt blue indicator dot and the download rate.
/// Width pins to block.width (58 pt), so rate string changes never
/// resize the item (VAC-2). Transitions stay discrete: no
/// .animation and no .contentTransition modifiers (VAC-9).
struct MenuBarNetworkBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Line 1: Upload rate
            HStack(alignment: .center, spacing: 3) {
                Circle()
                    .fill(Color(nsColor: .systemRed))
                    .frame(width: 6, height: 6)

                Spacer(minLength: 2)

                Text(block.valueText)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }

            // Line 2: Download rate
            HStack(alignment: .center, spacing: 3) {
                Circle()
                    .fill(Color(nsColor: .systemBlue))
                    .frame(width: 6, height: 6)

                Spacer(minLength: 2)

                Text(block.secondaryValueText ?? "-- KB/s")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
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

### 2.2 Model Builder Mapping (`StatsLite/MenuBarBlockModel.swift`)

In `MenuBarBlockBuilder.blocks`, `valueText` feeds Line 1 and `secondaryValueText` feeds Line 2:

```swift
        if showNetwork {
            // The network block owns its red upload dot and blue
            // download dot in the view, so dotState stays nil and the
            // label stays empty. Only a missing rate renders tertiary.
            blocks.append(
                MenuBarBlock(
                    kind: .network,
                    label: "",
                    dotState: nil,
                    valueText: MetricFormatters.networkRate(uploadRate),
                    valueTint: uploadRate == nil ? .tertiary : .primary,
                    width: MenuBarLayout.networkBlockWidth,
                    secondaryValueText: MetricFormatters.networkRate(downloadRate),
                    secondaryValueTint: downloadRate == nil ? .tertiary : .primary
                )
            )
        }
```

---

## 3. Complete State & Responsive Matrix

The network block renders in the macOS menu bar.
The block does not change width across viewports.
The block maintains a fixed width of `58 pt` across 1x and 2x Retina scales.

| UI State | Red Dot (Line 1, Top) | Line 1 Text (Upload) | Blue Dot (Line 2, Bottom) | Line 2 Text (Download) | Block Width |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Default (Active Traffic)** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color.primary`, `.system(size: 9, weight: .medium).monospacedDigit()`, for example `10 KB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color.primary`, `.system(size: 9, weight: .medium).monospacedDigit()`, for example `720 KB/s` | `58 pt` pinned |
| **Idle Traffic (Zero / Low)** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color.primary`, `0 KB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color.primary`, `0 KB/s` | `58 pt` pinned |
| **High Throughput (MB/s)** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color.primary`, for example `22 KB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color.primary`, for example `1.6 MB/s` or `94.9 MB/s` | `58 pt` pinned |
| **Gigabit Throughput (GB/s)** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color.primary`, for example `1.0 GB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color.primary`, for example `1.2 GB/s` | `58 pt` pinned |
| **Missing / Unavailable Data** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color(nsColor: .tertiaryLabelColor)`, `-- KB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color(nsColor: .tertiaryLabelColor)`, `-- KB/s` | `58 pt` pinned |
| **Asymmetric Available (Upload Nil)** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color(nsColor: .tertiaryLabelColor)`, `-- KB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color.primary`, for example `720 KB/s` | `58 pt` pinned |
| **Asymmetric Available (Download Nil)** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color.primary`, for example `10 KB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color(nsColor: .tertiaryLabelColor)`, `-- KB/s` | `58 pt` pinned |

---

## 4. Accessibility (WCAG 2.2) & Interaction Contracts

### 4.1 VoiceOver Reading Order & Microcopy Contract

The screen reader announcements must match visual top-to-bottom order.
Line 1 is visual top (Upload).
Line 2 is visual bottom (Download).
Therefore, VoiceOver must announce the upload rate before the download rate.

Implementation in `StatsLite/MenuBarAccessibility.swift`:

```swift
        if showNetwork {
            // latestNetwork is one optional pair: both rates arrive
            // together or the block reads "unavailable".
            if let downloadRate, let uploadRate {
                parts.append(
                    "Network Upload \(MetricFormatters.networkRate(uploadRate)), "
                        + "Download \(MetricFormatters.networkRate(downloadRate))"
                )
            } else {
                parts.append("Network unavailable")
            }
        }
```

VoiceOver string contracts:
- When all metrics are active with data:
  `"Stats Lite: CPU 14 percent, Memory Pressure Normal at 25 percent, GPU 28 percent, Network Upload 10 KB/s, Download 720 KB/s"`
- When network only is active:
  `"Stats Lite: Network Upload 22 KB/s, Download 1.6 MB/s"`
- When network rates are missing:
  `"Stats Lite: CPU 14 percent, Memory Pressure Normal at 25 percent, GPU 28 percent, Network unavailable"`
- When network is toggled off:
  VoiceOver completely omits the Network section.

### 4.2 WCAG 2.2 Compliance

- **SC 1.4.3 Contrast (Minimum)**: Active numerical rate text uses `Color.primary` (contrast ratio > 7:1 against menu bar backing in both light and dark modes). Unavailable rate text uses `Color(nsColor: .tertiaryLabelColor)` (contrast ratio >= 3:1).
- **SC 1.4.11 Non-text Contrast**: The red dot (`Color(nsColor: .systemRed)`) and blue dot (`Color(nsColor: .systemBlue)`) maintain a contrast ratio >= 3:1 against standard macOS light and dark menu bar surfaces.
- **SC 1.3.2 Meaningful Sequence**: VoiceOver speaks Line 1 (Upload) then Line 2 (Download). The speech sequence preserves the visual reading hierarchy.

---

## 5. Numbered Visual Acceptance Checklist

The following delta items replace their original counterparts from the base network monitor plan:

- **VAC-B1** (replaces **VAC-1**): The network block renders exactly two vertically stacked rows. Line 1 displays the upload rate with a leading red indicator dot. Line 2 displays the download rate with a leading blue indicator dot.
- **VAC-B4** (replaces **VAC-4**): The top indicator dot fill matches `Color(nsColor: .systemRed)` and pairs with the upload rate string. The bottom indicator dot fill matches `Color(nsColor: .systemBlue)` and pairs with the download rate string.
- **VAC-B10** (replaces **VAC-10**): When Network is active, the composite accessibility label includes `Network Upload <upRate>, Download <downRate>`. When rate values are missing, it includes `Network unavailable`.
- Unchanged base VAC items that remain active: **VAC-2** (Pinned Block Width — superseded by appendix B: 50 pt), **VAC-3** (Indicator Dot Geometry), **VAC-5** (Typography), **VAC-6** (Trailing Text Alignment — superseded by appendix B), **VAC-7** (Rate Formatting Thresholds — superseded by appendix B), **VAC-8** (Text Foreground Tint), **VAC-9** (No Animation or Content Transition), **VAC-11** (Length Math — superseded by appendix B).

---

## Appendix: Implementation Details & Code Diff Locations

### A.1 Exact File Changes

| File | Target Construct | Before Value | After Value |
| :--- | :--- | :--- | :--- |
| `StatsLite/MenuBarBlockModel.swift:157` | `MenuBarBlockBuilder.blocks` line 1 valueText | `valueText: MetricFormatters.networkRate(downloadRate),` | `valueText: MetricFormatters.networkRate(uploadRate),` |
| `StatsLite/MenuBarBlockModel.swift:158` | line 1 valueTint | `valueTint: downloadRate == nil ? .tertiary : .primary,` | `valueTint: uploadRate == nil ? .tertiary : .primary,` |
| `StatsLite/MenuBarBlockModel.swift:160` | line 2 secondaryValueText | `secondaryValueText: MetricFormatters.networkRate(uploadRate),` | `secondaryValueText: MetricFormatters.networkRate(downloadRate),` |
| `StatsLite/MenuBarBlockModel.swift:161` | line 2 secondaryValueTint | `secondaryValueTint: uploadRate == nil ? .tertiary : .primary` | `secondaryValueTint: downloadRate == nil ? .tertiary : .primary` |
| `StatsLite/MenuBarAccessibility.swift:52-53` | `compositeLabel` network string | `"Network Download …, Upload …"` | `"Network Upload …, Download …"` |

### A.2 Corrected Tests

| Test File | Test Case | Before | After |
| :--- | :--- | :--- | :--- |
| `StatsLiteTests/MenuBarBlockBuilderTests.swift:353-354` | `testNetworkBlockAppendsAfterGPUWithEmptyLabelAndPinnedWidth` | `valueText == "720 KB/s"`, `secondaryValueText == "10 KB/s"` | `valueText == "10 KB/s"`, `secondaryValueText == "720 KB/s"` |
| `StatsLiteTests/MenuBarBlockBuilderTests.swift:367` | `testNetworkOnlyProducesSingleNetworkBlock` | `valueText == "1.6 MB/s"`, `secondaryValueText == "22 KB/s"` | `valueText == "22 KB/s"`, `secondaryValueText == "1.6 MB/s"` |
| `StatsLiteTests/MenuBarBlockBuilderTests.swift` | `testNetworkBlockRendersPlaceholderWhenRatesMissing` | comments label line 1 download / line 2 upload | comments label line 1 upload / line 2 download |
| `StatsLiteTests/MenuBarAccessibilityTests.swift:161` | `testCompositeLabelWithNetworkRates` | `Network Download 720 KB/s, Upload 10 KB/s` | `Network Upload 10 KB/s, Download 720 KB/s` |
| `StatsLiteTests/MenuBarAccessibilityTests.swift:200` | `testCompositeLabelNetworkOnly` | `Network Download 1.6 MB/s, Upload 22 KB/s` | `Network Upload 22 KB/s, Download 1.6 MB/s` |
| `StatsLiteTests/MenuBarAccessibilityTests.swift:219` | `testCompositeLabelNetworkFollowsCPUWhenOtherMetricsOff` | `Network Download 720 KB/s, Upload 10 KB/s` | `Network Upload 10 KB/s, Download 720 KB/s` |

### A.3 Documentation & Code Comments to Update

1. `StatsLite/MenuBarBlockModel.swift:38`: `secondaryValueText holds the upload rate below the download rate.` → `…the download rate below the upload rate.`
2. `StatsLite/MenuBarBlockModel.swift:149-150`: `red download dot and blue upload dot` → `red upload dot and blue download dot`.
3. `StatsLite/MenuBarStackedItemView.swift:9-10`: `red dot plus download rate above blue dot plus upload rate` → `red dot plus upload rate above blue dot plus download rate`.
4. `StatsLite/MenuBarStackedItemView.swift:134-135`: line 1 = upload rate, line 2 = download rate.
5. `StatsLite/MenuBarStackedItemView.swift:144`: `// Line 1: Download rate` → `// Line 1: Upload rate`.
6. `StatsLite/MenuBarStackedItemView.swift:158`: `// Line 2: Upload rate` → `// Line 2: Download rate`.
7. `StatsLite/StatusItemController.swift:157-159`: example string `Network Download 720 KB/s, Upload 10 KB/s` → `Network Upload 10 KB/s, Download 720 KB/s`.
