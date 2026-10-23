# Design Blueprint: Menu Bar Temperature (TEMP) Label Styling Parity

## Executive Summary

The menu bar temperature (TEMP) block currently renders its subsystem prefixes (`CPU ` and `GPU `) as part of the value text in 9 pt regular monospaced digit font with primary foreground style (`Color.primary`). This diverges from every other menu bar metric label (`CPU`, `MEM`, `GPU`), which renders in 8 pt regular system font with secondary foreground style (`.foregroundStyle(.secondary)`).

This blueprint specifies the exact target state, component skeleton, visual tokens, layout invariants, and test migration steps to achieve complete visual parity across light and dark appearances.

---

## Propose New `DESIGN.md` Rule Statement

Record this durable design rule at the repository root:

```markdown
Menu bar metric labels (CPU, MEM, GPU, and two-row TEMP labels CPU and GPU) must use 8 pt regular text with secondary foreground style.
```

---

## 1. Current State & Defect Attribution

### 1.1 Code Citations & Mechanism
1. **Standard Metric Blocks (`CPU`, `MEM`, `GPU`)**:
   - Location: `StatsLite/MenuBarStackedItemView.swift:105-144` (`MenuBarBlockView`).
   - Category Label: `Text(block.label).font(.system(size: 8, weight: .regular)).foregroundStyle(.secondary)` at `MenuBarStackedItemView.swift:118-119`.
   - Metric Value: `Text(block.valueText).font(.system(size: 12, weight: .regular).monospacedDigit()).foregroundStyle(valueColor)` at `MenuBarStackedItemView.swift:122-123`.
   - Layout: Stacked vertically with `HStack(alignment: .center, spacing: 2)` for line 1 and `Text` for line 2, each inside `.frame(height: MenuBarLayout.rowHeight)` (11 pt).

2. **Network Block (`NET`)**:
   - Location: `StatsLite/MenuBarStackedItemView.swift:146-205` (`MenuBarNetworkBlockView`).
   - Line 1: 5 pt upload dot (`Color.networkUpload`) plus rate text in `.font(.system(size: 9, weight: .regular).monospacedDigit())` at `MenuBarStackedItemView.swift:162`.
   - Line 2: 5 pt download dot (`Color.networkDownload`) plus rate text in `.font(.system(size: 9, weight: .regular).monospacedDigit())` at `MenuBarStackedItemView.swift:175`.
   - Label: Network carries no textual category label (`label: ""` in `MenuBarBlockModel.swift:204`). Visual category is established solely by the colored indicator dots.

3. **Temperature Block (`TEMP`)**:
   - Location: `StatsLite/MenuBarStackedItemView.swift:207-260` (`MenuBarTempBlockView`) and `StatsLite/MenuBarBlockModel.swift:171-197`.
   - Builder: `MenuBarBlockBuilder.blocks` concatenates subsystem prefixes directly into the value strings:
     - `valueText: "CPU " + MetricFormatters.degrees(cpuCelsius)` at `MenuBarBlockModel.swift:190`.
     - `secondaryValueText: "GPU " + MetricFormatters.degrees(gpuCelsius)` at `MenuBarBlockModel.swift:193`.
     - `label: ""` at `MenuBarBlockModel.swift:188`.
   - View: `MenuBarTempBlockView` renders the entire conjoined string inside a single `Text` element per row:
     - Line 1: `Text(block.valueText).font(.system(size: 9, weight: .regular).monospacedDigit()).foregroundStyle(valueColor)` at `MenuBarStackedItemView.swift:225-226`.
     - Line 2: `Text(block.secondaryValueText ?? "GPU --°").font(.system(size: 9, weight: .regular).monospacedDigit()).foregroundStyle(secondaryValueColor)` at `MenuBarStackedItemView.swift:234-235`.

### 1.2 Photographic Evidence
- Screenshots cited:
  - `artifacts/2026-10-23-temp-menu-bar-metric/visual-vac/menubar-dark-final.png`
  - `artifacts/2026-10-23-temp-menu-bar-metric/visual-vac/menubar-light-final.png`
- Visual findings from screenshots:
  - In dark appearance, `CPU`, `MEM`, and `GPU` category labels render in dim gray (secondary label color). In contrast, `CPU 47°` and `GPU 34°` in the TEMP block render as uniform, bright white text across both label and value.
  - In light appearance, `CPU`, `MEM`, and `GPU` labels render in subtle medium gray. In contrast, `CPU 89°` and `GPU 41°` render in dark primary black across both label and value.
  - The glyph size of `CPU` and `GPU` in the TEMP block visually exceeds the glyph size of `CPU`, `MEM`, and `GPU` in standard blocks (9 pt versus 8 pt). Furthermore, the TEMP prefixes inherit monospaced digit formatting, which alters the letter proportions.

