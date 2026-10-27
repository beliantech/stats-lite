# 5-Part Design Blueprint: Sparkle 2 Auto-Update Integration

## Overview and Evidence Attribution

This Design Blueprint specifies the visual layout, user-visible copy, component metrics, interaction flows, and acceptance criteria for the Sparkle 2 in-app auto-update integration in Stats Lite for macOS.

### Design System and Rules
- Project design rules live in `DESIGN.md` at the repository root. Menu bar metric labels follow the 8 pt regular `.menuBarMetricLabel()` token and 5 pt inter-block spacing. Status item views must not use `.animation` or `.contentTransition`.
- Visual tokens ground directly in `StatsLite/DesignTokens.swift` (`.metricCardStyle()`), `StatsLite/PopoverContentView.swift`, and `StatsLite/SettingsView.swift`.
- The popover panel enforces a fixed 280 pt width. The update banner card uses `.metricCardStyle()` with an outer width of 260 pt and interior width of 240 pt.
- The Settings window enforces a fixed frame of 380x340 pt with `.formStyle(.grouped)`.
- The application memory budget remains 60 MB. All update UI uses native AppKit/SwiftUI primitives without heavy WebKit views or custom images.

### Visual Evidence Reference Pass
Visual specifications ground in the following repository baseline artifacts:
1. Popover dark mode baseline: `artifacts/2026-10-26-popover-storage-shortcut/dark.png`.
2. Popover light mode baseline: `artifacts/2026-10-26-popover-storage-shortcut/light.png`.
3. Settings window dark mode: `artifacts/2026-10-17-refresh-interval-network-caption/after/short_copy_w380_dark.png`.
4. Settings window light mode: `artifacts/2026-10-17-refresh-interval-network-caption/before/settings_window_light.png`.
5. Previous Tier 1 update banner design: `plans/2026-10-20-in-app-update-check/blueprint.md`.

---

## Part 1: Visual Intent and Design Language Integration

Stats Lite operates as a lightweight menu bar accessory (`LSUIElement = true`). The application never steals focus from active applications and never presents unprompted background modal alerts.

### Design Decisions

1. **Banner Primary Button Copy: "Install Update"**
   - *Selection*: `"Install Update"`
   - *Rationale*: "Install Update" states the exact user action. It matches standard macOS system terminology and Sparkle conventions. In contrast, "Update Now" suggests an immediate destructive restart. "Install Update" accurately signals that the user will inspect the release notes and confirm installation in Sparkle's update window.
   - *Action Semantics*: If the user clicks "Install Update", the view disables the button, brings Stats Lite to the front (`NSApplication.shared.activate(ignoringOtherApps: true)`), closes the popover, and transfers key focus to Sparkle's standard update window.

2. **Secondary Release Notes Affordance: Delegated to Sparkle**
   - *Selection*: Omit a secondary "Release notes" link on the banner card. Let Sparkle's standard update window own the release link and release notes.
   - *Rationale*: The popover card interior width is only 240 pt. Adding a second button or hyperlink clutters the card and creates competing targets. More importantly, Sparkle's standard update window already displays full, scrollable release notes with formatted text. Opening a browser link to GitHub defeats the purpose of an in-app update experience. The popover banner card stays minimal with a single primary action button and a top-right dismiss button.

3. **Settings Placement: Row 4 of "General" Section**
   - *Selection*: Place the "Check for Updates…" control inside the "General" section as row 4, directly below "Launch at Login".
   - *Rationale*: Software update settings belong under "General" in macOS convention (matching System Settings > General > Software Update). Placing the row inside "General" avoids creating a third section that exceeds the 340 pt window height and forces vertical scrolling.
   - *Row Styling*: The row follows the standard Settings form layout: leading label `Text("Software Update")` on the left, trailing `HStack` with an inline `ProgressView` (while checking) and `Button("Check for Updates…")` on the right.

4. **Install Handoff Feedback and Expectations**
   - *Visual State*: If the user clicks "Install Update", the button immediately enters a disabled state (`isHandingOff = true`) with 0.6 opacity to prevent duplicate clicks.
   - *Handoff Transition*: The app activates and dismisses the popover immediately. The popover dismisses because Sparkle opens a detached window. Keeping a transient popover open during window presentation creates awkward visual overlapping.
   - *Sparkle Progress Window*: Sparkle draws and manages its own standard modal window (`SUUpdateAlert`) containing download progress, verification status, and restart controls.

