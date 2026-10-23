# Plan: 2026-10-24-popover-activity-monitor-shortcut

Status: done — merged to `main` as 2c1c39e (2026-10-24). All 11 VAC items PASS.

Add an Activity Monitor shortcut button to the popover header, immediately left of the Settings gear.

## Current state

`PopoverContentView.header` (`StatsLite/PopoverContentView.swift:163-201`) renders, left to right: title `Stats Lite` (13 pt semibold), `Spacer()`, then two 24×24 plain buttons in `HStack(spacing: 8)`: Settings (`gearshape`, :171-181) and Quit (`power`, :183-193). No control launches Activity Monitor. The only external-launch precedent in the app is `NSWorkspace.shared.open(releaseURL)` at `StatsLite/UpdateBannerCardView.swift:71`.

## Target state

The header cluster renders three buttons: **Activity Monitor (new), Settings, Quit**. Clicking the new button launches macOS Activity Monitor via `NSWorkspace` (bundle id `com.apple.ActivityMonitor`, fallback path `/System/Applications/Utilities/Activity Monitor.app`). The button carries the tooltip and VoiceOver label `Open Activity Monitor`. The existing Settings and Quit buttons are unchanged. Two seams are exposed as static constants on `PopoverContentView` so the wiring is unit-testable.

## Hypothesis (falsification)

H1: The 280 pt fixed-width header can host a third 24×24 button at `spacing: 8` with no title truncation or wrap (designer budget: 60 pt title + 88 pt buttons + 24 pt padding = 172 pt, leaving a 108 pt spacer).
Falsification signature: if the title truncates or wraps at any VAC window width, or the cluster overlaps, H1 is dead — report the failure, do not resize the title.

## Scope

#### In
 Header button insertion (left of gear), `openActivityMonitor()` action, tooltip + accessibility label.
- Static seams + `StatsLiteTests/PopoverActivityMonitorShortcutTests.swift`.
- Dark/light VAC capture.

#### Out
 Keyboard shortcut (⌘-key) — "shortcut" here means the header quick-launch button only.
- Explicit popover-close logic from the view (no new closure seam in `StatusItemController`; launch activation + `.transient` behavior closes it — see Verification step 3).
- Any change to Settings, Quit, footer, menu-bar views, or the `stats-lite-macos` status item.
- `DESIGN.md` (absent at repo root; designer verified — all tokens come from `PopoverContentView.swift` + `DesignTokens.swift`).

## Design Blueprint (designer, verbatim)

# Design Blueprint: Activity Monitor Header Shortcut

## Visual Evidence Pass Summary

Visual evidence was captured directly from the macOS popover UI via `scripts/capture_baseline.sh` and custom AppKit/SwiftUI renderings. The popover dev instance was run with display caffeinated.

- Baseline Dark Mode Popover: `/tmp/designer/dark.png`
- Baseline Light Mode Popover: `/tmp/designer/light.png`
- SF Symbol Candidate Matrix: `/tmp/designer/all_symbols_dark.png`
- Proposed Header (Dark Mode): `/tmp/designer/proposed_header_dark.png`
- Proposed Header (Light Mode): `/tmp/designer/proposed_header_light.png`
- Proposed Header (Pressed State): `/tmp/designer/proposed_header_pressed_dark.png`
- Alternative Symbol (`waveform.path.ecg`): `/tmp/designer/proposed_header_alt_dark.png`

`DESIGN.md` was checked at the repository root and is absent. All visual tokens, layout dimensions, and component behaviors are grounded directly in `StatsLite/PopoverContentView.swift` and `StatsLite/DesignTokens.swift`.

---

### 1. Visual Hierarchy & ASCII Wireframe

The Stats Lite popover has a fixed width of 280 pt with 12 pt horizontal padding in the header row. The header row is 28 pt tall (base frame height).

The header contains the application title on the left and utility icon buttons on the right. Currently, the utility button cluster contains two buttons: Settings (`gearshape`) and Quit (`power`). The Activity Monitor shortcut button is inserted into this cluster immediately to the left of Settings.

#### ASCII Wireframe (Popover Header Row)

