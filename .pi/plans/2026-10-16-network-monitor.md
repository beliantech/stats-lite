# Plan: 2026-10-16-network-monitor

**Risk class: R2** (UI work — menu bar block).

## Intent

Add a NETWORK monitor to the StatsLite menu bar: a two-line block that shows download rate on line 1 (red dot) and upload rate on line 2 (blue dot), for example `720 KB/s` over `10 KB/s`.

Scope for this first cut (user decisions, 2026-10-16):

1. Menu bar block only. No popover card, no history buffer, no sparkline.
2. Rates aggregate the entire laptop: sum byte counters across all interfaces, exclude loopback.
3. The NETWORK toggle is ON by default (`@AppStorage` default `true`).
4. Network rates update on a fixed 1-second cadence. `refreshInterval` does not apply to network.
5. An adjacent plan removes the user interval toggle. That plan owns `refreshInterval` UI; this plan never touches it.

## Context (reconnaissance, verified)

- Pipeline today: `SystemMetricsProvider` (`StatsLite/SystemMetricsProvider.swift:12`) → `LiveSystemMetricsProvider` → `MetricSamplerActor.collectSnapshot(enabled:)` (`StatsLite/MetricSamplerActor.swift:25`, delta base `previousCPUTicks` at `:16`) → `SystemMonitor` loop (`StatsLite/SystemMonitor.swift:21`, sleeps `refreshInterval` at `:102`) → `SystemSnapshot` (`StatsLite/MetricTypes.swift:188`, hand-written `==` at `:201`) → `MenuBarBlockBuilder.blocks` (`StatsLite/MenuBarBlockModel.swift:78`) → `MenuBarStackedItemView` (`StatsLite/MenuBarStackedItemView.swift:59`) → `StatusItemController` (`StatsLite/StatusItemController.swift:44`).
- `MenuBarLayout.length` has two call sites: `StatsLite/StatusItemController.swift:47` and `:136`. Miss one and the item size desyncs.
- No network code exists anywhere: `rg -in "network|getifaddrs|if_data|kb/s|clipboard"` returns zero matches.
- The Xcode project uses filesystem-synchronized groups (`StatsLite.xcodeproj/project.pbxproj:6`, `objectVersion = 77`), so new `.swift` files under `StatsLite/` and `StatsLiteTests/` join the targets with no pbxproj edit.
- Test command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS,arch=arm64' -derivedDataPath .derivedData CODE_SIGN_IDENTITY="-"`
- Build command: same line with `xcodebuild build`.
- Band-aid scan: no `TODO`/`FIXME`/`HACK` in `StatsLite/` or `StatsLiteTests/`. Nothing to refactor away.
- No root `DESIGN.md`; visual tokens live in `StatsLite/DesignTokens.swift` and the menu bar views.

## Approach (decisions)

**D1 — Separate 1 s loop, separate published property (oracle, 2026-10-16).**
`SystemMonitor` runs a second task, `networkSamplingTask`, that sleeps a fixed 1.0 s on `ContinuousClock` and never reads `refreshInterval`. It publishes to a new `@Observable private(set) var latestNetwork: NetworkMetrics?`. `latestSnapshot` is untouched, so popover cards never re-evaluate on the 1 s network tick (FM-8).

**D2 — Delta base lives in the sampler.**
`MetricSamplerActor` owns `previousNetworkSample: (bytes: NetworkBytes, instant: ContinuousClock.Instant)?`, mirroring `previousCPUTicks`. The actor returns `nil` until sample two, keeps the base on a failed read, and clears it on disable.

**D3 — Network state is a `Bool`, not an `EnabledMetrics` bit.**
`EnabledMetrics`, `MonitorGuard`, `SystemSnapshot`, and `SystemSnapshot.==` stay unchanged. `SystemMonitor.showNetwork: Bool` gates the network task. Rationale: the existing last-one-enabled guard (`StatsLite/PreferencesStore.swift:82`, repair at `:123`) already guarantees a non-empty standard set, so `MonitorGuard.allowsSampling` needs no split; and keeping network out of `EnabledMetrics` avoids touching `SystemSnapshot.==`, the snapshot init filter, and the 8-permutation builder tests. This deviates from the oracle's optional `.network` bit; it is the smaller surface with identical behavior.

**D4 — `activeMetricCount` and `isToggleLocked` stay three-metric.**
The NETWORK toggle in Settings is independent and never locked. `PreferencesStore.activeMetricCount` (`:82`), `isToggleLocked` (`:89`), and the repair in `init` (`:123`) are unchanged.

**D5 — Rate math = measured elapsed time, never a hard-coded 1.0.**
`deltaBytes / elapsedSeconds` from `ContinuousClock`, with re-anchor guards: elapsed ≤ 0.001 s, elapsed > 2.5 s, or counter rollback → discard the delta, re-anchor, return `nil`.

**D6 — Live read via `getifaddrs` + `if_data`.**
`LiveSystemMetricsProvider.sampleNetworkBytes()` walks `getifaddrs`, skips `IFF_LOOPBACK`, sums `ifi_ibytes`/`ifi_obytes` over the remaining interfaces. Kernel calls stay in the provider; the loopback/sum rule goes into a pure function in `SystemMetricsParsing` so it is unit testable without kernel access.