### ASCII Wireframes

#### 1. Popover Update Banner Card (`UpdateBannerCardView.swift`)

```text
|<----------------------------- 280 pt popover ---------------------------->|
+---------------------------------------------------------------------------+
| 12 pt                                                               12 pt |
| Stats Lite                                       [⌹]   [📈]   [⚙]   [⏻]   |  <-- Header (28 pt)
+--[ 10 pt inset ]----------------------------------------------------------+  <-- Divider
|                                                                           |
|  +-- UpdateBannerCardView (outer width 260 pt, .metricCardStyle()) ----+  |
|  | 10 pt padding                                         10 pt padding |  |
|  | [↓] Update Available                                            [×] |  |  <-- Row 1: 18 pt
|  |                                                                     |  |
|  | Stats Lite v1.2.0 is available.                                     |  |  <-- Row 2: 14 pt
|  |                                                                     |  |
|  | [ Install Update ]                                                  |  |  <-- Row 3: 20 pt
|  +---------------------------------------------------------------------+  |
|                                                                           |
|  +-- CPU Total Card ---------------------------------------------------+  |
|  | ...                                                                 |  |
```

#### 2. Settings Window (`SettingsView.swift`, 380x340 pt)

```text
+---------------------------------------------------------------------------+
|  General                                                                  |
|  +---------------------------------------------------------------------+  |
|  | Refresh Interval                                            [ 2 s ⇅ ] |  |
|  | Network throughput always refreshes at 1-second intervals.           |  |
|  +---------------------------------------------------------------------+  |
|  | History Duration                                            [ 1 min ⇅]|  |
|  +---------------------------------------------------------------------+  |
|  | Launch at Login                                              ( O  )  |  |
|  +---------------------------------------------------------------------+  |
|  | Software Update                              [Check for Updates… ]  |  |  <-- Row 4 (New)
|  +---------------------------------------------------------------------+  |
|                                                                           |
|  Visible Metrics                                                          |
|  +---------------------------------------------------------------------+  |
|  | CPU Utilization                                              (  O )  |  |
|  | GPU Utilization                                              (  O )  |  |
|  | Memory Pressure (RAM)                                        (  O )  |  |
|  | Temperature                                                  (  O )  |  |
|  | Network Throughput                                           (  O )  |  |
|  +---------------------------------------------------------------------+  |
|  At least one metric must remain enabled.                                 |
|                                                                           |
|                       Stats Lite v1.1.2 (Build 4)                         |  <-- Footer
+---------------------------------------------------------------------------+
```

---

## Part 2: Exact User-Visible Copy Strings

Every user-visible string adheres to the terse, plain voice of Stats Lite.

### Update Banner Card (`UpdateBannerCardView.swift`)

| UI Element | Property / Modifier | Verbatim String |
| :--- | :--- | :--- |
| Header Title | `Text` | `"Update Available"` |
| Dismiss Button | `.help` tooltip | `"Dismiss"` |
| Dismiss Button | `.accessibilityLabel` | `"Dismiss update notification"` |
| Body Text | `Text` | `"Stats Lite \(updateVersion) is available."` |
| Primary Action Button | `Text` | `"Install Update"` |
| Primary Action Button | `.help` tooltip | `"Install Stats Lite \(updateVersion)"` |
| Primary Action Button | `.accessibilityLabel` | `"Install Stats Lite \(updateVersion)"` |
| Card Container | `.accessibilityLabel` | `"Update available. Stats Lite \(updateVersion) is available."` |

### Settings Window (`SettingsView.swift`)

| UI Element | Property / Modifier | Verbatim String |
| :--- | :--- | :--- |
| Update Row Label | `Text` | `"Software Update"` |
| Check Updates Button | `Text` | `"Check for Updates…"` |
| Check Updates Button | `.help` tooltip | `"Check for new versions of Stats Lite"` |
| Check Updates Button | `.accessibilityLabel` | `"Check for software updates"` |
| In-Flight Progress View | `.accessibilityLabel` | `"Checking for updates"` |
| In-Flight Trailing Text | `Text` (optional) | `"Checking…"` |

