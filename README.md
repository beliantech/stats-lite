# StatsLite

StatsLite is a menu-bar system monitor for macOS. It shows live CPU, memory pressure, GPU, and network metrics in the status bar. Click the status item to open a popover with detail cards and sparklines.

The app runs as a menu-bar agent. It has no Dock icon and no main window.

## Features

- **Menu bar blocks**: one stacked block per metric. Each block shows a category label and a value. Block widths stay fixed, so the status item never resizes.
  - CPU: total usage, with an optional per-core breakdown.
  - Memory: pressure percentage with a 4 pt pressure dot.
  - GPU: utilization percentage.
  - Network: upload rate in red, download rate in blue.
- **Popover**: per-metric cards, sparklines, a per-core CPU list, and buttons for Settings and Quit.
- **Settings window**:
  - Refresh interval: 1, 2, 3, or 5 seconds.
  - Visible metrics: toggle each metric on or off.
  - History duration: 30 seconds to 5 minutes.
  - Per-core CPU breakdown.
  - Launch at login.
- **Real system data**: the app reads metrics from Mach APIs, IOKit, `sysctl`, and `getifaddrs`.

## Requirements

- macOS 14.0 or later.
- Apple Silicon (arm64).
- Full Xcode. Xcode Command Line Tools alone do not work.

StatsLite has zero third-party dependencies. You do not install anything before you build.

## Build

Open `StatsLite.xcodeproj` in Xcode and run the `StatsLite` scheme.

To build from the command line:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -project StatsLite.xcodeproj \
  -scheme StatsLite \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .derivedData \
  CODE_SIGN_IDENTITY="-"
```

If `xcodebuild` reports that the active developer directory is a Command Line Tools instance, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` as shown above.

The build produces `StatsLite.app`. Launch it. The icon appears in the menu bar.

## Test

Run the test suite with this command:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project StatsLite.xcodeproj \
  -scheme StatsLite \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .derivedData \
  CODE_SIGN_IDENTITY="-"
```

The suite lives in `StatsLiteTests/` and contains unit, layout, churn, and contract tests.

## Project structure

```
StatsLite.xcodeproj/   Xcode project and shared scheme
StatsLite/             App target (Swift sources)
StatsLiteTests/        XCTest suite
scripts/               Measurement and screenshot scripts
docs/plans/            Completed development plans
AGENTS.md              Contributor rules
```

Key sources:

| File | Role |
| --- | --- |
| `StatsLite/StatsLiteApp.swift` | Entry point and app delegate |
| `StatsLite/StatusItemController.swift` | Status item and popover lifecycle |
| `StatsLite/SystemMonitor.swift` | Main-actor sampling state |
| `StatsLite/LiveSystemMetricsProvider.swift` | Real metric reads (Mach, IOKit, sysctl, `getifaddrs`) |
| `StatsLite/MenuBarStackedItemView.swift` | Menu bar rendering |
| `StatsLite/PopoverContentView.swift` | Popover UI |
| `StatsLite/SettingsView.swift` | Settings window |
| `StatsLite/PreferencesStore.swift` | UserDefaults-backed preferences |

## Scripts

- `scripts/measure_popover_footprint.sh --output <file>` — launch the release build, open the popover, and sample memory with `footprint`.
- `scripts/capture_baseline.sh` — capture dark-mode and light-mode popover screenshots.

Both scripts set `DEVELOPER_DIR` when needed.

## Configuration

Preferences save in UserDefaults. There are no config files and no environment variables. Change preferences in the Settings window.

## Contribute

Read `AGENTS.md` before you edit. One rule to remember: status item views must not use `.animation` or `.contentTransition`. Transitions stay discrete.