**D7 — Settings row label `Network Throughput`.**
Fourth row in the `Visible Metrics` section (`StatsLite/SettingsView.swift:75`), same `Toggle` styling as `GPU Utilization`. It carries no `.disabled(...)`: the lock helper counts only the three standard metrics, so network must never call it.

### Do-not-touch list (owned by the adjacent refreshInterval plan)

1. `PreferencesStore.refreshInterval` / `refreshIntervalStorage` (`StatsLite/PreferencesStore.swift:51`, `:106`)
2. `SettingsView` `Picker("Refresh Interval", ...)` (`StatsLite/SettingsView.swift:42`)
3. `SettingsView.onChange(of: preferences.refreshInterval)` (`StatsLite/SettingsView.swift:36`)
4. `SystemMonitor.refreshInterval` (`StatsLite/SystemMonitor.swift:28`)
5. `SystemMonitor.sparklineCapacity` (`StatsLite/SystemMonitor.swift:38`)
6. `MenuBarStackedItemView.onChange(of: preferences.refreshInterval)` (`StatsLite/MenuBarStackedItemView.swift:42`)

New lines may be added next to these; existing lines are never modified.

## Design Blueprint (designer, 2026-10-16 — copy verbatim)

### Design Context & Visual Evidence Pass

- **Reference Image**: `/var/folders/2r/gfzr0pms3bb5cyshql2g22900000gn/T/herdr-clipboard-images-501/client-64-clipboard-1792108137578147000-0.png` (84 pt × 43 pt at 2x Retina, 168 px × 86 px).
  - Top line: Red circular indicator dot with download speed string `720 KB/s`.
  - Bottom line: Blue circular indicator dot with upload speed string `10 KB/s`.
  - Right alignment invariant: The rightmost edges of `720 KB/s` and `10 KB/s` align on the identical trailing boundary (pixel delta = 0 px).
  - Left alignment invariant: The leftmost edges of the red and blue indicator dots align on the identical leading boundary (pixel delta = 0 px).
- **Live App Visual Evidence Pass**:
  - Captured active speed block in menu bar: Red indicator dot with `1.6 MB/s` on top row; Blue indicator dot with `22 KB/s` on bottom row.
  - Measured dot dimensions: 12 px Retina diameter = 6.0 pt.
  - Measured typography cap-height: 13 px Retina = 6.5 pt, matching a 9.0 pt medium font (`.system(size: 9, weight: .medium).monospacedDigit()`).
  - Total block width: 58.0 pt pinned width. Accommodates all rate strings from `0 KB/s` up to `99.9 MB/s` and `1.2 GB/s` with a minimum of 3.1 pt safety margin.
- **Repository Design System Status**: `DESIGN.md` does not exist at the repository root. All design tokens are grounded in existing production application files: `StatsLite/MenuBarStackedItemView.swift:23-84`, `StatsLite/MenuBarBlockModel.swift:14-124`, `StatsLite/StatusItemController.swift:44-51,126-156`, `StatsLite/DesignTokens.swift:10-20`, `StatsLite/MetricFormatters.swift:10-27`.

### 1. Visual Hierarchy & ASCII Wireframe

```
+-------------------------------------------------------------------+
| macOS Menu Bar (Height: 24 pt)                                    |
|                                                                   |
| [CPU Block] [MEM Block] [GPU Block]   [Network Block]             |
|   (34 pt)     (34 pt)     (34 pt)         (58 pt)                 |
|    gap:4       gap:4       gap:4                                  |
|                                                                   |
|                                      +--------------------------+ |
|                               Row 1: | (R)            720 KB/s  | |
|                                      |                          | |
|                               Row 2: | (B)             10 KB/s  | |
|                                      +--------------------------+ |
|                                       <-------- 58 pt --------->  |
+-------------------------------------------------------------------+

Legend:
- (R): 6.0 pt circular indicator dot in systemRed (Download indicator)
- (B): 6.0 pt circular indicator dot in systemBlue (Upload indicator)
- Leading: Dots pin to the left edge of the block.
- Trailing: Rate strings pin to the right edge with monospaced digits.
- Spacer: Flexible horizontal spacer between dot and rate string.
```

#### Spatial Hierarchy & Token Relationships

- **Block Dimensions**: Pinned width of `58 pt` (`MenuBarLayout.networkBlockWidth`). No frame height: the status button centers the hosting view vertically (`StatsLite/StatusItemController.swift:44-65`).
- **Indicator Dots**: 6.0 pt diameter (`width: 6, height: 6`).
  - Top dot fill: `Color(nsColor: .systemRed)` (`StatsLite/MenuBarStackedItemView.swift:83`).
  - Bottom dot fill: `Color(nsColor: .systemBlue)`.
- **Row Spacing**: `VStack(alignment: .leading, spacing: 1)`. Total row height: 11 pt + 1 pt + 11 pt = 23 pt, fitting within the 24 pt menu bar height without clipping.
- **Inter-element Spacing within Row**: `HStack(alignment: .center, spacing: 3)` with an expanding `Spacer(minLength: 2)` between indicator dot and value text.

