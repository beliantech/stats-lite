# Task 03 — Mach Metrics Provider

## Objective
Implement real CPU/RAM sampling via Mach APIs with leak-safe cleanup, behind a protocol so tests use fakes.

## Context
Read the ISC architecture section and the oracle report sections 4.3 + 5.1–5.3, 5.6 (`docs/plans/2026-10-13-stats-lite-menu-bar/notes.md`). Copy the resource-cleanup patterns exactly — leaks are blocking defects.

## Deliverables
1. `StatsLite/Services/SystemMetricsProvider.swift`: `protocol SystemMetricsProvider: Sendable { func sampleCPUTicks() throws -> [CoreTickSample]; func sampleMemory() throws -> MemoryMetrics }`.
2. `StatsLite/Services/MachMetricsProvider.swift`:
   - `sampleCPUTicks` via `mach_host_self()` + `host_processor_info(PROCESSOR_CPU_LOAD_INFO)`, with `defer { mach_port_deallocate(mach_task_self(), hostPort) }` and `defer { vm_deallocate(...) }` sized `processorInfoCount * MemoryLayout<integer_t>.stride`. Per-core offsets by `CPU_STATE_MAX`.
   - `sampleMemory` via `host_statistics64(HOST_VM_INFO64)` inside `withUnsafeMutablePointer` + `withMemoryRebound`, `defer` port deallocate. Runtime `vm_kernel_page_size`. Derivation via the pure helper from task 02.
   - Throw a typed `MetricsSamplingError` (with kernel return code) on failure.
3. Tests in `StatsLiteTests/MachProviderTests.swift`:
   - Live smoke test: `MachMetricsProvider()` returns non-empty cores, each core usage in 0...1 after two samples 100 ms apart, memory total == `ProcessInfo.processInfo.physicalMemory`, used ≤ total.
   - A `StubMetricsProvider` fake proving the `SystemMetricsProvider` abstraction drives `MetricMath` end-to-end (fake ticks → expected percentages; fake page counts → expected MemoryMetrics).

## Verify
`xcodebuild test` (ISC invocation). All green.

## Commit
`feat(metrics): add Mach-based CPU and memory sampling provider`
