# Design Blueprint: Settings Window Visible Metrics Lock For All Toggles

**Document version:** 1.0.0  
**Plan slug:** `2026-10-31-settings-visible-metrics-lock-all-toggles`  
**Target path:** `plans/2026-10-31-settings-visible-metrics-lock-all-toggles-blueprint.md`  
**Scope:** macOS Settings window Visible Metrics section (`StatsLite/SettingsView.swift` and `StatsLite/PreferencesStore.swift`).  

---

## Visual Evidence Pass (Problem Diagnosis)

### Current Problem Diagnosis
Two user-submitted screenshots document the defect:
- `client-72-clipboard-1793408394697845000-0.png` (Scenario 1):
  - CPU: OFF (interactive)
  - GPU: OFF (interactive)
  - Memory Pressure (RAM): ON (disabled, dimmed blue switch track, unclickable)
  - Temperature: ON (interactive, vibrant blue switch track)
  - Network Throughput: ON (interactive, vibrant blue switch track)
  - Defect: The Memory toggle renders disabled even though Temperature and Network are visibly enabled. Three metrics are enabled, yet Memory is locked.
- `client-72-clipboard-1793408433386844000-0.png` (Scenario 2):
  - CPU: OFF (interactive)
  - GPU: ON (disabled, dimmed blue switch track, unclickable)
  - Memory Pressure (RAM): OFF (interactive)
  - Temperature: ON (interactive, vibrant blue switch track)
  - Network Throughput: ON (interactive, vibrant blue switch track)
  - Defect: The GPU toggle renders disabled while three metrics are enabled.

### Verified Root Cause
1. `PreferencesStore.activeMetricCount` (`StatsLite/PreferencesStore.swift:94-96`) counts only CPU, RAM, and GPU. It excludes Temperature and Network.
2. `PreferencesStore.isToggleLocked` (`StatsLite/PreferencesStore.swift:101-103`) evaluates `activeMetricCount == 1 && isOn`. When only one of the three legacy metrics is enabled, `isToggleLocked` returns `true` even when Temperature and Network are enabled.
3. `SettingsView.visibleMetricsSection` (`StatsLite/SettingsView.swift:122-136`) attaches `.disabled(preferences.isToggleLocked(...))` only to CPU, GPU, and RAM. The Temperature and Network rows omit `.disabled` entirely.

### Approved Behavior Direction (Oracle Option A)
1. A toggle is disabled only when it is the last enabled metric among all five visible metrics.
2. When two or more metrics are enabled, all five toggles remain enabled and clickable.
3. All five rows receive the exact same `.disabled` modifier and macOS disabled toggle styling.
4. If a user or script attempts to turn off the fifth metric, the last enabled metric refuses to disable.
5. The section footer copy remains: `"At least one metric must remain enabled."`

---

## 1. Visual Hierarchy & ASCII Wireframe

Evidence citations:
- Problem Scenario 1 baseline: `client-72-clipboard-1793408394697845000-0.png`
- Problem Scenario 2 baseline: `client-72-clipboard-1793408433386844000-0.png`

The Settings window has a fixed width of 380 pt and a fixed height of 340 pt.
The window contains a grouped `Form` with two sections: "General" and "Visible Metrics".
Below the form sits the centered bundle version string.

### Wireframe: Target Multi-Enabled State (Scenario 1 Resolved)
When CPU and GPU are OFF, and Memory, Temperature, and Network are ON:
All three ON toggles remain vibrant and interactive.
Both OFF toggles remain interactive. Zero rows render disabled.