### 2. Template / Component Skeleton

```swift
// MARK: - Network Block View (StatsLite/MenuBarStackedItemView.swift)

/// Dedicated two-line network speed monitor block.
/// Line 1: 6 pt red indicator dot (leading) + download rate (trailing).
/// Line 2: 6 pt blue indicator dot (leading) + upload rate (trailing).
/// Width pins to block.width (58 pt) so transfer rate fluctuations never resize the item.
/// Transitions stay discrete: no .animation and no .contentTransition modifiers.
struct MenuBarNetworkBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Line 1: Download rate
            HStack(alignment: .center, spacing: 3) {
                Circle()
                    .fill(Color(nsColor: .systemRed))
                    .frame(width: 6, height: 6)

                Spacer(minLength: 2)

                Text(block.valueText)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }

            // Line 2: Upload rate
            HStack(alignment: .center, spacing: 3) {
                Circle()
                    .fill(Color(nsColor: .systemBlue))
                    .frame(width: 6, height: 6)

                Spacer(minLength: 2)

                Text(block.secondaryValueText ?? "-- KB/s")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(secondaryValueColor)
                    .lineLimit(1)
            }
        }
        .frame(width: block.width)
    }

    private var valueColor: Color {
        switch block.valueTint {
        case .primary, .warning, .critical:
            Color.primary
        case .tertiary:
            Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var secondaryValueColor: Color {
        switch block.secondaryValueTint ?? block.valueTint {
        case .primary, .warning, .critical:
            Color.primary
        case .tertiary:
            Color(nsColor: .tertiaryLabelColor)
        }
    }
}
```

```swift
// Inside MenuBarStackedItemView.body (StatsLite/MenuBarStackedItemView.swift:28-34):
HStack(alignment: .center, spacing: MenuBarLayout.gap) {
    ForEach(blocks, id: \.kind) { block in
        if block.kind == .network {
            MenuBarNetworkBlockView(block: block)
        } else {
            MenuBarBlockView(block: block)
        }
    }
}
.padding(.horizontal, MenuBarLayout.padding)
.accessibilityHidden(true)
```

Model extensions:

```swift
enum MenuBarBlockKind: Hashable {
    case cpu
    case ram
    case gpu
    case network
}

struct MenuBarBlock: Equatable {
    var kind: MenuBarBlockKind
    var label: String
    var dotState: MemoryPressureState?
    var valueText: String
    var valueTint: MenuBarValueTint
    var width: CGFloat
    var secondaryValueText: String? = nil
    var secondaryValueTint: MenuBarValueTint? = nil
}

enum MenuBarLayout {
    static let blockWidth: CGFloat = 34
    static let networkBlockWidth: CGFloat = 58
    static let gap: CGFloat = 4
    static let padding: CGFloat = 2

    static func length(
        showCPU: Bool,
        showRAM: Bool,
        showGPU: Bool,
        showNetwork: Bool = false
    ) -> CGFloat {
        let metricCount =
            (showCPU ? 1 : 0) + (showRAM ? 1 : 0) + (showGPU ? 1 : 0)
        let totalBlocks = metricCount + (showNetwork ? 1 : 0)
        let metricLength = CGFloat(metricCount) * blockWidth
        let networkLength = showNetwork ? networkBlockWidth : 0
        let gapsLength = CGFloat(max(totalBlocks - 1, 0)) * gap
        return 2 * padding + metricLength + networkLength + gapsLength
    }
}
```

Rate formatter token (`StatsLite/MetricFormatters.swift`):

```swift
extension MetricFormatters {

    /// Formats transfer speed in bytes per second:
    /// - Under 1000 KB/s: integer KB/s ("0 KB/s", "10 KB/s", "720 KB/s")
    /// - 1.0 MB/s to 99.9 MB/s: one decimal MB/s ("1.6 MB/s", "24.5 MB/s")
    /// - 100 MB/s to 999 MB/s: integer MB/s ("120 MB/s")
    /// - 1.0 GB/s and above: one decimal GB/s ("1.2 GB/s")
    /// - Missing / non-finite: "-- KB/s"
    static func networkRate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
            return "-- KB/s"
        }
        let kb = bytesPerSecond / 1024.0
        if kb < 1000.0 {
            return "\(Int(kb.rounded())) KB/s"
        }
        let mb = kb / 1024.0
        if mb < 100.0 {
            return String(format: "%.1f MB/s", mb)
        }
        if mb < 1000.0 {
            return "\(Int(mb.rounded())) MB/s"
        }
        let gb = mb / 1024.0
        return String(format: "%.1f GB/s", gb)
    }
}
```

### 3. Complete State & Responsive Matrix

