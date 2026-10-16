# Auto-Derived Sampling Interval & Expanded History Range

## Why

The user chose the sampling interval by hand (1/2/5 s) next to a 30/60 s history setting. Two interacting pickers confuse users and allow bad combos (1 s + long window = thousands of points to draw). We remove the interval picker and derive the interval from one user-facing choice: the history range. New range options: 5, 10, 15, 30, 60 minutes.

Memory cost is a non-issue: 24 B/point (HistoryBuffer.swift:13-24); worst case 720 points ≈ 17 KB per buffer.

## Current state → Target state

| Aspect | Current | Target |
|---|---|---|
| Interval picker | Manual 1/2/5 s in Settings (SettingsView.swift:48-51) | Removed; derived from history range |
| History options | 30 s / 60 s (SettingsView.swift:93-95) | 5/10/15/30/60 min |
| Stored `refreshInterval` | `@AppStorage` Int, default 2 (PreferencesStore.swift:54,107) | Derived computed property; storage key removed |
| Stored `historyDuration` | Int seconds, default 60 (PreferencesStore.swift:62,108) | Int seconds, default 1800; legacy 30/60 migrated to 1800 |
| Buffer capacity | `max(historyDuration * 2, 16)` (SystemMonitor.swift:123) | `max(historyDuration / refreshInterval, 16)` |
| Points per chart | ≤120 | 300–720 (bounded band, see mapping) |

## Mapping table (source of truth)

| Label | historyDuration (s) | refreshInterval (s) | sparklineCapacity | Default |
|---|---|---|---|---|
| 5 min | 300 | 1 | 300 | |
| 10 min | 600 | 1 | 600 | |
| 15 min | 900 | 2 | 450 | |
| 30 min | 1800 | 3 | 600 | Yes |
| 60 min | 3600 | 5 | 720 | Fallback |

## Implementation steps

1. **Create worktree** `worktrees/interval-history` on branch `feature/auto-interval-history` per the git-worktree skill. All code changes happen there; coder spawns get `cwd` = worktree.
2. **Red phase (tests first)** in `StatsLiteTests`:
   - `derivedRefreshInterval` returns 1/1/2/3/5 for 300/600/900/1800/3600.
   - Legacy migration: stored `historyDuration` of 30 or 60 loads as 1800; unknown values clamp to nearest valid option.
   - Buffer capacity at defaults = 600 (1800/3), not 3600.
   - Update `PreferencesStoreGuardTests.swift:126-133` for the new defaults/options.
   - Red run, capture output.
3. **Green phase**:
   - `PreferencesStore.swift`: replace stored `refreshInterval` with computed `derivedRefreshInterval` (keep name `refreshInterval: Int` as the derived property so call sites stay simple); remove `refreshIntervalStorage`; change `historyDuration` default to 1800; add migration in the load path (line 118-119 region) mapping any value not in {300,600,900,1800,3600} → 1800.
   - `SettingsView.swift`: delete the Refresh Interval picker; relabel history picker to `History Range` with the five options (`.pickerStyle(.menu)`); remove `.onChange(of: preferences.refreshInterval)` (line 40) — `historyDuration` change already triggers `monitor.apply`.
   - `SystemMonitor.swift:123`: capacity = `max(Int(historyDuration) / max(Int(refreshInterval), 1), 16)`.
   - `MenuBarStackedItemView.swift:44`: `onChange` still works via the derived property; verify observation fires when `historyDuration` changes.
   - `PopoverContentView.swift:111`: "Updated every …s" now shows the derived value (1/1/2/3/5); keep or drop the sentence — default keep, value auto-correct.
   - Green run, capture output.
4. **Code review** (reviewer): evidence = both test run outputs + full diff.
5. **Self-review checklist**: seven sections (S1–S7) per reviewer brief.
6. **Merge** `--ff-only` or `--squash` to `main`, report SHA.

