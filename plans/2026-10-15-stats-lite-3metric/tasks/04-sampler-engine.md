# Task 04 — Sampler Engine (Actor, Monitor, Preferences, Launch-at-Login)

## Objective

Toggle-aware sampling loop with instant restart; observable UI state; preferences with the last-one-enabled guard; launch-at-login.

## Read first

- ISC §Architecture: **Toggle-driven sampling**, Concurrency & UI, **Settings persistence & guard**.
- Extension blueprint §4 (interaction rules, `PreferencesStore` guard sketch).

## Deliverables

1. `MetricSamplerActor`: `collectSnapshot(enabled:)` samples ONLY enabled metrics; CPU disabled clears `previousCPUTicks`. Previous-tick state per metric for deltas.
2. `@Observable @MainActor SystemMonitor`: holds latest `SystemSnapshot`; `restartSampling()` = cancel current `samplingTask`, start new task sampling on tick zero, then `ContinuousClock` sleep with ~150 ms tolerance at the configured interval (default 2.0 s). Call restart on any toggle/interval change. `stop()`. No Combine, no AsyncStream channels, no short polling.
3. `PreferencesStore`: `@AppStorage` keys — `showCPU`, `showRAM`, `showGPU` (default true), `refreshInterval` (1/2/5, default 2), `historyDuration` (30/60), `showLabels`, `showCoreBreakdown`, `launchAtLogin`. Dropped: display format, RAM unit. Guard per ISC: `activeMetricCount` + `didSet` re-enable + init reset when all three false. Expose an `EnabledMetrics` view of the toggles.
4. `LaunchAtLoginService`: `SMAppService.mainApp`, status checks, `.requiresApproval` shows state without retry loops, error handling.
5. History ring buffers capped per `historyDuration` (sparkline data), capped as ISC requires.

## Tests

- Fake provider: enabled-set routing (disabled metric not sampled), CPU-state reset on disable→re-enable, zero-delta guard on rapid restart.
- Guard: all-false init → `showCPU` true; `didSet` blocks disabling the last one.

## Report

- Conventional commits, ≤2. List test names; confirm one timer/actor only (footprint rules).