| UI State | Red Dot (Line 1) | Line 1 Text (Download) | Blue Dot (Line 2) | Line 2 Text (Upload) | Block Width |
|---|---|---|---|---|---|
| **Default (Active Traffic)** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color.primary`, `.system(size: 9, weight: .medium).monospacedDigit()`, e.g. `720 KB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color.primary`, `.system(size: 9, weight: .medium).monospacedDigit()`, e.g. `10 KB/s` | `58 pt` pinned |
| **Idle Traffic (Zero / Low)** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color.primary`, `0 KB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color.primary`, `0 KB/s` | `58 pt` pinned |
| **High Throughput (MB/s)** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color.primary`, e.g. `1.6 MB/s` or `94.9 MB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color.primary`, e.g. `23.8 MB/s` | `58 pt` pinned |
| **Gigabit Throughput (GB/s)** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color.primary`, e.g. `1.2 GB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color.primary`, e.g. `1.0 GB/s` | `58 pt` pinned |
| **Unavailable / Nil Data** | `Color(nsColor: .systemRed)`, 6 pt circle | `Color(nsColor: .tertiaryLabelColor)`, `-- KB/s` | `Color(nsColor: .systemBlue)`, 6 pt circle | `Color(nsColor: .tertiaryLabelColor)`, `-- KB/s` | `58 pt` pinned |
| **Hover / Menu Bar Highlight** | Unchanged fill | Adapts automatically to menu bar vibrant foreground (`.primary`) | Unchanged fill | Adapts automatically to menu bar vibrant foreground (`.primary`) | `58 pt` pinned |
| **Click / Popover Open** | Retains active values; AppKit sets `button.isHighlighted = true` | Retains active values | Retains active values | Retains active values | `58 pt` pinned |

#### Responsive Layout Invariants (macOS Menu Bar)

- **Menu Bar Constraints**: macOS status bar items do not wrap across multiple lines.
- **Fixed Width Guarantee**: The item width equals `MenuBarLayout.length(showCPU:showRAM:showGPU:showNetwork:)`.
  - All 4 metrics enabled: `2 * 2 + 3 * 34 + 58 + 3 * 4 = 176 pt`.
  - CPU + Network enabled: `2 * 2 + 34 + 58 + 4 = 100 pt`.
  - Network only enabled: `2 * 2 + 58 = 62 pt`.
  - Network disabled (CPU + RAM + GPU): `114 pt` (matches existing production tests verbatim).
- **Zero Layout Shift**: Transitioning between `0 KB/s`, `720 KB/s`, `1.6 MB/s`, `120 MB/s`, and `-- KB/s` introduces 0.0 pt of status item width fluctuation.

### 4. Accessibility (WCAG 2.2) & Interaction Contracts

- **SC 1.4.3 Contrast**: active rate text uses `.primary`; unavailable text uses `Color(nsColor: .tertiaryLabelColor)` (≥ 4.5:1 against the menu bar material).
- **SC 1.4.11 Non-text Contrast**: red dot > 4.2:1, blue dot > 4.5:1 against the menu bar background.
- **SC 2.5.8 Target Size**: status button bounds ≥ 58 pt × 24 pt.
- **SC 4.1.2 Name, Role, Value**: hosting view stays `.accessibilityHidden(true)` (`StatsLite/MenuBarStackedItemView.swift:35`); the AppKit status button owns the element (`StatsLite/StatusItemController.swift:135-139`) and reads `MenuBarAccessibility.compositeLabel`.

VoiceOver composite label:

```swift
static func compositeLabel(
    showCPU: Bool,
    showRAM: Bool,
    showGPU: Bool,
    showNetwork: Bool = false,
    cpuPercent: Double?,
    pressurePercent: Double?,
    pressure: MemoryPressureState,
    gpuPercent: Double?,
    downloadRate: Double? = nil,
    uploadRate: Double? = nil
) -> String
```

- Network on with data: `Stats Lite: CPU 14 percent, Memory Pressure Normal at 25 percent, GPU 28 percent, Network Download 720 KB/s, Upload 10 KB/s`
- Network data unavailable: `..., Network unavailable`
- Network only: `Stats Lite: Network Download 1.6 MB/s, Upload 22 KB/s`

**Interaction contract**: click toggles the existing popover (`StatsLite/StatusItemController.swift:68-98`, 0.25 s debounce at `:70`). Status item views carry no `.animation` and no `.contentTransition` (`StatsLite/AGENTS.md`).

### 5. Visual Acceptance Checklist

