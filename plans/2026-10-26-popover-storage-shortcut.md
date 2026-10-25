# Plan: 2026-10-26-popover-storage-shortcut

Status: done — merged to `main` as 586a733 (2026-10-26). VAC-1…12 PASS, 446 tests green.

Plan name: `2026-10-26-popover-storage-shortcut`
Risk class: R2 (UI work)

## Intent

Add a "Storage" shortcut button to the popover header, immediately left of the existing Activity Monitor shortcut. One click opens the Storage pane of macOS System Settings (`Settings.app`). The button reuses the exact header button style already used by the Activity Monitor, Settings gear, and Quit buttons.

User decision: popover header placement (approved 2026-10-26). Not the Settings window.

## Notation

Plan -> Phase -> Task (`T*`) -> Receipts (red SHA / green SHA / review verdict).

## ISC

Yes/no checks. A check passes only when the evidence exists.

- VAC-1 Header order, left to right: Stats Lite title, Storage (`internaldrive`), Activity Monitor (`waveform.path.ecg.rectangle`), gear (`gearshape`), Quit (`power`).
- VAC-2 Storage icon is SF Symbol `internaldrive` at `.system(size: 12, weight: .medium)`.
- VAC-3 Storage icon uses `.foregroundStyle(.secondary)` in light and dark appearance.
- VAC-4 Button declares `.frame(width: 24, height: 24)`, `.contentShape(Rectangle())`, `.buttonStyle(.plain)`.
- VAC-5 Gap between Storage and Activity Monitor buttons is 8 pt (`HStack(spacing: 8)`).
- VAC-6 Title `Stats Lite` (13 pt semibold) stays on one line. No wrap, no truncation.
- VAC-7 Flexible spacer between title and button cluster is at least 70 pt. No overlap of title and buttons.
- VAC-8 Tooltip on hover reads `Open Storage Settings`.
- VAC-9 VoiceOver label is `Open Storage Settings`.
- VAC-10 Click dispatches URL `x-apple.systempreferences:com.apple.settings.Storage`.
- VAC-11 Fallback: bundle id `com.apple.systempreferences`, then path `/System/Applications/System Settings.app`.
- VAC-12 Icon is visible and correctly aligned in `.aqua` and `.darkAqua`.
- FM1 Unit tests exist for the URL seam, bundle id, fallback path, and label, and they pass.
- FM2 Typecheck errors on changed files = 0, lint errors on changed files = 0.
- FM3 Existing Activity Monitor shortcut tests (`StatsLiteTests/PopoverActivityMonitorShortcutTests.swift`) and the full suite still pass.
- FM4 Live dark + light header captures exist under `artifacts/2026-10-26-popover-storage-shortcut/` with a PASS/FAIL row for every VAC item (zero visual defects — blocking policy).

Viewports: the popover has a fixed 280 pt width. VAC verification (amended A2): token/order VACs (VAC-1…VAC-7, VAC-12) check statically from source plus the live captures; VAC-8/VAC-9 check via source seams and the unit tests; VAC-10/VAC-11 verify through the FM1 unit tests plus a live click. Live captures need the screen unlocked and the display awake — wrap in `caffeinate` (AGENTS.md: popover close is display-sleep-sensitive). `MenuBarRenderSnapshotTests.swift` covers the menu bar only and is not used here.

## Approach

### Design Blueprint (designer; amended per plan-review round 1)

Amendments from plan review:
- **A1 (dead code)**: `URL(string:)` on the fixed literal never fails, so the original `else if`/`else` branches were unreachable and VAC-11 was untestable. The fallback now keys off `NSWorkspace.shared.open(url)` returning `false` (real failure signal: no handler for the scheme).
- **A2 (verification path)**: `StatsLiteTests/MenuBarRenderSnapshotTests.swift` renders the menu bar, not the popover header. Popover header VACs verify through live dark/light header captures (display awake, caffeinate) plus static source checks — see ISC note and T2.

## Executive Summary & Architectural Clarification

The task requests a "Storage" shortcut placed next to the existing "Activity Monitor" shortcut to open the Storage pane of macOS System Settings (`Settings.app`).