### 1.3 Exact Current Styling Differences

| Dimension | Standard Labels (`CPU`, `MEM`, `GPU`) | Current TEMP Labels (`CPU`, `GPU`) | Parity Delta |
|---|---|---|---|
| **Font Size** | `8 pt` | `9 pt` | +1 pt oversized in TEMP |
| **Font Weight** | `.regular` | `.regular` | Match |
| **Digit Spacing** | Proportional (standard system font) | Monospaced (`.monospacedDigit()`) | Mismatched font tracking |
| **Foreground Style** | `.secondary` (`NSColor.secondaryLabelColor`) | `.primary` (`Color.primary`) | High-contrast primary instead of muted secondary |
| **Model Structure** | Discrete `block.label` property | Conjoined inside `block.valueText` | Entangled value and label |

---

## 2. Target State & Architecture

### 2.1 Visual Hierarchy & ASCII Wireframe

```
Standard Blocks (CPU / MEM / GPU)              TEMP Block (Target State)
=====================================          =====================================
+-----------------------------------+          +-----------------------------------+
|  [dot]  CPU / MEM / GPU           | (8pt sec)|  CPU (8pt sec)   84° (9pt mono)    | Row 1 (11pt)
+-----------------------------------+          +-----------------------------------+
|               5%                  | (12pt pri|  GPU (8pt sec)   61° (9pt mono)    | Row 2 (11pt)
+-----------------------------------+          +-----------------------------------+
|<------- 39 pt fixed width ------->|          |<------- 50 pt fixed width ------->|
 Total block height: 22 pt                      Total block height: 22 pt
```

### 2.2 Thermal Thresholds & Value Parity Recommendation
- **Label State Rule**: Labels (`CPU` and `GPU`) must remain unconditionally `.secondary` across all states (normal, high temperature, and unavailable). In `MenuBarBlockView`, the `CPU` label remains `.secondary` even when usage reaches 99% critical red (`MenuBarStackedItemView.swift:118-119`). TEMP labels must follow this invariant.
- **Value State Rule**: The degree values (`84°`, `61°`, `--°`) remain 9 pt regular monospaced digits.
  - Readable values: `Color.primary` (adapts cleanly to light and dark modes).
  - Unavailable values (`--°`): `Color(nsColor: .tertiaryLabelColor)` (dim gray).
  - Thermal-threshold color coding: Do not introduce arbitrary thermal-threshold colors (orange or red) in this task. Apple Silicon operating temperatures routinely reach 85°C to 95°C under burst workloads without thermal throttling. The existing design deliberately treats temperature as primary-by-design (`MenuBarTempVerificationTests.swift:348-360`). Any future thermal thresholds must affect only the value text, never the label.

---

## 3. Template & Component Skeleton

### 3.1 `StatsLite/MenuBarBlockModel.swift` Skeleton

Add `secondaryLabel: String? = nil` to `MenuBarBlock`:

```swift
struct MenuBarBlock: Equatable {
    var kind: MenuBarBlockKind
    var label: String
    var dotState: MemoryPressureState?
    var valueText: String
    var valueTint: MenuBarValueTint
    var width: CGFloat
    var secondaryValueText: String? = nil
    var secondaryValueTint: MenuBarValueTint? = nil
    var secondaryLabel: String? = nil
}
```

Update `MenuBarBlockBuilder.blocks` for `showTemperature`:

```swift
        if showTemperature {
            let cpuCelsius = temperature?.cpuCelsius
            let gpuCelsius = temperature?.gpuCelsius
            blocks.append(
                MenuBarBlock(
                    kind: .temp,
                    label: "CPU",
                    dotState: nil,
                    valueText: MetricFormatters.degrees(cpuCelsius),
                    valueTint: cpuCelsius == nil ? .tertiary : .primary,
                    width: MenuBarLayout.tempBlockWidth,
                    secondaryValueText: MetricFormatters.degrees(gpuCelsius),
                    secondaryValueTint: gpuCelsius == nil ? .tertiary : .primary,
                    secondaryLabel: "GPU"
                )
            )
        }
```

### 3.2 `StatsLite/MenuBarStackedItemView.swift` (`MenuBarTempBlockView`) Skeleton

