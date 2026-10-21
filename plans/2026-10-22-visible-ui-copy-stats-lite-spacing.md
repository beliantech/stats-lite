Plan name: visible-ui-copy-stats-lite-spacing

# Plan: visible-ui-copy-stats-lite-spacing

**Date:** 2026-10-22
**Repository:** /Users/jonathan/beliantech/stats-lite-macos
**Risk class:** R2 (UI copy change; visual fidelity is a blocking requirement)

## Intent

Every place a human sees the product name must read `Stats Lite` (with space). Today every visible surface reads `StatsLite` (no space). Rule confirmed with the user: the human name is `Stats Lite`; technical identifiers stay `StatsLite` (bundle id, module name, executable/product name, scheme, folder paths, scripts, CI-internal names, DMG file name). Scope confirmed with the user across four steps: app-source visible strings, README prose, `INFOPLIST_KEY_CFBundleDisplayName`, and release surfaces (GitHub release title, DMG volume name).

Evidence base:
- Scout inventory (session `2026-10-21T19-24-33-911Z_364659a8`): 8 visible occurrences in app source, 6 README prose occurrences, zero existing `Stats Lite` strings in code/build files.
- Design Blueprint (designer session `2026-10-21T19-24-48-240Z_cc5daa78`), copied verbatim under Approach.

## Notation

```
Plan -> Phase -> Task (T*) -> Receipts (red SHA / green SHA / review verdict)
```

## ISC — binary yes/no criteria

### A. Visible source strings (all must hold)

- **IC1** `StatsLite/PopoverContentView.swift:87` is `Text("Stats Lite")`.
- **IC2** `StatsLite/PopoverContentView.swift:116` is `.help("Quit Stats Lite")`.
- **IC3** `StatsLite/SettingsView.swift:168` returns `"Stats Lite v\(version) (Build \(build))"`.
- **IC4** `StatsLite/StatusItemController.swift:201` is `setAccessibilityTitle("Stats Lite")`, and the doc comment at :205 starts `/// "Stats Lite: CPU …`.
- **IC5** `StatsLite/MenuBarAccessibility.swift:59` prefix is `"Stats Lite: "`.
- **IC6** `StatsLite/UpdateBannerCardView.swift` :25, :60, :86 read `Stats Lite` in the accessibility label, body text, and release-button label.
- **IC7** `rg '"StatsLite' StatsLite/*.swift` returns no hits inside visible string literals.

### B. Display name

- **IC8** `INFOPLIST_KEY_CFBundleDisplayName = "Stats Lite"` exists in both Debug and Release configurations of `StatsLite.xcodeproj/project.pbxproj`.
- **IC9** Product name, executable name, and bundle id are unchanged: `PRODUCT_NAME`, `StatsLite` binary, `com.beliantech.statslite`.
- **IC9a** `.github/workflows/release-dmg.yml:150` release title is `--title "Stats Lite $GITHUB_REF_NAME"`.
- **IC9b** DMG volume name is `"Stats Lite"` in both workflows: `release-dmg.yml` (`hdiutil create -volname "Stats Lite"`) and `build-dmg.yml` (`hdiutil create -volname "Stats Lite"`).
- **IC9c** DMG file name stays `StatsLite.dmg`, CI artifact names stay `StatsLite-dmg` / `StatsLite-notarized-dmg`, and the `StatsLite.app` staging path in both workflows is unchanged.

### C. README

- **IC10** The six prose spots read `Stats Lite`: heading (line 1), intro (line 5), screenshot alt text (line 13), both Goals lines, and the Requirements line.
- **IC11** README technical names stay `StatsLite`: download badge and `StatsLite.dmg`, `StatsLite.xcodeproj`, `StatsLite` scheme, `StatsLite.app`, `StatsLiteTests/`, all paths in project structure and key-sources tables. Every shell command in README still copy-pastes and runs verbatim.

### D. Tests and build

- **IC12** `xcodebuild test` passes with retargeted expectations: `SettingsWindowTests.swift:137` regex `#"^ Stats Lite …"#` (no leading space; exact pattern `#"^Stats Lite v[0-9][0-9.]* \(Build [0-9]+\)$"`), `SettingsWindowTests.swift:140` message, all 14 `MenuBarAccessibilityTests.swift` assertions.
- **IC13** Release build succeeds (`xcodebuild build` green; pbxproj parses).