---

## Part 3: Layout Specification per Component

All dimensions, typography, and styling tokens ground in existing repository constants.

### 1. `UpdateBannerCardView` Specification

- **Container Modifier**: `.metricCardStyle()` (`StatsLite/DesignTokens.swift:39-55`).
  - Outer width: `260 pt` (`280 pt popover - 20 pt horizontal padding`).
  - Background: `Color(nsColor: .controlBackgroundColor).opacity(0.65)`.
  - Border: `RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)`.
  - Internal padding: `10 pt` on all four edges.
  - Internal content width: `240 pt` (`260 pt - 20 pt`).
  - Vertical row spacing: `4 pt` via `VStack(alignment: .leading, spacing: 4)`.

- **Row 1: Header Row (~18 pt height)**
  - Container: `HStack(spacing: 6)`.
  - Icon: `Image(systemName: "arrow.down.circle.fill")`.
    - Font: `.system(size: 11, weight: .semibold)`.
    - Foreground: `.blue` (`Color.blue`).
  - Title: `Text("Update Available")`.
    - Font: `.system(size: 11, weight: .semibold)`.
    - Foreground: `.primary`.
  - Spacer: `Spacer(minLength: 4)`.
  - Dismiss Button:
    - Label: `Image(systemName: "xmark")`.
    - Font: `.system(size: 9, weight: .bold)`.
    - Foreground: `.secondary`.
    - Frame: `width: 18 pt, height: 18 pt`.
    - Hit testing: `.contentShape(Rectangle())`.
    - Button style: `.plain`.

- **Row 2: Body Row (~14 pt height)**
  - Text: `Text("Stats Lite \(updateVersion) is available.")`.
  - Font: `.system(size: 10, weight: .regular)`.
  - Foreground: `.secondary`.
  - Line constraint: `.lineLimit(1)`.
  - Width budget: Text takes ~135 pt at 10 pt font for `"Stats Lite v1.2.0 is available."`. Clearance to card boundary is greater than 100 pt.

- **Row 3: Action Row (~20 pt height)**
  - Container: `HStack`.
  - Leading padding: `0 pt`. Top padding: `2 pt`.
  - Install Button:
    - Text: `Text("Install Update")`.
    - Font: `.system(size: 10, weight: .medium)`.
    - Foreground: `.white`.
    - Padding: `8 pt` horizontal, `3 pt` vertical.
    - Background: `RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.blue)`.
    - Button style: `.plain`.
    - Computed hit area: `~83 pt width x 20 pt height`.
  - Spacer: `Spacer(minLength: 0)`.

#### Component States for `UpdateBannerCardView`

| State | Background Fill | Border Stroke | Button Fill | Button Opacity | Text Foreground |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Default (Dark)** | `controlBackgroundColor` (0.65) | `separatorColor` (0.50) | `Color.blue` | 1.0 | Primary: White, Secondary: Gray |
| **Default (Light)** | `controlBackgroundColor` (0.65) | `separatorColor` (0.50) | `Color.blue` | 1.0 | Primary: Black, Secondary: Dark Gray |
| **Hover (Dismiss)** | As default | As default | As default | 1.0 | `xmark` foreground brightens to `.primary` |
| **Pressed (Dismiss)** | As default | As default | As default | 1.0 | `xmark` opacity drops to 0.70 |
| **Hover (Install)** | As default | As default | `Color.blue` (brightened) | 1.0 | White text |
| **Pressed (Install)** | As default | As default | `Color.blue` | 0.85 | White text |
| **Disabled (Handoff)** | As default | As default | `Color.blue` | 0.60 | White text (inactive) |

---

### 2. `SettingsView` Software Update Row Specification

