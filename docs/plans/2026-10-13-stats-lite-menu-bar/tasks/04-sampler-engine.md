# Task 04 — Sampler Engine, SystemMonitor, Preferences, Launch-at-Login

## Objective
Wire sampling into a background actor feeding a @MainActor observable monitor; add the preferences store and launch-at-login service.

## Context
Read the ISC concurrency/settings sections and oracle report sections 4.5 + 4.7 + 5.4–5.6 (`docs/plans/2026-10-13-stats-lite-menu-bar/notes.md`). Blueprint section 3 (State Matrix) defines threshold colors: normal <80%, warning 80–94% (orange), critical ≥95% (red) — encode thresholds as a pure helper here so task 05 just renders.

## Deliverables
1. `StatsLite/Models/SystemMonitor.swift`:
   - `MetricSamplerActor` per oracle 4.5 (holds previous ticks, computes snapshot).
   - `@Observable @MainActor final class SystemMonitor`: `snapshot: SystemSnapshot?`, `cpuHistory`/`ramHistory` ring buffers (Doubles for sparklines, capped by history duration × sample rate), `isPopoverVisible`, `start(intervalSeconds:)`/`stop()` with `ContinuousClock` + 150 ms tolerance, restart when interval setting changes. History append on each sample; expose `cpuSeverity`/`ramSeverity` thresholds (0/1/2).
   - Ring buffer must trim on history-duration change; no unbounded growth.
2. `StatsLite/Models/PreferencesStore.swift`: `@Observable @MainActor` wrapper over `@AppStorage`-backed keys: `refreshInterval` (Double, default 2.0; allowed 1/2/5), `displayFormat` (DisplayFormat, default .both), `ramUnit` (RAMUnit, default .gigabytes), `showLabels` (true), `showCoreBreakdown` (false), `historyDuration` (Int, default 30; allowed 30/60), `launchAtLogin` (Bool, synced to SMAppService).
3. `StatsLite/Services/LaunchAtLoginService.swift` per oracle 4.7, extended: `status` accessor mapping `.enabled/.notRegistered/.requiresApproval/.notFound` to an enum the settings UI can render (requiresApproval shows a hint, no retry loop).
4. Tests in `StatsLiteTests/`:
   - `SystemMonitorTests`: feed a scripted fake provider via injected actor; assert snapshot updates, history length caps at interval×duration, trim on duration change, severity thresholds (0.8/0.95 boundaries), start/stop idempotence. Use short intervals; no UI.
   - `PreferencesDefaultsTests`: default values match the ISC/blueprint.

## Verify
`xcodebuild test` (ISC invocation). All green. No UI yet.

## Commit
`feat(engine): add sampling actor, observable monitor, preferences, launch-at-login`