### Location Analysis & UX Consistency Push Back (Rule 6)
An inspection of the codebase reveals an architectural discrepancy:
1. **Existing Shortcut Location**: The existing Activity Monitor shortcut is implemented in the **menu bar popover header** (`StatsLite/PopoverContentView.swift:171-184`), immediately to the left of the Settings gear button (`gearshape`, lines 186-196).
2. **Current Settings Window (`SettingsView.swift`)**: The Settings window (`StatsLite/SettingsView.swift`) is a standard grouped configuration form (`Form { Section("General") ... Section("Visible Metrics") ... }`). It contains zero shortcut buttons or external launcher rows.
3. **UX & Architecture Recommendation**: Quick external launchers belong in the popover header. Menu bar utilities place launch buttons in the popover header for immediate single-click access. Placing shortcuts inside the Settings window requires three clicks (open popover, click Settings gear, click shortcut row).

This specification provides the **Primary Specification** for the popover header (`PopoverContentView.swift`) where the existing Activity Monitor shortcut lives. It also provides the **Alternative Specification** for `SettingsView.swift` if product requirements mandate a duplicate link inside the Settings window. *(User chose popover header.)*

### Design System Rules (`DESIGN.md`)
The repository root `DESIGN.md` defines rules strictly for menu bar metric labels (8 pt regular text with adaptive `Color.menuBarLabel`). It specifies no tokens for header icon buttons or form layouts. Header and settings styling tokens are therefore grounded in existing production views:
- `StatsLite/PopoverContentView.swift:163-239`
- `StatsLite/SettingsView.swift:1-160`
- `StatsLite/DesignTokens.swift:1-118`

---

### Visual Evidence Pass Summary

The design layout is verified against current visual captures in the repository:
- `artifacts/2026-10-24-popover-activity-monitor-shortcut/header-dark.png`: Dark mode popover header with Activity Monitor, Settings, and Quit buttons.
- `artifacts/2026-10-24-popover-activity-monitor-shortcut/header-light.png`: Light mode popover header with Activity Monitor, Settings, and Quit buttons.
- `artifacts/2026-10-24-popover-activity-monitor-shortcut/dark.png`: Full popover view showing fixed 280 pt width and 12 pt horizontal margins.
- `artifacts/2026-10-17-refresh-interval-network-caption/before/settings_window_dark.png`: Grouped Settings form at 380×340 pt.
- `artifacts/2026-10-17-refresh-interval-network-caption/after/short_copy_w380_dark.png`: Typography and row structure of the Settings window.

---

#### Part 1: Visual Hierarchy & ASCII Wireframe

##### Header Spatial Budget
- **Total Popover Width**: 280 pt (fixed width).
- **Horizontal Padding**: 12 pt leading + 12 pt trailing = 24 pt.
- **Available Header Width**: 256 pt.
- **App Title Width** (`Stats Lite`, 13 pt semibold): ~60 pt.
- **Header Button Cluster Width**:
  - 4 buttons × 24 pt = 96 pt.
  - 3 gaps × 8 pt = 24 pt.
  - Total cluster width = 120 pt.
- **Remaining Spacer Width**: 256 pt - 60 pt - 120 pt = 76 pt.
- **Layout Safety**: A 76 pt flexible spacer prevents title truncation and button collision.

##### ASCII Wireframe (Primary: Popover Header Row)

```text
|<----------------------------- 280 pt (Popover Width) ----------------------------->|
|                                                                                    |
|  12 pt pad                                                              12 pt pad  |
|  [--]                                                                        [--]  |
|                                                                                    |
|  +----------------+     +------------------+   +--------+   +--------+   +--------+   +--------+|
|  |   Stats Lite   |     |     (Spacer)     |   | [drive |   | [pulse |   |  gear  |   | power  ||
|  |  13 pt semibold|     |    flex space     |   |  icon] |   | window]|   | shape  |   |        ||
|  |   (.primary)   |     |      (76 pt)     |   |  (New) |   | (Exist)|   |        |   |        ||
|  +----------------+     +------------------+   +--------+   +--------+   +--------+   +--------+|
|       ~60 pt                                      24 pt        24 pt        24 pt        24 pt  |
|                                                       <--8pt-->    <--8pt-->    <--8pt-->       |
|                                                                                    |
|------------------------------------------------------------------------------------|
|  10 pt pad              Divider() (0.5 pt separator line)               10 pt pad  |
```

#### Part 2: Template / Component Skeleton