- **VAC-1 (Block Structure & Rows)**: The network block renders exactly two vertically stacked rows inside `MenuBarStackedItemView`. Line 1 displays the download rate with a leading red indicator dot. Line 2 displays the upload rate with a leading blue indicator dot.
- **VAC-2 (Pinned Block Width)**: The network block pins its horizontal width to exactly `58 pt` (`MenuBarLayout.networkBlockWidth`). No width alteration occurs across value changes (`0 KB/s`, `720 KB/s`, `1.6 MB/s`, `99.9 MB/s`, `120 MB/s`, `1.2 GB/s`, `-- KB/s`).
- **VAC-3 (Indicator Dot Geometry)**: Both red and blue indicator dots render as circular shapes with width = 6.0 pt and height = 6.0 pt (`Circle().frame(width: 6, height: 6)`). Each dot aligns on the leading boundary of the block.
- **VAC-4 (Indicator Dot Color Mapping)**: The top indicator dot fill matches `Color(nsColor: .systemRed)`. The bottom indicator dot fill matches `Color(nsColor: .systemBlue)`.
- **VAC-5 (Typography & Monospaced Digits)**: Both Line 1 and Line 2 render with font `.system(size: 9, weight: .medium).monospacedDigit()`. Digits do not shift horizontally when numbers fluctuate between narrow glyphs (such as `1`) and wide glyphs (such as `8`).
- **VAC-6 (Trailing Text Alignment)**: The rate strings on Line 1 and Line 2 share an identical trailing edge alignment. The rightmost glyph of Line 1 aligns vertically with the rightmost glyph of Line 2.
- **VAC-7 (Rate Formatting Thresholds)**: `MetricFormatters.networkRate` outputs: `< 1000 KB/s` integer + `" KB/s"` (`0 KB/s`, `10 KB/s`, `720 KB/s`); `1.0` to `< 100.0 MB/s` one decimal + `" MB/s"` (`1.6 MB/s`, `94.9 MB/s`); `100` to `< 1000 MB/s` integer + `" MB/s"` (`119 MB/s`); `>= 1.0 GB/s` one decimal + `" GB/s"` (`1.2 GB/s`); `nil` or negative → `"-- KB/s"`.
- **VAC-8 (Text Foreground Tint)**: Active rates render using `.primary`. Unavailable or missing rates render using `Color(nsColor: .tertiaryLabelColor)`.
- **VAC-9 (No Animation or Content Transition)**: The view hierarchy for `MenuBarNetworkBlockView` contains zero `.animation(...)` and zero `.contentTransition(...)` modifiers.
- **VAC-10 (VoiceOver Label Integration)**: When Network is active, the composite accessibility label includes `Network Download <downRate>, Upload <upRate>`. When rate values are missing, it includes `Network unavailable`.
- **VAC-11 (Total Menu Bar Item Length Math)**: `MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: true, showNetwork: true)` = exactly `176 pt`. With Network off it stays `114 pt`.

## ISC (binary yes/no)

Evidence rule: this is a macOS menu bar app, so the 375px / 768px / 1440px viewport rule does not apply. Every VAC item needs a 1x and a 2x Retina menu bar capture (or, where the item cannot be photographed, the unit test that proves it — say which in the report). Any "no" is blocking.

### Functional

- [ ] **F1**: With `showNetwork = true` (the default) the menu bar shows the NETWORK block after the GPU block, two lines, red dot + download rate above, blue dot + upload rate below.
- [ ] **F2**: Fresh install and existing install both land with NETWORK ON (default `true` in `@AppStorage("showNetwork")`).
- [ ] **F3**: Network rates publish every 1.0 s (± 150 ms tolerance) while `refreshInterval` is 1, 2, or 5. Changing `refreshInterval` never changes the network cadence; network keeps ticking during an interval change.
- [ ] **F4**: Rates sum all non-loopback interfaces. A download on Wi-Fi and an upload on a VPN adapter both count; `lo0` traffic never counts.
- [ ] **F5**: Sample 1 publishes no rate (`latestNetwork == nil`, block shows `-- KB/s`). Sample 2 and later publish rates.
- [ ] **F6**: Toggling NETWORK off in Settings stops the 1 s task, sets `latestNetwork = nil`, and clears the delta base. Toggling it back on restarts the task from a fresh anchor (no 10-minute-gap rate spike).
- [ ] **F7**: No popover card and no history/sparkline entry for network exists (`PopoverContentView.swift` and `SystemMonitor.recordHistory` unchanged).
- [ ] **F8**: The adjacent interval plan's symbols (do-not-touch list) show zero diff in this branch.
- [ ] **F9**: The VoiceOver composite label refreshes on each 1 s network tick. With `refreshInterval = 5`, the label's network rates track the visible block within one second instead of lagging to the next standard snapshot.
- [ ] **F10**: The `Network Throughput` toggle in Settings is never disabled: with exactly one standard metric active (`activeMetricCount == 1`) and network ON, the toggle stays clickable. Evidence: `SettingsView` carries no `.disabled(...)` on the network row (diff), plus the T3 live click check. Note: `isToggleLocked(true)` cannot be asserted false at `activeMetricCount == 1` — the helper is toggle-agnostic and `SettingsWindowTests.testSoleEnabledToggleIsLocked` pins it to `true`; the unit-level guarantee is the F10 companion test `showNetworkDoesNotAffectStandardToggleLock` (network never enters `activeMetricCount` / `enabledMetrics`).

### Failure modes (oracle, 2026-10-16)

