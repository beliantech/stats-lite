# ISC — Stats Lite: 3-Metric macOS Menu Bar Monitor (CPU / Memory Pressure / GPU)

## Context

Greenfield repo (`/Users/jonathan/beliantech/stats-lite` has no app code). A base plan exists at `.pi/plans/2026-10-13-stats-lite-menu-bar/` (ISC.md, notes.md, tasks/) but no code was written. This plan supersedes it and is self-contained: it adds GPU percent, reframes RAM as memory pressure, adds three metric visibility toggles, and adds a hard footprint constraint. Consult cited base files for detail as noted. Machine: macOS 27.0.1, Apple Silicon, Xcode 27.0.

## Requirements (delta over base plan)

1. Menu bar shows three metrics: CPU %, RAM memory pressure, GPU %.
2. Settings has three independent on/off toggles — CPU, RAM, GPU. Each toggle hides its menu bar slot and popover card. At least one metric stays enabled at all times.
3. **RSS < 50 MB with the Settings window closed** (hard acceptance criterion; see AC-10).

## Architecture (locked from designer + oracle consults — follow exactly)

### Packaging & build (unchanged from base ISC)

- Hand-written minimal `StatsLite.xcodeproj/project.pbxproj` with `PBXFileSystemSynchronizedRootGroup` (folders `StatsLite/`, `StatsLiteTests/`). No xcodegen, no SwiftPM app. `LSUIElement = YES` (no Dock icon). `SWIFT_VERSION = 6.0`, macOS 14.0 deployment target, ad-hoc sign (`CODE_SIGN_IDENTITY = "-"`).
- `xcode-select` points to CommandLineTools: every `xcodebuild` call MUST set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Test command: `DEVELOPER_DIR=... xcodebuild test -project StatsLite.xcodeproj -scheme StatsLite -destination 'platform=macOS,arch=arm64' -derivedDataPath .derivedData CODE_SIGN_IDENTITY="-"`. Add `.derivedData/` to `.gitignore`.

### CPU sampling (unchanged)

- `host_processor_info` / `PROCESSOR_CPU_LOAD_INFO`. Every sample: `defer { mach_port_deallocate(mach_task_self(), hostPort) }` after `mach_host_self()`, and `defer { vm_deallocate(...) }` on the returned `processor_info_array_t` (size = `processorInfoCount * MemoryLayout<integer_t>.stride`). Leak = blocking defect.

### RAM sampling (unchanged)

- `host_statistics64` / `HOST_VM_INFO64`. Activity Monitor formula: App = `(internal_page_count - purgeable_count) * vm_kernel_page_size`, Wired = `wire_count * pageSize`, Compressed = `compressor_page_count * pageSize`, Used = App + Wired + Compressed, Total = `ProcessInfo.processInfo.physicalMemory`. Read `vm_kernel_page_size` at runtime; never hardcode page size.

### GPU sampling (new — oracle decision)

- **Source**: IOKit `IOServiceMatching("IOAccelerator")` → `IOServiceGetMatchingServices(kIOMainPortDefault, ...)` → per service `IORegistryEntryCreateCFProperty(service, "PerformanceStatistics", ...)` → key `"Device Utilization %"` (`Int`, 0–100). Average across all matching devices (Apple Silicon may expose multiple); clamp result to 0...1. No root, no entitlements, public `IOKitLib.h` API only. Rejected: `powermetrics` (root), `IOReport.framework` (private), Metal counters (in-process only).
- **Memory safety (all mandatory)**: `defer { IOObjectRelease(iterator) }` right after acquisition; `defer { IOObjectRelease(service) }` inside the per-service loop; `takeRetainedValue()` on the CF property (never `takeUnretainedValue`); **never** `CFRelease` the matching dictionary (`IOServiceGetMatchingServices` consumes it); use `IORegistryEntryCreateCFProperty` for the single key — never `IORegistryEntryCreateCFProperties` (registry-tree copy blows RSS).
- **Unavailable state**: return `nil` when no service matches (VMs) or the key is missing. `nil` drives the designer's unavailable UI (`--%` in menu bar, dashed container in popover). Also read `Renderer Utilization %` / `Tiler Utilization %` into `GPUMetrics` for future use (optional fields).

### Memory pressure sampling (new — oracle decision)

