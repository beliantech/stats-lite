# Task 02 — Domain Metrics & Math

## Objective

Pure value types + pure math + formatters. No IOKit/Mach imports, no UI.

## Read first

- ISC §Architecture: CPU sampling, RAM sampling, CPU % math, Memory pressure sampling, footnote on honesty rule.
- Extension blueprint §2/§3 (`design-extension-gpu-pressure-toggles.md`) for `MemoryPressureLevel` naming/colors.

## Deliverables

1. Value types (all `Sendable`, `Equatable` where possible):
   - `CoreTickSample` (user/system/idle/nice ticks), `CPUMetrics` (totalUsage 0...1, per-core array).
   - `MemoryMetrics` (usedBytes, totalBytes, appMemoryBytes, wiredBytes, compressedBytes).
   - `MemoryPressureState` (`normal = 1`, `warning = 2`, `critical = 4`, `unknown = 0`; displayName), `MemoryPressureMetrics` (state + pressurePercentage 0...1).
   - `GPUMetrics` (device/renderer/tiler utilization, each 0...1).
   - `EnabledMetrics` OptionSet (`cpu`, `memory`, `gpu`).
   - `SystemSnapshot` with optional members per enabled set + timestamp.
2. `MetricMath.computePercentages(previous:current:)`: guards for first sample (no previous), `totalDelta == 0` → 0.0, rollover (`curr.total < prev.total`) → 0, clamp 0...1. Pure, deterministic.
3. Pressure percent helper: `(100 - availabilityPercent) / 100` clamped; fallback to fixed per-level values (0.15/0.65/0.90) when the sysctl read failed; `unknown` → 0.0.
4. Formatters: percent (integer, `--%` for nil), GB (one decimal).

## Tests (StatsLiteTests)

- CPU math: first-sample, zero-delta, rollover, clamp.
- Pressure percent: normal path, fallback path, unknown.
- Formatters: percent nil/0/100, GB.
- `EnabledMetrics` guard semantics: empty set rejected by the monitor guard helper (design the helper here if pure).

## Report

- Conventional commits, ≤2. List test names passing.
