# Task 02 — Domain Value Types, MetricMath, Formatters

## Objective
Implement the pure-logic core: Sendable snapshot value types, CPU tick-delta math, and byte/percent formatters — with full unit-test coverage.

## Context
Read the ISC architecture section in the main repo (`/Users/jonathan/beliantech/stats-lite/docs/plans/2026-10-13-stats-lite-menu-bar/ISC.md`) and the oracle report's code sketches in `docs/plans/2026-10-13-stats-lite-menu-bar/notes.md` (sections 4.2 and 4.4). Use those types/signatures as the contract.

## Deliverables
1. `StatsLite/Models/MetricSnapshots.swift`: `CoreTickSample` (user/system/idle/nice UInt64, computed `total`, `active`), `CPUMetrics` (totalUsage 0...1, coreUsages [Double]), `MemoryMetrics` (used/total/app/wired/compressed bytes, computed `usagePercentage`), `SystemSnapshot` (cpu, memory, timestamp). All `Sendable, Equatable`.
2. `StatsLite/Utilities/MetricMath.swift`:
   - `computePercentages(previous:current:) -> CPUMetrics` exactly per oracle section 4.4: mismatched/empty arrays → zeros; zero total delta → 0; counter rollover (`curr.total < prev.total`) → 0 for that core; clamp 0...1; total = aggregate active delta / aggregate total delta.
   - `RAMMetrics` derivation helper: pure function from raw page counts + pageSize + totalBytes to `MemoryMetrics` (App = internal−purgeable, guard underflow → 0; Wired; Compressed; Used = sum).
3. `StatsLite/Utilities/MetricFormatters.swift`:
   - `ByteCountFormatter`-based helper `formatBytes(_:)` producing "6.2G", "512M" style (GB with one decimal ≥1G, MB whole below).
   - `formatPercent(_:)` → "18%" / "100%" (whole numbers, clamped).
   - Menu bar string builder `menuBarString(cpuPercent:ramUsedGB:ramTotalGB:format:unit:showLabels:)` matching the blueprint's label logic ("CPU 14% · RAM 6.2G" or "CPU 14%", "RAM 38%").
   - Enums `DisplayFormat {both, cpuOnly, ramOnly}` and `RAMUnit {gigabytes, percentage}` as `String, CaseIterable, Sendable` (RawRepresentable for @AppStorage).
4. Tests in `StatsLiteTests/`:
   - `CPUMathTests`: first-sample guard, zero delta, normal delta (e.g. prev active 100/total 400, curr active 200/total 600 → 50%), rollover, per-core aggregation, clamping.
   - `RAMDerivationTests`: known page counts → exact bytes; purgeable > internal underflow; zero total.
   - `MetricFormatterTests`: GB/MB boundaries, percent rounding, menu bar strings for all format/unit/label combos.

## Verify
`xcodebuild test` with the ISC's DEVELOPER_DIR invocation. All tests green.

## Commit
`feat(core): add snapshot value types, CPU math, and metric formatters with tests`