## Acceptance criteria (VAC — all must pass)

- VAC-1: No "Refresh Interval" row anywhere in Settings.
- VAC-2: General section has only "Launch at Login"; no orphaned divider or trailing gap.
- VAC-3: Picker label reads exactly `History Range`.
- VAC-4: Picker offers exactly `5 min, 10 min, 15 min, 30 min, 60 min`.
- VAC-5: Native menu popup style (`.pickerStyle(.menu)`), right-aligned chevrons.
- VAC-6: Derivation 1/1/2/3/5 s per mapping table.
- VAC-7/8/9: No truncation/clipping at 375 / 768 / 1440 px widths.
- VAC-10: Window 450 pt shows all sections + footer with no scroll.
- Repo rule: no `.animation` / `.contentTransition` on status item views; transitions stay discrete.

## Risks & mitigations

- **Stored legacy values (30/60)** would match no picker tag → broken selection. Mitigated by explicit migration in step 2/3.
- **Observation**: derived `refreshInterval` must depend on `historyDuration` so `@Observable` re-fires `onChange` hooks; verify at MenuBarStackedItemView.swift:44.
- **720-point draw**: acceptable (no downsample needed); if review shows lag, add pixel-width downsample as follow-up — out of scope now.
- **Design constraint**: this project has no root DESIGN.md; blueprint grounds in `StatsLite/DesignTokens.swift` and native grouped-form standards (designer-verified).

---

# Appendix: Design Designer Blueprint (verbatim)

## Design Blueprint: Settings History Range & Sampling Interval UX

### Visual Evidence Pass Summary

- Dev server boot: Not applicable (native macOS AppKit/SwiftUI project; no HTTP web server port).
- `DESIGN.md` inspection: `DESIGN.md` does not exist at the repository root. All design tokens ground in `StatsLite/DesignTokens.swift`, AppKit semantic system colors, and native macOS grouped form standards.
- Visual captures captured and inspected:
  - Baseline settings (with refresh interval, height 340): `/tmp/designer/settings_current_dark_380.png` and `/tmp/designer/settings_current_light_380.png`. Finding: Height 340 caused `displayOptionsSection` to clip inside the embedded `NSScrollView`.
  - Target settings (refresh interval removed, 450 pt height): `/tmp/designer/clean_380_h450.png`.
  - Target settings with login item hint (470 pt height): `/tmp/designer/with_hint_380_h470.png`.
  - Responsive viewports:
    - 375px (Compact): `/tmp/designer/settings_target_375_dark.png` and `/tmp/designer/settings_target_375_light.png`.
    - 768px (Medium): `/tmp/designer/settings_target_768_dark.png` and `/tmp/designer/settings_target_768_light.png`.
    - 1440px (Wide): `/tmp/designer/settings_target_1440_dark.png` and `/tmp/designer/settings_target_1440_light.png`.

---

#### 1. Visual Hierarchy & ASCII Wireframe

The Settings scene displays a single grouped form with three clear sections followed by a centered version footer.

```
+-------------------------------------------------------------+
| Settings                                            _  [] X |
+-------------------------------------------------------------+
|                                                             |
| General                                                     |
| +---------------------------------------------------------+ |
| | Launch at Login                                    ( )  | |
| +---------------------------------------------------------+ |
|                                                             |
| Visible Metrics                                             |
| +---------------------------------------------------------+ |
| | CPU Utilization                                   (o )  | |
| |---------------------------------------------------------| |
| | Memory Pressure (RAM)                             (o )  | |
| |---------------------------------------------------------| |
| | GPU Utilization                                   (o )  | |
| +---------------------------------------------------------+ |
| At least one metric must remain enabled.                    |
|                                                             |
| Display Options                                             |
| +---------------------------------------------------------+ |
| | Show Per-Core CPU Breakdown                       (o )  | |
| |---------------------------------------------------------| |
| | History Range                                 [ 30 min v] | |
| +---------------------------------------------------------+ |
|                                                             |
|                  Stats Lite v1.0 (Build 1)                  |
|                                                             |
+-------------------------------------------------------------+
```