```text
|<----------------------------- 280 pt (Popover Width) ----------------------------->|
|                                                                                    |
|  12 pt pad                                                              12 pt pad  |
|  [--]                                                                        [--]  |
|                                                                                    |
|  +----------------+     +------------------+   +--------+   +--------+   +--------+|
|  |   Stats Lite   |     |     (Spacer)     |   | [~ pulse |   |  gear  |   | power  ||
|  |  13 pt semibold|     |    flex space     |   |  window] |   | shape  |   |        ||
|  |   (.primary)   |     |    (~108 pt)     |   |  (New)   |   |        |   |        ||
|  +----------------+     +------------------+   +--------+   +--------+   +--------+|
|       ~60 pt                                      24 pt        24 pt        24 pt  |
|                                                       <--8pt-->    <--8pt-->       |
|                                                                                    |
|------------------------------------------------------------------------------------|
|  10 pt pad              Divider() (0.5 pt separator line)               10 pt pad  |
```

#### Spatial Budget Breakdown

- Total popover width: 280 pt
- Horizontal outer padding: 12 pt left + 12 pt right = 24 pt
- Net header content width: 256 pt
- App title text ("Stats Lite", 13 pt semibold): ~60 pt
- Button cluster width: (3 buttons * 24 pt) + (2 gaps * 8 pt) = 88 pt
- Net flexible spacer width: 256 pt - 60 pt - 88 pt = 108 pt

The 108 pt remaining spacer ensures ample breathing room between the title and the action buttons. The layout prevents title truncation or touch/click target overlap.

---

### 2. Template / Component Skeleton

Target File: `StatsLite/PopoverContentView.swift`
Target Scope: `header` property in `PopoverContentView` and helper action `openActivityMonitor()`.

#### Verbatim Component Implementation

```swift
    // MARK: - Header (28 pt, Activity Monitor, gear, and quit 24x24 targets)

    private var header: some View {
        HStack(spacing: 8) {
            Text("Stats Lite")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

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
            .help("Open Activity Monitor")
            .accessibilityLabel("Open Activity Monitor")

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

    // MARK: - Actions

    /// Opens macOS Activity Monitor via bundle identifier or fallback app bundle path.
    private func openActivityMonitor() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            let fallbackURL = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
            NSWorkspace.shared.open(fallbackURL)
        }
    }
```

#### Symbol Choice Justification

- Primary Symbol: `waveform.path.ecg.rectangle`
  - Intrinsic glyph dimension: 16 pt width x 13 pt height at `size: 12, weight: .medium`.
  - Visual metaphor: Depicts a monitor window enclosing an activity wave trace. This directly mirrors the official macOS Activity Monitor application icon (`/System/Applications/Utilities/Activity Monitor.app`).
  - Balance: The rounded window outline provides optical parity with the circular cog `gearshape` (15x15 pt) and the circular ring `power` (15x15 pt). Refer to visual comparison in `/tmp/designer/all_symbols_dark.png`.
- Permissible Alternative: `waveform.path.ecg`
  - Intrinsic glyph dimension: 14 pt width x 15 pt height at `size: 12, weight: .medium`.
  - Open pulse line with no bounding rectangle. If an implementer prefers a borderless pulse, this symbol is fully compatible.

---

### 3. Complete State & Responsive Matrix

The popover panel operates at a fixed layout width of 280 pt on macOS. Responsive adaptations apply across system appearance modes (dark aqua vs aqua) rather than variable browser widths.

