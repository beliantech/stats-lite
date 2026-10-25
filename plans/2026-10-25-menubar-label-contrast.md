# 2026-10-25 Menubar Label Contrast

## Background / baseline (measured)

- User report (v1.0.1, MacBook Air, dark mode): menu bar labels CPU, MEM, GPU — and the TEMP labels C, G — render dark gray with too little contrast. Screenshot: `/var/folders/2r/gfzr0pms3bb5cyshql2g22900000gn/T/herdr-clipboard-images-501/client-2-clipboard-1792916300868152000-0.png`.
- Root attribution (designer measurements, receipts in the designer session 2026-10-25T08-19-55):
  - The five labels use `.font(.system(size: 8, weight: .regular))` + `.foregroundStyle(.secondary)` (`StatsLite/MenuBarStackedItemView.swift`, 3 sites: `MenuBarBlockView`, `MenuBarTempBlockView` ×2).
  - Rendered peak label ink on the dark teal menu bar (`#014B52`): `(124,124,124)` → contrast **2.38:1**, below WCAG AA 4.5:1. 8 pt regular strokes antialias down to ~45 % peak alpha even though `secondaryLabelColor` is white 0.55 alpha in `.darkAqua`.
- Current DESIGN.md rule (the source of the defect): "Menu bar metric labels must use 8 pt regular text with secondary foreground style."

## Goal / target state

- Target: the five labels render **white at 80 % opacity** in dark appearance and **black at 75 % opacity** in light appearance, through one shared modifier. Measured target contrast: 6.92:1 on dark teal, 11.03:1 on dark gray, 9.43:1 on light gray (blueprint §"Measured Contrast Defect" → "Target Behavior").
- Single deviation (one per subsection): **the label treatment only** — the foreground moves to `Color.menuBarLabel` through `.menuBarMetricLabel()`, which also carries `.lineLimit(1)` (already present on the TEMP labels, new on CPU/MEM/GPU; blueprint §2.A), plus updating the now-stale "secondary" doc comments (`MenuBarStackedItemView.swift` lines 242/244, `MenuBarBlockModel.swift` line 198). Fonts (8 pt regular / 9 pt temp values), block widths (27 / 36 / 50 pt), row heights (11 pt), offsets (`y: -0.5`), tints, and every network/value color stay unchanged.
- Scope: `StatsLite/DesignTokens.swift`, `StatsLite/MenuBarStackedItemView.swift`, `DESIGN.md`, tests in `StatsLiteTests/MenuBarValueTypographyTests.swift` and `StatsLiteTests/MenuBarRenderSnapshotTests.swift`.

## Falsification signature (H0)