##### Existing Precedent Citations
- **Activity Monitor button**: `StatsLite/PopoverContentView.swift:171-184`
- **Settings button**: `StatsLite/PopoverContentView.swift:186-196`
- **Quit button**: `StatsLite/PopoverContentView.swift:198-208`
- **Static seams**: `StatsLite/PopoverContentView.swift:212-219`
- **Launch action**: `StatsLite/PopoverContentView.swift:223-239`

##### Verbatim Implementation Code

```swift
    // MARK: - Header (28 pt, Storage, Activity Monitor, gear, and quit 24x24 targets)

    private var header: some View {
        HStack(spacing: 8) {
            Text("Stats Lite")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                openStorageSettings()
            } label: {
                Image(systemName: "internaldrive")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Self.storageButtonLabel)
            .accessibilityLabel(Self.storageButtonLabel)

            Button {
                openActivityMonitor()
            } label: {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Self.activityMonitorButtonLabel)
            .accessibilityLabel(Self.activityMonitorButtonLabel)

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

    // MARK: - Storage actions (amended A1: fallback keys off open() result)

    /// Opens the macOS System Settings Storage pane. Falls back to launching
    /// System Settings by bundle identifier (or its path) when the URL has no
    /// handler: `NSWorkspace.shared.open` returns false in that case.
    private func openStorageSettings() {
        if let url = URL(string: Self.storageSettingsURLString),
           NSWorkspace.shared.open(url) {
            return
        }
        let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Self.systemSettingsBundleIdentifier
        ) ?? URL(fileURLWithPath: Self.systemSettingsFallbackPath)
        NSWorkspace.shared.openApplication(
            at: appURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    // MARK: - Storage seams

    /// URL string for the macOS System Settings Storage pane.
    static let storageSettingsURLString =
        "x-apple.systempreferences:com.apple.settings.Storage"

    /// Bundle identifier for macOS System Settings.
    static let systemSettingsBundleIdentifier = "com.apple.systempreferences"

    /// Fallback app bundle path when URL scheme handling fails.
    static let systemSettingsFallbackPath =
        "/System/Applications/System Settings.app"

    /// Tooltip and VoiceOver label for the Storage shortcut button.
    static let storageButtonLabel = "Open Storage Settings"
```

Note: the skeleton order above places the actions MARK before the seams MARK for readability; final source order follows the existing file's MARK convention. Only the amended `openStorageSettings()` body binds.

##### Unit Test Contract (`StatsLiteTests/PopoverStorageShortcutTests.swift`)
Mirrors `StatsLiteTests/PopoverActivityMonitorShortcutTests.swift:1-37`:

```swift
import AppKit
import XCTest
@testable import StatsLite

final class PopoverStorageShortcutTests: XCTestCase {

    func testStorageSettingsURLIsValid() {
        let url = URL(string: PopoverContentView.storageSettingsURLString)
        XCTAssertNotNil(
            url,
            "Storage settings URL must be valid, got: \(PopoverContentView.storageSettingsURLString)"
        )
    }

    func testSystemSettingsBundleIdentifierResolves() {
        let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: PopoverContentView.systemSettingsBundleIdentifier
        )
        XCTAssertNotNil(
            url,
            "System Settings bundle identifier must resolve to an installed app, got: \(PopoverContentView.systemSettingsBundleIdentifier)"
        )
    }

    func testSystemSettingsFallbackPathExists() {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: PopoverContentView.systemSettingsFallbackPath),
            "System Settings fallback path must exist on disk, got: \(PopoverContentView.systemSettingsFallbackPath)"
        )
    }

    func testStorageButtonLabel() {
        XCTAssertEqual(
            PopoverContentView.storageButtonLabel,
            "Open Storage Settings"
        )
    }
}
```

#### Part 3: Complete State & Responsive Matrix

##### Button State Specifications

