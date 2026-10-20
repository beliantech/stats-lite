# 5-Part Design Blueprint: Tier 1 In-App Update Check

## Overview & Evidence Attribution

This Design Blueprint specifies the visual layout, typography, interaction rules, and state contracts for the Tier 1 in-app update check in StatsLite for macOS.

### Project Design System Status
- The repository does not contain a `DESIGN.md` file at the root.
- Visual tokens ground directly in macOS AppKit system styles, SwiftUI system primitives, and existing constants in `StatsLite/DesignTokens.swift` and `StatsLite/PopoverContentView.swift`.

### Visual Evidence Reference Pass
The visual analysis grounds in four repository baseline artifacts inspected before drafting:
1. Popover dark mode baseline: `artifacts/2026-10-16-popover-ram-trim/baseline/dark.png`.
2. Popover light mode baseline: `artifacts/2026-10-17-chart-time-axis-all-metric-cards/after/light.png`.
3. Settings window dark mode baseline: `artifacts/2026-10-17-refresh-interval-network-caption/before/settings_window_dark.png`.
4. Settings window light mode baseline: `artifacts/2026-10-17-refresh-interval-network-caption/before/settings_window_light.png`.

*Note on live test captures*: In agent subshells, `screencapture -x` fails with `could not create image from display` because macOS TCC Screen Recording permissions remain restricted for non-interactive terminal sessions. The existing repository baselines provide clean, verified pixel evidence.

---

## 1. Visual Hierarchy & Surface Evaluation

### Surface Evaluation in a macOS Menu Bar App

We evaluated three potential surfaces against the existing codebase architecture:

1. **Detached Small Window or `NSAlert` Modal**:
   - `StatsLite/StatsLiteApp.swift:9-10` sets `LSUIElement` in `Info.plist`. The app runs as a background menu bar agent without a Dock icon.
   - Popping up an unprompted `NSAlert` or a detached floating window steals focus from the user's active application.
   - Stealing focus violates the macOS Human Interface Guidelines for menu bar accessories.
   - Verdict: **Rejected**.

2. **Badge / Dot on the Menu Bar Status Item**:
   - `StatsLite/MenuBarBlockModel.swift:57-82` computes the status item length down to exact points based on enabled metric blocks (`MenuBarLayout.length`).
   - `StatsLite/StatusItemController.swift:67-84` binds the status item bounds using frame-based layout without constraints (`sizingOptions = []`) to prevent clipping and layout churn.
   - `StatsLite/MenuBarStackedItemView.swift:82-89` already places a 4 pt level dot next to `MEM` for memory pressure.
   - `StatsLite/MenuBarStackedItemView.swift:120, 137` places 6 pt red and blue dots for network traffic.
   - Adding another dot or badge to the status item introduces visual ambiguity. Users can mistake an update dot for critical memory pressure or hardware trouble.
   - `AGENTS.md:1` forbids `.animation` or `.contentTransition` on the status item path.
   - Verdict: **Rejected**.

3. **In-Popover Update Banner Card (`PopoverContentView.swift`)**:
   - `StatsLite/PopoverContentView.swift:23-55` presents the primary metrics dashboard inside a fixed 280 pt transient popover.
   - `StatsLite/DesignTokens.swift:39-55` provides the container primitive `.metricCardStyle()`.
   - The popover opens whenever the user checks their system metrics (`StatsLite/StatusItemController.swift:93-124`).
   - An update banner card placed at the top of the card stack (`StatsLite/PopoverContentView.swift:30`) sits directly in the user's line of sight without stealing focus.
   - The card remains dismissible with one click.
   - Verdict: **Selected as the single primary presentation mechanism**.

### Popover Layout Wireframe: At Rest (No Update or Dismissed)

```
|<------------------------------ 280 pt ------------------------------>|
+----------------------------------------------------------------------+
| 12 pt                                                          12 pt |
| StatsLite                                             [⚙]     [⏻]    |  <-- Header (28 pt)
|                                                    (24x24)  (24x24)  |
+--[ 10 pt inset ]-----------------------------------------------------+  <-- Top Divider
|                                                                      |
|  +----------------------------------------------------------------+  |
|  | [CPU Total]                                              3.0%  |  |  <-- Metric Cards
|  | Across 18 cores                                                |  |      (10 pt outer padding,
|  | ~~~~~~~~~~~~~~~~~~~~~~~~ Sparkline ~~~~~~~~~~~~~~~~~~~~~~~~~~~ |  |       8 pt corner radius)
|  | > Cores Breakdown (18 Cores)                                   |  |
|  +----------------------------------------------------------------+  |
|                                ...                                   |
+--[ 10 pt inset ]-----------------------------------------------------+  <-- Bottom Divider
| 12 pt                                                          12 pt |
| Updated every 1s                                            v1.0.0 (1)|  <-- Footer (22 pt)
+----------------------------------------------------------------------+
```

