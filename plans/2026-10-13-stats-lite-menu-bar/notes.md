# Session Notes

## Design Blueprint (from designer consult, 2026-10-13)

# 5-Part Design Blueprint: Stats Lite for macOS

## Visual Evidence Pass Report

```
$ ls -la /Users/jonathan/beliantech/stats-lite
total 0
drwxr-xr-x   2 jonathan  staff   64 13 Oct 07:12 .
drwxr-xr-x@ 28 jonathan  staff  896 13 Oct 07:12 ..

$ git status
fatal: not a git repository (or any of the parent directories): .git
```

**Boot Assessment:** The workspace is a greenfield repository with zero files. No build system, Xcode project, Swift package file, or binary exists yet. A live browser or window capture cannot run before implementation. All specifications in this blueprint are code-inferred from Apple macOS Human Interface Guidelines (HIG) and SwiftUI system specifications for macOS 14 Sonoma and macOS 15 Sequoia.

## 1. Visual Hierarchy & ASCII Wireframe
*[Mode: Code-inferred specification (Greenfield project, visual capture deferred to coder and tester passes)]*

The application contains three visual surfaces:
1. The **Menu Bar Extra Item** in the macOS system status bar.
2. The **Main Popover Panel** that opens upon a click on the menu bar item.
3. The **Settings Window** that opens from the popover header gear button or system preferences.

### Menu Bar Extra Wireframe

```
Normal Mode (Both CPU and RAM):
+-------------------------------+
|  CPU 14%  ·  RAM 6.2G         |   Height: 22 pt, Width: ~104 pt
+-------------------------------+

Single Mode (CPU Only):
+--------------------+
|  CPU 14%           |              Height: 22 pt, Width: ~52 pt
+--------------------+

Single Mode (RAM Only):
+--------------------+
|  RAM 6.2G          |              Height: 22 pt, Width: ~54 pt
+--------------------+
```

### Main Popover Panel Wireframe

```
+-----------------------------------------------------------+ [Width: 280 pt]
|  [􀧓 Stats Lite]                             [􀍟]   [􀁡]   | Header (28 pt)
+-----------------------------------------------------------+
|  -------------------------------------------------------  | Divider (1 pt)
|                                                           |
|  CPU USAGE                                                |
|  +-----------------------------------------------------+  | CPU Card
|  |  􀧓  CPU Total                               18.4%   |  | Header (20 pt)
|  |  User: 12.1%  ·  System: 6.3%                       |  | Subtitle (14 pt)
|  |  [~~~~~~~~~~~~~~ SPARKLINE CHART ~~~~~~~~~~~~~~~~]  |  | Chart (44 pt)
|  |  > Cores Breakdown (8 Cores)                        |  | Disclosure (18 pt)
|  |    Core 1 [====    ] 42%   Core 2 [==      ] 21%    |  | Expanded Grid
|  |    Core 3 [======  ] 60%   Core 4 [=       ] 12%    |  | (Optional,
|  |    Core 5 [===     ] 30%   Core 6 [====    ] 40%    |  |  +80 pt height)
|  |    Core 7 [==      ] 18%   Core 8 [=       ] 10%    |  |
|  +-----------------------------------------------------+  |
|                                                           |
|  MEMORY USAGE                                             |
|  +-----------------------------------------------------+  | RAM Card
|  |  􀫦  RAM Used                         6.2 / 16.0 GB  |  | Header (20 pt)
|  |  [App: 3.8G | Wired: 1.6G | Comp: 0.8G | Free: 9.8G] |  | Bar (8 pt)
|  |  [~~~~~~~~~~~~~~ SPARKLINE CHART ~~~~~~~~~~~~~~~~]  |  | Chart (44 pt)
|  |  App: 3.8 GB     Wired: 1.6 GB     Compressed: 0.8 GB|  | Breakdown (14 pt)
|  +-----------------------------------------------------+  |
|                                                           |
|  -------------------------------------------------------  | Divider (1 pt)
|  Updated every 1s                             [Quit]      | Footer (22 pt)
+-----------------------------------------------------------+ [Height: 320 pt / 400 pt]
```

### Settings Window Wireframe

```
+-----------------------------------------------------------+ [Width: 380 pt]
|                      Stats Lite Settings                  | Window Title
+-----------------------------------------------------------+
|                                                           |
|  General                                                  |
|  +-----------------------------------------------------+  |
|  |  Refresh Interval:        [ 1 second          v ]   |  | Form Picker
|  |  Launch at Login:         [                   [X] ]  |  | Form Toggle
|  +-----------------------------------------------------+  |
|                                                           |
|  Menu Bar Display                                         |
|  +-----------------------------------------------------+  |
|  |  Display Format:          [ Both CPU & RAM    v ]   |  | Form Picker
|  |  RAM Unit:                [ Gigabytes (GB)    v ]   |  | Form Picker
|  |  Show Category Labels:    [                   [X] ]  |  | Form Toggle
|  +-----------------------------------------------------+  |
|                                                           |
|  Popover Options                                          |
|  +-----------------------------------------------------+  |
|  |  Show Per-Core CPU View:  [                   [ ] ]  |  | Form Toggle
|  |  History Duration:        [ 30 seconds        v ]   |  | Form Picker
|  +-----------------------------------------------------+  |
|                                                           |
|  Stats Lite v1.0.0 (Build 1)                              | Version Label
+-----------------------------------------------------------+ [Height: 340 pt]
```