- H0: the low contrast comes from `.foregroundStyle(.secondary)` on 8 pt text, not from the background or the font.
- Measurement context: the only deterministic probe renders through the offscreen harness over a pinned 50 % gray background (`MenuBarRenderHarness.backgroundLuminance = 127.5`), not over the live teal bar. The live-teal reading (`124,124,124`, 2.38:1) is baseline context (D1) only — never a test threshold.
- If H0, then replacing the label style with `Color.menuBarLabel` raises the forced-`.darkAqua` CPU label **peak pixel luminance over the harness background** (ISC-7, 0–255 sRGB) from the T1 red measurement `V_red` (unverified prior ≈ 186: designer's effective alpha ≈ 0.46 over gray) to at least `T`, the ISC-7 threshold derived in T1.2 from `V_red` and the expected green render (unverified prior ≈ 213), with every geometry test unchanged.
- If the green run does not clear `T`, H0 is dead: the defect is elsewhere (background or font); this plan stops and reports instead of moving thresholds.

## Designer deliverable (5-part Design Blueprint, verbatim)

```markdown
# 5-Part Design Blueprint: Menu Bar Metric Label Contrast

## Executive Summary & Problem Diagnosis

Visual inspection of the user screenshot (`/var/folders/2r/gfzr0pms3bb5cyshql2g22900000gn/T/herdr-clipboard-images-501/client-2-clipboard-1792916300868152000-0.png`) confirms low contrast on macOS menu bar metric labels.

- **Current Behavior**: In dark appearance (`.darkAqua`), metric category labels ("CPU", "MEM", "GPU") and temperature subsystem labels ("C", "G") use 8 pt regular text with `.foregroundStyle(.secondary)`. In `NSAppearanceNameDarkAqua`, `.secondary` resolves to `NSColor.secondaryLabelColor` (white at 54.9% alpha). Because 8 pt regular glyph strokes are thin (~0.6 pt width), rasterization antialiasing attenuates stroke centers to ~45% peak alpha and ~35% average alpha.
- **Measured Contrast Defect**: Over the user dark teal menu bar (`#014B52`, relative luminance `L = 0.055`), the sampled label ink pixel (`124, 124, 124`, `L = 0.20`) yields a contrast ratio of only **2.38:1**. This violates the WCAG 2.2 AA minimum contrast threshold of 4.5:1. The label appears as a dim, muddy, dark gray smudge.
- **Target Behavior**: Metric category labels must render in crisp white with 80% opacity (`#FFFFFF` at alpha `0.80`) in dark appearance, and 75% black (`#000000` at alpha `0.75`) in light appearance. This adaptive treatment provides **6.92:1** contrast on dark teal, **11.03:1** on dark gray (`#1E1E1E`), and **9.43:1** on light gray (`#EBEBEB`), exceeding WCAG 2.2 AA in all modes while preserving visual subordination to primary metric values.

---

## 1. Visual Hierarchy & ASCII Wireframe

### Menu Bar Block Visual Hierarchy (Dark Mode)

```
+---------------------------------------------------------------------------------------------------+
| macOS Menu Bar (Translucent Dark Background, e.g. #014B52 or #1E1E1E)                             |
|                                                                                                   |
|  [Standard Block: CPU]       [Standard Block: MEM]       [Temp Block: C/G]      [Network Block]  |
|  Frame: 27 pt                Frame: 27 pt                Frame: 36 pt           Frame: 50 pt     |
|                                                                                                   |
|  Row 1 (11 pt height):       Row 1 (11 pt height):       Row 1 (11 pt height):  Row 1:           |
|  ..........................  ..........................  .....................  ................ |
|  :                     CPU:  :                 *4pt MEM:  : C 84°             :  : *5pt 11 KB/s  : |
|  :  8 pt Regular          :  :  4 pt dot + 8 pt Regular:  : 8 pt Reg + 9pt Mo :  : 5pt dot+9pt Mo: |
|  :  White 80% Opacity     :  :  White 80% Opacity      :  : White 80% Opacity  :  : Primary Red  : |
|  :  Contrast 6.9:1 (PASS) :  :  Contrast 6.9:1 (PASS)  :  : Contrast 6.9:1 (P) :  : Contrast 7+:1 : |
|  ..........................  ..........................  .....................  ................ |
|                                                                                                   |
|  Row 2 (11 pt height):       Row 2 (11 pt height):       Row 2 (11 pt height):  Row 2:           |
|  ..........................  ..........................  .....................  ................ |
|  :                     13%:  :                      49%:  : G 61°             :  : *5pt 15 KB/s  : |
|  :  12 pt Monospaced      :  :  12 pt Monospaced       :  : 8 pt Reg + 9pt Mo :  : 5pt dot+9pt Mo: |
|  :  Primary (100% White)  :  :  Primary (100% White)   :  : White 80% Opacity  :  : Primary Cyan : |
|  :  yOffset: -1 pt        :  :  yOffset: -1 pt         :  : (G label row 2)    :  : Contrast 7+:1 : |
|  ..........................  ..........................  .....................  ................ |
+---------------------------------------------------------------------------------------------------+
```

### Contrast Comparison Matrix

| Element | Size & Weight | Background Context | Before (`.secondary`) | After (`Color.menuBarLabel`) | WCAG AA Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Labels (CPU, MEM, GPU, C, G)** | 8 pt Regular | Dark Teal (`#014B52`) | 2.38:1 (Measured) | **6.92:1** | **PASS** (>= 4.5:1) |
| **Labels (CPU, MEM, GPU, C, G)** | 8 pt Regular | Dark Charcoal (`#1E1E1E`) | 3.85:1 | **11.03:1** | **PASS** (>= 4.5:1) |
| **Labels (CPU, MEM, GPU, C, G)** | 8 pt Regular | Light Menu Bar (`#EBEBEB`) | 4.55:1 | **9.43:1** | **PASS** (>= 4.5:1) |
| **Values (13%, 49%, 16%)** | 12 pt Regular Mono | Dark Teal / Dark Charcoal | > 7.5:1 | > 7.5:1 (Unchanged) | **PASS** (>= 4.5:1) |
| **Temperature Readings (84°, 61°)** | 9 pt Regular Mono | Dark Teal / Dark Charcoal | > 7.5:1 | > 7.5:1 (Unchanged) | **PASS** (>= 4.5:1) |

---

## 2. Template / Component Skeleton

The design requires changes in two source files:
1. `StatsLite/DesignTokens.swift`: Define `Color.menuBarLabel` and the `MenuBarMetricLabelStyle` view modifier.
2. `StatsLite/MenuBarStackedItemView.swift`: Apply `.menuBarMetricLabel()` to all five category labels.

### A. Design Tokens Definition (`StatsLite/DesignTokens.swift`)

```swift
extension Color {
    /// Adaptive menu bar category label color: 80% white in dark appearance
    /// for crisp contrast on dark and colorful translucent menu bars,
    /// 75% black in light appearance for crisp contrast on light menu bars.
    static let menuBarLabel = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.80)
            : NSColor.black.withAlphaComponent(0.75)
    })
}

/// Menu bar metric category label style: 8 pt regular text with the
/// adaptive menuBarLabel foreground style and lineLimit(1).
struct MenuBarMetricLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 8, weight: .regular))
            .foregroundStyle(Color.menuBarLabel)
            .lineLimit(1)
    }
}

extension View {
    /// Applies the standard 8 pt regular typography and adaptive high-contrast
    /// color to a menu bar metric category label.
    func menuBarMetricLabel() -> some View {
        modifier(MenuBarMetricLabelStyle())
    }
}
```

### B. Standard Metric Block Skeleton (`StatsLite/MenuBarStackedItemView.swift: MenuBarBlockView`)

```swift
struct MenuBarBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                if let dotState = block.dotState {
                    Circle()
                        .fill(dotState.levelColor)
                        .frame(width: 4, height: 4)
                        .offset(y: -0.5)
                }
                Text(block.label)
                    .menuBarMetricLabel()
            }
            .frame(height: MenuBarLayout.rowHeight)

            Text(block.valueText)
                .font(.system(size: 12, weight: .regular).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .padding(.trailing, 0.5)
                .frame(height: MenuBarLayout.rowHeight)
                .offset(y: MenuBarLayout.valueYOffset)
        }
        .frame(width: block.width, alignment: .trailing)
    }
    // ... valueColor remains unchanged ...
}
```

### C. Temperature Block Skeleton (`StatsLite/MenuBarStackedItemView.swift: MenuBarTempBlockView`)

```swift
struct MenuBarTempBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Line 1: CPU die temperature
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(block.label)
                    .menuBarMetricLabel()
                    .offset(y: -0.5)

                Text(block.valueText)
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)

            // Line 2: GPU die temperature
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(block.secondaryLabel ?? "G")
                    .menuBarMetricLabel()
                    .offset(y: -0.5)

                Text(block.secondaryValueText ?? "--°")
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(secondaryValueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)
        }
        .frame(width: block.width)
    }
    // ... valueColor and secondaryValueColor remain unchanged ...
}
```

---

## 3. Complete State & Responsive Matrix

| State / Appearance | Visual Description | Color Token Specification | Geometry / Alignment Invariants |
| :--- | :--- | :--- | :--- |
| **Dark Appearance (`.darkAqua`)** | Crisp white text against translucent dark menu bar. High legibility over dark teal wallpapers. | `Color.menuBarLabel` resolves to `NSColor.white.withAlphaComponent(0.80)` (`rgba(255, 255, 255, 0.80)`). | Font: 8 pt regular. Frame height: 11 pt. No animation. Zero layout shifts. |
| **Light Appearance (`.aqua`)** | Crisp black text against translucent light menu bar. High legibility on light wallpapers. | `Color.menuBarLabel` resolves to `NSColor.black.withAlphaComponent(0.75)` (`rgba(0, 0, 0, 0.75)`). | Font: 8 pt regular. Frame height: 11 pt. No animation. Zero layout shifts. |
| **RAM Pressure Warning / Critical** | MEM label keeps adaptive color. 4 pt pressure dot changes to yellow or red. | Label: `Color.menuBarLabel`. Dot: `levelColor` (`systemYellow` / `systemRed`). | Dot sits 2 pt left of "MEM". Optical y-offset: -0.5 pt on dot. |
| **Metric Warning (>= 80%) / Critical (>= 95%)** | Category label keeps constant adaptive color. Value line 2 changes to orange or red. | Label: `Color.menuBarLabel`. Value: `systemOrange` or `systemRed`. | Block width pins to 27 pt. Value trailing inset: 0.5 pt. |
| **Unavailable / Cold Metric (`--%`, `--°`)** | Category label keeps constant adaptive color. Missing value renders tertiary gray. | Label: `Color.menuBarLabel`. Value: `tertiaryLabelColor`. | Block width pins to 27 pt (standard) or 36 pt (TEMP). |
| **Status Item Clicked / Highlighted** | Menu bar button enters highlighted state. Popover opens. | Status button handles click. Label appearance inherits button selection. | Debounce window: 0.25 s on dismissal. No layout resizing on click. |

---

## 4. Accessibility (WCAG 2.2) & Interaction Contracts

### WCAG 2.2 Contracts
- **SC 1.4.3 Contrast (Minimum - Level AA)**: Text under 18 pt requires contrast of at least 4.5:1 against its background.
  - Dark mode over `#014B52` (user teal wallpaper): `6.92:1` (Exceeds 4.5:1).
  - Dark mode over `#1E1E1E` (standard dark menu bar): `11.03:1` (Exceeds 4.5:1).
  - Light mode over `#EBEBEB` (standard light menu bar): `9.43:1` (Exceeds 4.5:1).
- **Target Size (Minimum - SC 2.5.8 Level AA)**: The interactive target is the status bar button. The hosting view uses `PassthroughHostingView` with `hitTest(_:) -> nil`. All clicks pass to `NSStatusBarButton` which spans the full status item frame (`height = 22 pt`, width >= 27 pt), matching macOS platform menu bar standards.
- **VoiceOver & Screen Readers**: The stacked visual views carry `.accessibilityHidden(true)`. The status button accessibility element provides a localized composite description via `MenuBarAccessibility.compositeLabel(...)`.

---

## 5. DESIGN.md Rule Specification

The current rule for `DESIGN.md`:
```markdown
# Design

- Menu bar metric labels must use 8 pt regular text with secondary foreground style.
- This rule covers the CPU, MEM, and GPU labels and the two-row TEMP labels C and G.
```

### Revised Rule for `DESIGN.md`
```markdown
# Design

- Menu bar metric labels must use 8 pt regular text with the adaptive `Color.menuBarLabel` foreground style.
- The label color renders 80% white in dark appearance and 75% black in light appearance.
- This rule covers the CPU, MEM, and GPU labels and the two-row TEMP labels C and G through `.menuBarMetricLabel()`.
```

---

## 6. Deterministic Unit-Test Specification

The implementation must verify across three deterministic test layers:

### Layer 1: Source Token Assertions (`StatsLiteTests/MenuBarValueTypographyTests.swift`)

1. Update `expectedLabelStyle` in `MenuBarValueTypographyTests.swift`:
   ```swift
   /// `.menuBarMetricLabel()`
   private let expectedLabelModifier = ".menuBarMetricLabel()"
   ```
2. Update `testLabelFontIsEightPointRegularSecondary`:
   - Rename to `testLabelAppliesSharedMenuBarMetricLabelModifier()`.
   - Verify that the scope between `Text(block.label)` and `Text(block.valueText)` in `MenuBarBlockView` contains `.menuBarMetricLabel()`.
   - Verify that `MenuBarStackedItemView.swift` contains zero instances of `.foregroundStyle(.secondary)`.
3. Update `testTempBlockLabelsAreEightPointRegularSecondary`:
   - Rename to `testTempBlockLabelsApplySharedMenuBarMetricLabelModifier()`.
   - Verify that `Text(block.label)` and `Text(block.secondaryLabel` in `MenuBarTempBlockView` each carry `.menuBarMetricLabel()`.
4. Add token guard for `DesignTokens.swift`:
   - Verify that `MenuBarMetricLabelStyle` declares `.font(.system(size: 8, weight: .regular))`.
   - Verify that `MenuBarMetricLabelStyle` declares `.foregroundStyle(Color.menuBarLabel)`.

### Layer 2: Dynamic Programmatic Color Assertions (`StatsLiteTests/MenuBarValueTypographyTests.swift`)

Add a unit test verifying exact dynamic color resolution in both appearances:

```swift
func testMenuBarLabelAdaptiveColorResolvesTargetOpacityInBothAppearances() throws {
    let darkAppearance = try XCTUnwrap(NSAppearance(named: .darkAqua))
    var darkColor: NSColor?
    darkAppearance.performAsCurrentDrawingAppearance {
        darkColor = NSColor(Color.menuBarLabel).usingColorSpace(.deviceRGB)
    }
    let unwrappedDark = try XCTUnwrap(darkColor)
    XCTAssertEqual(unwrappedDark.redComponent, 1.0, accuracy: 0.01)
    XCTAssertEqual(unwrappedDark.greenComponent, 1.0, accuracy: 0.01)
    XCTAssertEqual(unwrappedDark.blueComponent, 1.0, accuracy: 0.01)
    XCTAssertEqual(unwrappedDark.alphaComponent, 0.80, accuracy: 0.01)

    let lightAppearance = try XCTUnwrap(NSAppearance(named: .aqua))
    var lightColor: NSColor?
    lightAppearance.performAsCurrentDrawingAppearance {
        lightColor = NSColor(Color.menuBarLabel).usingColorSpace(.deviceRGB)
    }
    let unwrappedLight = try XCTUnwrap(lightColor)
    XCTAssertEqual(unwrappedLight.redComponent, 0.0, accuracy: 0.01)
    XCTAssertEqual(unwrappedLight.greenComponent, 0.0, accuracy: 0.01)
    XCTAssertEqual(unwrappedLight.blueComponent, 0.0, accuracy: 0.01)
    XCTAssertEqual(unwrappedLight.alphaComponent, 0.75, accuracy: 0.01)
}
```

### Layer 3: Offscreen Render Luminance Probe (`StatsLiteTests/MenuBarRenderSnapshotTests.swift`)

Add a forced-appearance luminance probe for label ink:

```swift
func testMenuBarLabelLuminanceDeltaUnderBothForcedAppearances() throws {
    let blocks = try builtBlocks()
    var labelLuminance: [NSAppearance.Name: Double] = [:]
    for appearance in appearances {
        let bitmap = MenuBarRenderHarness.render(
            MenuBarBlockView(block: blocks.cpu),
            appearance: appearance
        )
        // Measure CPU label ink luminance across line 1
        let mean = try XCTUnwrap(
            bitmap.meanInkLuminance(
                columns: 1..<bitmap.pixelsWide,
                yRange: line1,
                threshold: inkThreshold
            ),
            "no CPU label ink under \(appearance.rawValue)"
        )
        labelLuminance[appearance] = mean
    }
    let dark = try XCTUnwrap(labelLuminance[.darkAqua])
    let light = try XCTUnwrap(labelLuminance[.aqua])
    let delta = abs(dark - light)
    XCTAssertGreaterThanOrEqual(
        delta,
        40.0,
        "label luminance delta \(delta) must meet or exceed 40 between dark and light appearances"
    )
    XCTAssertGreaterThan(dark, light, "dark appearance label ink must be lighter than light appearance ink")
}
```

---

## 7. Numbered Visual Acceptance Checklist (VAC)

- **VAC-1**: In dark appearance (`.darkAqua`), the category labels "CPU", "MEM", and "GPU" render with `Color.menuBarLabel` resolving to white with 80% opacity (`rgba(1.0, 1.0, 1.0, 0.80)`), verified against baseline screenshot `/var/folders/2r/gfzr0pms3bb5cyshql2g22900000gn/T/herdr-clipboard-images-501/client-2-clipboard-1792916300868152000-0.png`.
- **VAC-2**: In dark appearance (`.darkAqua`), the two-row temperature subsystem labels "C" and "G" render with `Color.menuBarLabel` resolving to white with 80% opacity (`rgba(1.0, 1.0, 1.0, 0.80)`).
- **VAC-3**: In light appearance (`.aqua`), all five labels ("CPU", "MEM", "GPU", "C", "G") adaptively resolve to black with 75% opacity (`rgba(0.0, 0.0, 0.0, 0.75)`).
- **VAC-4**: In both dark and light appearances, all five labels maintain WCAG 2.2 AA contrast ratio >= 4.5:1 against standard macOS menu bar backgrounds and saturated wallpapers.
- **VAC-5**: All five labels ("CPU", "MEM", "GPU", "C", "G") receive typography and color styling from the single shared modifier `.menuBarMetricLabel()`.
- **VAC-6**: Standard metric blocks pin to width 27 pt (`MenuBarLayout.blockWidth`) and temperature blocks pin to width 36 pt (`MenuBarLayout.tempBlockWidth`) with zero frame size shifts resulting from the label style change.
- **VAC-7**: Line 1 frame height remains exactly 11 pt (`MenuBarLayout.rowHeight`) and total block fitting height remains exactly 22 pt matching `NSStatusBar.system.thickness`.
- **VAC-8**: Temperature labels "C" and "G" retain `.offset(y: -0.5)` optical baseline alignment with the 9 pt degree values.
- **VAC-9**: `StatsLite/MenuBarStackedItemView.swift` contains zero references to `.foregroundStyle(.secondary)`.
- **VAC-10**: Offscreen bitmap render tests in `MenuBarRenderSnapshotTests` pass with label ink luminance delta >= 40 between forced `.darkAqua` and `.aqua` appearances.
```

## Acceptance criteria (from VAC, verbatim mapping)

Designer VAC quoted above, verbatim. Numbered ACs:

1. (VAC-1) Dark appearance: CPU, MEM, GPU labels = white 0.80 alpha (`Color.menuBarLabel` resolution), asserted by the Layer-2 color test and the dark-mode peak-luminance probe (ISC-7).
2. (VAC-2) Dark appearance: C and G labels = white 0.80 alpha, asserted by the Layer-1 TEMP token test + Layer-2 color test.
3. (VAC-3) Light appearance: all five labels = black 0.75 alpha, asserted by Layer-2 color test.
4. (VAC-4) Contrast ≥ 4.5:1 in both appearances: hold by computation from AC-1/AC-3 over the measured backgrounds (designer receipts: 6.92 / 11.03 / 9.43:1); live screenshot check in QC-T4.
5. (VAC-5) All five label sites use the single `.menuBarMetricLabel()` modifier; no label carries its own font/foreground pair — asserted by Layer-1 source tests.
6. (VAC-6) Block widths unchanged: 27 / 36 / 50 pt frames — existing `MenuBarBlockBuilderTests` + layout tests stay green.
7. (VAC-7) Row height 11 pt, block fitting height 22 pt — existing render tests stay green.
8. (VAC-8) TEMP labels keep `.offset(y: -0.5)` — existing `testTempBlockLabelsApplyVerticalOpticalOffset` stays green.
9. (VAC-9) `MenuBarStackedItemView.swift` has zero `.foregroundStyle(.secondary)` — asserted by Layer-1 test.
10. (VAC-10) `MenuBarRenderSnapshotTests` fully green including the new label luminance delta probe (delta ≥ 40, dark > light). Its red value is recorded in D2; because `.secondary` already adapts, the red delta may already clear 40 (est. 34–98, unverified prior) — then this probe stands as a regression net, documented "already-green in red", and ISC-7 carries the guaranteed red.

Out of scope (unchanged, regression-guarded): value colors (`.primary`/tertiary/warning/critical), network dots (`networkUpload`/`networkDownload`), MEM pressure dot, all widths/offsets/heights, popover UI, no `.animation`/`.contentTransition` on the status item path.

## Tasks

### T1 red — deterministic tests first (no production-code edits)

Falsification for T1: if a supposed red test passes on current code (or no test fails), the plan proved nothing — recalibrate per the clauses below before any green code.

- [x] T1.1 In a worktree (git-worktree skill, branch e.g. `menubar-label-contrast`), `StatsLiteTests/MenuBarValueTypographyTests.swift`: apply blueprint Layer 1 — rename the label constant to `expectedLabelModifier = ".menuBarMetricLabel()"`, assert `.menuBarMetricLabel()` at all five label sites, assert zero `.foregroundStyle(.secondary)` in `MenuBarStackedItemView.swift`, add the `DesignTokens.swift` token guard (8 pt regular + `Color.menuBarLabel`). **Delete** the in-body label `expectedLabelFont` assertions from `testLabelFontIsEightPointRegularSecondary` and `testTempBlockLabelsAreEightPointRegularSecondary` (they re-added only inside `DesignTokens.swift` after T2, so the token guard owns that coverage — keeping them in-body would make green impossible). Rename per blueprint.
- [x] T1.2 `StatsLiteTests/MenuBarRenderSnapshotTests.swift`: (a) add blueprint Layer 3 — `testMenuBarLabelLuminanceDeltaUnderBothForcedAppearances` (delta ≥ 40, dark > light), but first record its red delta; the harness background is fixed gray and `.secondary` already adapts, so red may already pass (est. 34–98, unverified prior) — if so, mark it "already-green regression net" in D2 and it is not the red. (b) Add the guaranteed-red probe as **ISC-7** (ISC-1…6 are taken in this file): forced-`.darkAqua` render of `MenuBarBlockView(block: cpu)` via `MenuBarRenderHarness`, assert **peak pixel luminance (0–255 sRGB)** in the line-1 label region ≥ `T`. Calibration: run once on red code to measure `V_red` (unverified prior ≈ 186 — the live-teal 124 does not transfer to gray 127.5); set `T` strictly above `V_red` and ≥ 8 below the expected green render (prior ≈ 213); if `V_red` leaves no room, probe the actual defect instead (composite a teal background inside the test and measure there — no harness change) and re-run red; record `V_red`, `T`, and the formula in D2. Units: luminance, never ink-distance (ink-distance over gray cannot reach 165).
- [x] T1.3 Run red **without Layer 2 yet** (Layer 2 references `Color.menuBarLabel`, which does not exist; a compile error would sink the whole test target and make per-test receipts unproducible): `xcodebuild test -project StatsLite.xcodeproj -scheme StatsLite -only-testing:StatsLiteTests/MenuBarValueTypographyTests -only-testing:StatsLiteTests/MenuBarRenderSnapshotTests -only-testing:StatsLiteTests/MenuBarTempBlockTests`. Receipt: Layer-1 tests fail, ISC-7 fails printing `V_red`, Layer-3 probe result recorded (red or "already-green"), all pre-existing tests still green. Commit red state (`test(menu-bar): red ...`, git-commit skill).
- [x] T1.4 Add blueprint Layer 2 last — `testMenuBarLabelAdaptiveColorResolvesTargetOpacityInBothAppearances` (dark → white 0.80, light → black 0.75). Its red is the compiler error ("Type 'Color' has no member 'menuBarLabel'"); capture that output as its own D2 receipt and commit.
- [x] T1 QC-T1 plan-review GO — reviewer checks: red tests exist and fail for the right reason; thresholds trace to measurements taken **in the probe harness**; Layer-2 red is sequenced last; one deviation only; every AC testable; no invented facts.

### T2 green — production code + DESIGN.md (single scope, T1 done and committed)

Falsification for T2: after the change, ISC-7 peak luminance must clear `T` (the threshold derived in T1.2 from the red measurement `V_red`). If it does not, H0 is false — stop, report, do not adjust thresholds.

- [x] T2.1 `StatsLite/DesignTokens.swift`: add `Color.menuBarLabel` (dynamic `NSColor(name:)` — 80 % white on `.darkAqua`, 75 % black on `.aqua`), `MenuBarMetricLabelStyle` (8 pt regular + `Color.menuBarLabel` + `lineLimit(1)`), and `View.menuBarMetricLabel()` exactly per blueprint §2.A. This also makes Layer 2 compile again.
- [x] T2.2 `StatsLite/MenuBarStackedItemView.swift`: replace the three label style pairs (CPU/MEM/GPU in `MenuBarBlockView`; C and G in `MenuBarTempBlockView`) with `.menuBarMetricLabel()`. Keep `.offset(y: -0.5)` on the TEMP labels. Zero `.foregroundStyle(.secondary)` left in this file. Update the two stale "secondary" doc comments (lines 242/244). No other line changes.
- [x] T2.3 `DESIGN.md`: apply blueprint §5 revised rule (verbatim replacement); update the stale "secondary" comment at `MenuBarBlockModel.swift:198`.
- [x] T2.4 Run the full suite: `xcodebuild test -project StatsLite.xcodeproj -scheme StatsLite`. Receipt: all tests green including every T1 red; record ISC-7's green peak luminance (must clear `T`; prior ≈ 213 vs red `V_red` ≈ 186) and the Layer-3 delta (≥ 40, or documented already-green). Commit (`fix(menubar): raise menu bar label contrast with adaptive white/black token`).

### Integration task (one deviation integrated)

- [x] TI.1 Verify the integrated result: full suite green on one commit; ISC = forced-`.darkAqua` offscreen render shows CPU label peak luminance ≥ `T` (red `V_red` < `T`, both recorded in D2/D3) while every geometry test (27/36/50 pt widths, 11 pt rows, 22 pt fitting) stays green — one observable behavior moved, geometry provably did not. Receipt: test output + `git diff --stat`.

## QC tasks (after T2 green; QC-T1 runs earlier at end of T1)

- [x] QC-T2 tester — full `xcodebuild test` run; verify every AC test exists and passes; cross-check plan ledger receipts against test names. Report (item, state, evidence).
- [x] QC-T3 reviewer — VAC-1..10 against the verbatim blueprint: `scripts/capture_menubar.sh` dark-mode screenshot from the **main checkout** (the script is committed there; live spot check needs unlocked screen + awake display — AGENTS.md), plus code reading for AC-5/AC-6/AC-8/AC-9. Report per-VAC GO/NO-GO (items, state, evidence).
- [x] QC-T4 designer receipt — designer re-checks the screenshot vs VAC-1..4 (contrast) and reports GO/NO-GO with receipts; runs **in parallel with QC-T3** (a NO-GO routes to the designer first). Also confirm or correct the D1 baseline pixel: a neutral `(124,124,124)` is inconsistent with a white-over-`#014B52` blend (should be teal-tinted); the luminance reading 124 is what the contrast math uses — state which is right in the receipt.
- [x] QC-T5 git-worktree cleanup after merge (skill rules).

## Plan ledger (record as work proceeds)

- D1 baseline (done): user screenshot; label peak ink `(124,124,124)` over `#014B52` → 2.38:1; secondary renders white 0.55 alpha / ~0.45 peak in `.darkAqua`; current DESIGN.md rule names `.secondary`. Designer session: 2026-10-25T08-19-55 (blueprint + measurements).
- D2 red (done, commits b4234b9 + 03f648d): Layer-1 source assertions failed (VAC-5 ×3 regions, VAC-9 count 3≠0), token guard XCTUnwrap failed; ISC-7 `V_red = 198.0`, `T = 201`, formula `floor((V_red + 205) / 2)`; Layer-3 delta = 90.32 → **already-green regression net**; Layer-2 red = compiler error `type 'Color' has no member 'menuBarLabel'`. Red run: 41 tests, 6 failures in the 4 intended tests, TempBlockTests 9/9 green. Plan-review GO on red.
- D3 green (done, commit 3f72627): full suite 441 tests, 0 failures (caffeinate); ISC-7 green peak luminance = 230.0 ≥ 201 (198 → 230, H0 confirmed); Layer-3 green delta = 131.37 (dark 195.97 / light 64.60); DESIGN.md rule replaced per blueprint §5.
- D4 (done): QC-T2 tester PASS ×6 (thresholds byte-identical red→HEAD, diff = exactly 4 files, AC-4 math reproduced); QC-T3 reviewer GO on VAC-1..10 (live capture blocked by the user's running StatsLite — offscreen render evidence per AGENTS.md); QC-T4 designer GO (VAC-1..10; D1 baseline `(124,124,124)` clarified as untinted grayscale shorthand for scalar luminance — true blend is teal-tinted `(117,158,162)`; both readings fail AA, claim unchanged). Merged `--ff-only` to main: **3f72627**.