##### Layout and Spacing Specifications

1. Window frame:
   - Width: 380 pt standard macOS Settings window width.
   - Height: 450 pt base height (expands up to 470 pt to fit multi-line login item approval hints with zero clipping).
2. Form style:
   - `.formStyle(.grouped)`
   - System standard corner radius on section cards: 10 pt continuous.
   - Card background: `Color(nsColor: .controlBackgroundColor)` in light mode, dark translucent plate in dark mode.
   - Card separator: 0.5 pt `Color(nsColor: .separatorColor)`.
3. General section:
   - Contains exactly one row: `Launch at Login` toggle.
   - When the refresh interval picker is removed, the card shrinks to fit the single row. No divider line renders.
4. Visible Metrics section:
   - Contains three rows: CPU Utilization, Memory Pressure (RAM), GPU Utilization.
   - Section footer: `.caption` text "At least one metric must remain enabled." in `.secondary` foreground style.
5. Display Options section:
   - Contains two rows:
     - Row 1: `Show Per-Core CPU Breakdown` toggle.
     - Row 2: `History Range` popup menu picker.
   - Separator: standard 0.5 pt divider between row 1 and row 2.
6. Footer:
   - Version label: 10 pt system font in `.tertiary` style.
   - Padding: 4 pt top, 8 pt bottom, centered horizontally.

---

#### 2. Template / Component Skeleton

```swift
//
//  SettingsView.swift
//  StatsLite
//

import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    var monitor: SystemMonitor
    var launchAtLogin: LaunchAtLoginService

    var body: some View {
        VStack(spacing: 0) {
            Form {
                generalSection
                visibleMetricsSection
                displayOptionsSection
            }
            .formStyle(.grouped)

            Text(Self.versionLabel())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
        .frame(width: 380, height: 450)
        .onAppear {
            launchAtLogin.refresh()
            monitor.apply(preferences)
        }
        .onChange(of: preferences.enabledMetrics) { monitor.apply(preferences) }
        .onChange(of: preferences.historyDuration) { monitor.apply(preferences) }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            launchAtLoginRow
        }
    }

    private var launchAtLoginRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle("Launch at Login", isOn: launchAtLoginBinding)
                .disabled(loginItemLocked)

            if let hint = loginHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Visible Metrics (VAC-23, VAC-24)

    private var visibleMetricsSection: some View {
        Section {
            Toggle("CPU Utilization", isOn: $preferences.showCPU)
                .disabled(preferences.isToggleLocked(preferences.showCPU))
            Toggle("Memory Pressure (RAM)", isOn: $preferences.showRAM)
                .disabled(preferences.isToggleLocked(preferences.showRAM))
            Toggle("GPU Utilization", isOn: $preferences.showGPU)
                .disabled(preferences.isToggleLocked(preferences.showGPU))
        } header: {
            Text("Visible Metrics")
        } footer: {
            Text("At least one metric must remain enabled.")
        }
    }

    // MARK: - Display Options

    private var displayOptionsSection: some View {
        Section("Display Options") {
            Toggle("Show Per-Core CPU Breakdown", isOn: $preferences.showCoreBreakdown)
            historyPickerRow
        }
    }

    private var historyPickerRow: some View {
        Picker("History Range", selection: $preferences.historyDuration) {
            Text("5 min").tag(300)
            Text("10 min").tag(600)
            Text("15 min").tag(900)
            Text("30 min").tag(1800)
            Text("60 min").tag(3600)
        }
        .pickerStyle(.menu)
    }

    // MARK: - Launch at login

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: {
                launchAtLogin.state == .enabled
                    || launchAtLogin.state == .approvalNeeded
            },
            set: { turnOn in
                if turnOn {
                    launchAtLogin.register()
                } else {
                    launchAtLogin.unregister()
                }
            }
        )
    }

    private var loginItemLocked: Bool {
        switch launchAtLogin.state {
        case .approvalNeeded, .unavailable:
            return true
        case .enabled, .disabled, .notRegistered:
            return false
        }
    }

    private var loginHint: String? {
        switch launchAtLogin.state {
        case .approvalNeeded:
            return "Waiting for your approval in System Settings > General > Login Items."
        case .unavailable(let message):
            return message
        case .enabled, .disabled, .notRegistered:
            return launchAtLogin.errorMessage
        }
    }

    // MARK: - Version footer

    static func versionLabel(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Stats Lite v\(version) (Build \(build))"
    }
}
```