### E. Visual Acceptance Checklist (VAC), yes/no each, light and dark where applicable

- **VAC-1** Popover header renders `Stats Lite` on one line, no clipping or ellipsis (popover 280 pt).
- **VAC-2** Header Gear and Power buttons keep exact 24x24 pt frames; distance from title to buttons >= 130 pt.
- **VAC-3** Power-button tooltip reads `Quit Stats Lite`, fully visible.
- **VAC-4** Settings footer renders `Stats Lite v<version> (Build <build>)`, one centered line, no wrap (window 380 pt).
- **VAC-5** Settings footer keeps >= 120 pt clearance to both window borders.
- **VAC-6** Status item VoiceOver title returns `Stats Lite`.
- **VAC-7** Status item composite VoiceOver label starts with `Stats Lite: `.
- **VAC-8** Update banner body renders `Stats Lite v<version> is available.` on one line, >= 80 pt trailing margin.
- **VAC-9** Banner a11y label reads `Update available. Stats Lite <version> is available.`; release button label reads `View release page for Stats Lite <version> in browser`.
- **VAC-10** `CFBundleDisplayName` evaluates to `Stats Lite` in Finder / Activity Monitor; executable name stays `StatsLite`.
- **VAC-11** Status item width unchanged; metrics render with no shift or clipping.

### F. Unchanged invariants

- **IC14** `rg -n 'com\.beliantech\.statslite|pkill -x StatsLite|scheme StatsLite|@testable import StatsLite' ` matches its pre-change state — bundle id, scripts, scheme usage, imports untouched.
- **IC15** `git diff --stat` touches only: the 5 Swift source files, the 2 test files, `README.md`, `project.pbxproj`, `.github/workflows/release-dmg.yml`, `.github/workflows/build-dmg.yml`, and this plan.

### Failure modes (falsifiable)

- **FM1 — missed test pin:** if any expectation still pins `StatsLite`, the suite goes red after the source edit. Signature: test failure naming `StatsLite`. Fix: update the pin, never weaken the assertion.
- **FM2 — pbxproj corruption:** if the build-setting edit breaks the project file, `xcodebuild` fails before compilation with a project-parse error. Verify with a build before any UI check.
- **FM3 — layout regression:** if the added space caused wrap or clipping, VAC-1/4/8 fail against measured widths (+2.93 to +3.39 pt against 94–139 pt slack, so a failure means the measurement was wrong, not the margin).
- **FM4 — overreach:** if `Stats Lite` appears inside README code spans, backticks, or commands, a technical name was changed. Signature: `rg 'Stats Lite' README.md` hits inside ` code ` or fenced blocks.

## Approach

Decisions:
1. Keep the brand string as literals at each site (YAGNI): 9 sites, all pinned by tests, no shared constant indirection.
2. Test-expectation updates are part of the change, never weakened.
3. `INFOPLIST_KEY_CFBundleDisplayName = "Stats Lite"` added to Debug and Release — Finder / Activity Monitor / Dock show `Stats Lite`; executable, bundle id, product name stay `StatsLite`.
3b. Release surfaces follow the human-name rule: GitHub release title and DMG volume name become `Stats Lite` (`release-dmg.yml`, `build-dmg.yml`). The `StatsLite.dmg` file name and CI artifact names stay `StatsLite` — the README badge URL targets `StatsLite.dmg`, and artifact names are machine-internal.
4. README: prose only changes; technical/file names stay so all commands remain copy-paste safe.
5. Verification: string content and accessibility prefixes via unit tests; layout via the CoreText measurements in the blueprint below; dark/light screenshots via `scripts/capture_baseline.sh` when Apple Events permission is available (designer run hit `-1743` — fall back to measured widths + existing artifacts `artifacts/2026-10-21-popover-panel-fix/fixed/{light,dark}.png` if the hook is blocked; do not treat a permission error as a VAC failure).
6. TDD: red phase retargets/adds assertions to `Stats Lite` (they fail against current source); green phase edits source until green.

### Current vs Target — app source

