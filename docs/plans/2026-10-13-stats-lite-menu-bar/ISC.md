# ISC — Stats Lite: macOS Menu Bar CPU/RAM Monitor

## Context

Greenfield repo (`/Users/jonathan/beliantech/stats-lite` is empty). Build a native macOS menu bar app in SwiftUI that monitors CPU and RAM, shows a detail popover, and includes a mini settings window. Machine: macOS 27.0.1, Apple Silicon, Xcode 27.0.

## Architecture (locked from consult — follow exactly)

- **Packaging**: hand-written minimal `StatsLite.xcodeproj/project.pbxproj` using `PBXFileSystemSynchronizedRootGroup` (synchronized folders `StatsLite/` and `StatsLiteTests/`). No xcodegen, no SwiftPM app. `LSUIElement = YES` in Info.plist (Dock icon must never appear). `SWIFT_VERSION = 6.0`, macOS 14.0 deployment target, ad-hoc code sign (`CODE_SIGN_IDENTITY = "-"`).
- **Build/test invocation**: `xcode-select` points to CommandLineTools, so every `xcodebuild` call MUST set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Test command: `DEVELOPER_DIR=... xcodebuild test -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS,arch=arm64' -derivedDataPath .derivedData CODE_SIGN_IDENTITY="-"`. Add `.derivedData/` to `.gitignore`.
- **CPU sampling**: `host_processor_info` / `PROCESSOR_CPU_LOAD_INFO` (per-core + total ticks). Every sample: `defer { mach_port_deallocate(mach_task_self(), hostPort) }` after `mach_host_self()`, and `defer { vm_deallocate(...) }` on the returned `processor_info_array_t` (size = `processorInfoCount * MemoryLayout<integer_t>.stride`). Leak = blocking defect.
- **RAM sampling**: `host_statistics64` / `HOST_VM_INFO64`. Activity Monitor formula: App = `(internal_page_count - purgeable_count) * vm_kernel_page_size`, Wired = `wire_count * pageSize`, Compressed = `compressor_page_count * pageSize`, Used = App + Wired + Compressed, Total = `ProcessInfo.processInfo.physicalMemory`. Read `vm_kernel_page_size` at runtime; never hardcode 4096 or 16384.
- **CPU % math**: pure function `MetricMath.computePercentages(previous:current:)` over tick samples; guard first sample (no previous), zero deltas, and counter rollover (`curr.total < prev.total`) by returning 0. Clamp to 0...1.
- **Concurrency**: sampling in a `MetricSamplerActor`; UI state in `@Observable @MainActor SystemMonitor`. Loop with `ContinuousClock` sleep + tolerance (~150 ms). Default refresh interval 2.0 s (settings offer 1/2/5 s).
- **UI**: `MenuBarExtra` with `.menuBarExtraStyle(.window)`; separate `Settings` scene. Settings opened from popover must call `NSApplication.shared.activate(ignoringOtherApps: true)` before `openSettings()` (LSUIElement apps otherwise open the window behind active apps).
- **Settings persistence**: `@AppStorage`/UserDefaults via a small `PreferencesStore`. Launch-at-login via `SMAppService.mainApp` with status checks (`.requiresApproval` must not loop retries) and error handling.
- **Swift 6 strict concurrency**: `Sendable` value-type snapshots (`CoreTickSample`, `CPUMetrics`, `MemoryMetrics`, `SystemSnapshot`); no shared mutable state outside the actor.

## Design Authority

The Design Blueprint (5-part, from `designer`) is in `docs/plans/2026-10-13-stats-lite-menu-bar/notes.md`. It is the visual source of truth: wireframes, exact sizes (popover 280 pt, settings 380×340 pt, sparkline 38 pt, cards 8 pt radius/0.5 pt border), colors, state matrix, and the VAC list. UI tasks must read it first and follow it verbatim. The oracle's sample view code in the blueprint is indicative only — the blueprint's visual specs win; the oracle's Mach/concurrency code wins for anything non-visual.

## Tasks

- `tasks/01-project-scaffold.md` — Xcode project, targets, Info.plist, gitignore, empty buildable app + test target
- `tasks/02-domain-metrics-math.md` — value types, MetricMath, formatters, unit tests
- `tasks/03-mach-metrics-provider.md` — Mach sampling provider + tests via fake provider
- `tasks/04-sampler-engine.md` — MetricSamplerActor, SystemMonitor, PreferencesStore, LaunchAtLoginService
- `tasks/05-menu-bar-popover-ui.md` — app entry, menu bar label, popover (CPU/RAM cards, sparklines, segmented bar, core grid)
- `tasks/06-settings-window.md` — Settings scene, launch-at-login wiring, version label

## Acceptance Criteria

1. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build` succeeds with zero errors and no warnings introduced by our code.
2. `xcodebuild test` (same env, macOS destination) passes: CPU % math (first-sample, rollover, zero-delta), RAM derivation from fake VM stats, formatter output for GB/percent modes.
3. App runs as a menu bar agent: no Dock icon, no main menu; menu bar item shows live CPU and RAM values with monospaced digits.
4. Popover opens from menu bar item with CPU card (total + user/system + sparkline + optional per-core grid) and RAM card (used/total, segmented App/Wired/Compressed/Free bar, sparkline); header has Settings and Quit; Escape/outside-click closes it.
5. Settings window opens from the popover gear, is 380×340 pt, grouped form, and every control (refresh interval, display format, RAM unit, labels toggle, per-core toggle, history duration, launch-at-login) changes app behavior live.
6. Launch-at-login toggle reflects `SMAppService.mainApp.status` and handles `.requiresApproval` without retry loops.
7. No Mach port or VM deallocation leaks: all `defer` cleanups present per Architecture section; verified by code review.
8. Every VAC item below marked "Met" in the coder's report and verified visually (screenshot) where possible.
9. Two or fewer intermediate commits per task; conventional commit messages.

## Visual Acceptance Checklist (from Design Blueprint)

| ID | Invariant | Met |
| --- | --- | --- |
| VAC-1 | Menu bar text uses monospaced digits; value changes cause zero width jitter | |
| VAC-2 | Menu bar item renders on one line, no wrapping, in all display modes (both/CPU-only/RAM-only) | |
| VAC-3 | In "Both" mode the middle-dot separator renders centered between CPU and RAM values | |
| VAC-4 | Popover outer container width measures exactly 280 pt | |
| VAC-5 | Popover background uses native macOS visual material translucency | |
| VAC-6 | CPU and RAM metric cards use 8 pt continuous corner radius and 0.5 pt subtle border | |
| VAC-7 | CPU and RAM sparklines are 38 pt high with no axis lines or tick labels | |
| VAC-8 | Segmented RAM bar shows App (blue), Wired (purple), Compressed (orange), Free (quaternary) segments in a 4 pt rounded container | |
| VAC-9 | Header Settings and Quit buttons have ≥24×24 pt hit targets with hover pill | |
| VAC-10 | Collapsed core breakdown: popover height ≈320 pt | |
| VAC-11 | Expanded core grid renders per-core bars without overflowing the 280 pt width | |
| VAC-12 | Settings window opens at 380×340 pt with native grouped form styling | |
| VAC-13 | All labels and charts stay legible in both Light and Dark appearance | |

## Deferred / Out of Scope

- Network/disk monitoring, fan/temperature sensors.
- Historical persistence across launches.
- Sparkline history retention beyond the in-memory window (30/60 s ring buffer).
- Notarization/distribution signing (ad-hoc only).