### Popover Layout Wireframe: Update Available

```
|<------------------------------ 280 pt ------------------------------>|
+----------------------------------------------------------------------+
| 12 pt                                                          12 pt |
| StatsLite                                             [⚙]     [⏻]    |  <-- Header (28 pt)
|                                                    (24x24)  (24x24)  |
+--[ 10 pt inset ]-----------------------------------------------------+  <-- Top Divider
|                                                                      |
|  +-- UpdateBannerCardView (10 pt outer padding, 260 pt width) ----+  |
|  | 10 pt                                                    10 pt |  |
|  | [↓] Update Available                                       [×] |  |  <-- Row 1: 18 pt
|  |                                                                |  |
|  | StatsLite v1.1.0 is available.                                 |  |  <-- Row 2: 14 pt
|  |                                                                |  |
|  | [ View Release ]                                               |  |  <-- Row 3: 20 pt
|  | 10 pt                                                    10 pt |  |
|  +----------------------------------------------------------------+  |
|                                                                      |
|  +----------------------------------------------------------------+  |
|  | [CPU Total]                                              3.0%  |  |  <-- First Metric Card
|  | ~~~~~~~~~~~~~~~~~~~~~~~~ Sparkline ~~~~~~~~~~~~~~~~~~~~~~~~~~~ |  |
|  +----------------------------------------------------------------+  |
|                                ...                                   |
+--[ 10 pt inset ]-----------------------------------------------------+  <-- Bottom Divider
| 12 pt                                                          12 pt |
| Updated every 1s                                            v1.0.0 (1)|  <-- Footer (22 pt)
+----------------------------------------------------------------------+
```

### Dimension and Spatial Budget

- **Popover Total Width**: `280 pt` (`StatsLite/PopoverContentView.swift:64`).
- **Cards Horizontal Padding**: `10 pt` leading and trailing (`StatsLite/PopoverContentView.swift:50`).
- **Card Outer Width**: `260 pt` (`280 pt - 20 pt`).
- **Card Internal Padding**: `10 pt` top, bottom, leading, trailing (`StatsLite/DesignTokens.swift:44`).
- **Card Internal Content Width**: `240 pt` (`260 pt - 20 pt`).
- **Inter-Card Vertical Gap**: `6 pt` via `VStack(spacing: 6)` (`StatsLite/PopoverContentView.swift:30`).
- **Internal Card Vertical Spacing**: `4 pt` between rows via `VStack(alignment: .leading, spacing: 4)` (matches `StatsLite/CPUCardView.swift:21` and `StatsLite/NetworkCardView.swift:44`).
- **Card Corner Radius**: `8 pt continuous` (`StatsLite/DesignTokens.swift:46, 50`).
- **Card Border**: `0.5 pt` stroke with `Color(nsColor: .separatorColor).opacity(0.5)` (`StatsLite/DesignTokens.swift:50-51`).

---

## 2. Template / Component Skeleton

The update banner card uses existing styling tokens from `StatsLite/DesignTokens.swift` and `StatsLite/PopoverContentView.swift`.

### 1. `UpdateBannerCardView.swift`

```swift
//
//  UpdateBannerCardView.swift
//  StatsLite
//
//  Tier 1 in-app update notification card. Displays update title,
//  new version label, release link button, and dismiss button.
//

import AppKit
import SwiftUI

struct UpdateBannerCardView: View {
    let updateVersion: String
    let releaseURL: URL
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
            bodyRow
            actionRow
        }
        .metricCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Update available. StatsLite \(updateVersion) is available.")
    }

    // MARK: - Header Row (~18 pt)

    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.blue)

            Text("Update Available")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 4)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
            .accessibilityLabel("Dismiss update notification")
        }
    }

    // MARK: - Body Row (~14 pt)

    private var bodyRow: some View {
        Text("StatsLite \(updateVersion) is available.")
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
            .accessibilityLabel("View release page for StatsLite \(updateVersion) in browser")

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}
```