- **Container Section**: `Section("General")` in `Form` with `.formStyle(.grouped)`.
- **Row Position**: Row 4, directly following `launchAtLoginRow`.
- **Row Layout**:
  ```swift
  private var checkForUpdatesRow: some View {
      HStack {
          Text("Software Update")
          Spacer()
          if updateChecker.isChecking {
              ProgressView()
                  .controlSize(.small)
          }
          Button("Check for Updates…") {
              updateChecker.checkForUpdates()
          }
          .disabled(updateChecker.isChecking)
      }
  }
  ```
- **Typography and Metrics**:
  - Row label: `Text("Software Update")`. Font: system Form standard (13 pt regular). Foreground: `.primary`.
  - Trailing button: `Button("Check for Updates…")`. Font: 13 pt regular. Standard bordered or plain macOS control style matching Form buttons.
  - Progress spinner: `ProgressView().controlSize(.small)` (~16x16 pt).
  - Row height: ~28 pt inside the grouped section container.

- **Window Layout Budget (380x340 pt)**:
  - Form width: 380 pt. Form grouped content width: ~340 pt.
  - Section 1 ("General", 4 rows): ~128 pt total.
  - Section 2 ("Visible Metrics", 5 toggles + footer): ~154 pt total.
  - Window footer (`Text(Self.versionLabel())`): ~20 pt total (`padding(.top, 2)`, `padding(.bottom, 6)`).
  - Total vertical footprint: ~302 pt out of 340 pt available. No scrolling occurs.

#### Component States for Settings Row

| State | Trailing Button State | Progress Spinner | Row Label Foreground |
| :--- | :--- | :--- | :--- |
| **Idle** | Enabled (`Button("Check for Updates…")`) | Absent | `.primary` |
| **Checking** | Disabled (`.disabled(true)`) | Visible (`ProgressView().controlSize(.small)`) | `.primary` |
| **Up to Date** | Enabled (Sparkle alert dismissed) | Absent | `.primary` |
| **Update Available** | Enabled (Sparkle window presented) | Absent | `.primary` |
| **Error / Offline** | Enabled (Sparkle error alert dismissed) | Absent | `.primary` |

---

## Part 4: Interaction Specification

### Flow 1: Popover Banner Update Installation

```text
[ Background Check finds update ]
                │
                ▼
[ User clicks Stats Lite menu bar item ]
                │
                ▼
[ Popover opens: UpdateBannerCardView visible at top ]
                │
     ┌──────────┴──────────┐
     ▼                     ▼
[ User clicks (×) ]    [ User clicks "Install Update" ]
     │                     │
     ▼                     ▼
[ Dismiss version ]    [ 1. Disable Install button (isHandingOff = true) ]
[ Animate card out ]   [ 2. NSApplication.shared.activate(...)           ]
[ Persist to defaults] [ 3. Close popover cleanly                        ]
                       [ 4. Hand off to Sparkle (updater.checkForUpdates) ]
                                   │
                                   ▼
                       [ Sparkle presents SUUpdateAlert window ]
                       [ User reads notes, clicks "Install & Relaunch" ]
```

1. **Discovery**: Background polling detects a new release via Sparkle 2 gentle reminders. Sparkle notifies `UpdateCheckService`. `UpdateCheckService` sets `availableUpdate`.
2. **Display**: The user opens the popover. If the version is not dismissed, `UpdateBannerCardView` renders at the top of the card stack directly beneath the header divider.
3. **User Action: Dismiss**:
   - The user clicks `Image(systemName: "xmark")`.
   - `UpdateCheckService.dismiss(version:)` persists the normalized version string to `UserDefaults`.
   - `availableUpdate` clears to `nil`.
   - The card transitions out with `.transition(.opacity)`. The remaining cards shift up smoothly.
4. **User Action: Install**:
   - The user clicks `"Install Update"`.
   - The button disables immediately to block duplicate activations.
   - The application brings itself to the front via `NSApplication.shared.activate(ignoringOtherApps: true)`.
   - The popover dismisses via `onDismiss()` to prevent orphaned floating popover artifacts.
   - The service invokes Sparkle's update flow (`updater.checkForUpdates()` or gentle reminder continuation).
   - Sparkle takes key window focus and displays its standard update alert window (`SUUpdateAlert`) containing release notes and installation controls.

### Flow 2: Interactive Check from Settings Window

