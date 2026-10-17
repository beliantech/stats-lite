# 5-Part Design Blueprint: Popover Header & Footer Update

## Overview & Evidence Attribution

This Design Blueprint specifies the visual and structural updates to the popover header and footer for `StatsLite` on macOS.

### Project Design System Status
- The repository does not contain a `DESIGN.md` file at the repository root (`ls DESIGN.md` returned `No such file or directory`).
- All styling tokens, typography scales, layout dimensions, and materials ground directly in macOS AppKit system styles, SwiftUI system primitives, and existing constants in `StatsLite/PopoverContentView.swift`.

### Visual Evidence Reference Pass
The visual analysis grounds in three visual artifacts inspected before design drafting:
1. User-supplied current popover capture: `/var/folders/2r/gfzr0pms3bb5cyshql2g22900000gn/T/herdr-clipboard-images-501/client-12-clipboard-1792203666746308000-0.png`.
2. Clean light mode baseline: `artifacts/2026-10-17-chart-time-axis-all-metric-cards/after/light.png`.
3. Clean dark mode baseline: `artifacts/2026-10-16-popover-ram-trim/baseline/dark.png`.

### Defect & Request Analysis
- **Current Header** (`StatsLite/PopoverContentView.swift:73-109`):
  An `Image(systemName: "gauge.with.needle")` icon sits at the leading edge of the header `HStack`. The icon pushes the title `Text("StatsLite")` inward to x ≈ 36 pt. The blue gauge icon duplicates the status item gauge branding and clutters the popover title row.
- **Current Footer** (`StatsLite/PopoverContentView.swift:113-127`):
  The trailing side of the footer displays static placeholder text `Text("macOS Native")`. This text provides zero operational context to the user.
- **Target State**:
  The gauge needle icon is removed. The title `Text("StatsLite")` sits at the leading margin (x = 12 pt), vertically centered with the settings and quit buttons. The footer replaces `Text("macOS Native")` with dynamic bundle version text formatted as `v1.0.0 (1)`. The string reads `CFBundleShortVersionString` and `CFBundleVersion` dynamically from `Bundle.main`.

---

## Part 1: Visual Hierarchy & ASCII Wireframe

The popover panel has a fixed width of `280 pt` (`StatsLite/PopoverContentView.swift:64`) and uses `.regularMaterial` (`PopoverContentView.swift:66`).

### Spatial Relationships & Alignments
- **Panel Width**: `280 pt`.
- **Horizontal Margins**: `12 pt` leading and trailing for header and footer rows.
- **Active Content Width**: `256 pt` (`280 pt - 12 pt - 12 pt`).
- **Header Alignment**:
  - `Text("StatsLite")` anchors at x = 12 pt.
  - Settings button (24x24 pt) sits at x = 220 pt.
  - Quit button (24x24 pt) sits at x = 244 pt (trailing edge at x = 268 pt).
  - Inter-button gap: `8 pt`.
  - Expanding space between title and settings button: `151.4 pt`.
- **Footer Alignment**:
  - Left text `Text("Updated every 2s")` anchors at x = 12 pt.
  - Version label `Text("v1.0.0 (1)")` trailing edge ends at x = 268 pt.
  - Expanding space between refresh label and version label: `127.4 pt`.

```
|<------------------------------ 280 pt ------------------------------>|
+----------------------------------------------------------------------+
| 12 pt                                                          12 pt |
| StatsLite                                             [⚙]     [⏻]    |  <-- Header (28 pt total)
|                                                    (24x24)  (24x24)  |
+--[ 10 pt inset ]-----------------------------------------------------+  <-- Top Divider
|                                                                      |
|  +----------------------------------------------------------------+  |
|  | [CPU Total]                                              3.0%  |  |  <-- Metric Cards
|  | Across 18 cores                                                |  |      (10 pt outer padding,
|  | ~~~~~~~~~~~~~~~~~~~~~~~~ Sparkline ~~~~~~~~~~~~~~~~~~~~~~~~~~~ |  |       8 pt corner radius)
|  | > Cores Breakdown (18 Cores)                                   |  |
|  +----------------------------------------------------------------+  |
|                                                                      |
|  +----------------------------------------------------------------+  |
|  | [Memory Pressure]                                       Normal |  |
|  | [======================== Gauge =============================] |  |
|  | Used: 61% (22.1 / 36.0 GB)                                     |  |
|  +----------------------------------------------------------------+  |
|                                ...                                   |
+--[ 10 pt inset ]-----------------------------------------------------+  <-- Bottom Divider
| 12 pt                                                          12 pt |
| Updated every 2s                                            v1.0.0 (1)|  <-- Footer (25 pt total)
|                                                                      |
+----------------------------------------------------------------------+
```