```text
+-----------------------------------------------------------+ [380 pt window width]
| Stats Lite Settings                               - [ ] x | Window Title Bar
+-----------------------------------------------------------+
|  General                                                  | Section 1: General
|  +-----------------------------------------------------+  |
|  | Refresh Interval                              1 s v |  | Row 1
|  | Network throughput always refreshes at 1-second...  |  | Caption
|  |-----------------------------------------------------|  | Divider
|  | History Duration                             60 s v |  | Row 2
|  |-----------------------------------------------------|  | Divider
|  | Launch at Login                               [   ] |  | Row 3
|  |-----------------------------------------------------|  | Divider
|  | Software Update              [ Check for Updates… ] |  | Row 4
|  +-----------------------------------------------------+  |
|                                                           |
|  Visible Metrics                                          | Section 2: Visible Metrics
|  +-----------------------------------------------------+  | Grouped Card Container
|  | CPU Utilization                               (   ) |  | Row 1: OFF, ENABLED
|  |-----------------------------------------------------|  | Divider (0.5 pt hairline)
|  | GPU Utilization                               (   ) |  | Row 2: OFF, ENABLED
|  |-----------------------------------------------------|  | Divider (0.5 pt hairline)
|  | Memory Pressure (RAM)                         ( * ) |  | Row 3: ON, ENABLED (RESOLVED)
|  |-----------------------------------------------------|  | Divider (0.5 pt hairline)
|  | Temperature                                   ( * ) |  | Row 4: ON, ENABLED
|  |-----------------------------------------------------|  | Divider (0.5 pt hairline)
|  | Network Throughput                            ( * ) |  | Row 5: ON, ENABLED
|  +-----------------------------------------------------+  |
|  At least one metric must remain enabled.                 | Section Footer (secondary)
|                                                           |
|                 Stats Lite v1.2.1 (Build 6)               | Window Footer (tertiary, 10 pt)
+-----------------------------------------------------------+ [340 pt window height]

Legend:
  (   ) = Toggle OFF, interactive (gray pill, white thumb on left)
  ( * ) = Toggle ON, interactive (accent blue pill, white thumb on right)
  [ X ] = Toggle ON, LOCKED/DISABLED (dimmed accent pill, dimmed label)
```

### Wireframe: Target Sole-Enabled Locked State (Network Only ON)
When CPU, GPU, RAM, and Temperature are OFF, and Network Throughput is ON:
Network Throughput is the last enabled metric.
The Network Throughput toggle renders in the disabled state.
The other four toggles render in the enabled state (clickable to turn on).

```text
|  Visible Metrics                                          | Section Header
|  +-----------------------------------------------------+  | Grouped Card Container
|  | CPU Utilization                               (   ) |  | Row 1: OFF, ENABLED
|  |-----------------------------------------------------|  | Divider (0.5 pt hairline)
|  | GPU Utilization                               (   ) |  | Row 2: OFF, ENABLED
|  |-----------------------------------------------------|  | Divider (0.5 pt hairline)
|  | Memory Pressure (RAM)                         (   ) |  | Row 3: OFF, ENABLED
|  |-----------------------------------------------------|  | Divider (0.5 pt hairline)
|  | Temperature                                   (   ) |  | Row 4: OFF, ENABLED
|  |-----------------------------------------------------|  | Divider (0.5 pt hairline)
|  | Network Throughput                            [ X ] |  | Row 5: ON, LOCKED/DISABLED
|  +-----------------------------------------------------+  |
|  At least one metric must remain enabled.                 | Section Footer (secondary)
```

### Spatial Relationships & Geometry
- Container: macOS grouped form card with continuous corner radius.
- Padding: 16 pt horizontal padding from the card edge to text labels and switch controls.
- Row heights: Standard macOS grouped toggle row height (~32 pt).
- Hairline dividers: 0.5 pt separator strokes spanning the card width inside default insets.
- Section header: 10 pt vertical clearance above the card container.
- Section footer: 6 pt vertical clearance below the card container in secondary foreground style.
- Toggle switch control: 38 pt width by 22 pt height, right-aligned.

---

## 2. Template / Component Skeleton

The coder subagent must apply the following changes verbatim.

### Component 1: `StatsLite/SettingsView.swift`
Replace the `visibleMetricsSection` computed property.
Remove the legacy carve-out comments.
Apply `.disabled(preferences.isToggleLocked(...))` to all five toggle rows.

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
            Toggle("Temperature", isOn: $preferences.showTemperature)
                .disabled(preferences.isToggleLocked(preferences.showTemperature))
            Toggle("Network Throughput", isOn: $preferences.showNetwork)
                .disabled(preferences.isToggleLocked(preferences.showNetwork))
        } header: {
            Text("Visible Metrics")
        } footer: {
            Text("At least one metric must remain enabled.")
        }
    }