- **Level**: `sysctlbyname("kern.memorystatus_vm_pressure_level")` → `1` Normal, `2` Warning, `4` Critical (matches Activity Monitor green/yellow/red). Map unknown values to `.unknown`.
- **Percentage**: `pressurePercent = (100 - sysctl("kern.memorystatus_level")) / 100.0`, clamped 0...1. If that sysctl fails, fall back to fixed per-level values (normal 0.15, warning 0.65, critical 0.90).
- **Honesty rule**: the popover gauge and badge show kernel pressure; the menu bar dot shows the level; any raw used/total percentage is labeled "Used" (occupancy), never presented as pressure. Do not derive pressure from `vm_statistics64` fill math.
- `DISPATCH_SOURCE_TYPE_MEMORYPRESSURE` is rejected as the loop source (push-only, no initial state).

### CPU % math (unchanged)

- Pure `MetricMath.computePercentages(previous:current:)`; guard first sample, zero deltas (`totalDelta == 0` → 0.0; rapid toggle restarts can produce sub-ms deltas), and counter rollover (`curr.total < prev.total` → 0). Clamp 0...1.

### Toggle-driven sampling (new — oracle decision)

- `EnabledMetrics` OptionSet (`cpu`, `memory`, `gpu`; pressure rides with memory). `MetricSamplerActor.collectSnapshot(enabled:)` samples only enabled metrics; when CPU is disabled, clear `previousCPUTicks` so re-enable starts clean.
- On any toggle/interval change, `@MainActor SystemMonitor` calls `restartSampling()`: cancel the current `samplingTask`, start a new task that samples on tick zero (instant UI response), then `ContinuousClock.sleep(for:tolerance: ~150ms)`. No AsyncStream/continuation channels, no short polling loop.

### Concurrency & UI (unchanged, plus designer additions)

- Sampling in `MetricSamplerActor`; UI state in `@Observable @MainActor SystemMonitor`; default interval 2.0 s (settings offer 1/2/5 s). Swift 6 strict concurrency: `Sendable` value-type snapshots (`CoreTickSample`, `CPUMetrics`, `MemoryMetrics`, `MemoryPressureMetrics`, `GPUMetrics`, `SystemSnapshot` with optional members per enabled set).
- `MenuBarExtra` with `.menuBarExtraStyle(.window)`; separate `Settings` scene. Settings from popover: `NSApplication.shared.activate(ignoringOtherApps: true)` before `openSettings()`.

### Settings persistence & guard (new)

- `PreferencesStore` (`@AppStorage`/UserDefaults) gains `showCPU`, `showRAM`, `showGPU` (all default `true`) and drops the base plan's "display format" picker and "RAM unit" setting.
- **Last-one-enabled guard**: model-level — `activeMetricCount` computed property; each `showX { didSet { if !showX && activeMetricCount == 0 { showX = true } } }`; on init, if all three keys are `false`, reset `showCPU = true`. UI-level — when `activeMetricCount == 1`, the sole ON toggle gets `.disabled(true)` and the section footer reads "At least one metric must remain enabled."
- Launch-at-login via `SMAppService.mainApp` with status checks (`.requiresApproval` must not loop retries).

### Footprint budget (< 50 MB RSS, Settings closed)

- Oracle projection: 18–28 MB idle; ~2 KB heap per tick; <60 µs per full sample; <0.03 % CPU at 2 s.
- Rules: draw sparklines with `Canvas`/`Path` (no `import Charts`); no image assets/preview resources in the bundle; history ring buffers capped; one timer, one actor, no Combine pipelines; skip sampling for disabled metrics; `IORegistryEntryCreateCFProperty` single-key reads only. Target is measured on the built app (AC-10), not assumed.

## Design Authority

- **Extension blueprint (GPU, pressure, toggles): `.pi/plans/2026-10-13-stats-lite-menu-bar/design-extension-gpu-pressure-toggles.md`** — visual source of truth for the new elements: menu bar widths for all 7 combinations (3-metric: 129 pt bare / 200 pt labeled), 6 pt pressure dot, GPU card + dashed unavailable state, dynamic popover heights (~390/300/210 pt collapsed, ~470/380/290 pt expanded, width fixed 280 pt), Settings "Visible Metrics" section, VAC-14..VAC-24, accessibility contracts.
- Base blueprint (unchanged elements): `.pi/plans/2026-10-13-stats-lite-menu-bar/notes.md` — VAC-1..VAC-13, tokens, card/poll styles.
- Conflict rule: blueprint specs win for anything visual; oracle specs win for anything non-visual (Mach/IOKit/sysctl/concurrency).
- **Supersession rules (resolve base-vs-extension conflicts):**
  - Extension **VAC-22 supersedes base VAC-10**: popover height is dynamic (~390/300/210 pt collapsed, ~470/380/290 pt expanded); no configuration must measure ≈320 pt.
  - Extension **VAC-14, VAC-15, VAC-17 supersede base VAC-2 and VAC-3**: the display-format picker is gone; verify all 7 toggle combinations instead of both/CPU-only/RAM-only modes.
  - Pressure gauge bar height is **8 pt** (VAC-21), not the 6 pt noted in the extension wireframe sketch.