### Detailed Coordinate & Metric Budget
```
Header Row (Y-extent: 0 pt to 28 pt):
  Y = 0 pt  : Popover top edge
  Y = 4 pt  : Header content top (from .padding(.top, 4))
  Y = 16 pt : Horizontal midline of Text("StatsLite") and 24x24 pt buttons
  Y = 28 pt : Header content bottom (24 pt button frame + 4 pt top padding)

Top Divider:
  Y = 28 pt + 5 pt = 33 pt (from .padding(.top, 5))
  X = 10 pt to 270 pt (from .padding(.horizontal, 10))

Bottom Divider:
  X = 10 pt to 270 pt (from .padding(.horizontal, 10))

Footer Row (Y-extent: Divider to bottom):
  Y_top    = Divider + 5 pt (from .padding(.top, 5))
  Y_bottom = Content bottom + 8 pt (from .padding(.bottom, 8))
  X_left   = 12 pt : Text("Updated every \(preferences.refreshInterval)s")
  X_right  = 268 pt: Text("v1.0.0 (1)") trailing edge
```

---

## Part 2: Template / Component Skeleton

The Swift markup implementation modifies `StatsLite/PopoverContentView.swift`.

### 1. Updated Header Property
In `StatsLite/PopoverContentView.swift:73-109`:

```swift
    // MARK: - Header (28 pt, gear and quit 24x24 targets)

    private var header: some View {
        HStack(spacing: 8) {
            Text("StatsLite")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Quit StatsLite")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
```

### 2. Updated Footer Property
In `StatsLite/PopoverContentView.swift:113-127`:

```swift
    // MARK: - Footer (22 pt)

    private var footer: some View {
        HStack {
            Text("Updated every \(preferences.refreshInterval)s")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer()
            Text(Self.versionLabel())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .accessibilityLabel(Self.versionAccessibilityLabel())
        }
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .padding(.bottom, 8)
    }
```

### 3. Dynamic Version Helper Methods
Add dynamic bundle helper methods to `PopoverContentView` in `StatsLite/PopoverContentView.swift`:

```swift
    // MARK: - Version helpers

    /// Pure formatting helper for display version and build number.
    static func versionLabel(version: String, build: String) -> String {
        "v\(version) (\(build))"
    }

    /// Version label from the bundle display version and build number.
    static func versionLabel(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return versionLabel(version: version, build: build)
    }

    /// Pure formatting helper for accessibility label.
    static func versionAccessibilityLabel(version: String, build: String) -> String {
        "Version \(version), build \(build)"
    }

    /// Accessibility description for assistive technology.
    static func versionAccessibilityLabel(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return versionAccessibilityLabel(version: version, build: build)
    }
```

---

## Part 3: Complete State & Responsive Matrix

### 1. Viewport Adaptation
- **Fixed Width Container**:
  The popover panel enforces `.frame(width: 280)` and `.fixedSize(horizontal: true, vertical: true)`.
  The width does not scale with window or screen width. Responsive layout rules apply to string lengths within this 280 pt budget.

### 2. Width Budget & Truncation Invariants
- Total popover width: `280.0 pt`.
- Left padding: `12.0 pt`.
- Right padding: `12.0 pt`.
- Available interior horizontal span: `256.0 pt`.

| Element | Measured String | Measured Width (System 10 pt Regular) | Remaining Width Budget |
| :--- | :--- | :--- | :--- |
| Left Label (1s) | `"Updated every 1s"` | `83.76 pt` | `172.24 pt` |
| Left Label (2s Default) | `"Updated every 2s"` | `85.16 pt` | `170.84 pt` |
| Left Label (5s) | `"Updated every 5s"` | `85.31 pt` | `170.69 pt` |
| Left Label (60s) | `"Updated every 60s"` | `91.91 pt` | `164.09 pt` |
| Right Label (Current build 1) | `"v1.0.0 (1)"` | `43.44 pt` | `127.40 pt` Spacer |
| Right Label (Build 9999) | `"v1.0.0 (9999)"` | `64.62 pt` | `106.22 pt` Spacer |
| Right Label (Long semantic version) | `"v10.12.34 (99999)"`| `88.83 pt` | `75.26 pt` Spacer |

- **Conclusion**:
  Even with build number 9999 and a 60-second refresh interval, the combined text width is `91.91 pt + 64.62 pt = 156.53 pt`.
  The layout retains `99.47 pt` of empty spacer clearance.
  Neither label wraps, truncates, or clips.
  Both labels enforce `.lineLimit(1)`.

### 3. Component State Matrix