| State | Visual Appearance | Token / Modifier | Evidence |
| :--- | :--- | :--- | :--- |
| **Default (Dark Mode)** | Glyph renders in secondary label color on dark translucent material. No outer border or background pill. | `.foregroundStyle(.secondary)`, `.buttonStyle(.plain)` | `/tmp/designer/proposed_header_dark.png` |
| **Default (Light Mode)** | Glyph renders in secondary label color on light translucent material. Full contrast maintained against system vibrancy. | `.foregroundStyle(.secondary)`, `.buttonStyle(.plain)` | `/tmp/designer/proposed_header_light.png` |
| **Hover** | Cursor displays standard pointer. macOS native tooltip appears after standard hover dwell delay. No background shift. | `.help("Open Activity Monitor")` | Standard macOS AppKit tooltip mechanism |
| **Active / Pressed** | Button opacity drops to ~0.5–0.7 opacity while mouse is held down. Discrete instant response with zero spring animation. | Native `.buttonStyle(.plain)` press behavior | `/tmp/designer/proposed_header_pressed_dark.png` |
| **Keyboard Focus** | When navigating with Full Keyboard Access, system focus ring wraps the 24x24 pt interactive target. | System `.contentShape(Rectangle())` focus bounds | macOS Sonoma Accessibility Focus Ring |
| **Hit Target** | 24 pt width x 24 pt height bounding square. The full rectangle registers clicks, not just the glyph strokes. | `.frame(width: 24, height: 24).contentShape(Rectangle())` | Verbatim token parity with Settings and Quit |
| **Window Width (280 pt)** | Fixed popover width. Header items occupy 172 pt total (60 pt title + 88 pt buttons + 24 pt margins), leaving 108 pt flex spacer. | `.frame(width: 280).fixedSize(...)` | `/tmp/designer/dark.png`, `/tmp/designer/light.png` |

---

### 4. Accessibility (WCAG 2.2) & Interaction Contracts

#### WCAG 2.2 Criteria Compliance

1. **Target Size (Minimum) (SC 2.5.8 - Level AA)**:
   - Interactive bounding box is explicitly declared as `.frame(width: 24, height: 24)` with `.contentShape(Rectangle())`.
   - Spacing to adjacent controls is 8 pt on the right (Settings) and 108 pt flexible space on the left.
   - Meets the minimum 24x24 CSS pixel / point target size requirement without overlap.
2. **Contrast (Minimum) (SC 1.4.3 - Level AA)**:
   - Uses `.foregroundStyle(.secondary)` against system material background.
   - macOS system `.secondary` label color on `.regularMaterial` produces contrast >= 4.5:1 under both `.darkAqua` and `.aqua` system appearances.
3. **Name, Role, Value (SC 4.1.2 - Level A)**:
   - Interactive element is a native SwiftUI `Button` (`role: button`).
   - `.accessibilityLabel("Open Activity Monitor")` explicitly announces the button action to VoiceOver.
   - `.help("Open Activity Monitor")` sets the tooltip and fallback accessibility description.

#### Keyboard & Interaction Navigation

- **Tab Order**: Stats Lite Popover opens as a non-activating panel. If Full Keyboard Access is enabled, Tab navigates sequentially:
  1. Activity Monitor button
  2. Settings button
  3. Quit button
  4. Metric disclosure buttons
- **Activation**: Pressing Space or Return on the focused button executes `openActivityMonitor()`.
- **Dismissal / Focus Shift**: Invoking `openActivityMonitor()` activates the Activity Monitor application via `NSWorkspace`. The operating system transfers active key focus to Activity Monitor. The Stats Lite transient popover closes via its existing outside-click monitors.

---

### 5. Numbered Visual Acceptance Checklist (VAC)

- **VAC-1 (Header Button Order)**: In `PopoverContentView`, the header action controls must render from left to right as: Activity Monitor button, Settings button (`gearshape`), Quit button (`power`).
- **VAC-2 (Icon Selection)**: The Activity Monitor button must display the SF Symbol `waveform.path.ecg.rectangle` (or the accepted alternative `waveform.path.ecg`).
- **VAC-3 (Icon Typography & Weight)**: The button glyph must use `.font(.system(size: 12, weight: .medium))` and `.foregroundStyle(.secondary)`, matching the Settings and Quit icons.
- **VAC-4 (Hit Target Bounds)**: The interactive hit frame must measure exactly 24 pt width by 24 pt height with `.contentShape(Rectangle())`.
- **VAC-5 (Button Style)**: The button must use `.buttonStyle(.plain)` with zero custom border, zero custom background fill, and zero animated transitions.
- **VAC-6 (Header Spacing Invariant)**: The inter-button horizontal gap between Activity Monitor and Settings must measure 8 pt, defined by the parent `HStack(spacing: 8)`.
- **VAC-7 (Title Isolation)**: At the fixed 280 pt popover width, the title text "Stats Lite" must display with zero line wrapping or truncation, separated by a flexible `Spacer()` from the button cluster.
- **VAC-8 (Tooltip Microcopy)**: Hovering over the Activity Monitor button must display the native macOS tooltip with text `"Open Activity Monitor"`.
- **VAC-9 (Accessibility Label)**: The button must announce `"Open Activity Monitor"` to assistive technology via `.accessibilityLabel("Open Activity Monitor")`.
- **VAC-10 (Appearance Adaptability)**: The button must render legibly across both dark mode (`.darkAqua`) and light mode (`.aqua`) without manual color branching, inheriting macOS system `.secondary` foreground styling.
- **VAC-11 (Action Invocation)**: Clicking the button must resolve bundle identifier `"com.apple.ActivityMonitor"` and launch Activity Monitor using `NSWorkspace.shared.openApplication(at:configuration:)` or fallback URL `/System/Applications/Utilities/Activity Monitor.app`.