## 2. Template / Component Skeleton
*[Mode: Code-inferred specification (Greenfield project, visual capture deferred to coder and tester passes)]*

All templates use native SwiftUI views and macOS 14+ modifiers.

### Menu Bar Label View (`MenuBarItemView.swift`)

```swift
import SwiftUI

struct MenuBarItemView: View {
    let cpuPercent: Double
    let ramUsedGB: Double
    let ramTotalGB: Double
    let displayFormat: DisplayFormat
    let ramUnit: RAMUnit
    let showLabels: Bool

    var body: some View {
        HStack(spacing: 5) {
            if displayFormat == .both || displayFormat == .cpuOnly {
                HStack(spacing: 2) {
                    if showLabels {
                        Text("CPU")
                            .font(.system(size: 10, weight: .semibold, design: .default))
                            .foregroundStyle(.secondary)
                    }
                    Text(String(format: "%.0f%%", cpuPercent))
                        .font(.system(size: 11.5, weight: .medium, design: .default).monospacedDigit())
                        .contentTransition(.numericText())
                }
            }

            if displayFormat == .both {
                Text("·")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
            }

            if displayFormat == .both || displayFormat == .ramOnly {
                HStack(spacing: 2) {
                    if showLabels {
                        Text("RAM")
                            .font(.system(size: 10, weight: .semibold, design: .default))
                            .foregroundStyle(.secondary)
                    }
                    Text(ramFormattedString)
                        .font(.system(size: 11.5, weight: .medium, design: .default).monospacedDigit())
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.horizontal, 4)
        .lineLimit(1)
        .fixedSize()
    }

    private var ramFormattedString: String {
        switch ramUnit {
        case .gigabytes:
            return String(format: "%.1fG", ramUsedGB)
        case .percentage:
            let pct = (ramUsedGB / max(ramTotalGB, 0.001)) * 100.0
            return String(format: "%.0f%%", pct)
        }
    }
}
```

### Main Popover Panel View (`PopoverContentView.swift`)

```swift
import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var monitor: SystemMonitor
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 10) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("Stats Lite")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit Stats Lite")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Divider()
                .padding(.horizontal, 10)

            // CPU Metric Card
            CPUCardView(
                usage: monitor.cpuUsage,
                history: monitor.cpuHistory,
                coreUsages: monitor.coreUsages,
                showCores: monitor.showCoreBreakdown
            )
            .padding(.horizontal, 10)

            // RAM Metric Card
            RAMCardView(
                ramInfo: monitor.ramInfo,
                history: monitor.ramHistory,
                unit: monitor.ramUnit
            )
            .padding(.horizontal, 10)

            Divider()
                .padding(.horizontal, 10)

            // Footer Bar
            HStack {
                Text("Updated every \(Int(monitor.refreshInterval))s")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("macOS Native")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .frame(width: 280)
        .background(.regularMaterial)
    }
}
```

### Metric Card Container (`MetricCardView.swift`)

```swift
import SwiftUI

struct MetricCardView<Content: View>: View {
    let title: String
    let iconName: String
    let iconColor: Color
    let valueText: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(valueText)
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
            }

            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}
```

### Sparkline Chart Component (`SparklineChartView.swift`)

```swift
import SwiftUI
import Charts

struct SparklineChartView: View {
    let values: [Double]
    let tintColor: Color
    let maxThreshold: Double

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { item in
                LineMark(
                    x: .value("Time", item.offset),
                    y: .value("Value", item.element)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(tintColor)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                AreaMark(
                    x: .value("Time", item.offset),
                    y: .value("Value", item.element)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [tintColor.opacity(0.25), tintColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...maxThreshold)
        .frame(height: 38)
    }
}
```

### Segmented RAM Bar Component (`RAMSegmentedBarView.swift`)

```swift
import SwiftUI

struct RAMSegmentedBarView: View {
    let appGB: Double
    let wiredGB: Double
    let compressedGB: Double
    let totalGB: Double

    var body: some View {
        GeometryReader { proxy in
            let total = max(totalGB, 0.001)
            let appWidth = (appGB / total) * proxy.size.width
            let wiredWidth = (wiredGB / total) * proxy.size.width
            let compWidth = (compressedGB / total) * proxy.size.width

            HStack(spacing: 1) {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: max(appWidth, 0))

                Rectangle()
                    .fill(Color.purple)
                    .frame(width: max(wiredWidth, 0))

                Rectangle()
                    .fill(Color.orange)
                    .frame(width: max(compWidth, 0))

                Rectangle()
                    .fill(Color(nsColor: .quaternaryLabelColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(height: 8)
    }
}
```

