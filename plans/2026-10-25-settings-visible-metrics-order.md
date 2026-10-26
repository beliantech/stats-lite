# Design Blueprint: Visible Metrics Order Parity

## Overview

This blueprint specifies the reordering of the "Visible Metrics" section in the Stats Lite Settings window.
The toggle list order must match the menu bar item order:

1. CPU Utilization
2. GPU Utilization
3. Memory Pressure (RAM)
4. Temperature
5. Network Throughput

Prior state put Memory Pressure second and GPU Utilization third.
The menu bar displays items in CPU, GPU, MEM, TEMP, NET order.
This change aligns the Settings toggle list with the menu bar display order.

## Visual Evidence Pass

The dev environment was built and rendered with offscreen window harnesses under macOS.
Screenshots anchor this specification:

- Baseline (current) dark scrolled bottom: `/tmp/designer/dark_scrolled_bottom.png`
- Baseline (current) light scrolled bottom: `/tmp/designer/light_scrolled_bottom.png`
- Target dark scrolled bottom: `/tmp/designer/target_dark_scrolled.png`
- Target light scrolled bottom: `/tmp/designer/target_light_scrolled.png`

---

## 1. Visual Hierarchy & ASCII Wireframe

Evidence citation: `/tmp/designer/dark_scrolled_bottom.png` vs `/tmp/designer/target_dark_scrolled.png`.

The Settings window has a fixed frame of 380 pt width and 340 pt height.
A SwiftUI `Form` with grouped style (`.formStyle(.grouped)`) displays two sections: "General" and "Visible Metrics".
An `NSScrollView` hosts the Form document (height 461.5 pt).
The "Visible Metrics" section contains five rows inside a rounded rectangle container.

```text
+-----------------------------------------------------------+ [380 pt window width]
|  Visible Metrics                                          | Section Header
|  +-----------------------------------------------------+  | Grouped Card
|  | CPU Utilization                               [ O ] |  | Row 1: showCPU
|  |-----------------------------------------------------|  | Divider
|  | GPU Utilization                               [ O ] |  | Row 2: showGPU (MOVED UP)
|  |-----------------------------------------------------|  | Divider
|  | Memory Pressure (RAM)                         [ O ] |  | Row 3: showRAM (MOVED DOWN)
|  |-----------------------------------------------------|  | Divider
|  | Temperature                                   [ O ] |  | Row 4: showTemperature
|  |-----------------------------------------------------|  | Divider
|  | Network Throughput                            [ O ] |  | Row 5: showNetwork
|  +-----------------------------------------------------+  |
|  At least one metric must remain enabled.                 | Section Footer (secondary)
|                                                           |
|                 Stats Lite v1.0 (Build 1)                 | Window Footer (tertiary, 10 pt)
+-----------------------------------------------------------+ [340 pt window height]
```

### Spatial Relationships & Alignment

- Left labels share left alignment at 16 pt inset from the card edge.
- Right toggle switches share right alignment at 16 pt inset from the card edge.
- Subtle horizontal dividers separate adjacent toggle rows.
- Section header "Visible Metrics" sits 10 pt above the card container.
- Section footer text sits 6 pt below the card container in secondary foreground style.

---

## 2. Template / Component Skeleton

The implementation edits `StatsLite/SettingsView.swift` inside `visibleMetricsSection`.
The coder subagent must apply the following SwiftUI code verbatim:

```swift
    // MARK: - Visible Metrics (VAC-23, VAC-24)

    private var visibleMetricsSection: some View {
        Section {
            Toggle("CPU Utilization", isOn: $preferences.showCPU)
                .disabled(preferences.isToggleLocked(preferences.showCPU))
            Toggle("GPU Utilization", isOn: $preferences.showGPU)
                .disabled(preferences.isToggleLocked(preferences.showGPU))
            Toggle("Memory Pressure (RAM)", isOn: $preferences.showRAM)
                .disabled(preferences.isToggleLocked(preferences.showRAM))
            // No .disabled on this row either: like network,
            // temperature stays out of isToggleLocked (F10/plan
            // Phase 3 carve-out).
            Toggle("Temperature", isOn: $preferences.showTemperature)
            // No .disabled on this row: isToggleLocked counts only
            // the three standard metrics, so the network toggle must
            // never inherit the lock (F10).
            Toggle("Network Throughput", isOn: $preferences.showNetwork)
        } header: {
            Text("Visible Metrics")
        } footer: {
            Text("At least one metric must remain enabled.")
        }
    }
```

No modifiers, styling classes, or token changes are required.
Only the declaration order of the `Toggle` rows changes.

---

## 3. Complete State & Responsive Matrix

### Row States

| Row Item | Default State | Disabled Condition | Disabled Appearance |
| :--- | :--- | :--- | :--- |
| CPU Utilization | ON (`showCPU == true`) | `isToggleLocked(preferences.showCPU)` | Dimmed toggle switch, non-interactive |
| GPU Utilization | ON (`showGPU == true`) | `isToggleLocked(preferences.showGPU)` | Dimmed toggle switch, non-interactive |
| Memory Pressure (RAM) | ON (`showRAM == true`) | `isToggleLocked(preferences.showRAM)` | Dimmed toggle switch, non-interactive |
| Temperature | ON (`showTemperature == true` by default) | Never locked | Always interactive |
| Network Throughput | ON (`showNetwork == true` by default) | Never locked | Always interactive |