- [ ] **FM1**: Counter rollback (interface reset / USB-Ethernet reconnect) does not trap and does not emit a bogus rate; the base re-anchors. Test: `current < previous` input.
- [ ] **FM2**: First sample never divides a cumulative uptime counter by 1 s. Test: provider returns large first counters → `nil`.
- [ ] **FM3**: A > 2.5 s gap (system sleep/wake) re-anchors and returns `nil`, never a diluted rate.
- [ ] **FM4**: Two samples 0.0005 s apart return `nil` instead of `infinity`/`NaN`.
- [ ] **FM5**: A failed kernel read (`sampleNetworkBytes()` → `nil`) keeps the base; the next successful read still has its predecessor (only one pass lost, not two).
- [ ] **FM6**: Disable → clear base → re-enable produces no rate until sample 2 of the new session.
- [ ] **FM7**: Ten rapid NETWORK toggles leave exactly one `networkSamplingTask` running (no task accumulation).
- [ ] **FM8**: Popover cards (`CPUCardView`, `MemoryPressureCardView`, `GPUCardView`) never read `latestNetwork`; a 1 s network tick while the popover is open causes no card re-evaluation.
- [ ] **FM9**: The status item width never changes while rates fluctuate: `MenuBarLayout.length` output is constant for a fixed toggle set.
- [ ] **FM10**: No `getifaddrs`/`sysctl` call runs on the main actor; all provider work happens inside `MetricSamplerActor`.
- [ ] **FM11**: A NETWORK-only preference change does not restart the standard sampling loop (CPU/GPU delta bases survive).
- [ ] **FM12**: Toggling NETWORK changes the status item length through `onPreferencesChange` → `updateItemLength()`: no 62 pt blank gap remains when network turns off, and the block is not clipped when it turns on.

### VAC

- [ ] **VAC-1** … [ ] **VAC-11**: every item from the Design Blueprint checklist answers yes, with the evidence named above. VAC-9 additionally passes `StatsLiteTests/MenuBarRedrawChurnTests.swift`.

## Task list

| Task | Goal | Agent | Depends on |
|---|---|---|---|
| T1 | Red + green: domain types, provider contract + fake, sampler delta logic, formatter, block model/layout/builder/accessibility (unit tested) | coder | - |
| T2 | Green: live `getifaddrs` read, 1 s loop in `SystemMonitor`, network block view, controller + settings wiring, build passes | coder | T1 |
| T3 | Verify: full suite, build, live 1x/2x menu bar captures vs VAC + ISC (F1–F10, FM1–FM12) | tester | T2 |

One worktree hosts T1 → T2 → T3, then squash-merge to `main`.

- Branch: `feat/2026-10-16-network-monitor`
- Worktree: `/Users/jonathan/beliantech/stats-lite/worktrees/2026-10-16-network-monitor`

### T1 — Model, sampler, formatter, block model (TDD)

Status: red `089720c` (test-only, 9 files under `StatsLiteTests/`, +775/−3, verified in git) · green `045cf89` (9 app files, no test edits) · gap revision red `37d3a9f` / green `d66951a` · suite 192 tests / 0 failures, build clean · review PASS (branch review, `[code-review]` on `diff main...HEAD`)

Ratification (2026-10-16, planner): the discontinuity cap in `MetricSamplerActor.sampleNetwork` is **2.5 s** per D5 and FM3. The green phase had shipped a 5 s cap to satisfy a contradicting red test (`testNetworkRateDividesByMeasuredElapsedTime` used a 4 s gap and expected a rate); that test is amended instead, and a 3.0 s → `nil` boundary test is added. `NetworkInterfaceRow` is declared top-level in `StatsLite/SystemMetricsParsing.swift` (the pure rule stays inside the enum) — no plan conflict.

**Red cycle first.** New or updated tests: `StatsLiteTests/MetricSamplerActorTests.swift`, `StatsLiteTests/SystemMetricsProviderContractTests.swift`, `StatsLiteTests/FakeSystemMetricsProvider.swift`, `StatsLiteTests/SystemMetricsParsingTests.swift`, `StatsLiteTests/MetricFormatterTests.swift`, `StatsLiteTests/MenuBarBlockBuilderTests.swift`, `StatsLiteTests/MenuBarLayoutTests.swift`, `StatsLiteTests/MenuBarAccessibilityTests.swift`, `StatsLiteTests/PreferencesStoreGuardTests.swift`. Run the test command; compile errors against the new API count as red. Touch no application code in the red spawn.

Expected API (green):

```swift
// StatsLite/MetricTypes.swift
struct NetworkBytes: Sendable, Equatable { var bytesIn: UInt64; var bytesOut: UInt64 }
struct NetworkMetrics: Sendable, Equatable { var downloadBytesPerSecond: Double; var uploadBytesPerSecond: Double }

// StatsLite/SystemMetricsProvider.swift
func sampleNetworkBytes() -> NetworkBytes?

// StatsLite/MetricSamplerActor.swift
func sampleNetwork(enabled: Bool) -> NetworkMetrics?   // nil while disabled
func clearNetworkBase()

// StatsLite/MetricFormatters.swift
static func networkRate(_ bytesPerSecond: Double?) -> String

// StatsLite/MenuBarBlockModel.swift
static let networkBlockWidth: CGFloat = 58
static func length(showCPU: Bool, showRAM: Bool, showGPU: Bool, showNetwork: Bool = false) -> CGFloat
static func blocks(showCPU: Bool, showRAM: Bool, showGPU: Bool, showNetwork: Bool,
                   cpuPercent: Double?, pressurePercent: Double?, pressureState: MemoryPressureState?,
                   gpuPercent: Double?, downloadRate: Double?, uploadRate: Double?) -> [MenuBarBlock]
```