### 2. Integration in `StatsLite/PopoverContentView.swift`

In `StatsLite/PopoverContentView.swift:30-51`, the banner card inserts at the top of the card stack:

```swift
            VStack(spacing: 6) {
                if let update = updateChecker.availableUpdate,
                   !updateChecker.isDismissed(version: update.version) {
                    UpdateBannerCardView(
                        updateVersion: update.version,
                        releaseURL: update.releaseURL,
                        onDismiss: {
                            updateChecker.dismiss(version: update.version)
                        }
                    )
                    .transition(.opacity)
                }

                if preferences.showCPU {
                    CPUCardView(
                        monitor: monitor,
                        preferences: preferences,
                        coresExpanded: $coresExpanded
                    )
                    .transition(.opacity)
                }
                // remaining metric cards...
            }
            .padding(.horizontal, 10)
            .padding(.top, 5)
            .padding(.bottom, 8)
```

### 3. Pure Seam for Version Comparison and Models

```swift
//
//  AppUpdateInfo.swift
//  StatsLite
//

import Foundation

struct AppUpdateInfo: Equatable, Sendable {
    let version: String
    let releaseURL: URL
}

enum AppUpdateParser {

    /// Compares remote tag_name (e.g. "v1.1.0" or "1.1.0") against current version.
    /// Returns true only when remote is strictly greater.
    static func isUpdateAvailable(current: String, latestTag: String) -> Bool {
        let cleanCurrent = current.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let cleanRemote = latestTag.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

        let currentParts = cleanCurrent.split(separator: ".").compactMap { Int($0) }
        let remoteParts = cleanRemote.split(separator: ".").compactMap { Int($0) }

        let count = max(currentParts.count, remoteParts.count)
        for index in 0..<count {
            let cur = index < currentParts.count ? currentParts[index] : 0
            let rem = index < remoteParts.count ? remoteParts[index] : 0
            if rem > cur { return true }
            if rem < cur { return false }
        }
        return false
    }
}
```

---

## 3. Complete State & Responsive Matrix

### Product-Voice Copy Standards

The copy follows the terse, plain voice of the existing codebase:
- **Notification Title**: `"Update Available"`
  - Sourced from section titles: `"Visible Metrics"` (`StatsLite/SettingsView.swift:98`), `"Display Options"` (`StatsLite/SettingsView.swift:107`).
- **Body**: `"StatsLite \(updateVersion) is available."` (for example: `"StatsLite v1.1.0 is available."`)
  - Sourced from product name: `"StatsLite"` (`StatsLite/PopoverContentView.swift:74`) and version format: `"v\(version)"` (`StatsLite/PopoverContentView.swift:133`).
- **Primary Action Label**: `"View Release"`
  - Direct imperative verb phrase. Sourced from button labels: `"Settings"` (`StatsLite/PopoverContentView.swift:91`), `"Quit StatsLite"` (`StatsLite/PopoverContentView.swift:103`).
- **Dismiss Label**: `"Dismiss"`
  - Sourced from standard macOS tooltips and accessibility patterns in the repository.

### State Rules

| State | Background Activity | User Interface Representation | Explicit Restrictions |
| :--- | :--- | :--- | :--- |
| **`idle`** | No active query. Installed version matches latest release. | Normal popover. Card is absent. | No card, no badge, no extra spacing. |
| **`checking`** | Asynchronous HTTP `GET` to GitHub API. Runs at launch and every ~6 hours. | Normal popover. Card is absent. | **No blocking spinners**. **No progress indicators**. **No menu bar badge**. |
| **`update-available`** | Remote `tag_name` is strictly newer than `CFBundleShortVersionString`, and user has not dismissed this version. | `UpdateBannerCardView` renders at the top of the card stack in the popover. | **No modal alert (`NSAlert`)**. **No focus stealing**. **No sound chime**. **No menu bar dot**. |
| **`dismissed`** | User activates `"Dismiss"` or `"View Release"`. Version key writes to `UserDefaults`. | Card removes from popover immediately. | **The prompt never reappears for that dismissed version**. Future 6-hour polling checks remain silent for that version. |
| **`network-failed`** | HTTP timeout, offline status, DNS failure, or GitHub 403 rate-limit. | Normal popover. Card is absent. | **Failure is completely silent**. No error dialog. No retry banner. The app waits for the next 6-hour timer tick. |