```text
[ User opens Settings window -> General section ]
                       │
                       ▼
    [ Row 4: "Software Update" + "Check for Updates…" ]
                       │
                       ▼
       [ User clicks "Check for Updates…" ]
                       │
                       ▼
   [ 1. isChecking = true                              ]
   [ 2. Disable "Check for Updates…" button            ]
   [ 3. Display small ProgressView adjacent to button  ]
   [ 4. Call updater.checkForUpdates()                 ]
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
   [ Update found ] [ Up to date ] [ Network error ]
         │             │             │
         ▼             ▼             ▼
   Sparkle shows   Sparkle shows Sparkle shows
   update window   info alert    error alert
         │             │             │
         └─────────────┼─────────────┘
                       ▼
   [ Check completes: isChecking = false               ]
   [ Re-enable "Check for Updates…" button             ]
   [ Remove ProgressView                               ]
```

1. **Trigger**: The user clicks `"Check for Updates…"` in the Settings window.
2. **Immediate Feedback**: `isChecking` becomes true. The button disables. A small progress spinner appears next to the button. VoiceOver announces the checking state.
3. **Sparkle Execution**: Sparkle performs an immediate asynchronous appcast fetch.
4. **Completion Handling**:
   - If a newer version exists: Sparkle displays its update window with release notes and the "Install and Relaunch" button.
   - If the installed version is current: Sparkle presents the standard macOS information alert stating the software is up to date.
   - If the network fails: Sparkle presents the standard macOS error alert.
5. **State Reset**: When Sparkle's interactive operation finishes, `isChecking` resets to false. The button in Settings re-enables. The spinner disappears.

### Keyboard Navigation Contract

1. In the Popover:
   - `Tab` moves focus sequentially: Storage button -> Activity Monitor button -> Settings button -> Quit button -> "Install Update" button -> Dismiss "[×]" button -> Metric card disclosures.
   - `Space` or `Return` activates the focused button.
   - `Escape` closes the popover without activating updates.
2. In the Settings Window:
   - `Tab` navigates through Form controls: Refresh Interval picker -> History Duration picker -> Launch at Login toggle -> "Check for Updates…" button -> Metric toggles.
   - `Space` or `Return` activates the "Check for Updates…" button.

---

## Part 5: Numbered Visual Acceptance Checklist (VAC)

Every item specifies a discrete, objectively verifiable invariant for offscreen render tests or view inspection.

- **VAC-1 (Banner Surface and Outer Geometry)**:
  - **Selector**: `UpdateBannerCardView`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The banner card outer width computes to exactly 260 pt (280 pt popover minus 20 pt horizontal container padding). Corner radius matches 8 pt continuous. Border stroke matches 0.5 pt with `Color(nsColor: .separatorColor).opacity(0.5)`. Interior padding matches 10 pt on all four edges.

- **VAC-2 (Banner Stack Placement)**:
  - **Selector**: `PopoverContentView.swift:VStack(spacing: 6)`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: If an update is available and not dismissed, `UpdateBannerCardView` sits directly below the top divider and above the first enabled metric card. If no update is available or the version was dismissed, the banner is absent and popover height clamps to the active metric cards with zero empty space.

- **VAC-3 (Banner Header Row Alignment)**:
  - **Selector**: `UpdateBannerCardView.swift:headerRow`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The header row displays `Image(systemName: "arrow.down.circle.fill")` in `.blue` (11 pt semibold) and `Text("Update Available")` in `.font(.system(size: 11, weight: .semibold))`. The trailing edge contains the dismiss button. The icon, title, and dismiss button share vertical center alignment.

- **VAC-4 (Banner Dismiss Button Invariant)**:
  - **Selector**: `UpdateBannerCardView.swift:headerRow`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The dismiss button displays `Image(systemName: "xmark")` in 9 pt bold with `.secondary` foreground. Hit area measures 18x18 pt via `.frame(width: 18, height: 18).contentShape(Rectangle())`. Button style matches `.plain`. Tooltip reads `"Dismiss"`.