```swift
/// Dedicated two-line temperature monitor block:
/// line 1 displays label "CPU" in 8 pt regular secondary text plus the CPU reading in 9 pt monospacedDigit text.
/// line 2 displays label "GPU" in 8 pt regular secondary text plus the GPU reading in 9 pt monospacedDigit text.
/// Each row displays "--°" and tints tertiary when its subsystem is unreadable.
/// Width pins to block.width (MenuBarLayout.tempBlockWidth), so value changes never resize the item.
/// Transitions stay discrete: no .animation and no .contentTransition modifiers.
struct MenuBarTempBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Line 1: CPU die temperature
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(block.label)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(block.valueText)
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)

            // Line 2: GPU die temperature
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(block.secondaryLabel ?? "GPU")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(block.secondaryValueText ?? "--°")
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

## 4. Visual Tokens & State Matrix

### 4.1 Visual Tokens Specification

| UI Element | Property | Canonical Design Token | Visual Output |
|---|---|---|---|
| **Subsystem Labels** (`CPU`, `GPU`) | Font | `.font(.system(size: 8, weight: .regular))` | 8 pt proportional system font |
| | Color (All States) | `.foregroundStyle(.secondary)` | `NSColor.secondaryLabelColor` |
| **Temperature Values** (`84°`, `--°`) | Font | `.font(.system(size: 9, weight: .regular).monospacedDigit())` | 9 pt monospaced-digit system font |
| | Color (Readable) | `Color.primary` | `NSColor.labelColor` (White in Dark, Black in Light) |
| | Color (Unavailable) | `Color(nsColor: .tertiaryLabelColor)` | Tertiary label color |
| **Row Alignment** | Baseline Alignment | `.firstTextBaseline` | Perfect baseline alignment between 8 pt and 9 pt |
| | Inter-item Spacing | `2.0 pt` | Space between label and degree value |
| | Row Height | `MenuBarLayout.rowHeight` (`11.0 pt`) | Two rows total 22.0 pt (`NSStatusBar.system.thickness`) |
| **Block Bounds** | Block Width | `MenuBarLayout.tempBlockWidth` (`50.0 pt`) | Pinned container width |
| | Transitions | Discrete only | No `.animation` or `.contentTransition` |

### 4.2 State Matrix

| State | Line 1 Label | Line 1 Value | Line 2 Label | Line 2 Value |
|---|---|---|---|---|
| **Normal (Both Present)** | `CPU` (8pt regular, `.secondary`) | `84°` (9pt mono, `Color.primary`) | `GPU` (8pt regular, `.secondary`) | `61°` (9pt mono, `Color.primary`) |
| **High Load (e.g. 99°C / 102°C)** | `CPU` (8pt regular, `.secondary`) | `99°` (9pt mono, `Color.primary`) | `GPU` (8pt regular, `.secondary`) | `102°` (9pt mono, `Color.primary`) |
| **CPU Only Readable** | `CPU` (8pt regular, `.secondary`) | `84°` (9pt mono, `Color.primary`) | `GPU` (8pt regular, `.secondary`) | `--°` (9pt mono, tertiary) |
| **GPU Only Readable** | `CPU` (8pt regular, `.secondary`) | `--°` (9pt mono, tertiary) | `GPU` (8pt regular, `.secondary`) | `61°` (9pt mono, `Color.primary`) |
| **Neither Readable** | `CPU` (8pt regular, `.secondary`) | `--°` (9pt mono, tertiary) | `GPU` (8pt regular, `.secondary`) | `--°` (9pt mono, tertiary) |
| **Clamp Maximum (130°C)** | `CPU` (8pt regular, `.secondary`) | `130°` (9pt mono, `Color.primary`) | `GPU` (8pt regular, `.secondary`) | `130°` (9pt mono, `Color.primary`) |

### 4.3 Typography Clearance Measurements (AppKit Verified)

Measured in AppKit with `NSFont.systemFont(ofSize: 8, weight: .regular)` and `NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)`:
- `CPU` (8 pt label): `17.32 pt`
- `GPU` (8 pt label): `17.56 pt`
- Space gap: `2.00 pt`
- Value `84°` (9 pt mono): `16.08 pt` -> Total CPU row: `35.40 pt` (Clearance in 50 pt: `14.60 pt`)
- Value `61°` (9 pt mono): `16.08 pt` -> Total GPU row: `35.65 pt` (Clearance in 50 pt: `14.35 pt`)
- Value `--°` (9 pt mono): `13.24 pt` -> Total GPU row: `32.80 pt` (Clearance in 50 pt: `17.20 pt`)
- Value `130°` (clamp max): `21.92 pt` -> Total GPU row: `41.48 pt` (Clearance in 50 pt: `8.52 pt`)

Every row format satisfies the `>= 2.5 pt` clearance rule with zero clipping.

---

## 5. Accessibility, Interaction & Test Contracts

### 5.1 Accessibility & VoiceOver Contract
- Location: `StatsLite/MenuBarAccessibility.swift:49-58`.
- The VoiceOver label relies on `MenuBarAccessibility.compositeLabel(...)`, generating `"Temperature: CPU 84 degrees, GPU 61 degrees"`.
- The status item hosting view maintains `.accessibilityHidden(true)` (`StatsLite/MenuBarStackedItemView.swift:49`).
- Separating the label and degree values visually in `MenuBarTempBlockView` causes zero change to VoiceOver announcements.

### 5.2 Existing Tests Requiring Updates

1. **`StatsLiteTests/MenuBarTempBlockTests.swift`**:
   - `testTempRowsRenderPerSubsystemDegreesWithRowPlaceholders` (`:346-422`):
     - Assertions currently pin `both.label == ""`, `both.valueText == "CPU 84°"`, and `both.secondaryValueText == "GPU 62°"`.
     - Update to assert:
       - `both.label == "CPU"`
       - `both.secondaryLabel == "GPU"`
       - `both.valueText == "84°"`
       - `both.secondaryValueText == "62°"`
     - Update single-sensor and nil tests similarly (`cpuOnly.valueText == "84°"`, `cpuOnly.secondaryValueText == "--°"`, `neither.valueText == "--°"`).

2. **`StatsLiteTests/MenuBarTempVerificationTests.swift`**:
   - `testTempBlockWidthFitsClampMaxGPUDegreesRow` (`:300-335`):
     - Assertions currently pin `block.valueText == "CPU 130°"` and `block.secondaryValueText == "GPU 130°"`.
     - Update to assert `block.valueText == "130°"` and `block.secondaryValueText == "130°"`.
     - Update the width verification calculation to measure composite row width: `(label as NSString).size(withAttributes: [.font: labelFont]).width + 2.0 + (value as NSString).size(withAttributes: [.font: monoFont]).width`.
   - `testTempRowTintsFollowNetworkPrimaryByDesign` (`:444-486`):
     - Keeps the same tint mapping check (`case .primary, .warning, .critical: Color.primary`).

3. **`StatsLiteTests/MenuBarValueTypographyTests.swift`**:
   - Extend `testLabelFontIsEightPointRegularSecondary` (`:219-245`) or add `testTempBlockLabelsAreEightPointRegularSecondary` to assert that `MenuBarTempBlockView` declares `.font(.system(size: 8, weight: .regular))` and `.foregroundStyle(.secondary)` on its label text.
   - Add `MenuBarTempBlockView` to `testBlockFittingHeightsAreEqualAndMatchStatusBarThickness` (`:494-550`) to verify fitting height computes to exactly `22.0 pt`.

---

## 6. Numbered Visual Acceptance Checklist (VAC)

- **VAC-1**: `MenuBarTempBlockView` line 1 displays label `CPU` and line 2 displays label `GPU` with font `.system(size: 8, weight: .regular)`, matching standard category labels in size and weight.
- **VAC-2**: `MenuBarTempBlockView` labels `CPU` and `GPU` display with `.secondary` foreground style in both dark and light appearances, matching standard category label color.
- **VAC-3**: `MenuBarTempBlockView` degree values display with font `.system(size: 9, weight: .regular).monospacedDigit()`, matching Network block numeric rate styling.
- **VAC-4**: Readable temperature values display in `Color.primary` (`NSColor.labelColor`), rendering bright white in dark appearance and black/graphite in light appearance.
- **VAC-5**: Unavailable temperature values render `--°` in `Color(nsColor: .tertiaryLabelColor)` without hiding the block or altering row layout.
- **VAC-6**: Each row aligns label and degree value on `.firstTextBaseline` with exactly 2 pt horizontal spacing between label and value.
- **VAC-7**: Total fitting height of `MenuBarTempBlockView` computes to exactly 22.0 pt (two 11.0 pt rows), matching status bar thickness without clipping.
- **VAC-8**: Clamp-maximum readings (`CPU 130°` and `GPU 130°`) fit within `MenuBarLayout.tempBlockWidth` (50 pt) with at least 8.0 pt clearance and zero line wrapping.
- **VAC-9**: VoiceOver composite accessibility label continues to announce `"Temperature: CPU 84 degrees, GPU 61 degrees"` without regressions.
- **VAC-10**: Neither `MenuBarTempBlockView` nor its child views use `.animation` or `.contentTransition`.