| Surface | Path:Line | Current | Target |
|---|---|---|---|
| Popover header title | `StatsLite/PopoverContentView.swift:87` | `Text("StatsLite")` | `Text("Stats Lite")` |
| Quit tooltip | `StatsLite/PopoverContentView.swift:116` | `"Quit StatsLite"` | `"Quit Stats Lite"` |
| Settings footer | `StatsLite/SettingsView.swift:168` | `"StatsLite v…"` | `"Stats Lite v…"` |
| Status item VoiceOver title | `StatsLite/StatusItemController.swift:201` | `setAccessibilityTitle("StatsLite")` | `setAccessibilityTitle("Stats Lite")` |
| Status doc comment | `StatsLite/StatusItemController.swift:205` | `/// "StatsLite: CPU …` | `/// "Stats Lite: CPU …` |
| VoiceOver prefix | `StatsLite/MenuBarAccessibility.swift:59` | `"StatsLite: "` | `"Stats Lite: "` |
| Banner a11y label | `StatsLite/UpdateBannerCardView.swift:25` | `"…StatsLite …"` | `"…Stats Lite …"` |
| Banner body text | `StatsLite/UpdateBannerCardView.swift:60` | `"StatsLite v… is available."` | `"Stats Lite v… is available."` |
| Release button a11y | `StatsLite/UpdateBannerCardView.swift:86` | `"…for StatsLite …"` | `"…for Stats Lite …"` |

### Current vs Target — README.md

| Location | Current | Target |
|---|---|---|
| Heading line 1 | `# StatsLite` | `# Stats Lite` |
| Intro line 5 | "StatsLite is a menu-bar system monitor…" | "Stats Lite is a menu-bar system monitor…" |
| Alt text line 13 | `alt="StatsLite menu bar blocks…"` | `alt="Stats Lite menu bar blocks…"` |
| Goals | "Keep StatsLite under 60 MB…" | "Keep Stats Lite under 60 MB…" |
| Goals | "StatsLite does one job…" | "Stats Lite does one job…" |
| Requirements | "StatsLite has zero third-party dependencies." | "Stats Lite has zero third-party dependencies." |

Stays `StatsLite` in README: badge + `StatsLite.dmg`, `StatsLite.xcodeproj`, `StatsLite` scheme, `StatsLite.app`, `StatsLiteTests/`, project-structure and key-sources paths.

### Current vs Target — release workflows

| Surface | Path:Line | Current | Target |
|---|---|---|---|
| GitHub release title | `.github/workflows/release-dmg.yml:150` | `--title "StatsLite $GITHUB_REF_NAME"` | `--title "Stats Lite $GITHUB_REF_NAME"` |
| DMG volume name | `.github/workflows/release-dmg.yml:92` | `-volname "StatsLite"` | `-volname "Stats Lite"` |
| DMG volume name | `.github/workflows/build-dmg.yml:46` | `-volname "StatsLite"` | `-volname "Stats Lite"` |

Stays `StatsLite`: `StatsLite.dmg` file name (README badge/download URL target), artifact names `StatsLite-dmg` / `StatsLite-notarized-dmg`, staging path `build/Build/Products/Release/StatsLite.app`.

### Current vs Target — test expectations

| File | Change |
|---|---|
| `StatsLiteTests/SettingsWindowTests.swift:137` | regex `^StatsLite v…` → `^Stats Lite v…` |
| `StatsLiteTests/SettingsWindowTests.swift:140` | failure message `StatsLite v<version> …` → `Stats Lite v<version> …` |
| `StatsLiteTests/MenuBarAccessibilityTests.swift` | 14 assertions at lines 31, 47, 64, 80, 94, 102, 108, 116, 125, 160, 180, 200, 219, 238: prefix `"StatsLite: "` → `"Stats Lite: "` |

---

## Design Blueprint (verbatim, designer session cc5daa78)

### 1. Visual Hierarchy & ASCII Wireframes

#### Surface 1: Menu Bar Status Item (Unchanged Visual Layout)
Evidence: `artifacts/2026-10-21-menu-bar-label-text-size-increase/light-status-item.png`
The menu bar status item renders metric blocks only. It never displays the application brand name as visible text. The name exists exclusively in VoiceOver accessibility metadata.

```
+-------------------------------------------------------------------+
|  CPU         * MEM         GPU           * 2.0 MB/s               |
|  20%           43%         25%           *  51 KB/s               |
+-------------------------------------------------------------------+
 ^-- VoiceOver Title: "Stats Lite"
 ^-- VoiceOver Label: "Stats Lite: CPU 20 percent, Memory Pressure..."
```