Test expectations covering F3-equivalent logic, FM1–FM6, VAC-7, VAC-10, VAC-11:

- Sampler: `enabled == false` → `nil` and no base stored; first enabled sample → `nil` + base stored; second sample → `delta / elapsed`; rollback → `nil` + re-anchor; elapsed `0.0005` → `nil`; elapsed `7200` → `nil`; `sampleNetworkBytes() == nil` → `nil` result with base preserved; `clearNetworkBase()` then sample → `nil` again.
- Because `sampleNetwork` takes a clock argument (inject the elapsed duration or the two instants from the test), the time guards are testable without sleeping. Live path passes `ContinuousClock.now`.
- Parsing: loopback rows excluded, multi-interface sum correct, negative/absent `if_data` → `nil`.
- Formatter: VAC-7 thresholds table, `nil` → `-- KB/s`, `Double.infinity` → `-- KB/s`.
- Block builder: network block `kind == .network`, `label == ""` (no label text — the reference block has none), `valueText == networkRate(download)`, `secondaryValueText == networkRate(upload)`, `width == 58`, order CPU → MEM → GPU → NET.
- Layout: `length(... showNetwork: false)` keeps 114 / 76 / 38 / 4; all four on → `176`; network only → `62`; CPU + network → `100`.
- Accessibility: strings per the blueprint (with data / `Network unavailable` / network only).
- `PreferencesStoreGuardTests`: `showNetwork` defaults true, persists, and does not change `activeMetricCount` (still 3 max) nor lock behavior.

Files touched: `StatsLite/MetricTypes.swift`, `StatsLite/SystemMetricsProvider.swift`, `StatsLite/MetricSamplerActor.swift`, `StatsLite/MetricFormatters.swift`, `StatsLite/MenuBarBlockModel.swift`, `StatsLite/MenuBarAccessibility.swift`, `StatsLite/PreferencesStore.swift`, plus the test files above.

### T2 — Live read, 1 s loop, view, wiring

Status: green `33be055` (6 files, +419/−28; new `SystemMonitorNetworkTests` covers FM7/FM11/F6) · suite 195 tests, build clean · review PASS

Note (planner verification, 2026-10-16): `StatusItemControllerPopoverTests.testTogglePopoverCyclesMountAndRelease` failed on one worktree run (5 failures, all that test) and passed on the immediate re-run (195/0), on the single-class run in the worktree, and on `main` full-suite + single-class runs. The failure is `[StatusBar] Unhandled disconnected scene` timing with a stray Release build of StatsLite running from `/tmp/statslite-dd` (pid 9796), and the T2 diff contains no popover code. Treated as a pre-existing flaky environmental test; T3 re-runs it and reports flakiness rather than a branch regression.

Green = T1 tests stay green + build clean + F1/F2/F6/F7 behavior present.

1. `StatsLite/LiveSystemMetricsProvider.swift`: implement `sampleNetworkBytes()` with `getifaddrs`, skip `IFF_LOOPBACK`, sum `ifi_ibytes` / `ifi_obytes`; keep the pure rule in `StatsLite/SystemMetricsParsing.swift`.
2. `StatsLite/SystemMonitor.swift`:
   - `private(set) var latestNetwork: NetworkMetrics?`, `private var networkSamplingTask: Task<Void, Never>?`, `private var showNetwork = false`.
   - `apply(_:)` splits the change test: standard properties (`enabledMetrics`, `refreshInterval`, `historyDuration`) restart `samplingTask` as today; `preferences.showNetwork` changes start/stop only `networkSamplingTask`. Never restart the standard loop for a network-only change (FM11).
   - `networkSamplingTask`: loop with `ContinuousClock.sleep(for: .seconds(1), tolerance: .milliseconds(150))`, calls `sampler.sampleNetwork(enabled: true)`, assigns `latestNetwork`, exits on cancellation. Cancel + nil before starting a new one (FM7). On stop: `latestNetwork = nil` and `await sampler.clearNetworkBase()`.
   - `stop()` cancels both tasks.
   - Do not touch `refreshInterval`, `sparklineCapacity`, or `recordHistory`.
3. `StatsLite/MenuBarStackedItemView.swift`: render `MenuBarNetworkBlockView` per the blueprint skeleton; `blocks` reads `preferences.showNetwork` and `monitor.latestNetwork`. Add two observers, both required:
   - `.onChange(of: preferences.showNetwork) { monitor.apply(preferences); onPreferencesChange?() }` — `showNetwork` is outside `enabledMetrics` (D3), so this is the only path that resizes the status item (`updateItemLength`) on a network toggle (FM12).
   - `.onChange(of: monitor.latestNetwork) { onSnapshotChange?() }` — `latestNetwork` ticks at 1 s while `latestSnapshot` ticks at `refreshInterval`, so this is the only path that refreshes the VoiceOver label on network data (F9).
   No `.animation` / `.contentTransition` (VAC-9). Leave the `refreshInterval` onChange line untouched.