---

## Testability rule (implementation detail, visual contract unchanged)

To make VAC-8/VAC-9/VAC-11 unit-testable in the `@testable import StatsLite` style of `StatsLiteTests/PopoverVersionLabelTests.swift`, the blueprint's string/identifier literals are hoisted into static seams on `PopoverContentView`. The blueprint's visual tokens (symbol, font, colors, frames, spacing) are binding and must not change.

- `static let activityMonitorBundleIdentifier = "com.apple.ActivityMonitor"`
- `static let activityMonitorFallbackPath = "/System/Applications/Utilities/Activity Monitor.app"`
- `static let activityMonitorButtonLabel = "Open Activity Monitor"` — used by both `.help(...)` and `.accessibilityLabel(...)`.
- `openActivityMonitor()` reads the seams instead of inline literals.

Required tests in `StatsLiteTests/PopoverActivityMonitorShortcutTests.swift`:

1. `testActivityMonitorBundleIdentifierResolves` — `NSWorkspace.shared.urlForApplication(withBundleIdentifier: PopoverContentView.activityMonitorBundleIdentifier)` is non-nil (VAC-11 premise on the test host).
2. `testActivityMonitorFallbackPathExists` — `FileManager.default.fileExists(atPath: PopoverContentView.activityMonitorFallbackPath)` is true (VAC-11 fallback).
3. `testActivityMonitorButtonLabel` — `PopoverContentView.activityMonitorButtonLabel == "Open Activity Monitor"` (VAC-8/VAC-9 copy).

## Steps

- **step 1 — scout (done during planning):** located the insertion point and wiring. Report: Settings gear at `StatsLite/PopoverContentView.swift:175`, header property :163-201, `HStack(spacing: 8)` at :164, insertion point between `Spacer()` (:169) and the gear `Button` (:171); `NSWorkspace` precedent only at `UpdateBannerCardView.swift:71`; popover owned by `StatusItemController` (`.transient`), SwiftUI content has no popover-close seam; gotchas: LSUIElement activation, display-sleep close sensitivity, worktree duplicate sources. Session: `2026-10-23T23-10-19-271Z_838cdd56-5ebc9649-ff89f839-c405.jsonl`.
- **step 2 — designer (done during planning):** produced the 5-part Design Blueprint + 11 numbered VAC items above, with dark/light/pressed captures. Session: `2026-10-23T23-10-19-291Z_b4e8e61f-d646ed32-214f5401-0729.jsonl`.
- **step 3 — coder, worktree.** Worktree `/Users/jonathan/beliantech/stats-lite-macos/worktrees/2026-10-24-popover-activity-monitor-shortcut`, branch `feat/2026-10-24-popover-activity-monitor-shortcut` (created by planner from `main`). Implement the blueprint in `StatsLite/PopoverContentView.swift` (header insertion + `openActivityMonitor()` + static seams) and add `StatsLiteTests/PopoverActivityMonitorShortcutTests.swift`. Build and run the full test suite (commands in Verification 1-2), keep the display awake (`caffeinate`) during the run. Commit as one conventional commit (`feat(popover): add Activity Monitor shortcut next to Settings`). Report the branch name and the exact test command output tail. If the title truncates (H1 falsification), stop and report instead of resizing the title.
- **step 4 — reviewer.** Verify in the worktree: (a) the new test file exists and the full suite passes (re-run it), (b) diff matches the blueprint tokens (VAC-1..7 and VAC-11 statically checkable from source), (c) one clean commit on the branch, nothing outside scope (no `.animation`/`.contentTransition`, no popover-close seam, Settings/Quit/footer untouched), (d) plan/deviations matching. Report VERDICT: GO/NO-GO.
- **step 5 — designer, VAC pass.** In the worktree, run the app with the display caffeinated, capture dark + light header screenshots (`scripts/capture_baseline.sh` for baselines), verify all 11 VAC items live, and save the captures under `artifacts/2026-10-24-popover-activity-monitor-shortcut/` in the worktree (planner commits them) (VAC-8 tooltip, VAC-9 VoiceOver label, VAC-11 click launches Activity Monitor). Report PASS/FAIL per numbered VAC item with file paths to captures. FAIL on any visual defect (blocking policy).
- **step 6 — planner merges.** `git merge --ff-only feat/2026-10-24-popover-activity-monitor-shortcut` (or `--squash` + single commit), then remove the worktree and delete the branch. Report the merge SHA to the user. No deploy unless commanded.