| State | Visual Manifestation | SwiftUI Token / Modifier | Behavior Contract |
| :--- | :--- | :--- | :--- |
| **Default** | Outline `internaldrive` symbol rendered in `.secondary` foreground. No background fill or border. | `Image(systemName: "internaldrive")`<br>`.font(.system(size: 12, weight: .medium))`<br>`.foregroundStyle(.secondary)`<br>`.frame(width: 24, height: 24)` | Baseline passive presentation. |
| **Hover** | Standard macOS pointer cursor. Native tooltip appears after hover dwell. Zero background flicker. | `.help(Self.storageButtonLabel)` | Standard AppKit tooltip presentation. |
| **Active / Pressed** | Standard SwiftUI button opacity dip to approximately 60% opacity while clicked. | `.buttonStyle(.plain)` | Provides visual feedback on click. |
| **Focus-Visible** | Standard macOS accessibility focus ring surrounds the 24×24 pt frame during Full Keyboard Access. | System default focus ring | Visible during Tab key navigation. |
| **Disabled** | N/A (Shortcut remains persistently active and available). | None | Button is never disabled. |

##### Appearance Adaptation

| Appearance Mode | Icon Color | Background Context | Contrast Compliance |
| :--- | :--- | :--- | :--- |
| **Dark Appearance (`darkAqua`)** | System `.secondary` (~65% white over dark panel) | Dark translucent popover surface | Contrast ratio >= 4.5:1 against popover background. |
| **Light Appearance (`aqua`)** | System `.secondary` (~65% black over light panel) | Light translucent popover surface | Contrast ratio >= 4.5:1 against popover background. |

##### Responsive & Layout Bounds
- **Popover Header**: Fixed 280 pt width. Responsive stacking is not applicable.
- **Clipping Guard**: 76 pt flexible spacer guarantees that title and action cluster do not overlap.

#### Part 4: Accessibility (WCAG 2.2) & Interaction Contracts

##### WCAG 2.2 Criteria Compliance
1. **Target Size (Minimum) (SC 2.5.8 - Level AA)**: Button uses `.frame(width: 24, height: 24)` and `.contentShape(Rectangle())`. The interactive area measures exactly 24×24 pt.
2. **Contrast (Minimum) (SC 1.4.3 - Level AA)**: Foreground style `.secondary` provides compliant perceptual contrast against both light and dark translucent popover backgrounds.
3. **Name, Role, Value (SC 4.1.2 - Level A)**: Role is `Button`. VoiceOver accessibility label is explicitly assigned: `"Open Storage Settings"`.
4. **Focus Appearance (SC 2.4.13 - Level AAA)**: Conforms to native macOS AppKit focus ring around the 24×24 pt frame.

##### Interaction & Keyboard Contracts
- **Activation**: Clicking the button or pressing Space/Enter when focused calls `openStorageSettings()`.
- **System Settings Launch**: `NSWorkspace.shared.open(url)` opens macOS System Settings directly to the Storage pane.
- **Focus Transition**: When System Settings opens, macOS transitions key focus to System Settings. The transient Stats Lite popover closes automatically via its outside-click monitor.
- **VoiceOver Announcement**: Focus announces: *"Open Storage Settings, button"*.

#### Part 5: Numbered Visual Acceptance Checklist (VAC)

- **VAC-1 (Header Button Sequence)**: In `PopoverContentView.header`, the action buttons render from left to right in the exact order: Storage (`internaldrive`), Activity Monitor (`waveform.path.ecg.rectangle`), Settings (`gearshape`), Quit (`power`).
- **VAC-2 (Icon Selection)**: The Storage button renders SF Symbol `internaldrive` with `.font(.system(size: 12, weight: .medium))`.
- **VAC-3 (Icon Color Token)**: The Storage icon uses `.foregroundStyle(.secondary)` in both light and dark appearances.
- **VAC-4 (Interactive Hit Target)**: The button declares `.frame(width: 24, height: 24)` with `.contentShape(Rectangle())` and `.buttonStyle(.plain)`.
- **VAC-5 (Uniform Inter-Button Spacing)**: The horizontal gap between the Storage button and the Activity Monitor button measures exactly 8 pt, governed by `HStack(spacing: 8)`.
- **VAC-6 (Title Integrity & Zero Wrap)**: The app title `Stats Lite` (13 pt semibold) remains on a single line with zero truncation or text wrapping.
- **VAC-7 (Minimum Flexible Spacer Width)**: The flexible spacer between `Stats Lite` and the button cluster measures at least 70 pt across standard window scaling.
- **VAC-8 (Tooltip Microcopy)**: Hovering over the Storage button displays the native macOS tooltip text `"Open Storage Settings"`.
- **VAC-9 (Assistive VoiceOver Label)**: Assistive technologies read the button label as `"Open Storage Settings"`, set via `.accessibilityLabel("Open Storage Settings")`.
- **VAC-10 (URL Scheme Launch Seam)**: Activating the button dispatches URL `"x-apple.systempreferences:com.apple.settings.Storage"`.
- **VAC-11 (Fallback Resolution, amended A1)**: When `NSWorkspace.shared.open(url)` returns `false` (no handler for the scheme), the action falls back to `openApplication` with bundle identifier `"com.apple.systempreferences"`, or path `"/System/Applications/System Settings.app"` when the bundle id does not resolve. No unreachable `else` branches.
- **VAC-12 (Appearance Contrast Parity)**: The icon glyph maintains visible distinction and identical 24×24 pt alignment in both `.darkAqua` and `aqua` system appearances.