```

### Component 2: `StatsLite/PreferencesStore.swift`
Update `PreferencesStore` to include Temperature and Network in the guard, the count, and the lock.

```swift
    // MARK: - Visible metrics (last-one-enabled guard)

    var showCPU: Bool = true {
        didSet {
            guard !isSeeding else { return }
            if !showCPU && activeMetricCount == 0 { showCPU = true }
            showCPUStorage = showCPU
        }
    }

    var showRAM: Bool = true {
        didSet {
            guard !isSeeding else { return }
            if !showRAM && activeMetricCount == 0 { showRAM = true }
            showRAMStorage = showRAM
        }
    }

    var showGPU: Bool = true {
        didSet {
            guard !isSeeding else { return }
            if !showGPU && activeMetricCount == 0 { showGPU = true }
            showGPUStorage = showGPU
        }
    }

    var showTemperature: Bool = true {
        didSet {
            guard !isSeeding else { return }
            if !showTemperature && activeMetricCount == 0 { showTemperature = true }
            showTemperatureStorage = showTemperature
        }
    }

    var showNetwork: Bool = true {
        didSet {
            guard !isSeeding else { return }
            if !showNetwork && activeMetricCount == 0 { showNetwork = true }
            showNetworkStorage = showNetwork
        }
    }

    // MARK: - Derived state

    /// Number of visible metrics enabled. All five metrics count
    /// toward visibility. The Settings UI disables the sole ON
    /// toggle when this value is 1.
    var activeMetricCount: Int {
        (showCPU ? 1 : 0)
            + (showGPU ? 1 : 0)
            + (showRAM ? 1 : 0)
            + (showTemperature ? 1 : 0)
            + (showNetwork ? 1 : 0)
    }

    /// True when `isOn` reports the state of the only enabled metric
    /// toggle. The Settings UI renders that toggle disabled in the
    /// ON position.
    func isToggleLocked(_ isOn: Bool) -> Bool {
        activeMetricCount == 1 && isOn
    }