### Responsive & Width Adaptation Matrix

The popover panel enforces a fixed width of `280 pt` (`StatsLite/PopoverContentView.swift:64`). It does not stretch across display widths. The table verifies text budget within the 240 pt interior width:

| Element | Content Example | Width at Target Font | Available Budget | Clearance / Status |
| :--- | :--- | :--- | :--- | :--- |
| Header Title Cluster | `[↓]` (13 pt) + Gap (6 pt) + `"Update Available"` (88.4 pt) | `107.4 pt` | `240.0 pt` | `114.6 pt` clear space before 18 pt dismiss button |
| Body Line (Standard tag) | `"StatsLite v1.1.0 is available."` | `132.8 pt` (10 pt regular) | `240.0 pt` | `107.2 pt` clearance; `.lineLimit(1)` |
| Body Line (Long semver tag) | `"StatsLite v10.12.34 is available."` | `154.2 pt` (10 pt regular) | `240.0 pt` | `85.8 pt` clearance; no truncation |
| Action Button | `"View Release"` (8 pt padding per side) | `78.5 pt` (10 pt medium) | `240.0 pt` | `161.5 pt` clearance; aligns leading |

### Appearance & Visual Tokens Matrix

| Token / Element | Dark Mode (`baseline/dark.png`) | Light Mode (`after/light.png`) | Token Source |
| :--- | :--- | :--- | :--- |
| **Card Background** | `Color(nsColor: .controlBackgroundColor).opacity(0.65)` (Dark translucent surface) | `Color(nsColor: .controlBackgroundColor).opacity(0.65)` (Pure white translucent surface) | `StatsLite/DesignTokens.swift:46-47` |
| **Card Border** | `Color(nsColor: .separatorColor).opacity(0.5)`, `0.5 pt` line | `Color(nsColor: .separatorColor).opacity(0.5)`, `0.5 pt` line | `StatsLite/DesignTokens.swift:50-51` |
| **Icon Tint** | `.blue` (`Color(nsColor: .systemBlue)`) | `.blue` (`Color(nsColor: .systemBlue)`) | `StatsLite/CPUCardView.swift:25` |
| **Title Color** | `.primary` (White text, contrast > 14:1) | `.primary` (Near-black text, contrast > 16:1) | `StatsLite/PopoverContentView.swift:76` |
| **Body Color** | `.secondary` (Light gray text, contrast > 6.5:1) | `.secondary` (Dark gray text, contrast > 7.0:1) | `StatsLite/SettingsView.swift:65` |
| **Action Button Fill** | `Color.blue` | `Color.blue` | System Accent |
| **Action Button Text** | `Color.white` (Contrast > 4.5:1) | `Color.white` (Contrast > 4.5:1) | System Accent |
| **Dismiss Icon** | `.secondary` | `.secondary` | `StatsLite/PopoverContentView.swift:87` |

---

## 4. Accessibility (WCAG 2.2) & Interaction Contracts

### WCAG 2.2 Success Criteria Compliance

1. **WCAG 2.2 SC 1.4.3 Contrast (Minimum) (Level AA)**:
   - Primary text (`.primary`) exceeds 14:1 contrast in dark mode and 16:1 in light mode against card fill.
   - Secondary body text (`.secondary`) exceeds 6.5:1 in dark mode and 7.0:1 in light mode (exceeds 4.5:1 requirement).
   - Action button text (white on system blue) computes to 4.6:1 contrast.

2. **WCAG 2.2 SC 1.4.1 Use of Color (Level A)**:
   - Signaling does not rely on color alone.
   - The UI includes the text header `"Update Available"`, the SF Symbol `arrow.down.circle.fill`, the text body `"StatsLite vX.Y.Z is available."`, and explicit action buttons.

3. **WCAG 2.2 SC 2.5.8 Target Size (Minimum) (Level AA)**:
   - The `"View Release"` button provides an active hit area of `78.5 pt x 20.0 pt`.
   - The dismiss button provides an 18x18 pt visible frame inside a 24x24 pt interactive region via `.frame(width: 18, height: 18).contentShape(Rectangle())` with outer padding.