##### Derived Sampling Interval Store Logic

```swift
// Mapping in PreferencesStore.swift:
extension PreferencesStore {
    /// Sampling interval in seconds, derived from historyDuration.
    /// 5 min (300 s)  -> 1 s
    /// 10 min (600 s) -> 1 s
    /// 15 min (900 s) -> 2 s
    /// 30 min (1800 s) -> 3 s
    /// 60 min (3600 s) -> 5 s
    var derivedRefreshInterval: Int {
        switch historyDuration {
        case ...300: return 1
        case 301...600: return 1
        case 601...900: return 2
        case 901...1800: return 3
        default: return 5
        }
    }
}
```

---

#### 3. Complete State & Responsive Matrix

##### History Range and Sampling Interval Mapping Table

| Option Label | History Duration (Seconds) | Derived Refresh Interval (Seconds) | Sparkline Capacity (Points) | Default Selection |
|---|---|---|---|---|
| `5 min` | 300 | 1 | 300 | No |
| `10 min` | 600 | 1 | 600 | No |
| `15 min` | 900 | 2 | 450 | No |
| `30 min` | 1800 | 3 | 600 | Yes (Recommended default) |
| `60 min` | 3600 | 5 | 720 | Fallback |

##### Control State Matrix

| Control | State | Visual Appearance | Interactive Behavior |
|---|---|---|---|
| `History Range` Picker | Default / Closed | Right-aligned popup menu button displaying selected text (for example `30 min`) with vertical double chevron icon | Click or Space opens native dropdown menu |
| `History Range` Picker | Open / Active | Native macOS popover menu lists 5 items with checkmark on current selection | Click or Enter selects option; Esc cancels |
| `History Range` Picker | Focused | System blue focus ring around popup button boundary | Up/Down arrows traverse options; Space opens menu |
| `Launch at Login` Toggle | Normal | System switch toggle with leading label | Space or click toggles state |
| `Launch at Login` Toggle | Locked / Pending | Dimmed switch toggle; caption hint renders directly underneath | Non-interactive while locked |
| `CPU / RAM / GPU` Toggles | Normal | Standard enabled state; switch displays blue accent fill when active | Click or Space toggles state |
| `CPU / RAM / GPU` Toggles | Sole Active Locked | Disabled switch locked in the ON position; text remains normal weight | Non-interactive to protect last active metric |
| `Show Per-Core CPU Breakdown` | Normal | Standard switch toggle; leading label | Space or click toggles state |

##### Responsive Breakpoint Adaptations

| Viewport | Window Width | Layout Invariant | Evidence Capture |
|---|---|---|---|
| Compact (Mobile Equivalence) | 375 px | Grouped cards inset 16 pt from window boundaries; card width 343 pt; single-line labels without truncation | `/tmp/designer/settings_target_375_dark.png` |
| Standard Settings Window | 380 px | Standard fixed frame width; height 450 pt fits all 3 sections and version string without vertical scroll | `/tmp/designer/clean_380_h450.png` |
| Medium (Tablet Equivalence) | 768 px | Grouped cards stretch horizontally to fill available width; toggles and popup menu stay pinned to trailing edge | `/tmp/designer/settings_target_768_dark.png` |
| Wide (Desktop Equivalence) | 1440 px | Full-width expansion; labels remain left-aligned; controls stay right-aligned; version label remains centered | `/tmp/designer/settings_target_1440_light.png` |

