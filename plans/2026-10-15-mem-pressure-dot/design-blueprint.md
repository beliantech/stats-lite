# Design Blueprint: Stacked Menu Bar Item — MEM Label, Pressure Dot, Pressure Value

Source: designer agent output, 2026-10-15 (session `ac056afe-1d5fa614-7414ee65-0552`). Status: Ready for Implementation. Reference captures in `/tmp/designer/` (`current_statslite_menubar_2x.png`, `test_baseline_4x.png`, `tint_comparison_dark_2x.png`, `tint_comparison_light_2x.png`, `complete_normal_dark_3x.png`, `complete_warning_dark_3x.png`, `complete_critical_dark_3x.png`, `complete_unknown_dark_3x.png`).

## Design decisions

### 1. Label update
Line 1 of the memory block changes from `RAM` to `MEM`. At SF Pro 8 pt Bold, `MEM` measures 20.09 pt (`RAM` was 19.28 pt).

### 2. Status dot geometry and alignment
- **Dot diameter**: 4.0 pt — `Circle().frame(width: 4, height: 4)`. 4 physical px at 1x, 8 px at 2x. Matches the optical cap-height (5.6 pt) of the 8 pt bold label.
- **Spacing**: 2.0 pt gap between dot and `MEM` — `HStack(alignment: .center, spacing: 2)`.
- **Vertical alignment**: `.offset(y: -0.5)` on the dot to sit at the optical center of the uppercase glyphs (standard `HStack` centering places it 0.5 pt low because of text container margins).
- **Layout math**: pinned block width stays `MenuBarLayout.blockWidth = 34` pt. Line 1 total = 4 + 2 + 20.09 = 26.09 pt → ~3.96 pt clearance per side. Widest element stays `100%` on line 2 (30.83 pt). Total status item length unchanged (114 pt for three metrics).

### 3. Line-2 value tint decision — AMENDED per user decision

> **Amendment (2026-10-15, user):** the MEM number escalates **green → orange → red**: normal renders `Color(nsColor: .systemGreen)`, warning `systemOrange`, critical `systemRed`, unavailable/nil `tertiaryLabelColor` with `--%`. This overrides the original `.primary`-for-normal decision below. The WCAG contrast concern (green text ≈ 2.3:1 on light menu bars) was surfaced to the user and explicitly accepted; the dot plus number both carry the state redundantly. `MenuBarValueTint` gains a `.green` case.

Original rationale (kept for context):
Line 2 uses `.primary` for normal, `.warning` (systemOrange) for warning, `.critical` (systemRed) for critical, `.tertiary` for unavailable/nil.
Justification for not tinting normal green:
1. WCAG 2.2 SC 1.4.3 — `systemGreen` text at 10.5 pt gives 2.3:1 on light menu bars (needs 4.5:1); `systemYellow` gives 1.4:1.
2. Visual balance — CPU/GPU normal values are neutral `.primary`; green memory text would over-salience the block. The dot alone carries the categorical color.
3. Escalation consistency — warning/critical escalation matches the CPU/GPU tint behavior.

### 4. Accessibility label
VoiceOver reports what is on screen: `Memory Pressure Normal at 25 percent` (was `... with 62 percent used`); `Memory Pressure unavailable` when pressure is nil.

## Part 1 — Wireframe

```text
========================================================================================
STATS LITE MENU BAR ITEM (Total Width: 114 pt, Pinned Height: Centered in Menu Bar)
========================================================================================
[ Outer Padding: 2 pt ]                                              [ Outer Padding: 2 pt ]
+------------------------+  gap   +------------------------+  gap   +------------------------+
|      CPU Block         |  4 pt  |      MEM Block         |  4 pt  |      GPU Block         |
|      Width: 34 pt      | <----> |      Width: 34 pt      | <----> |      Width: 34 pt      |
| Line 1: [  CPU  ]      |        | Line 1: [ (o) MEM ]    |        | Line 1: [  GPU  ]      |
|  8pt Bold, Secondary,  |        |  (o): 4pt circle       |        |  8pt Bold, Secondary,  |
|  Centered in 34 pt     |        |  filled with pressure  |        |  Centered in 34 pt     |
|                        |        |  color; gap 2pt;       |        |                        |
|                        |        |  MEM 8pt Bold;         |        |                        |
|                        |        |  offset y = -0.5pt     |        |                        |
| Line 2: [  13%  ]      |        | Line 2: [  25%  ]      |        | Line 2: [   0%  ]      |
|  10.5pt Monospaced,    |        |  10.5pt Monospaced,    |        |  10.5pt Monospaced,    |
|  Primary/Warning/      |        |  Pressure percentage,  |        |  Primary/Warning/      |
|  Critical/Tertiary     |        |  Primary/Warning/      |        |  Critical/Tertiary     |
|                        |        |  Critical/Tertiary     |        |                        |
+------------------------+        +------------------------+        +------------------------+
```