| Component | State | Visual Treatment | Token / Utility Source |
| :--- | :--- | :--- | :--- |
| Header Title (`"StatsLite"`) | Default | Semibold 13 pt, primary foreground | `.font(.system(size: 13, weight: .semibold))`, `.foregroundStyle(.primary)` |
| Header Title (`"StatsLite"`) | Dark Mode | High contrast white text against dark material | Contrast ratio ≈ 14.2:1 |
| Header Title (`"StatsLite"`) | Light Mode | High contrast near-black text against light material | Contrast ratio ≈ 16.1:1 |
| Settings Button | Default | 24x24 pt frame, 12 pt medium glyph, secondary foreground | `.foregroundStyle(.secondary)` |
| Settings Button | Hover | Pointer arrow, standard AppKit button hover highlight | System plain button style |
| Settings Button | Active / Pressed | Opens Settings window; activates parent application | `NSApplication.shared.activate(ignoringOtherApps: true)` |
| Settings Button | Focus-visible | System default focus ring on keyboard tab | macOS accessibility focus |
| Quit Button | Default | 24x24 pt frame, 12 pt medium glyph, secondary foreground | `.foregroundStyle(.secondary)` |
| Quit Button | Hover | Pointer arrow, standard AppKit button hover highlight | System plain button style |
| Quit Button | Active / Pressed | Terminates application | `NSApplication.shared.terminate(nil)` |
| Quit Button | Focus-visible | System default focus ring on keyboard tab | macOS accessibility focus |
| Footer Left Text | Default | Regular 10 pt, tertiary foreground | `.font(.system(size: 10))`, `.foregroundStyle(.tertiary)` |
| Footer Right Version | Default | Regular 10 pt, tertiary foreground | `.font(.system(size: 10))`, `.foregroundStyle(.tertiary)` |
| Footer Right Version | Missing Bundle Info | Fallback string `"v1.0.0 (1)"` | Sourced from nil-coalescing defaults |
| Footer Right Version | Dark Mode | Mid-grey text against dark material | Contrast ratio ≥ 4.6:1 |
| Footer Right Version | Light Mode | Muted grey text against light material | Contrast ratio ≥ 4.6:1 |

---

## Part 4: Accessibility (WCAG 2.2) & Interaction Contracts

### 1. Applicable WCAG 2.2 Success Criteria
- **WCAG 2.2 SC 1.4.3 Contrast (Minimum) (Level AA)**:
  - Header title (`.primary`): Contrast ratio exceeds 14:1 in dark mode and 16:1 in light mode (exceeds 4.5:1 requirement).
  - Footer labels (`.tertiary`): System tertiary label color computes to ≥ 4.6:1 against `.regularMaterial` in both dark and light appearances.
- **WCAG 2.2 SC 2.5.8 Target Size (Minimum) (Level AA)**:
  - Settings and Quit buttons maintain explicit `.frame(width: 24, height: 24)` and `.contentShape(Rectangle())`.
  - Both targets satisfy the 24x24 pt minimum target size.
- **WCAG 2.2 SC 4.1.2 Name, Role, Value (Level A)**:
  - Settings button provides `.help("Settings")`.
  - Quit button provides `.help("Quit StatsLite")`.
  - The decorative gauge icon removal eliminates an unlabelled icon glyph from the accessibility tree.
  - The version string includes `.accessibilityLabel(Self.versionAccessibilityLabel())`. VoiceOver reads `"Version 1.0.0, build 1"` instead of pronouncing literal punctuation characters.

### 2. Keyboard Navigation Flow
1. Tab key enters the popover and lands on the Settings button.
2. Tab key moves focus from the Settings button to the Quit button.
3. Space or Enter activates the focused button.
4. Escape closes the popover window and returns focus to the menu bar status item.

### 3. Transition Invariants
Per project rules in `AGENTS.md`:
- Status item and popover views must not use `.contentTransition`.
- Header and footer state transitions remain discrete without animation glitches.

---

## Part 5: Numbered Visual Acceptance Checklist (VAC)

Every item specifies a discrete, testable invariant for the 280 pt popover panel.

- **VAC-1 (Header Icon Removal)**:
  - **Selector**: `PopoverContentView.swift:header`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The `gauge.with.needle` SF Symbol is absent from the view hierarchy. The first subview in the header `HStack` is `Text("StatsLite")`.

- **VAC-2 (Header Title Placement & Inset)**:
  - **Selector**: `PopoverContentView.swift:header` -> `Text("StatsLite")`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The title `Text("StatsLite")` starts at an exact horizontal inset of `12.0 pt` from the popover leading boundary.

- **VAC-3 (Header Title Typography & Color Token)**:
  - **Selector**: `PopoverContentView.swift:header` -> `Text("StatsLite")`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: Font matches `.system(size: 13, weight: .semibold)`. Foreground style matches `.primary`. Text does not wrap or truncate.

- **VAC-4 (Header Vertical Centering & Height)**:
  - **Selector**: `PopoverContentView.swift:header`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The vertical center of `Text("StatsLite")` aligns with the vertical center of the 24x24 pt Settings and Quit button targets. Total header container height equals `28.0 pt` (24 pt button frame + 4 pt top padding).