### Implementation notes

- Marker: `[skip-red]` is not used. The red phase writes the FM1 unit tests first, which fail because the seams do not exist yet.
- No band-aids or refactors needed: the change adds one button reusing existing patterns.
- AGENTS.md rules apply: no `.animation`/`.contentTransition` on status item views; this button adds none.

## Refactors

None required. No `TODO`/`FIXME`/`HACK` touched.

## Execution (git-worktree skill)

```bash
MAIN_REPO=/Users/jonathan/beliantech/stats-lite-macos
TASK_NAME=2026-10-26-popover-storage-shortcut
BRANCH="feat/${TASK_NAME}"
WORKTREE_DIR="${MAIN_REPO}/worktrees/${TASK_NAME}"
git -C "${MAIN_REPO}" worktree list   # check first; unique slug if needed
git -C "${MAIN_REPO}" worktree add -B "${BRANCH}" "${WORKTREE_DIR}" main
```

Coder spawn: `cwd` = `${WORKTREE_DIR}` (absolute). All commands below run inside `${WORKTREE_DIR}`:

```bash
# Unit tests (T1 red/green)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Debug -derivedDataPath .derivedData test -destination 'platform=macOS' -only-testing:StatsLiteTests/PopoverStorageShortcutTests

# Full suite (FM1/FM2/FM3)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project StatsLite.xcodeproj -scheme StatsLite -configuration Debug -derivedDataPath .derivedData test -destination 'platform=macOS'
```

Merging: ff-only (`git merge --ff-only feat/2026-10-26-popover-storage-shortcut`), planner owns the merge; then `git worktree remove`.

## Tasks

- [x] **T1** — Create the worktree, write red seam tests (`PopoverStorageShortcutTests`), then green: Storage button + reachable fallback in `PopoverContentView.swift` per the amended blueprint. red 3874729 · green 63bd662 · review GO
- [x] **T2** — Verify VACs: static source checks + FM1 unit tests + live dark/light header captures under `artifacts/2026-10-26-popover-storage-shortcut/` (caffeinated, display awake), PASS/FAIL per VAC item. red n/a · green VAC-1…12 PASS + FM1–FM4 PASS · review GO (designer)

## Receipts

- Plan review: NO GO round 1 (dead code in VAC-11 fallback, nonexistent snapshot-test citation, missing execution/worktree spec) → amended A1/A2 + Execution section → GO round 2. Session `2026-10-25T23-18-08-063Z_a2a6a197-a8b89136-b5f24060-a925.jsonl`.
- T1 red: commit `3874729` — 4 seam tests failed (missing seams), as expected.
- T1 green: commit `63bd662` — scoped tests 4/4, full suite **446 passed, 0 failed** (`TEST SUCCEEDED`).
- T1 code review: **GO** — suite re-run green, blueprint/VACs hold from source, only the two files in scope, no forbidden modifiers. Session `2026-10-25T23-25-02-017Z_9c9d4f22-822c50aa-20c2f586-7487.jsonl`.
- T2 VAC pass: **VAC-1…VAC-12 all PASS** in dark and light, zero visual defects; FM1–FM4 PASS. Captures: `artifacts/2026-10-26-popover-storage-shortcut/{header-dark,header-light,dark,light,hover-storage}.png`. Live click opened System Settings at the Storage pane. Session `2026-10-25T23-25-02-032Z_1eb77496-76fa3de1-17fa1880-bdfc.jsonl`.
- Merged ff-only: code + captures `586a733` (2026-10-26).