- UI tasks must read the relevant blueprint file first and follow it verbatim.

## Tasks

- `01-project-scaffold.md` — Xcode project, targets, Info.plist (`LSUIElement`), gitignore (`.derivedData/`), empty buildable app + test target
- `02-domain-metrics-math.md` — value types incl. `GPUMetrics`, `MemoryPressureMetrics`/`MemoryPressureState`, `EnabledMetrics`, snapshot with optionals; `MetricMath`; formatters; unit tests
- `03-system-metrics-provider.md` — provider protocol + Mach/IOKit/sysctl implementation (CPU, RAM, GPU, pressure) with all leak `defer`s; tests via fake provider
- `04-sampler-engine.md` — `MetricSamplerActor` (conditional sampling), `SystemMonitor` (restart-on-change), `PreferencesStore` (toggles + guard), `LaunchAtLoginService`
- `05-menu-bar-popover-ui.md` — app entry, 3-slot menu bar item per width spec, popover (CPU card, Memory Pressure card, GPU card, dynamic heights, header/footer)
- `06-settings-window.md` — Settings scene with "Visible Metrics" section + guard wiring, display options, version label

**Task file location**: all six files are generated fresh under `.pi/plans/2026-10-15-stats-lite-3metric/tasks/` before any coder spawn. The old files in `.pi/plans/2026-10-13-stats-lite-menu-bar/tasks/` are obsolete two-metric specs (they reference `DisplayFormat`, `RAMUnit`, and omit GPU/pressure/toggles) — never hand them to a coder. Coder spawns run from a worktree on a non-base branch.

## Acceptance Criteria

1. `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build` succeeds with zero errors and no warnings introduced by our code.
2. `xcodebuild test` (same env, macOS destination) passes: CPU % math (first-sample, rollover, zero-delta incl. rapid-restart), RAM derivation from fake VM stats, pressure percent fallback, GPU averaging from fake property dicts, formatter output.
3. App runs as a menu bar agent: no Dock icon, no main menu; item shows only enabled metrics with monospaced digits.
4. Popover: cards render only for enabled metrics, heights adapt (~390/300/210 pt collapsed), width fixed 280 pt; Escape/outside-click closes; header Settings + Quit buttons work.
5. Memory pressure: dot colors green/yellow/red match kernel level (1/2/4); gauge/badge use `100 - kern.memorystatus_level` percent; used percentage is labeled "Used".
6. GPU: value sampled from `Device Utilization %` without root; on unsupported hardware the menu bar shows `--%` and the popover shows the dashed unavailable state (no crash, no error dialog).
7. Settings: three independent toggles; flipping one immediately shows/hides menu bar slot + popover card; the last enabled toggle is disabled (UI + model guard, incl. corrupted-defaults init case); refresh interval (1/2/5 s) and history duration (30/60 s) changes take effect live (observable in sampling cadence / sparkline window); no retry loop on `SMAppService` `.requiresApproval`.
8. No Mach port, VM, IOKit iterator/service, or CF ownership leaks: all `defer` cleanups per Architecture section; `takeRetainedValue()` on CF property; verified by code review.
9. Every VAC-1..VAC-24 item marked "Met" in the coder's report and verified visually (screenshot) where possible, applying the supersession rules (VAC-22 over VAC-10; VAC-14/15/17 over VAC-2/3).
10. **RSS < 50 MB with Settings window closed**, measured via `ps -o rss= -p <pid>` after launch, popover opened once then closed, 60 s idle at 2 s interval. If exceeded: profile (`footprint`), fix the top consumer, re-measure, report before closing.
11. Release `xcodebuild -configuration Release` bundle < 50 MB (`du -sk StatsLite.app`).
12. Two or fewer intermediate commits per task; conventional commit messages.

## Contingency

- Design consult: base `notes.md` / extension `design-extension-gpu-pressure-toggles.md`.
- Architecture consult: this ISC's Architecture section (locked; non-visual details win).
- Partially implemented build: `git log`, `git diff`.
- User's third requirement (RSS < 50 MB, Settings closed): AC-10.

## Deferred / Out of Scope

- Network/disk monitoring, fan/temperature sensors.
- Per-GPU-device breakdown (single averaged figure only).
- Historical persistence across launches.
- Sparkline history beyond the in-memory window (30/60 s ring buffer).
- Notarization/distribution signing (ad-hoc only).