## Verification

1. Build:
   ```sh
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
   xcodebuild build \
     -project StatsLite.xcodeproj \
     -scheme StatsLite \
     -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath .derivedData \
     CODE_SIGN_IDENTITY="-"
   ```
2. Test (display must be awake — popover lifecycle tests stall on a sleeping display; wrap in `caffeinate`):
   ```sh
   caffeinate -i env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
   xcodebuild test \
     -project StatsLite.xcodeproj \
     -scheme StatsLite \
     -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath .derivedData \
     CODE_SIGN_IDENTITY="-"
   ```
   Expected: all tests pass, including `PopoverActivityMonitorShortcutTests`.
3. Manual (step 5): open the popover → three header buttons in order Activity Monitor / gear / power, 8 pt gaps, title unwrapped; hover shows `Open Activity Monitor` tooltip; click launches Activity Monitor. **Popover-close check:** Activity Monitor activation should dismiss the `.transient` popover. If the popover stays open after Activity Monitor comes to front, record it as a defect in the report — do NOT add a close seam from the view (that is out of scope and needs a new design pass).
4. Run inside the worktree only; do not touch the main checkout during implementation.

## Result

- Merged ff-only: code `c7c58d8`, captures `2c1c39e`. Tests: 393 → green, incl. the 3 new seam tests.
- VAC-1…11 PASS in dark and light (`artifacts/2026-10-24-popover-activity-monitor-shortcut/`). H1 holds.
- **Recorded defect (out of scope here, follow-up decision):** after the button launches Activity Monitor, the popover stays open until the next outside click — `.transient` does not dismiss on app-to-front by itself. No close seam was added, per Verification step 3.
- Process note: the step-4 reviewer returned in 5 s without re-running tests; the planner re-ran the suite (twice, green) and reviewed the diff directly. The branch was rebased onto `main` (11518b8) first, because the TEMP-parity plan landed on `main` mid-task.

## Evidence / Links

- Designer session: `pi --session /Users/jonathan/.pi/agent/sessions/--Users-jonathan-beliantech-stats-lite-macos--/2026-10-23T23-10-19-291Z_b4e8e61f-d646ed32-214f5401-0729.jsonl`
- Scout session: `pi --session /Users/jonathan/.pi/agent/sessions/--Users-jonathan-beliantech-stats-lite-macos--/2026-10-23T23-10-19-271Z_838cdd56-5ebc9649-ff89f839-c405.jsonl`
- Designer captures: `/tmp/designer/dark.png`, `/tmp/designer/light.png`, `/tmp/designer/proposed_header_dark.png`, `/tmp/designer/proposed_header_light.png`, `/tmp/designer/proposed_header_pressed_dark.png`, `/tmp/designer/all_symbols_dark.png`
- Source: `StatsLite/PopoverContentView.swift:163-201` (header), `StatsLite/UpdateBannerCardView.swift:71` (NSWorkspace precedent), `StatsLiteTests/PopoverVersionLabelTests.swift` (test style), `README.md` (build/test commands).