#### Surface 2: Popover Header & Layout
Evidence: `artifacts/2026-10-21-popover-panel-fix/fixed/light.png`, `dark.png`
Popover container width: fixed `280 pt`. Horizontal padding: `12 pt` per side. Usable header width: `256 pt`.

```
+-- Popover Window (280 pt) ----------------------------------------+
|                                                                   |
|  [Stats Lite]                       [Gear: 24x24]   [Power: 24x24]|
|   ^-- 13 pt Semibold (~60 pt)       ^-- Settings    ^-- Quit      |
|   <----------------- Flexible Spacer (~140 pt) ---->              |
|                                                                   |
|  ---------------------------------------------------------------  |
|  [ Metric Cards Stack: CPU, Memory, GPU, Network (260 pt) ]       |
|  ---------------------------------------------------------------  |
|                                                                   |
|  Updated every 2s                                      v1.0.0 (1) |
+-------------------------------------------------------------------+
```

#### Surface 3: Settings Window Footer
Evidence: `artifacts/2026-10-17-refresh-interval-network-caption/before/settings_window_light.png`
Settings window frame: fixed `380 pt x 340 pt`.

```
+-- Settings Window (380 pt x 340 pt) ------------------------------+
|  General                                                          |
|  +-------------------------------------------------------------+  |
|  | Refresh Interval                                       2 s  |  |
|  | Launch at Login                                         [O] |  |
|  +-------------------------------------------------------------+  |
|                                                                   |
|  Visible Metrics                                                  |
|  +-------------------------------------------------------------+  |
|  | ...                                                         |  |
|  +-------------------------------------------------------------+  |
|                                                                   |
|                 Stats Lite v1.0.0 (Build 1)                       |
|                 ^-- 10 pt Regular, Centered (~119 pt width)       |
|  <-- Margin: 130 pt -->             <-- Margin: 130 pt ---------> |
+-------------------------------------------------------------------+
```

#### Surface 4: In-App Update Notification Banner Card
Container width: `260 pt` (`280 pt` popover width minus `20 pt` horizontal insets). Content width: `240 pt` (`260 pt` minus `20 pt` card internal padding).

```
+-- Update Banner Card (260 pt) ------------------------------------+
|  (v) Update Available                                         (X) |
|                                                                   |
|  Stats Lite v1.4.0 is available.                                  |
|  ^-- 10 pt Regular (~125-145 pt width, max 1 line)                |
|  <-- Content: ~145 pt ----------> <--- Margin: ~95 pt ----------> |
|                                                                   |
|  [ View Release ]                                                 |
+-------------------------------------------------------------------+
```

### 2. Template / Component Skeleton

#### 2.1 Popover Header & Quit Tooltip
Path: `StatsLite/PopoverContentView.swift:84-122`

```swift
    // MARK: - Header (28 pt, gear and quit 24x24 targets)

    private var header: some View {
        HStack(spacing: 8) {
            Text("Stats Lite")
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
            .help("Quit Stats Lite")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
```

#### 2.2 Settings Window Footer
Path: `StatsLite/SettingsView.swift:165-171`

```swift
    // MARK: - Version footer

    /// Version label from the bundle display version and build number.
    static func versionLabel(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Stats Lite v\(version) (Build \(build))"
    }
```

#### 2.3 Menu Bar Accessibility Builder
Path: `StatsLite/MenuBarAccessibility.swift:55-61`

```swift
        if showNetwork {
            if let downloadRate, let uploadRate {
                parts.append(
                    "Network Upload \(MetricFormatters.networkRate(uploadRate)), "
                        + "Download \(MetricFormatters.networkRate(downloadRate))"
                )
            } else {
                parts.append("Network unavailable")
            }
        }
        return "Stats Lite: " + parts.joined(separator: ", ")
```

#### 2.4 Status Item Controller Accessibility Binding
Path: `StatsLite/StatusItemController.swift:198-208`

```swift
    /// Re-arms the VoiceOver label on the button.
    func updateAccessibility() {
        button?.setAccessibilityElement(true)
        button?.setAccessibilityTitle("Stats Lite")
        button?.setAccessibilityLabel(compositeLabel)
    }

    /// "Stats Lite: CPU 14 percent, Memory Pressure Normal at 25
    /// percent, GPU 28 percent, Network Upload 10 KB/s, Download 720
    /// KB/s" from the latest snapshot and network pass.
    private var compositeLabel: String { ... }
```