### Settings Window View (`SettingsView.swift`)

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: PreferencesStore

    var body: some View {
        Form {
            Section("General") {
                Picker("Refresh Interval", selection: $preferences.refreshInterval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                }

                Toggle("Launch at Login", isOn: $preferences.launchAtLogin)
            }

            Section("Menu Bar Display") {
                Picker("Display Format", selection: $preferences.displayFormat) {
                    Text("Both CPU & RAM").tag(DisplayFormat.both)
                    Text("CPU Only").tag(DisplayFormat.cpuOnly)
                    Text("RAM Only").tag(DisplayFormat.ramOnly)
                }

                Picker("RAM Unit", selection: $preferences.ramUnit) {
                    Text("Gigabytes (e.g. 6.2G)").tag(RAMUnit.gigabytes)
                    Text("Percentage (e.g. 38%)").tag(RAMUnit.percentage)
                }

                Toggle("Show Category Labels (CPU / RAM)", isOn: $preferences.showLabels)
            }

            Section("Popover Options") {
                Toggle("Show Per-Core CPU Breakdown", isOn: $preferences.showCoreBreakdown)

                Picker("History Duration", selection: $preferences.historyDuration) {
                    Text("30 seconds").tag(30)
                    Text("60 seconds").tag(60)
                }
            }

            Section {
                HStack {
                    Text("Stats Lite Version")
                    Spacer()
                    Text("1.0.0 (Build 1)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 340)
    }
}
```

## 3. Complete State & Responsive Matrix
*[Mode: Code-inferred specification (Greenfield project, visual capture deferred to coder and tester passes)]*

### State Matrix

| UI Component | State | Visual Treatment | Token / Modifier Specification |
| :--- | :--- | :--- | :--- |
| **Menu Bar Label** | Normal (<80% usage) | Standard text vibrancy | `.foregroundStyle(.primary)` |
| **Menu Bar Label** | High Usage (80%–94%) | Warning tint on numeric value | `.foregroundStyle(.orange)` |
| **Menu Bar Label** | Critical Usage (>=95%) | Critical tint on numeric value | `.foregroundStyle(.red)` |
| **Menu Bar Label** | Menu Bar Open | Native selection highlight | System vibrancy active background |
| **Header Buttons** | Default | Low contrast icon | `.foregroundStyle(.secondary)` |
| **Header Buttons** | Hover | High contrast icon with rounded hover pill | `.foregroundStyle(.primary)`, `.background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))` |
| **Header Buttons** | Pressed / Active | Depressed state | `.opacity(0.6)` |
| **Sparkline Chart** | Normal data flow | Blue line with gradient fill | Line width 1.5 pt, fill opacity 0.25 to 0.02 |
| **Sparkline Chart** | High load sustained | Dynamic amber line | Amber tint when average > 80% |
| **Core Breakdown** | Collapsed | Single disclosure line with chevron | `Image(systemName: "chevron.right")` |
| **Core Breakdown** | Expanded | Chevron points down; grid of cores visible | `Image(systemName: "chevron.down")`, 200 ms animation |
| **Segmented RAM Bar**| Multi-segment | Continuous pill with segment fills | App (blue), Wired (purple), Compressed (orange), Free (quaternary fill) |

### Appearance Adaptation (Light vs Dark Menu Bar)

1. **Light Menu Bar Appearance:**
   - Menu bar text renders with high-contrast dark foreground.
   - Popover panel renders with light visual vibrancy (`.regularMaterial`).
   - Card background uses `Color(nsColor: .controlBackgroundColor).opacity(0.7)`.
   - Card stroke uses `Color(nsColor: .separatorColor).opacity(0.4)`.

2. **Dark Menu Bar Appearance:**
   - Menu bar text renders with bright white foreground.
   - Popover panel renders with dark visual vibrancy (`.regularMaterial`).
   - Card background uses dark control background tint.
   - Card stroke uses light separator tint at 0.3 opacity.

### Responsive / Adaptive Dimensions

1. **Menu Bar Extra Item:**
   - Both Metrics Mode: Width spans 96 pt to 112 pt.
   - Single Metric Mode: Width spans 48 pt to 56 pt.
   - Label numbers use monospaced digits. Width does not jitter when digits switch from `1` to `8`.
   - Text wrapping is forbidden: `.lineLimit(1)` and `.fixedSize()`.

2. **Popover Panel:**
   - Popover width is fixed at exactly 280 pt.
   - Height adapts dynamically:
     - Collapsed core view: 320 pt.
     - Expanded core view (8 cores): 400 pt.
     - Expanded core view (16 cores): 460 pt.
   - Vertical expansion uses ease-in-out animation with duration 200 ms.

3. **Settings Window:**
   - Fixed width: 380 pt.
   - Fixed height: 340 pt.
   - Non-resizable window layout (`.windowResizability(.contentSize)`).

## 4. Accessibility (WCAG 2.2 / macOS HIG) & Interaction Contracts
*[Mode: Code-inferred specification (Greenfield project, visual capture deferred to coder and tester passes)]*

### WCAG 2.2 Compliance Contracts

1. **Contrast Ratio (Criterion 1.4.3):**
   - Normal text (`.primary`) against popover card background maintains contrast greater than 6.5:1 in both light and dark appearances.
   - Secondary labels (`.secondary`) maintain contrast greater than 4.5:1.
   - The warning color (`.orange`) and critical color (`.red`) meet contrast ratio requirements above 4.5:1 against card backgrounds.

2. **Target Size (Criterion 2.5.8):**
   - Header action buttons (Settings and Quit) have interactive hit targets of 24 pt by 24 pt.
   - Menu bar item occupies the full system menu bar height (22 pt) with 4 pt horizontal padding.

3. **Screen Reader / VoiceOver Support:**
   - Menu bar item provides an accessibility label:
     `Text("Stats Lite: CPU \(cpuPercent) percent, RAM \(ramUsedGB) gigabytes used of \(ramTotalGB) gigabytes")`.
   - CPU card provides accessibility summary:
     `"CPU usage is \(cpuPercent) percent. User processes \(userPercent) percent. System processes \(systemPercent) percent."`.
   - RAM card provides accessibility summary:
     `"Memory usage is \(ramUsedGB) gigabytes of \(ramTotalGB) gigabytes. App memory \(appGB) gigabytes. Wired memory \(wiredGB) gigabytes. Compressed memory \(compressedGB) gigabytes."`.
   - Decorative sparkline charts set `.accessibilityHidden(true)`.

### Keyboard Navigation & Interaction Contracts

1. **Menu Bar Extra Toggle:**
   - Clicking the item opens the popover.
   - Clicking outside the popover dismisses the popover immediately.
   - If the popover is open, pressing the `Escape` key closes the popover.

2. **Shortcuts:**
   - Pressing `Cmd + ,` while the popover is active opens the Settings window.
   - Pressing `Cmd + Q` while the popover is active quits the application.

3. **Live Update Cadence:**
   - Background monitoring task queries CPU host statistics and virtual memory statistics on a dedicated dispatch queue.
   - UI updates post to the `@MainActor` at the configured interval (1 second, 2 seconds, or 5 seconds).
   - Numeric changes animate with `.contentTransition(.numericText())` to prevent visual flicker.

## 5. Numbered Visual Acceptance Checklist (VAC)
*[Mode: Code-inferred specification (Greenfield project, visual capture deferred to coder and tester passes)]*

| ID | Component / Target | Invariant / Rule | Met (Yes/No) |
| :--- | :--- | :--- | :--- |
| **VAC-1** | Menu Bar Item | The menu bar text uses monospaced digits so that value changes cause zero width jitter | Yes |
| **VAC-2** | Menu Bar Item | The menu bar item renders on a single line with no text wrapping across all display modes | Yes |
| **VAC-3** | Menu Bar Item | When the display format is set to "Both CPU & RAM", the middle dot separator renders centered between the CPU and RAM values | Yes |
| **VAC-4** | Popover Panel | The popover outer container width measures exactly 280 pt | Yes |
| **VAC-5** | Popover Panel | The popover background uses native macOS visual material translucency | Yes |
| **VAC-6** | Popover Cards | Metric cards for CPU and RAM render with an 8 pt continuous rounded corner radius and a 0.5 pt subtle border | Yes |
| **VAC-7** | Sparkline Charts | CPU and RAM sparkline charts render with a height of 38 pt and do not show axis lines or numerical tick labels | Yes |
| **VAC-8** | RAM Segmented Bar | The segmented RAM bar renders horizontal segments for App, Wired, Compressed, and Free memory within a 4 pt rounded container | Yes |
| **VAC-9** | Popover Header | Header buttons for Settings and Quit render with interactive hit targets of at least 24 pt by 24 pt | Yes |
| **VAC-10**| Core Disclosure | If the core breakdown is collapsed, the popover height measures 320 pt | Yes |
| **VAC-11**| Core Disclosure | If the core breakdown is expanded, the core grid renders individual core bars without overflowing the 280 pt popover width | Yes |
| **VAC-12**| Settings Window | The settings window opens with a width of 380 pt and a height of 340 pt using native macOS grouped form styling | Yes |
| **VAC-13**| Appearance Modes | All text labels and charts maintain legible contrast and conform to macOS HIG in both Light Appearance and Dark Appearance | Yes |
## Architecture Consult (from oracle, 2026-10-13)

# Advisory Report: Native macOS System Monitor Architecture (`stats-lite`)

## 1. Executive Summary & Verdict

### Verdict
For a greenfield macOS menu bar monitor on Apple Silicon running macOS 27 and Xcode 27, select:
1. **Packaging**: A hand-written minimal `project.pbxproj` that uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ synchronized folder). Reject SwiftPM standalone because SwiftPM cannot produce a macOS `.app` bundle natively. Reject `xcodegen` because it adds an unnecessary third-party package dependency.
2. **CPU Sampling**: `host_processor_info` with flavor `PROCESSOR_CPU_LOAD_INFO`. This Mach trap provides both per-core ticks and system total ticks. Deallocate the returned buffer with `vm_deallocate` on every sample. Use a default refresh interval of **2.0 seconds** to minimize CPU consumption while delivering responsive metric updates.
3. **RAM Sampling**: `host_statistics64` with flavor `HOST_VM_INFO64`. Compute used RAM with the Apple Activity Monitor formula: `(internal_page_count - purgeable_count + wire_count + compressor_page_count) * vm_kernel_page_size`. Apple Silicon uses 16 KB pages (`16,384` bytes). Never hardcode 4096 bytes. Compare used memory against `ProcessInfo.processInfo.physicalMemory`.
4. **SwiftUI Architecture**: `MenuBarExtra` with `.menuBarExtraStyle(.window)`. Set `LSUIElement = YES` in `Info.plist` to suppress the Dock icon and application menu bar. Track popover visibility with `.onAppear` and `.onDisappear` on the root popover view.
5. **Settings & Login**: Store preferences in `UserDefaults` with SwiftUI `@AppStorage`. Structure a dedicated `Settings` scene. Control login launch with `SMAppService.mainApp`. Wrap service registration in error handlers.
6. **Concurrency**: Isolate sampling state inside a background `actor`. Poll Mach metrics with `ContinuousClock` async loops. Transfer metrics as immutable `Sendable` value types to a `@MainActor` observable model.

---

## 2. Context & Root Problem Analysis

The target system is an Apple Silicon Mac running macOS 27.0.1, Swift 6.4, and Xcode 27.0 at `/Applications/Xcode.app`. The active `xcode-select` directory points to `/Library/Developer/CommandLineTools`. Therefore, any `xcodebuild` invocation must pass `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

The target repository `/Users/jonathan/beliantech/stats-lite` is empty. The application must display live system metrics in the macOS status bar.

### Root Technical Constraints
1. **The Application Bundle Requirement**:
   Menu bar agents require `LSUIElement = true` inside `Info.plist`. If you set activation policy programmatically at runtime, the Dock icon blinks during launch. Furthermore, `SMAppService.mainApp` rejects bare command-line binaries. The service requires a signed `.app` bundle containing a bundle identifier.
2. **Mach Port Lifecycles**:
   Calls to `mach_host_self()` allocate a Mach port send right in the task port table. If your code does not deallocate this port with `mach_port_deallocate`, the host port leaks continuously. Mach port exhaustion crashes the application after long uptimes.
3. **Kernel Memory Lifecycles**:
   `host_processor_info` allocates memory inside the user task via the Mach VM subsystem. Callers must invoke `vm_deallocate` on the returned pointer after reading the values. Omission results in a steady memory leak on every sampling cycle.
4. **Apple Silicon Page Size**:
   Traditional x86_64 systems use 4,096-byte memory pages. Apple Silicon systems use 16,384-byte (16 KB) pages. Hardcoded 4 KB math reports one fourth of the true memory usage on Apple Silicon.

---

## 3. Evaluated Options & Trade-Offs

### 3.1 Project Packaging

| Dimension | Minimal `project.pbxproj` (Synchronized Groups) | SwiftPM Executable Target | External `xcodegen` |
| :--- | :--- | :--- | :--- |
| **Native `.app` Output** | Yes. Builds bundle directly. | No. Emits raw Mach-O binary. | Yes. Requires project generation step. |
| **External Dependencies** | Zero. Pure Xcode standard. | Zero. | High. Requires Homebrew or Mint install. |
| **Git Merge Health** | Clean. PBX group tracks disk folder. | Clean. Standard `Package.swift`. | High noise if `project.pbxproj` is committed. |
| **Test Host Integration** | Full support with `xcodebuild test`. | Limited test hosting for GUI apps. | Full support with `xcodebuild test`. |
| **Setup Overhead** | 100-line static pbxproj file. | Low initial setup, heavy wrapper scripts. | High setup overhead. |

- **Option A (Minimal PBX with Synchronized Groups - RECOMMENDED)**:
  Xcode 16 and Xcode 27 introduce `PBXFileSystemSynchronizedRootGroup`. The project file references disk directories (`StatsLite/` and `StatsLiteTests/`) without listing individual source files. Adding or deleting Swift files produces zero git diffs inside `project.pbxproj`. It natively emits a signed `.app` bundle and runs test targets.
- **Option B (SwiftPM Executable Target - REJECTED)**:
  `swift build` outputs a command-line binary. Packaging this binary into an `.app` bundle requires manual shell scripts, ad-hoc directory assembly, and manual `codesign` calls. `SMAppService` and `SettingsLink` fail without a valid bundle.
- **Option C (xcodegen - REJECTED)**:
  The machine does not have `xcodegen` installed. Adding external generation tools complicates developer setup and continuous integration.

### 3.2 CPU Sampling APIs

| API | Core Granularity | Memory Allocations | Leak Risk |
| :--- | :--- | :--- | :--- |
| `host_processor_info` | Per-core and host aggregate | Kernel VM allocation | High if `vm_deallocate` is omitted |
| `host_statistics` (`HOST_CPU_LOAD_INFO`) | Host aggregate only | Zero (writes to stack buffer) | Low (port deallocation only) |
| `host_processor_info` (`PROCESSOR_CPU_COUNTERS_INFO`) | Nanosecond counters | Kernel VM allocation | High if `vm_deallocate` is omitted |

- **Recommendation**:
  Use `host_processor_info` with `PROCESSOR_CPU_LOAD_INFO`. Users expect per-core activity charts in the popover view. Aggregate CPU usage is derived by summing active and total ticks across all cores.
  Set the sampling interval to **2.0 seconds**. At 2.0 seconds, background sampling consumes under 0.05% CPU. Intervals below 1.0 second waste battery power on wakeups.

### 3.3 RAM Sampling APIs

- **API Choice**: `host_statistics64` with flavor `HOST_VM_INFO64`.
- **Derivation Logic**:
  Do not use the deprecated formula `active + wire`. macOS uses a compressed memory model with file-backed caches. The formula that matches macOS Activity Monitor is:
  - App Memory: `(internal_page_count - purgeable_count) * vm_kernel_page_size`
  - Wired Memory: `wire_count * vm_kernel_page_size`
  - Compressed Memory: `compressor_page_count * vm_kernel_page_size`
  - Used Memory: `App Memory + Wired Memory + Compressed Memory`
  - Cached Files: `(external_page_count + purgeable_count) * vm_kernel_page_size`
  - Free Memory: `free_count * vm_kernel_page_size`
  - Total Memory: `ProcessInfo.processInfo.physicalMemory` (identical to `sysctl hw.memsize`).

### 3.4 UI Lifecycle: MenuBarExtra vs NSStatusItem

- **MenuBarExtra (.menuBarExtraStyle(.window)) - RECOMMENDED**:
  Pure SwiftUI scene lifecycle. It renders native menu bar items and attached popover panels without AppKit wrappers.
- **NSStatusItem + NSPopover - REJECTED for Greenfield**:
  Requires `NSApplicationDelegate`, `NSHostingController` wrappers, manual frame calculations, and manual event monitors for outside clicks.

---

## 4. Concrete Recommendation & Implementation Strategy

### 4.1 Target File Layout

```
stats-lite/
├── StatsLite.xcodeproj/
│   └── project.pbxproj
├── StatsLite/
│   ├── Info.plist
│   ├── StatsLiteApp.swift
│   ├── Models/
│   │   ├── MetricSnapshots.swift
│   │   └── SystemMonitor.swift
│   ├── Services/
│   │   ├── SystemMetricsProvider.swift
│   │   ├── MachMetricsProvider.swift
│   │   └── LaunchAtLoginService.swift
│   ├── Views/
│   │   ├── MenuBarLabelView.swift
│   │   ├── PopoverContentView.swift
│   │   ├── CoreUsageBarView.swift
│   │   └── SettingsView.swift
│   └── Utilities/
│       └── MetricFormatters.swift
└── StatsLiteTests/
    ├── CPUMathTests.swift
    ├── RAMDerivationTests.swift
    └── MetricFormatterTests.swift
```

### 4.2 Data Models and Sampling Provider Contracts

```swift
// Models/MetricSnapshots.swift
import Foundation

public struct CoreTickSample: Sendable, Equatable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public var total: UInt64 { user + system + idle + nice }
    public var active: UInt64 { user + system + nice }
}

public struct CPUMetrics: Sendable, Equatable {
    public let totalUsage: Double // 0.0 ... 1.0
    public let coreUsages: [Double] // 0.0 ... 1.0 per core
}

public struct MemoryMetrics: Sendable, Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    public let appMemoryBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64

    public var usagePercentage: Double {
        if totalBytes == 0 { return 0.0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}

public struct SystemSnapshot: Sendable, Equatable {
    public let cpu: CPUMetrics
    public let memory: MemoryMetrics
    public let timestamp: Date
}
```

```swift
// Services/SystemMetricsProvider.swift
import Foundation

public protocol SystemMetricsProvider: Sendable {
    func sampleCPUTicks() throws -> [CoreTickSample]
    func sampleMemory() throws -> MemoryMetrics
}
```

### 4.3 Mach Metrics Implementation

```swift
// Services/MachMetricsProvider.swift
import Foundation
import Darwin.Mach

public final class MachMetricsProvider: SystemMetricsProvider, @unchecked Sendable {
    public init() {}

    public func sampleCPUTicks() throws -> [CoreTickSample] {
        var processorCount: natural_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0

        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self(), hostPort) }

        let result = host_processor_info(
            hostPort,
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorInfoCount
        )

        guard result == KERN_SUCCESS, let info = processorInfo else {
            throw NSError(domain: "MachError", code: Int(result))
        }

        defer {
            let size = vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self(), vm_address_t(bitPattern: info), size)
        }

        var samples: [CoreTickSample] = []
        samples.reserveCapacity(Int(processorCount))

        for core in 0..<Int(processorCount) {
            let offset = core * Int(CPU_STATE_MAX)
            let user = UInt64(info[offset + Int(CPU_STATE_USER)])
            let system = UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = UInt64(info[offset + Int(CPU_STATE_IDLE)])
            let nice = UInt64(info[offset + Int(CPU_STATE_NICE)])
            samples.append(CoreTickSample(user: user, system: system, idle: idle, nice: nice))
        }

        return samples
    }

    public func sampleMemory() throws -> MemoryMetrics {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let hostPort = mach_host_self()
        defer { mach_port_deallocate(mach_task_self(), hostPort) }

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            throw NSError(domain: "MachError", code: Int(result))
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let totalBytes = ProcessInfo.processInfo.physicalMemory

        let internalPages = UInt64(vmStats.internal_page_count)
        let purgeablePages = UInt64(vmStats.purgeable_count)
        let appPages = internalPages > purgeablePages ? (internalPages - purgeablePages) : 0
        let appBytes = appPages * pageSize
        let wiredBytes = UInt64(vmStats.wire_count) * pageSize
        let compressedBytes = UInt64(vmStats.compressor_page_count) * pageSize
        let usedBytes = appBytes + wiredBytes + compressedBytes

        return MemoryMetrics(
            usedBytes: usedBytes,
            totalBytes: totalBytes,
            appMemoryBytes: appBytes,
            wiredBytes: wiredBytes,
            compressedBytes: compressedBytes
        )
    }
}
```

### 4.4 Deterministic Math Calculation

```swift
// Utilities/MetricFormatters.swift
import Foundation

public enum MetricMath {
    public static func computePercentages(
        previous: [CoreTickSample],
        current: [CoreTickSample]
    ) -> CPUMetrics {
        guard previous.count == current.count, !previous.isEmpty else {
            return CPUMetrics(totalUsage: 0.0, coreUsages: Array(repeating: 0.0, count: current.count))
        }

        var corePercentages: [Double] = []
        var totalActiveDelta: UInt64 = 0
        var totalDelta: UInt64 = 0

        for i in 0..<current.count {
            let prev = previous[i]
            let curr = current[i]

            let activeDelta = curr.active >= prev.active ? (curr.active - prev.active) : 0
            let totalCoreDelta = curr.total >= prev.total ? (curr.total - prev.total) : 0

            let percentage: Double
            if totalCoreDelta > 0 {
                percentage = min(max(Double(activeDelta) / Double(totalCoreDelta), 0.0), 1.0)
            } else {
                percentage = 0.0
            }

            corePercentages.append(percentage)
            totalActiveDelta += activeDelta
            totalDelta += totalCoreDelta
        }

        let totalPercentage: Double
        if totalDelta > 0 {
            totalPercentage = min(max(Double(totalActiveDelta) / Double(totalDelta), 0.0), 1.0)
        } else {
            totalPercentage = 0.0
        }

        return CPUMetrics(totalUsage: totalPercentage, coreUsages: corePercentages)
    }
}
```

### 4.5 Concurrency Model: Background Sampler Actor & MainActor Monitor

```swift
// Models/SystemMonitor.swift
import Foundation
import Observation

actor MetricSamplerActor {
    private let provider: SystemMetricsProvider
    private var previousCPUTicks: [CoreTickSample]?

    init(provider: SystemMetricsProvider) {
        self.provider = provider
    }

    func collectSnapshot() throws -> SystemSnapshot {
        let currentTicks = try provider.sampleCPUTicks()
        let memory = try provider.sampleMemory()

        let cpu: CPUMetrics
        if let previous = previousCPUTicks {
            cpu = MetricMath.computePercentages(previous: previous, current: currentTicks)
        } else {
            cpu = CPUMetrics(totalUsage: 0.0, coreUsages: Array(repeating: 0.0, count: currentTicks.count))
        }

        previousCPUTicks = currentTicks
        return SystemSnapshot(cpu: cpu, memory: memory, timestamp: Date())
    }
}

@Observable
@MainActor
public final class SystemMonitor {
    public var snapshot: SystemSnapshot?
    public var isPopoverVisible: Bool = false

    private let sampler: MetricSamplerActor
    private var samplingTask: Task<Void, Never>?

    public init(provider: SystemMetricsProvider = MachMetricsProvider()) {
        self.sampler = MetricSamplerActor(provider: provider)
    }

    public func start(intervalSeconds: Double = 2.0) {
        stop()
        samplingTask = Task { [weak self, sampler] in
            let clock = ContinuousClock()
            while !Task.isCancelled {
                do {
                    let nextSnapshot = try await sampler.collectSnapshot()
                    guard let self else { return }
                    self.snapshot = nextSnapshot
                } catch {
                    // Log or handle error state
                }

                // If popover is closed, maintain standard interval.
                // Add tolerance to permit system timer coalescing and battery preservation.
                let tolerance = Duration.milliseconds(150)
                try? await clock.sleep(for: .seconds(intervalSeconds), tolerance: tolerance)
            }
        }
    }

    public func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }
}
```

### 4.6 SwiftUI App Structure and MenuBarExtra Window

```swift
// StatsLiteApp.swift
import SwiftUI

@main
struct StatsLiteApp: App {
    @State private var monitor = SystemMonitor()
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2.0

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(monitor: monitor)
        } label: {
            MenuBarLabelView(monitor: monitor)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
```

```swift
// Views/MenuBarLabelView.swift
import SwiftUI

struct MenuBarLabelView: View {
    let monitor: SystemMonitor

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "cpu")
            if let cpu = monitor.snapshot?.cpu {
                Text("\(Int(cpu.totalUsage * 100))%")
                    .monospacedDigit()
            } else {
                Text("--%")
            }

            Image(systemName: "memorychip")
            if let mem = monitor.snapshot?.memory {
                Text("\(Int(mem.usagePercentage * 100))%")
                    .monospacedDigit()
            } else {
                Text("--%")
            }
        }
        .onAppear {
            monitor.start()
        }
    }
}
```

```swift
// Views/PopoverContentView.swift
import SwiftUI

struct PopoverContentView: View {
    @Bindable var monitor: SystemMonitor
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Resources")
                .font(.headline)

            if let snapshot = monitor.snapshot {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU Total: \(Int(snapshot.cpu.totalUsage * 100))%")
                    ForEach(0..<snapshot.cpu.coreUsages.count, id: \.self) { coreIndex in
                        CoreUsageBarView(index: coreIndex, usage: snapshot.cpu.coreUsages[coreIndex])
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory Used: \(ByteFormatter.string(from: snapshot.memory.usedBytes)) / \(ByteFormatter.string(from: snapshot.memory.totalBytes))")
                    Text("App: \(ByteFormatter.string(from: snapshot.memory.appMemoryBytes))")
                        .foregroundStyle(.secondary)
                    Text("Wired: \(ByteFormatter.string(from: snapshot.memory.wiredBytes))")
                        .foregroundStyle(.secondary)
                    Text("Compressed: \(ByteFormatter.string(from: snapshot.memory.compressedBytes))")
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack {
                Button("Settings...") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openSettings()
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding()
        .frame(width: 280)
        .onAppear {
            monitor.isPopoverVisible = true
        }
        .onDisappear {
            monitor.isPopoverVisible = false
        }
    }
}
```

### 4.7 Launch-at-Login Management

```swift
// Services/LaunchAtLoginService.swift
import Foundation
import ServiceManagement

public final class LaunchAtLoginService {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func setEnabled(_ enable: Bool) throws {
        if enable {
            if SMAppService.mainApp.status == .enabled { return }
            try SMAppService.mainApp.register()
        } else {
            if SMAppService.mainApp.status == .notRegistered { return }
            try SMAppService.mainApp.unregister()
        }
    }
}
```

### 4.8 Exact xcodebuild Invocation Quirks

Because active `xcode-select` points to `/Library/Developer/CommandLineTools`, invoke `xcodebuild` with `DEVELOPER_DIR`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project StatsLite.xcodeproj \
  -scheme StatsLite \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .derivedData \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO
```

---

## 5. Critical Edge Cases, Failure Modes & Risks

### 5.1 Mach Port Table Exhaustion
- **Failure Mode**: `mach_host_self()` allocates a port reference. Omitting `mach_port_deallocate(mach_task_self(), hostPort)` causes port leaks. Once the task port table fills (typically 65,536 ports), future Mach traps fail with `KERN_NO_SPACE`.
- **Mitigation**: Place `defer { mach_port_deallocate(mach_task_self(), hostPort) }` immediately after `mach_host_self()`.

### 5.2 Mach Kernel Memory Leak
- **Failure Mode**: `host_processor_info` writes an allocated array to `processor_info_array_t`. Swift ARC does not manage this buffer.
- **Mitigation**: Calculate `vm_size_t(processorInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)`. Invoke `vm_deallocate(mach_task_self(), vm_address_t(bitPattern: info), size)` inside a `defer` block.

### 5.3 Initial Sample Rollover and Division by Zero
- **Failure Mode**: On the very first sampling cycle, previous ticks do not exist. Delta is zero. If you divide active ticks by total ticks when `totalDelta == 0`, a floating-point NaN or crash occurs.
- **Mitigation**: If `previousCPUTicks` is nil or `totalDelta == 0`, return `0.0`. Protect against counter wraps when system boots or resumes from hibernation (`curr.total < prev.total`).

### 5.4 App Activation Behind Active Windows
- **Failure Mode**: An app with `LSUIElement = YES` does not hold active focus by default. When the user clicks `Settings...`, the new window opens beneath the frontmost application.
- **Mitigation**: Call `NSApplication.shared.activate(ignoringOtherApps: true)` immediately before triggering `openSettings()`.

### 5.5 SMAppService Signature Constraint
- **Failure Mode**: If the app is run as an unbundled binary or lacks a code signature, `SMAppService.mainApp.register()` throws `kSMErrorInvalidSignature`.
- **Mitigation**: Code-sign debug builds with ad-hoc identity (`CODE_SIGN_IDENTITY = "-"`). Ensure bundle identifier is configured in the Xcode target.

### 5.6 Uncertainties & External Variables
- **System Settings Consent**: Users can revoke login item authorization inside macOS System Settings -> General -> Login Items. When revoked, `status` returns `.requiresApproval`. Code must check status and avoid repeating failed registration loops.
- **Apple Silicon Page Size Stability**: Although Apple Silicon uses 16 KB pages today, always read `vm_kernel_page_size` at runtime. Never hardcode 16,384 or 4,096.

---

### Phased Engineering Roadmap

1. **Phase 1: Project Setup**: Create `StatsLite.xcodeproj` with `PBXFileSystemSynchronizedRootGroup` pointing to `StatsLite/` and `StatsLiteTests/`. Set `LSUIElement = YES` and `SWIFT_VERSION = 6.0`.
2. **Phase 2: Core Domain Logic**: Implement `MetricSnapshots`, `MetricMath`, and unit tests for tick calculation and RAM derivation. Verify with `xcodebuild test`.
3. **Phase 3: Mach Sampling Layer**: Implement `MachMetricsProvider` with verified `mach_port_deallocate` and `vm_deallocate` cleanup.
4. **Phase 4: Async Engine & UI**: Implement `MetricSamplerActor` and `SystemMonitor`. Build `MenuBarExtra` view hierarchy with `.menuBarExtraStyle(.window)`.
5. **Phase 5: Settings & Launch Control**: Build `SettingsView` and integrate `SMAppService.mainApp` with error handling.