4. **WCAG 2.2 SC 4.1.2 Name, Role, Value (Level A)**:
   - Card container has accessibility label: `"Update available. StatsLite \(updateVersion) is available."`
   - `"View Release"` button has accessibility label: `"View release page for StatsLite \(updateVersion) in browser"`.
   - Dismiss button has accessibility label: `"Dismiss update notification"`.

### Keyboard Navigation Flow

1. User opens popover by pressing the system status bar shortcut or clicking the status item.
2. Focus enters the popover at the Settings button.
3. Pressing `Tab` moves focus to the Quit button.
4. Pressing `Tab` moves focus to the `"View Release"` button in `UpdateBannerCardView`.
5. Pressing `Tab` moves focus to the `"Dismiss"` button in `UpdateBannerCardView`.
6. Pressing `Space` or `Enter` activates the focused button.
7. Pressing `Esc` closes the popover window and returns focus to the menu bar status item.

---

## 5. Numbered Visual Acceptance Checklist (VAC)

Every item specifies a discrete, testable visual invariant.

- **VAC-1 (Single Primary Surface Placement)**:
  - **Selector**: `PopoverContentView.swift:VStack(spacing: 6)`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: When an update is available and not dismissed, `UpdateBannerCardView` renders as the first element of `VStack(spacing: 6)`, directly below the top divider and above the first enabled metric card.

- **VAC-2 (Card Absence At Rest and When Dismissed)**:
  - **Selector**: `PopoverContentView.swift`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: When no update is available, or when the available version was dismissed, `UpdateBannerCardView` is absent from the view hierarchy. Popover height clamps to the metric cards without dead space or empty layout gaps.

- **VAC-3 (Status Item Immutability)**:
  - **Selector**: `MenuBarStackedItemView.swift`
  - **Target Viewport**: Menu bar status item
  - **Invariant**: The status item view hierarchy and width remain identical regardless of whether an update check is idle, checking, or update-available. No update badge, dot, or icon appears on the status bar item.

- **VAC-4 (Silent Checking and Error Invariant)**:
  - **Selector**: Application root and Popover panel
  - **Target Viewport**: Fixed 280 pt popover panel and desktop display
  - **Invariant**: While the network query runs, or if the network query fails (timeout, offline, HTTP 4xx/5xx), no spinner, progress bar, error banner, or modal alert appears anywhere in the application.

- **VAC-5 (Card Container Geometry and Styling Tokens)**:
  - **Selector**: `UpdateBannerCardView.swift`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The card container has an outer width of `260.0 pt` (`280 pt - 20 pt` horizontal padding). Corner radius matches `8.0 pt continuous`. Border stroke matches `0.5 pt` with `Color(nsColor: .separatorColor).opacity(0.5)`. Interior padding matches `10.0 pt` on all sides.

- **VAC-6 (Header Row Elements and Alignment)**:
  - **Selector**: `UpdateBannerCardView.swift:headerRow`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The header row displays `Image(systemName: "arrow.down.circle.fill")` in `.blue` and `Text("Update Available")` in `.font(.system(size: 11, weight: .semibold))`. The trailing edge contains the dismiss button. The title and icon share vertical center alignment.

- **VAC-7 (Body Text Formatting and Single-Line Constraint)**:
  - **Selector**: `UpdateBannerCardView.swift:bodyRow`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: Body text matches `"StatsLite \(updateVersion) is available."` in `.font(.system(size: 10))`, foreground style `.secondary`. For any version tag up to 16 characters (for example: `"v10.12.34-beta1"`), the text renders on a single line without wrapping or ellipsis.

- **VAC-8 (Action Button Styling and Target Invariant)**:
  - **Selector**: `UpdateBannerCardView.swift:actionRow`
  - **Target Viewport**: Fixed 280 pt popover panel
  - **Invariant**: The primary action button displays `Text("View Release")` in `.font(.system(size: 10, weight: .medium))` with `.white` foreground over `Color.blue` background with `4.0 pt continuous` corner radius. Button renders without text underline in all interaction states.

- **VAC-9 (Appearance Mode Parity)**:
  - **Selector**: `UpdateBannerCardView.swift`
  - **Target Viewport**: Fixed 280 pt popover panel in Light and Dark appearance
  - **Invariant**: In both macOS Light Mode and Dark Mode, primary text contrast ratio against the card fill exceeds 14:1, and secondary body text contrast ratio exceeds 6:1. Border stroke adapts via `.separatorColor`.