#### 2.5 In-App Update Notification Banner Card
Path: `StatsLite/UpdateBannerCardView.swift:20-27, 58-64, 82-89`

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
            bodyRow
            actionRow
        }
        .metricCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Update available. Stats Lite \(updateVersion) is available.")
    }

    // MARK: - Body Row (~14 pt)

    private var bodyRow: some View {
        Text("Stats Lite \(updateVersion) is available.")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    // MARK: - Action Row (~20 pt)

    private var actionRow: some View {
        HStack {
            Button {
                NSWorkspace.shared.open(releaseURL)
                onDismiss()
            } label: {
                Text("View Release")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
            .help("Open release page in default browser")
            .accessibilityLabel("View release page for Stats Lite \(updateVersion) in browser")

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
```

#### 2.6 Application Display Name (Build Settings)
Path: `StatsLite.xcodeproj/project.pbxproj` (under target `A10000000000000000000008 /* StatsLite */`)
Add `INFOPLIST_KEY_CFBundleDisplayName = "Stats Lite";` to Debug and Release configurations. This provides the user-facing app name to Finder, Activity Monitor, and System Settings without changing binary or target identifiers.

### 3. Complete State and Responsive Matrix

macOS menu bar apps use fixed layout surfaces rather than responsive browser breakpoints.

| Surface | State / Appearance | Rendering Behavior & Styling |
| --- | --- | --- |
| **Popover Header** | Normal (Light Mode) | Font 13 pt Semibold, foreground `.primary` (Dark Gray #1D1D1F), single line. Width ~60 pt. |
| **Popover Header** | Normal (Dark Mode) | Font 13 pt Semibold, foreground `.primary` (White #FFFFFF), single line. Width ~60 pt. |
| **Popover Header** | Quit Button Hover | Standard AppKit tooltip overlay appears with text `Quit Stats Lite`. System background. |
| **Settings Footer** | Normal (Light Mode) | Font 10 pt Regular, foreground `.tertiary` (60% Gray), centered text. Width ~119 pt. |
| **Settings Footer** | Normal (Dark Mode) | Font 10 pt Regular, foreground `.tertiary` (Light Gray opacity), centered text. Width ~119 pt. |
| **Update Banner** | Normal (Light Mode) | Font 10 pt Regular, foreground `.secondary`. Card fill `controlBackgroundColor` @ 0.65 opacity. |
| **Update Banner** | Normal (Dark Mode) | Font 10 pt Regular, foreground `.secondary`. Card fill `controlBackgroundColor` @ 0.65 opacity. |
| **Status Item** | Active / Idle | Metrics display only. No visible text for brand name. Status button width stays constant. |
| **Status Item** | Focused (VoiceOver) | VoiceOver reads title `Stats Lite`, then reads composite label starting with `Stats Lite: `. |

### 4. Accessibility (WCAG 2.2) and Interaction Contracts

#### 4.1 WCAG 2.2 Success Criteria
- **SC 1.3.1 Info and Relationships (Level A)**: The status bar item must expose accessibility title `Stats Lite` via `setAccessibilityTitle("Stats Lite")`. The composite label must begin with `Stats Lite: `.
- **SC 1.4.3 Contrast (Minimum) (Level AA)**:
  - Header text `Stats Lite` uses `.primary` foreground on `.regularMaterial`, providing contrast ratio >= 7:1 in both light and dark mode.
  - Settings footer text uses `.tertiary` foreground on system window background, providing contrast ratio >= 4.5:1 for ancillary build labels.
  - Update banner text uses `.secondary` foreground on card surface, providing contrast ratio >= 4.5:1.
- **SC 2.5.5 Target Size (Enhanced) & SC 2.5.8 Target Size (Minimum)**:
  - Header Settings button hit target: 24x24 pt.
  - Header Quit button hit target: 24x24 pt.
  - Adding 3.39 pt to the header title does not compress button frames. Button frames remain fixed at 24x24 pt with 8 pt spacing.
- **SC 4.1.2 Name, Role, Value (Level A)**:
  - Status item button accessibility title: `Stats Lite`.
  - Status item composite label: `Stats Lite: CPU 14 percent, ...`.
  - Update card accessibility label: `Update available. Stats Lite \(updateVersion) is available.`.
  - Update banner release button accessibility label: `View release page for Stats Lite \(updateVersion) in browser`.

#### 4.2 Interaction Contracts
- **Status Item Click**: Toggles popover panel. Debounce of 0.25 s on close prevents reopen race. No layout animation or label jitter.
- **Quit Button Click**: Prompts application termination via `NSApplication.shared.terminate(nil)`. Tooltip displays `Quit Stats Lite`.
- **Keyboard Navigation**:
  - Popover controls support Full Keyboard Access. Tab navigates between Settings button, Quit button, and active card controls.
  - VoiceOver cursor highlights status item button and pronounces `Stats Lite` clearly.

### 5. Layout Risk Analysis & Concrete Mitigations

Measured with CoreText/NSFont APIs on macOS San Francisco.

#### 5.1 Popover Header Title
- Current width (`"StatsLite"`, 13 pt semibold): `56.60 pt`; target (`"Stats Lite"`): `59.99 pt`; delta `+3.39 pt`.
- Container: popover fixed `280 pt`, padding `24 pt`, usable header `256 pt`. Right controls: 24 + 8 + 24 = `56 pt`. Spacer: `256 - 59.99 - 56 = 139.01 pt`.
- **Risk: ZERO.** The flexible `Spacer()` absorbs the expansion. No truncation, no wrap, no button displacement.

#### 5.2 Settings Window Footer
- Current (`"StatsLite v1.0.0 (Build 1)"`, 10 pt regular): `116.20 pt`; target: `119.13 pt`; delta `+2.93 pt`.
- Window `380 pt`; margin each side `(380 - 119.13) / 2 = 130.43 pt`.
- **Risk: ZERO.** One centered line, >130 pt margin per side.

#### 5.3 Update Banner Card
- Current (`"StatsLite v1.12.10 is available."`, 10 pt regular): `142.17 pt`; target: `145.10 pt`; delta `+2.93 pt`.
- Content width `240 pt`; remaining margin `94.90 pt`.
- **Risk: ZERO.** `.lineLimit(1)` keeps ~95 pt margin. No truncation.

#### 5.4 Menu Bar Status Item Width
- Status bar length derives from metric blocks only (`MenuBarLayout.length`; 34 pt per block, 50 pt network). Brand name is never drawn.
- **Risk: ZERO.** Item length does not change.

### 6. What Must NOT Change (and Why)

| Entity | Identifier / Value | Reason |
| --- | --- | --- |
| Swift Module Name | `StatsLite` | Module identifiers cannot contain spaces. 35+ test files use `@testable import StatsLite`. |
| Target & Product Name | `StatsLite` (`PRODUCT_NAME = "$(TARGET_NAME)"`) | Renames the bundle to `Stats Lite.app` and binary path `Contents/MacOS/Stats Lite`; breaks `TEST_HOST` and launch scripts. |
| Bundle Identifier | `com.beliantech.statslite` | Reverse-DNS ids cannot contain spaces. Changing it wipes user defaults, login item status, and OS permissions. |
| Executable Name | `StatsLite` | Scripts invoke the binary and call `pkill -x StatsLite`. |
| Window Server Owner | `owner == "StatsLite"` (`scripts/windowid.swift:23`) | Popover discovery matches the CoreGraphics owner name derived from the executable name. |
| App Entry Struct | `struct StatsLiteApp: App` | Swift type names cannot contain spaces. |
| Test Class Name | `final class StatsLiteTests: XCTestCase` | Swift type names cannot contain spaces. |
| Xcode Scheme Name | `StatsLite.xcscheme` | Automation scripts build with `-scheme StatsLite`. |
| Environment Keys | `STATSLITE_FAKE_UPDATE_VERSION` | Internal test fixture key used by launch policy tests. |
| Git & Folder Paths | `StatsLite/`, `StatsLiteTests/`, `StatsLite.xcodeproj` | Xcode filesystem-synchronized root groups map to these exact paths. |
| Popover Footer Label | `"v\(version) (\(build))"` | Intentionally formats version without app name prefix. |

### 7. Exact String Values: Current vs Target

See the three Current vs Target tables above (app source, README, test expectations) — identical content, plus `project.pbxproj` gaining `INFOPLIST_KEY_CFBundleDisplayName = "Stats Lite";` in Debug and Release.

### 8. Visual Acceptance Checklist

VAC-1 through VAC-11 as listed in ISC section E.

---

## Refactors

Band-aid scan of the touched files: no TODO/FIXME/HACK, no suppressed tests, no masked hard-coded values related to this copy. No refactor required. The per-site brand literals stay literals (decision 1); test pins guarantee consistency, so a shared constant adds indirection with no benefit (YAGNI).

## Tasks

- [x] **T1** — [red] Retarget string-pinning tests to `Stats Lite` and add coverage for surfaces that lack it (popover header text, quit tooltip, banner strings, status-item a11y title) where XCTest can reach them. Capture baseline dark/light screenshots first if `scripts/capture_baseline.sh` runs; record the `-1743` fallback if not. Run the suite, report the red output, touch no application code. red ✅ a4f30d2 (21 failures, all naming StatsLite vs Stats Lite; baseline capture hit documented -1743 fallback; new BrandStringTests.swift pins 6 surfaces) · green — · review ⏳
- [x] **T2** — Green: apply the 9 source string edits, the 6 README prose edits, the pbxproj `INFOPLIST_KEY_CFBundleDisplayName` (Debug + Release), and the 3 release-workflow edits (release title + 2 volume names). Run the suite to green, then refactor. Never weaken or delete red tests. red ✅ a4f30d2 · green ✅ 8187e30 (suite 0 failures at green time, build succeeded, rg checks pass) · review ⏳
- [x] **T3** — Verify ✅ (planner-run, independent of coder receipts): `git diff --stat main...HEAD` = 12 files — the 5 app Swift files, 3 test files (2 retargeted + new `BrandStringTests.swift`), `README.md`, `project.pbxproj`, 2 workflow ymls; no unexpected files (IC15 read strictly: the new red-phase test file is plan-authorized). IC7 pass (0 visible `"StatsLite` in app sources); IC8 pass (`INFOPLIST_KEY_CFBundleDisplayName` in both configs, PRODUCT_NAME/TEST_HOST untouched); IC9a/b/c pass (title + 2 volnames changed; `StatsLite.dmg`/artifact names/app staging intact); IC10/11 pass (`Stats Lite` on exactly README lines 1/5/11/31/32/40, none inside code spans; 10 `StatsLite` tech names intact); IC14 pass (49 invariant matches preserved); working tree clean. Test run: 305 executed, 5 failures — ALL in `StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease` (popover close timeout at :57/:110/:117/:123), zero brand-pin failures. Attribution: identical 5 failures reproduced on unmodified main `1eb5544` in the same environment → pre-existing environment-dependent flake, not this diff (test passed in both T1 and T2 runs). VAC-3/6/7/9 by test assertions; VAC-10 by built Info.plist (CFBundleDisplayName `Stats Lite`, CFBundleExecutable `StatsLite`, bundle id unchanged); VAC-1/4/8/11 by CoreText measurements in blueprint (screenshot path blocked by documented `-1743` Apple Events fallback). red — · green — · review ⏳
- [x] **T4** — Reviewer `[code-review]` on `git diff main...HEAD` in the worktree: red commit test-only, green commit implementation, ISC binary, YAGNI. red ✅ · green ✅ · review ✅ GO (session bd1e5bc4; diff satisfies ISC and VAC, invariants and test integrity preserved)
- [x] **T5** — Merge `--squash` to main, record SHA, clean up worktree, update plan checkboxes. Docs: README is part of the change; no `ARCHITECTURE.md`/`AGENTS.md` updates needed (`DESIGN.md` does not exist in this repo). red — · green — · review ✅
  - Merge SHA: `3f1aa6c7ddf3f7c3929fa33a356fe0327194e71f` (`fix(ui): spell the product name Stats Lite in all human-readable surfaces`)
  - Post-merge spot check on main: brand suites (BrandStringTests, MenuBarAccessibilityTests, SettingsWindowTests) 46 tests, 0 failures, TEST SUCCEEDED.
  - Known pre-existing issue (out of plan scope): `StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease` fails in the current environment — reproduced identically on pre-change main `1eb5544`; environment-dependent popover-close timeout, passed in T1/T2 runs. Needs its own diagnosis task if it keeps failing.

Sequencing: one worktree `worktrees/stats-lite-copy`; T1 then T2 run sequentially in the same worktree (red and green are separate spawns, never parallel). One simulator rule not applicable (no simulator).