- **VAC-5 (Banner Body Single-Line Invariant)**:
  - **Selector**: `UpdateBannerCardView.swift:bodyRow`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: Body text matches `"Stats Lite \(updateVersion) is available."` in 10 pt regular text with `.secondary` foreground. For version tags up to 16 characters (for example `"Stats Lite v10.12.34 is available."`), the text renders on a single line without wrapping, truncation, or ellipsis inside the 240 pt interior width.

- **VAC-6 (Banner Primary Action Button Styling)**:
  - **Selector**: `UpdateBannerCardView.swift:actionRow`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The action button displays `Text("Install Update")` in 10 pt medium text with `.white` foreground over `Color.blue` background with 4 pt continuous corner radius. Button renders without text underline across default, hover, and pressed states.

- **VAC-7 (Banner Install Button Hit Target and Spacing)**:
  - **Selector**: `UpdateBannerCardView.swift:actionRow`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The `"Install Update"` button has 8 pt horizontal and 3 pt vertical padding (computed frame ~83x20 pt). It sits leading-aligned in `HStack` with 2 pt top padding.

- **VAC-8 (Banner Appearance Mode Parity)**:
  - **Selector**: `UpdateBannerCardView.swift`
  - **Target Viewport**: Light Mode and Dark Mode
  - **Invariant**: In Dark Mode, card background fill renders `controlBackgroundColor` at 0.65 opacity with white primary text (contrast > 14:1). In Light Mode, card background fill renders `controlBackgroundColor` at 0.65 opacity with near-black primary text (contrast > 14:1). Action button white text over system blue achieves contrast > 4.5:1 in both modes.

- **VAC-9 (Banner Accessibility Contract)**:
  - **Selector**: `UpdateBannerCardView.swift`
  - **Target Viewport**: VoiceOver Accessibility Tree
  - **Invariant**: The card container exposes `.accessibilityLabel("Update available. Stats Lite \(updateVersion) is available.")`. The dismiss button exposes `.accessibilityLabel("Dismiss update notification")`. The install button exposes `.accessibilityLabel("Install Stats Lite \(updateVersion)")`.

- **VAC-10 (Status Item Immutability)**:
  - **Selector**: `MenuBarStackedItemView.swift`
  - **Target Viewport**: Menu bar status item
  - **Invariant**: The menu bar status item width, views, and typography remain completely unchanged across all update states (idle, checking, update available, dismissed). No update dot, icon, or badge renders on the status bar item.

- **VAC-11 (Settings Row Placement and Order)**:
  - **Selector**: `SettingsView.swift:generalSection`
  - **Target Viewport**: Settings Window (380x340 pt)
  - **Invariant**: The "Software Update" row resides inside the "General" section as row 4, directly following "Launch at Login" and preceding the "Visible Metrics" section header.

- **VAC-12 (Settings Row Typography and Layout)**:
  - **Selector**: `SettingsView.swift:checkForUpdatesRow`
  - **Target Viewport**: Settings Window (380x340 pt)
  - **Invariant**: The row displays `Text("Software Update")` leading-aligned in 13 pt regular text. The trailing edge displays `Button("Check for Updates…")`. The label and button share vertical center alignment.

- **VAC-13 (Settings Checking State Invariant)**:
  - **Selector**: `SettingsView.swift:checkForUpdatesRow`
  - **Target Viewport**: Settings Window (380x340 pt)
  - **Invariant**: When `isChecking` is true, the `"Check for Updates…"` button is disabled (`.disabled(true)`), and an inline `ProgressView().controlSize(.small)` renders adjacent to the button. When `isChecking` is false, the button is enabled and the `ProgressView` is absent.

- **VAC-14 (Settings Window Height Bounds)**:
  - **Selector**: `SettingsView.swift`
  - **Target Viewport**: Fixed 380x340 pt window
  - **Invariant**: The entire Form (General section with 4 rows, Visible Metrics section with 5 toggles, and bottom version footer) renders inside the 340 pt height without clipping controls and without triggering vertical scroll indicators.

- **VAC-15 (Dismiss Persistence Contract)**:
  - **Selector**: `UpdateCheckService` and `UserDefaults`
  - **Target Viewport**: Popover panel across relaunches
  - **Invariant**: Activating the dismiss button writes the normalized version string to `UserDefaults`. Reopening the popover or relaunching the application suppresses the update banner for that version.