## Part 2 — Component skeleton

### `StatsLite/MenuBarBlockModel.swift`

```swift
/// One stacked menu bar block. The dotState property carries the memory
/// pressure state for the MEM block. CPU and GPU blocks keep dotState nil.
struct MenuBarBlock: Equatable {
    var kind: MenuBarBlockKind
    var label: String
    var dotState: MemoryPressureState?
    var valueText: String
    var valueTint: MenuBarValueTint
    var width: CGFloat
}

enum MenuBarBlockBuilder {
    static func blocks(
        showCPU: Bool,
        showRAM: Bool,
        showGPU: Bool,
        cpuPercent: Double?,
        pressurePercent: Double?,
        pressureState: MemoryPressureState?,
        gpuPercent: Double?
    ) -> [MenuBarBlock] {
        var blocks: [MenuBarBlock] = []

        if showCPU {
            blocks.append(
                MenuBarBlock(
                    kind: .cpu, label: "CPU", dotState: nil,
                    valueText: MetricFormatters.percent(cpuPercent),
                    valueTint: usageTint(cpuPercent),
                    width: MenuBarLayout.blockWidth
                )
            )
        }

        if showRAM {
            let resolvedState = (pressureState ?? .unknown)
                .displayState(pressure: pressurePercent ?? 0)
            blocks.append(
                MenuBarBlock(
                    kind: .ram, label: "MEM", dotState: resolvedState,
                    valueText: MetricFormatters.percent(pressurePercent),
                    valueTint: pressureTint(percent: pressurePercent, state: resolvedState),
                    width: MenuBarLayout.blockWidth
                )
            )
        }

        if showGPU {
            blocks.append(
                MenuBarBlock(
                    kind: .gpu, label: "GPU", dotState: nil,
                    valueText: MetricFormatters.percent(gpuPercent),
                    valueTint: usageTint(gpuPercent),
                    width: MenuBarLayout.blockWidth
                )
            )
        }

        return blocks
    }

    /// Usage tint for CPU and GPU: >= 95 % critical, >= 80 % warning, else primary.
    private static func usageTint(_ value: Double?) -> MenuBarValueTint {
        guard let value else { return .tertiary }
        if value >= 0.95 { return .critical }
        if value >= 0.80 { return .warning }
        return .primary
    }

    /// Value tint for memory pressure. Unavailable values render tertiary.
    private static func pressureTint(
        percent: Double?,
        state: MemoryPressureState
    ) -> MenuBarValueTint {
        guard percent != nil else { return .tertiary }
        switch state {
        case .critical: return .critical
        case .warning: return .warning
        case .normal, .unknown: return .primary
        }
    }
}
```

`MenuBarLayout` constants are unchanged (blockWidth 34, gap 4, padding 2).

### `StatsLite/MenuBarStackedItemView.swift`