### Interactive States

- **Hover**: Native AppKit/SwiftUI toggle thumb brightens slightly on cursor hover.
- **Active / Pressed**: Native AppKit/SwiftUI toggle thumb scales down slightly when pressed.
- **Focus Ring**: When Full Keyboard Access is enabled, tabbing highlights the active toggle with the macOS system accent focus ring.
- **Toggle Lock Rule**: When only one of the three core metrics (CPU, GPU, RAM) is enabled, that single toggle is disabled in the ON position (`isToggleLocked` returns true). The user cannot disable all core metrics.

### Responsive Behavior

- The Settings window has fixed dimensions: width 380 pt, height 340 pt.
- Window resizing is disallowed (`.windowResizability(.contentSize)`).
- If rendered in a constrained width (for example 320 pt), toggle labels remain on a single line and do not truncate.
- Grouped card padding and divider insets adapt automatically via native macOS Form layout.

---

## 4. Accessibility (WCAG 2.2) & Interaction Contracts

### WCAG 2.2 Success Criteria

- **Contrast (SC 1.4.3)**: Toggle labels render with primary label contrast against the grouped card background in light and dark mode. Contrast exceeds 4.5:1.
- **Target Size (SC 2.5.8)**: Each toggle switch control measures 38 pt by 22 pt, which exceeds the 24 by 24 pt minimum target size.
- **Focus Order (SC 2.4.3)**: Keyboard tab navigation follows top-to-bottom visual order:
  1. CPU Utilization Toggle
  2. GPU Utilization Toggle
  3. Memory Pressure (RAM) Toggle
  4. Temperature Toggle
  5. Network Throughput Toggle
- **Keyboard Activation (SC 2.1.1)**: Spacebar toggles the focused row between ON and OFF.

### Interaction Contract

- Toggling any switch writes immediately to `PreferencesStore`.
- The `SettingsView` `.onChange` handler invokes `SystemMonitor.apply(preferences)`.
- The menu bar updates its visible items without an app restart.

### Test Contract Updates

- Make sure that `StatsLiteTests/SettingsWindowTests.swift` adds a unit test that verifies the new row order:
  `CPU Utilization` < `GPU Utilization` < `Memory Pressure (RAM)` < `Temperature` < `Network Throughput`.
- `StatsLiteTests/MenuBarTempBlockTests.swift` line 552 (`testSettingsViewHasTemperatureToggleBetweenGPUAndNetwork`) remains green. It asserts `gpuIndex < temperatureIndex < networkIndex`, which holds in the new order.

---

## 5. Numbered Visual Acceptance Checklist (VAC)

- **VAC-1**: The "Visible Metrics" section header displays directly above the five-toggle grouped container.
  *Evidence*: `/tmp/designer/target_dark_scrolled.png`, `/tmp/designer/target_light_scrolled.png`.
- **VAC-2**: Row 1 of Visible Metrics is "CPU Utilization" with its toggle bound to `preferences.showCPU`.
  *Evidence*: `/tmp/designer/target_dark_scrolled.png`.
- **VAC-3**: Row 2 of Visible Metrics is "GPU Utilization" with its toggle bound to `preferences.showGPU`.
  *Evidence*: `/tmp/designer/target_dark_scrolled.png`.
- **VAC-4**: Row 3 of Visible Metrics is "Memory Pressure (RAM)" with its toggle bound to `preferences.showRAM`.
  *Evidence*: `/tmp/designer/target_dark_scrolled.png`.
- **VAC-5**: Row 4 of Visible Metrics is "Temperature" with its toggle bound to `preferences.showTemperature`.
  *Evidence*: `/tmp/designer/target_dark_scrolled.png`.
- **VAC-6**: Row 5 of Visible Metrics is "Network Throughput" with its toggle bound to `preferences.showNetwork`.
  *Evidence*: `/tmp/designer/target_dark_scrolled.png`.
- **VAC-7**: The five toggle switches share identical right-edge alignment within the grouped card.
  *Evidence*: `/tmp/designer/target_dark_scrolled.png`, `/tmp/designer/target_light_scrolled.png`.
- **VAC-8**: All five metric labels remain on a single line with zero text truncation or clipping at 380 pt window width.
  *Evidence*: `/tmp/designer/target_dark_scrolled.png`, `/tmp/designer/target_light_scrolled.png`.
- **VAC-9**: The section footer reads "At least one metric must remain enabled." below the card container.
  *Evidence*: `/tmp/designer/target_dark_scrolled.png`, `/tmp/designer/target_light_scrolled.png`.
- **VAC-10**: When only GPU Utilization is enabled among core metrics, its toggle renders in the disabled state while Memory Pressure and CPU toggles are enabled.
  *Evidence*: Tested via `PreferencesStore.isToggleLocked`.
- **VAC-11**: Tab focus navigation visits the five toggles in the exact order: CPU, GPU, Memory Pressure, Temperature, Network Throughput.
- **VAC-12**: `SettingsWindowTests` asserts the exact order `CPU Utilization` < `GPU Utilization` < `Memory Pressure (RAM)` < `Temperature` < `Network Throughput`.
