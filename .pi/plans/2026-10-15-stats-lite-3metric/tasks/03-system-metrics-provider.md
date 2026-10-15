# Task 03 — System Metrics Provider (Mach / IOKit / sysctl)

## Objective

`SystemMetricsProvider` protocol + real implementation sampling CPU, RAM, GPU, memory pressure. Leak-free.

## Read first

- ISC §Architecture: CPU sampling, RAM sampling, **GPU sampling**, **Memory pressure sampling** (every memory-safety rule is mandatory), failure/fallback expectations in AC-6.

## Deliverables

1. `SystemMetricsProvider` protocol (`Sendable`): `sampleCPUTicks()`, `sampleMemory()`, `sampleGPU() -> GPUMetrics?`, `sampleMemoryPressure()`.
2. Real provider (name per ISC/task 04 conventions):
   - CPU: `host_processor_info` with `defer { mach_port_deallocate(...) }` + `defer { vm_deallocate(...) }` (size = count × stride).
   - RAM: `host_statistics64` / `HOST_VM_INFO64`, Activity Monitor formula, runtime `vm_kernel_page_size`.
   - GPU: `IOServiceMatching("IOAccelerator")` → `IOServiceGetMatchingServices` → per-service `IORegistryEntryCreateCFProperty("PerformanceStatistics")` → `"Device Utilization %"` Int 0–100 averaged over devices, clamped 0...1. **All ISC rules**: `defer { IOObjectRelease(iterator) }`, `defer { IOObjectRelease(service) }` per iteration, `.takeRetainedValue()`, never `CFRelease` the matching dict, single-key property only. Return `nil` when no service/key (VMs, future HW). Optional renderer/tiler fields populated too.
   - Pressure: `sysctlbyname("kern.memorystatus_vm_pressure_level")` → state; `kern.memorystatus_level` → percent via ISC formula with fallback.
3. Errors: no force-unwraps; failed reads throw or return nil per protocol semantics — never crash.

## Tests

- Provider tested through task 02's fake provider contract (fake implements protocol; sampler tests come in task 04). Add direct unit tests for any pure helpers you extract (e.g. pressure percent mapping from raw Int32 values).

## Report

- Conventional commits, ≤2. Quote the leak-`defer` lines in your report (AC-8 evidence) and state IOKit ownership handling.