---

#### 4. Accessibility (WCAG 2.2) & Interaction Contracts

##### WCAG 2.2 Criteria Conformance

1. Contrast ratios:
   - Primary text (`Launch at Login`, metric names, `History Range`) on card background: > 10.5:1 (passes WCAG AAA).
   - Secondary text (`At least one metric must remain enabled.`, login item hint): > 4.8:1 (passes WCAG AA).
   - Tertiary text (version footer): > 3.2:1 against main window background.
2. Target size:
   - Every toggle switch row: height 32 pt (exceeds 24x24 pt minimum).
   - Picker popup button: height 22 pt, interactive bounding box 70x22 pt (exceeds 24x24 pt minimum).
3. Focus appearance:
   - macOS native system focus ring with minimum 2 pt thickness and > 3:1 contrast against adjacent background.

##### NSAccessibility and VoiceOver Contracts

- History Picker:
  - Role: `AXPopUpButton`
  - Label: `"History Range"`
  - Value: Reads current selection, for example `"30 min"`
  - VoiceOver announcement: `"History Range, 30 min, pop up button"`
- Keyboard Navigation Order:
  1. `Launch at Login` switch
  2. `CPU Utilization` switch
  3. `Memory Pressure (RAM)` switch
  4. `GPU Utilization` switch
  5. `Show Per-Core CPU Breakdown` switch
  6. `History Range` popup button

##### Project Architectural Rule Note

Status item views in this repository must not use `.animation` or `.contentTransition`. Transitions in the Settings scene remain discrete and do not apply animations to status item components.

---

#### 5. Numbered Visual Acceptance Checklist (VAC)

- **VAC-1**: The "Refresh Interval" row is completely absent from the General section. (Evidence: `/tmp/designer/clean_380_h450.png`)
- **VAC-2**: The General section card contains only "Launch at Login", with zero orphaned divider lines, zero trailing gaps, and uniform padding. (Evidence: `/tmp/designer/clean_380_h450.png`)
- **VAC-3**: The Display Options history picker label reads exactly `History Range` left-aligned on its row. (Evidence: `/tmp/designer/clean_380_h450.png`)
- **VAC-4**: The history picker presents exactly five options: `5 min`, `10 min`, `15 min`, `30 min`, `60 min`. (Evidence: `/tmp/designer/clean_380_h450.png`)
- **VAC-5**: The history picker renders as a native macOS menu popup button (`.pickerStyle(.menu)`) with right-aligned vertical chevrons. (Evidence: `/tmp/designer/clean_380_h450.png`)
- **VAC-6**: Selecting `5 min` or `10 min` derives a 1 s sampling interval; `15 min` derives 2 s; `30 min` derives 3 s; `60 min` derives 5 s.
- **VAC-7**: At 375 px width, all row labels render on a single line without truncation, clipping, or horizontal scrolling. (Evidence: `/tmp/designer/settings_target_375_dark.png`, `/tmp/designer/settings_target_375_light.png`)
- **VAC-8**: At 768 px width, grouped section cards stretch across the form with controls pinned right and headers left-aligned. (Evidence: `/tmp/designer/settings_target_768_dark.png`, `/tmp/designer/settings_target_768_light.png`)
- **VAC-9**: At 1440 px width, the layout preserves proportional margins, single-line text rendering, and centered footer positioning. (Evidence: `/tmp/designer/settings_target_1440_dark.png`)
- **VAC-10**: The Settings window height (450 pt) displays all three sections and the version footer cleanly with zero vertical scroll requirement in standard state. (Evidence: `/tmp/designer/clean_380_h450.png`)