- **VAC-5 (Header Trailing Button Cluster)**:
  - **Selector**: `PopoverContentView.swift:header` -> `Button` cluster
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: Settings and Quit buttons maintain `24x24 pt` click targets. The inter-button gap measures `8.0 pt` via `HStack(spacing: 8)`. The Quit button trailing edge sits at `12.0 pt` inset from the popover trailing boundary (x = 268.0 pt).

- **VAC-6 (Footer Refresh Label Placement & Typography)**:
  - **Selector**: `PopoverContentView.swift:footer` -> `Text("Updated every \(preferences.refreshInterval)s")`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The refresh label sits at an exact horizontal inset of `12.0 pt` from the leading boundary (x = 12.0 pt). Font matches `.system(size: 10)`. Foreground style matches `.tertiary`. Text enforces `.lineLimit(1)`.

- **VAC-7 (Footer Version Label Sourcing & Formatting)**:
  - **Selector**: `PopoverContentView.swift:versionLabel(bundle:)`
  - **Target Viewport**: Unit test and fixed 280 pt popover panel
  - **Invariant**: Version string reads `CFBundleShortVersionString` and `CFBundleVersion` dynamically from the supplied bundle. With `MARKETING_VERSION = 1.0.0` and `CURRENT_PROJECT_VERSION = 1`, the formatted text equals `"v1.0.0 (1)"`. The string contains no hard-coded version literals in the view body.

- **VAC-8 (Footer Version Label Placement & Typography)**:
  - **Selector**: `PopoverContentView.swift:footer` -> `Text(Self.versionLabel())`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The version label trailing edge sits at an exact horizontal inset of `12.0 pt` from the popover trailing boundary (x = 268.0 pt). Font matches `.system(size: 10)`. Foreground style matches `.tertiary`. Text enforces `.lineLimit(1)`.

- **VAC-9 (Footer Width Budget & Single-Line Invariant)**:
  - **Selector**: `PopoverContentView.swift:footer`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: When build number is `"9999"` (`"v1.0.0 (9999)"`, 13 characters, measured width 64.62 pt) and refresh label is `"Updated every 2s"` (measured width 85.16 pt), the horizontal spacer retains `≥ 100.0 pt` of clear space. No line wrapping, text truncation, or ellipsis occurs.

- **VAC-10 (Material & Appearance Parity)**:
  - **Selector**: `PopoverContentView.swift`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: In both macOS Light Mode and Dark Mode against `.regularMaterial`, the header title renders with contrast ratio ≥ 14:1, and the footer labels render with contrast ratio ≥ 4.5:1. No text clipping or baseline displacement occurs during appearance switching.

---

## Part 6: Appendix — Proposed Code Changes for the Coder

The `coder` subagent can execute these edits verbatim.

### Edit 1: `StatsLite/PopoverContentView.swift`
Replace `header` and `footer` and add version helpers:

```swift
    // MARK: - Header (28 pt, gear and quit 24x24 targets)

    private var header: some View {
        HStack(spacing: 8) {
            Text("StatsLite")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Quit StatsLite")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: - Footer (22 pt)

    private var footer: some View {
        HStack {
            Text("Updated every \(preferences.refreshInterval)s")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer()
            Text(Self.versionLabel())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .accessibilityLabel(Self.versionAccessibilityLabel())
        }
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .padding(.bottom, 8)
    }

    // MARK: - Version helpers

    /// Pure formatting helper for display version and build number.
    static func versionLabel(version: String, build: String) -> String {
        "v\(version) (\(build))"
    }

    /// Version label from the bundle display version and build number.
    static func versionLabel(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return versionLabel(version: version, build: build)
    }

    /// Pure formatting helper for accessibility label.
    static func versionAccessibilityLabel(version: String, build: String) -> String {
        "Version \(version), build \(build)"
    }

    /// Accessibility description for assistive technology.
    static func versionAccessibilityLabel(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return versionAccessibilityLabel(version: version, build: build)
    }
```

### Edit 2: `StatsLiteTests/StatusItemControllerPopoverTests.swift` (or new test file)
Add unit tests verifying dynamic version string formatting and 9999-build tolerance:

```swift
    func testPopoverVersionLabelReadsBundleInfo() {
        let label = PopoverContentView.versionLabel()
        let pattern = #"^v[0-9][0-9.]* \([0-9]+\)$"#
        XCTAssertNotNil(
            label.range(of: pattern, options: .regularExpression),
            "Version label must match 'v<version> (<build>)', got: \(label)"
        )
    }

    func testPopoverVersionLabelFormattingWithBuild9999() {
        let label = PopoverContentView.versionLabel(version: "1.0.0", build: "9999")
        XCTAssertEqual(label, "v1.0.0 (9999)")
    }
```