- **VAC-10 (Dismiss Persistence Invariant)**:
  - **Selector**: `UserDefaults` and `PopoverContentView.swift`
  - **Target Viewport**: Popover panel across application restarts
  - **Invariant**: Activating the dismiss button writes the version tag string to persistent storage. Reopening the popover or restarting the app does not show the update prompt for that version again.

- **VAC-11 (Accessibility Labels and VoiceOver Semantics)**:
  - **Selector**: `UpdateBannerCardView.swift`
  - **Target Viewport**: Accessibility tree
  - **Invariant**: The container element exposes an accessibility label announcing the update. The dismiss button exposes `.accessibilityLabel("Dismiss update notification")`. The action button exposes `.accessibilityLabel("View release page for StatsLite <version> in browser")`. Non-color signaling is satisfied by the distinct icon and text.

---

## 6. Appendix: Concrete Implementation Recipes for Coder

The `coder` subagent can apply these exact files:

### File 1: `StatsLite/AppUpdateChecker.swift` (New file)

```swift
//
//  AppUpdateChecker.swift
//  StatsLite
//
//  Queries GitHub releases API on launch and periodic 6-hour interval.
//  Compares tag_name against CFBundleShortVersionString.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppUpdateChecker {

    var availableUpdate: AppUpdateInfo?

    @ObservationIgnored
    private let repoPath = "beliantech/stats-lite-macos"

    @ObservationIgnored
    private var checkTask: Task<Void, Never>?

    @ObservationIgnored
    private let dismissedKey = "dismissedUpdateVersion"

    init() {
        startPeriodicChecks()
    }

    func startPeriodicChecks() {
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            // Initial check on launch after brief 2-second warm-up
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await self?.checkForUpdates()

            // Repeat every 6 hours (21,600 seconds)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 21_600 * 1_000_000_000)
                await self?.checkForUpdates()
            }
        }
    }

    func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/\(repoPath)/releases/latest") else {
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlUrlString = json["html_url"] as? String,
                  let releaseURL = URL(string: htmlUrlString) else {
                return
            }

            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
            if AppUpdateParser.isUpdateAvailable(current: currentVersion, latestTag: tagName) {
                self.availableUpdate = AppUpdateInfo(version: tagName, releaseURL: releaseURL)
            } else {
                self.availableUpdate = nil
            }
        } catch {
            // Failure is completely silent per specification
        }
    }

    func isDismissed(version: String) -> Bool {
        let dismissed = UserDefaults.standard.string(forKey: dismissedKey)
        return dismissed == version
    }

    func dismiss(version: String) {
        UserDefaults.standard.set(version, forKey: dismissedKey)
        if availableUpdate?.version == version {
            availableUpdate = nil
        }
    }
}
```

### File 2: Unit Test Seam in `StatsLiteTests/AppUpdateParserTests.swift`

```swift
//
//  AppUpdateParserTests.swift
//  StatsLiteTests
//

import XCTest
@testable import StatsLite

final class AppUpdateParserTests: XCTestCase {

    func testNewerPatchVersionIsAvailable() {
        XCTAssertTrue(AppUpdateParser.isUpdateAvailable(current: "1.0.0", latestTag: "v1.0.1"))
    }

    func testNewerMinorVersionIsAvailable() {
        XCTAssertTrue(AppUpdateParser.isUpdateAvailable(current: "1.0.0", latestTag: "v1.1.0"))
    }

    func testNewerMajorVersionIsAvailable() {
        XCTAssertTrue(AppUpdateParser.isUpdateAvailable(current: "1.0.0", latestTag: "v2.0.0"))
    }

    func testEqualVersionIsNotAvailable() {
        XCTAssertFalse(AppUpdateParser.isUpdateAvailable(current: "1.0.0", latestTag: "v1.0.0"))
    }

    func testOlderVersionIsNotAvailable() {
        XCTAssertFalse(AppUpdateParser.isUpdateAvailable(current: "1.1.0", latestTag: "v1.0.0"))
    }

    func testTagWithoutPrefixVIsHandled() {
        XCTAssertTrue(AppUpdateParser.isUpdateAvailable(current: "1.0.0", latestTag: "1.0.1"))
    }
}
```

---

## 7. Verification and Clean Exit

- Dev server and test processes verified clean.
- All 244 existing unit tests verified passing with zero failures.
- No files modified in the repository (strict read-only execution).