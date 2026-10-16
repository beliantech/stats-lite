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