```

---

## 3. Complete State & Responsive Matrix

### Toggle Visual Appearance Matrix

| State | Track Background | Thumb Position | Label Style | Cursor & Interaction |
| :--- | :--- | :--- | :--- | :--- |
| **ON & Interactive** | System accent color (vibrant blue) | Right edge | Primary text (`.primary`) | Pointer arrow. Click toggles to OFF. Spacebar toggles to OFF. |
| **OFF & Interactive** | System quaternary fill (neutral light gray) | Left edge | Primary text (`.primary`) | Pointer arrow. Click toggles to ON. Spacebar toggles to ON. |
| **ON & Locked (Disabled)** | System accent color with ~50% opacity | Right edge | Secondary text (`.secondary`, ~50% opacity) | Non-interactive. Click produces no change. Spacebar produces no change. |
| **OFF & Disabled** | **Unreachable state.** An OFF toggle never locks (`isToggleLocked(false)` is always `false`). | Left edge | N/A | N/A |

### State Matrix Across Metric Combinations

| Combination Scenario | Active Count | CPU Row | GPU Row | RAM Row | TEMP Row | NET Row |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **All 5 ON (Default)** | 5 | ON, Enabled | ON, Enabled | ON, Enabled | ON, Enabled | ON, Enabled |
| **4 Metrics ON** (Any 1 OFF) | 4 | Enabled | Enabled | Enabled | Enabled | Enabled |
| **3 Metrics ON** (Scenario 1: RAM, TEMP, NET) | 3 | OFF, Enabled | OFF, Enabled | ON, Enabled | ON, Enabled | ON, Enabled |
| **3 Metrics ON** (Scenario 2: GPU, TEMP, NET) | 3 | OFF, Enabled | ON, Enabled | OFF, Enabled | ON, Enabled | ON, Enabled |
| **2 Metrics ON** (Two of any five ON) | 2 | As Selected | As Selected | As Selected | As Selected | As Selected |
| **Sole Metric ON: CPU** | 1 | **ON, Locked** | OFF, Enabled | OFF, Enabled | OFF, Enabled | OFF, Enabled |
| **Sole Metric ON: GPU** | 1 | OFF, Enabled | **ON, Locked** | OFF, Enabled | OFF, Enabled | OFF, Enabled |
| **Sole Metric ON: RAM** | 1 | OFF, Enabled | OFF, Enabled | **ON, Locked** | OFF, Enabled | OFF, Enabled |
| **Sole Metric ON: Temperature** | 1 | OFF, Enabled | OFF, Enabled | OFF, Enabled | **ON, Locked** | OFF, Enabled |
| **Sole Metric ON: Network** | 1 | OFF, Enabled | OFF, Enabled | OFF, Enabled | OFF, Enabled | **ON, Locked** |

### Edge Case Handling (Attempted Zero Metrics)

1. **Attempt to turn off sole enabled metric via UI**:
   - The toggle is disabled in the ON state (`.disabled(true)`).
   - Mouse clicks and spacebar presses produce zero change.
2. **Attempt to turn off sole enabled metric via code**:
   - The setter `didSet` guard evaluates `if !show<Metric> && activeMetricCount == 0 { show<Metric> = true }`.
   - The property refuses to flip to `false` and remains `true`.
3. **Corrupted storage where all five keys are false**:
   - During startup, `PreferencesStore.init()` evaluates `if activeMetricCount == 0`.
   - It restores `showCPU = true` and `showCPUStorage = true` as the safe fallback.

### Responsive & Layout Invariants
- The Settings window frame is fixed at 380 pt width by 340 pt height.
- Resizing is disabled.
- All five metric label strings fit comfortably within the 380 pt width. No label truncates. No label wraps to a second line.
- Grouped card padding and switch alignment stay uniform in light and dark macOS appearance.

---

## 4. Accessibility (WCAG 2.2) & Interaction Contracts

### WCAG 2.2 Compliance
- **SC 1.4.3 Contrast (Minimum)**:
  - Enabled metric labels render in `.primary` text color. In light mode, contrast exceeds 13:1 against card background. In dark mode, contrast exceeds 12:1.
  - Section header and footer text exceed the 4.5:1 ratio for regular text.
  - Disabled controls follow native macOS platform conventions with reduced contrast to communicate non-interactive status.
- **SC 2.5.8 Target Size (Minimum)**:
  - Each toggle switch measures 38 pt by 22 pt.
  - The clickable row target extends across the entire container width (348 pt by ~32 pt), exceeding the 24 by 24 pt requirement.
- **SC 2.1.1 Keyboard Navigation**:
  - Full Keyboard Access allows Tab navigation through all five toggles in top-to-bottom visual order.
  - Pressing Spacebar toggles an enabled row.
  - Pressing Spacebar on a disabled row produces no change.
- **SC 2.4.3 Focus Order**:
  - Focus order strictly matches visual order:
    1. CPU Utilization
    2. GPU Utilization
    3. Memory Pressure (RAM)
    4. Temperature
    5. Network Throughput

### VoiceOver Contract
- Role: Switch / Toggle.
- Name: Row text label (for example "Temperature").
- Value: "1" (on) or "0" (off).
- State: When locked, VoiceOver announces "dimmed" or "disabled".

### Microcopy Review & Final Copy Proposal
- Current section footer copy: `"At least one metric must remain enabled."`
- Evaluation:
  - Before this change, the copy was misleading. The app locked CPU, GPU, or RAM even when Temperature and Network were enabled.
  - Under Option A, all five metrics participate equally in the rule.
  - The sentence contains 7 words, well within the Simplified Technical English limit of 25 words.
  - The sentence uses the approved modal `must` to declare a mandatory constraint.
  - The sentence contains zero contractions and zero technical jargon.
  - The copy matches native macOS Settings patterns.
- Recommendation: Keep `"At least one metric must remain enabled."` verbatim.

### Test Contract Updates
The implementation will update existing test assertions that enforced the legacy 3-metric carve-out:
1. `StatsLiteTests/SettingsWindowTests.swift`:
   - Update `testSoleEnabledToggleIsLocked` and `testSoleEnabledToggleIsRAMWhenOthersOff` to turn off all other four metrics before testing single-toggle lock.
   - Add tests asserting that Temperature and Network lock when each is the sole enabled metric.
2. `StatsLiteTests/PreferencesStoreGuardTests.swift`:
   - Update `testDefaultsEnableAllThreeMetrics` to verify all five metrics default to enabled (`activeMetricCount == 5`).
   - Replace `testShowNetworkDoesNotAffectStandardToggleLock` and `testShowNetworkDoesNotChangeActiveMetricCountOrEnabledMetrics` with assertions that Network participates in `activeMetricCount` and toggle locking.
3. `StatsLiteTests/PreferencesShowTemperatureWiringTests.swift`:
   - Replace `testShowTemperatureStaysOutsideCountGuardAndToggleLock` with assertions that Temperature participates in `activeMetricCount` and toggle locking.

---

## 5. Numbered Visual Acceptance Checklist (VAC)

All items verify on macOS in the Stats Lite Settings window (frame 380 pt by 340 pt).

- **VAC-1**: The Visible Metrics section lists exactly five toggle rows in sequential top-to-bottom order: `CPU Utilization`, `GPU Utilization`, `Memory Pressure (RAM)`, `Temperature`, `Network Throughput`.
- **VAC-2**: Below the grouped card, the section footer text reads `"At least one metric must remain enabled."` verbatim.
- **VAC-3**: When all five metrics are ON (default state), all five toggles render in the ON and interactive state with zero rows disabled.
- **VAC-4**: In Scenario 1 (CPU OFF, GPU OFF, Memory ON, Temperature ON, Network ON), all five toggles remain interactive. Specifically, the Memory Pressure (RAM) toggle renders in the enabled state and remains clickable.
- **VAC-5**: In Scenario 2 (CPU OFF, GPU ON, Memory OFF, Temperature ON, Network ON), all five toggles remain interactive. Specifically, the GPU Utilization toggle renders in the enabled state and remains clickable.
- **VAC-6**: When exactly two metrics are ON in any combination (for example Temperature ON and Network ON, with CPU, GPU, and RAM OFF), both ON toggles remain enabled and clickable.
- **VAC-7**: When CPU Utilization is the sole enabled metric (CPU ON, all other four OFF):
  - The CPU Utilization toggle renders ON and disabled (dimmed track, dimmed text label).
  - The other four toggles render OFF and enabled.
- **VAC-8**: When GPU Utilization is the sole enabled metric (GPU ON, all other four OFF):
  - The GPU Utilization toggle renders ON and disabled (dimmed track, dimmed text label).
  - The other four toggles render OFF and enabled.
- **VAC-9**: When Memory Pressure (RAM) is the sole enabled metric (RAM ON, all other four OFF):
  - The Memory Pressure (RAM) toggle renders ON and disabled (dimmed track, dimmed text label).
  - The other four toggles render OFF and enabled.
- **VAC-10**: When Temperature is the sole enabled metric (Temperature ON, all other four OFF):
  - The Temperature toggle renders ON and disabled (dimmed track, dimmed text label).
  - The other four toggles render OFF and enabled.
- **VAC-11**: When Network Throughput is the sole enabled metric (Network ON, all other four OFF):
  - The Network Throughput toggle renders ON and disabled (dimmed track, dimmed text label).
  - The other four toggles render OFF and enabled.
- **VAC-12**: Disabled visual parity: Across all five rows, the disabled ON state produces identical dimmed styling (accent track at ~50% opacity, label at secondary text opacity).
- **VAC-13**: All-five-attempted-off refusal:
  - In the UI, clicking a disabled sole-ON toggle produces no change.
  - In code, setting the sole-ON metric property to `false` is refused by the `didSet` guard, keeping `activeMetricCount == 1`.
  - When UserDefaults contains `false` for all five metric keys, `PreferencesStore.init()` resets `showCPU` to `true`.
- **VAC-14**: Layout stability: All five metric labels remain on a single line with zero text wrapping and zero clipping at 380 pt window width.