4. `StatsLite/StatusItemController.swift`: pass `showNetwork:` at both `MenuBarLayout.length` call sites (`:47`, `:136`) and pass `showNetwork` + `downloadRate`/`uploadRate` from `monitor.latestNetwork` into `compositeLabel`.
5. `StatsLite/PreferencesStore.swift`: `showNetwork: Bool = true` with `@AppStorage("showNetwork")` and seeding in `init`. No change to `activeMetricCount`, `isToggleLocked`, or the repair block.
6. `StatsLite/SettingsView.swift`: `Toggle("Network Throughput", isOn: $preferences.showNetwork)` after `GPU Utilization`, with NO `.disabled(...)` modifier. `isToggleLocked` (`StatsLite/PreferencesStore.swift:89`) returns `activeMetricCount == 1 && isOn`, which counts only CPU/RAM/GPU — calling it here would lock the network toggle in the ON position whenever a single standard metric is active (F10). Add `.onChange(of: preferences.showNetwork) { monitor.apply(preferences) }`. Do not touch the `refreshInterval` picker or its onChange.
7. Build with the build command → zero errors, no new warnings.

### T3 — Verification (tester)

Status: PASS (`33be055`, run 1: 195 tests / 0 failures including the flaky popover test; build 0 errors / 0 warnings; live 1x+2x captures in `/tmp/t3/`).
Per-criterion: F1–F9 PASS (F9 via the plan's stated fallback), F10 / FM8 / FM12 interactive halves NOT-TESTABLE (locked session, Accessibility/input-injection TCC denied) with complete static + unit evidence; all remaining FM1–FM7, FM9–FM11 and VAC-1–VAC-11 PASS. Zero defects.
Open follow-up: re-run the three interactive checks (F10 click at `activeMetricCount == 1`, FM8 popover-open observation, FM12 toggle resize) once the session is unlocked with the Accessibility grant.

Worktree: `/Users/jonathan/beliantech/stats-lite/worktrees/2026-10-16-network-monitor`.

1. Full test command → all suites green, including `MenuBarRedrawChurnTests` and every pre-existing suite.
2. Build command → zero errors, no warnings introduced by this branch.
3. Launch the built app; capture the menu bar at 1x and 2x (`screencapture -x -R<region>`), dark and light menu bar appearance, and during real traffic (large download) and at idle.
4. Report per-item pass/fail for F1–F10, FM1–FM12, VAC-1–VAC-11 with screenshot or test-name evidence. Any "no" is a BLOCKING failure; the report states the concrete deviation.
   - FM12 evidence: toggle network off in Settings, confirm the menu bar item shrinks and the next icon moves left with no blank gap; toggle it on and confirm the block is fully visible (nothing clipped).
   - F9 evidence: set `refreshInterval` to 5 s, then read the VoiceOver label (or assert `compositeLabel` inputs change) while the visible block updates each second.
   - F10 evidence: set CPU on, RAM off, GPU off, then click the `Network Throughput` toggle in Settings — it must respond.
5. Cadence check: with `refreshInterval` at 5 s, confirm the network block still updates about once per second (frame captures or log timestamps).

## Verification (overall)

- Test suite green, build clean, every ISC item yes with evidence.
- Diff review: no changes to `refreshInterval` symbols, `SystemSnapshot`, `EnabledMetrics`, `MonitorGuard`, `PopoverContentView`, `recordHistory`, or `HistoryBuffer`.

## Git safety protocol

- All code changes happen in the worktree `/Users/jonathan/beliantech/stats-lite/worktrees/2026-10-16-network-monitor` on branch `feat/2026-10-16-network-monitor`, created before the T1 spawn: `git worktree add -B feat/2026-10-16-network-monitor <dir> main`.
- Coder commits per task: `test(network): red tests for network sampler and block`, `feat(network): 1 s network sampling and menu bar network block`.
- Merge into `main` only after T3 passes and the reviewer GO: `git merge --ff-only feat/2026-10-16-network-monitor` (or `--squash`). Never `--no-ff`.
- Cleanup: `git worktree remove --force <dir>`, `git worktree prune`, `git branch -d feat/2026-10-16-network-monitor`.
- Never touch `main` directly; stage files from inside the worktree only.

## Deviations from prior plans / oracle

- The oracle offered an `EnabledMetrics.network` bit plus a split `MonitorGuard`; D3 keeps network as a `Bool` on `SystemMonitor` instead (smaller surface, same behavior). Everything else in the oracle verdict (separate loop, separate `latestNetwork` property, base in the sampler, measured-elapsed rate math, re-anchor guards) is adopted as specified.
- Root `DESIGN.md` does not exist; the blueprint grounds tokens in `StatsLite/DesignTokens.swift` and the menu bar views.
- The 375/768/1440px viewport rule is replaced by the 1x/2x menu bar capture rule stated in the ISC.

## Open questions

None. Scope, defaults, cadence, and aggregation were fixed by direct user decisions on 2026-10-16; the designer blueprint fixed the visual details; the oracle fixed the sampling architecture.