```swift
private var blocks: [MenuBarBlock] {
    let pressure = snapshot?.memoryPressure
    return MenuBarBlockBuilder.blocks(
        showCPU: preferences.showCPU,
        showRAM: preferences.showRAM,
        showGPU: preferences.showGPU,
        cpuPercent: snapshot?.cpu?.totalUsage,
        pressurePercent: pressure?.pressurePercentage,
        pressureState: pressure?.state,
        gpuPercent: snapshot?.gpu?.deviceUtilization
    )
}

private struct MenuBarBlockView: View {
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
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .frame(width: block.width)
        .animation(.easeInOut(duration: 0.2), value: block.valueText)
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

### `StatsLite/MenuBarAccessibility.swift`

```swift
static func compositeLabel(
    showCPU: Bool,
    showRAM: Bool,
    showGPU: Bool,
    cpuPercent: Double?,
    pressurePercent: Double?,
    pressure: MemoryPressureState,
    gpuPercent: Double?
) -> String {
    var parts: [String] = []
    if showCPU {
        if let cpuPercent {
            parts.append("CPU \(wholePercent(cpuPercent)) percent")
        } else {
            parts.append("CPU unavailable")
        }
    }
    if showRAM {
        if let pressurePercent {
            parts.append(
                "Memory Pressure \(pressure.displayName) at \(wholePercent(pressurePercent)) percent"
            )
        } else {
            parts.append("Memory Pressure unavailable")
        }
    }
    if showGPU {
        if let gpuPercent {
            parts.append("GPU \(wholePercent(gpuPercent)) percent")
        } else {
            parts.append("GPU unavailable")
        }
    }
    return "Stats Lite: " + parts.joined(separator: ", ")
}
```

`StatusItemController.compositeLabel` passes `cpuPercent: snapshot?.cpu?.totalUsage` and `pressurePercent: snapshot?.memoryPressure?.pressurePercentage` (both optional), keeping the existing `displayState(pressure:)` derivation for `pressure`.

## Part 3 — State and responsive matrix (MEM block)

| State | Pressure | Dot color | Value text | Value tint | Dark / light text |
|---|---|---|---|---|---|
| Normal | 0.00–0.59 (or kernel normal) | systemGreen | `25%` | systemGreen (amended) | green |
| Warning | 0.60–0.80 (or kernel warning) | systemYellow | `68%` | systemOrange | orange |
| Critical | > 0.80 (or kernel critical) | systemRed | `88%` | systemRed | red |
| Unknown / nil | `nil` | systemGray | `--%` | tertiaryLabelColor | dim |
| Zero usage | 0.00 | systemGreen | `0%` | systemGreen (amended) | green |
| Full saturation | 1.00 | systemRed | `100%` | systemRed | red |

Zoom/density: menu bar items do not respond to viewport breakpoints. 1x → dot 4×4 px, label row 26 px, ≥ 3.5 px clearance per side; 2x → dot 8×8 px, label row 52 px, ≥ 7 px clearance. Single-metric item stays 38 pt; CPU+MEM pair stays 76 pt. Pinned widths prevent jitter when values change.

## Part 4 — Accessibility contracts

- SC 1.4.3 contrast: `.primary` > 12:1 dark / > 14:1 light; systemOrange 6.2:1 dark / 4.6:1 light; systemRed 5.1:1 / 4.8:1. Green value text rejected (2.3:1).
- SC 1.4.11 non-text: dot colors exceed 3.0:1 on both menu bar appearances.
- SC 2.5.8 target size: full NSStatusBarButton (114 pt × ≥ 24 pt) is the target; SwiftUI side stays `.accessibilityHidden(true)` with `PassthroughHostingView`.
- VoiceOver pattern: `Stats Lite: CPU {N} percent, Memory Pressure {State} at {N} percent, GPU {N} percent`.
- Keyboard: `Control+F8` focuses menu bar extras; Space/Return toggles the popover; Escape dismisses.

## Part 5 — Visual Acceptance Checklist

- [ ] **VAC-1 (Label String)**: Line 1 of the memory block reads `MEM`. `RAM` appears nowhere in the menu bar. Evidence: `/tmp/designer/complete_normal_dark_3x.png`.
- [ ] **VAC-2 (Dot Placement and Geometry)**: Dot immediately left of `MEM` on line 1, diameter 4.0 pt, gap 2.0 pt. Evidence: `/tmp/designer/test_baseline_4x.png`.
- [ ] **VAC-3 (Optical Vertical Baseline Alignment)**: Dot center aligns with optical center of `MEM` uppercase glyphs via −0.5 pt offset. Evidence: `/tmp/designer/test_baseline_4x.png`.
- [ ] **VAC-4 (Pressure State Color Mapping)**: normal→systemGreen, warning→systemYellow, critical→systemRed, unknown/nil→systemGray. Evidence: `complete_{normal,warning,critical,unknown}_dark_3x.png`.
- [ ] **VAC-5 (Line 2 Value Source)**: Line 2 shows formatted `pressurePercentage`, not RAM occupancy. Evidence: `/tmp/designer/complete_normal_dark_3x.png`.
- [ ] **VAC-6 (Line 2 Value Tint Invariant)**: normal `systemGreen` (user-decided amendment); warning `systemOrange`; critical `systemRed`; unknown/nil `tertiaryLabelColor` with `--%`. Evidence: `tint_comparison_{dark,light}_2x.png`.
- [ ] **VAC-7 (Zero Wrapping / Zero Clipping)**: Neither line wraps or truncates at 34 pt; dot ≥ 3.5 pt from leading edge, text ≥ 3.5 pt from trailing edge.
- [ ] **VAC-8 (Zero Layout Shift)**: Block stays 34.0 pt across `0%` / `25%` / `100%` / `--%`; item stays 114.0 pt with three metrics; no adjacent icon movement. Evidence: `MenuBarLayout.blockWidth`, `MenuBarLayoutTests.swift`.
- [ ] **VAC-9 (VoiceOver Label Accuracy)**: `Stats Lite: CPU 14 percent, Memory Pressure Normal at 25 percent, GPU 28 percent`. Evidence: `StatsLite/MenuBarAccessibility.swift`.

## Test verification requirements

1. `MenuBarBlockBuilderTests.swift`: `RAM`→`MEM` expectations; `dotState` checks per state (normal/warning/critical/nil→`.unknown` + `--%` + tertiary); `width == 34` for every block.
2. `MenuBarAccessibilityTests.swift`: expect `Memory Pressure Normal at 25 percent`.
3. `MenuBarLayoutTests.swift`: all existing totals (114, 76, 38, 4) pass unchanged.
