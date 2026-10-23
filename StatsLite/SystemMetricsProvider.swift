//
//  SystemMetricsProvider.swift
//  StatsLite
//
//  Read-once access to the kernel counters behind the metrics.
//  The sampler actor owns the previous-sample state; the provider only
//  reads the system. No method throws and no method crashes: a `nil`
//  return means the read failed or the source is unavailable.
//

/// Source of CPU, memory, GPU, temperature, and memory-pressure
/// readings.
protocol SystemMetricsProvider: Sendable {

    /// One CPU sample: one tick entry per core plus the aggregate sum.
    /// Returns `nil` when the Mach CPU read fails.
    func sampleCPUTicks() -> CPUTicks?

    /// Activity Monitor style memory figures in bytes.
    /// Returns `nil` when the VM statistics read fails.
    func sampleMemory() -> MemoryMetrics?

    /// GPU utilization as fractions in 0...1.
    /// Returns `nil` when no accelerator is present or when no device
    /// reports utilization (for example in a VM).
    func sampleGPU() -> GPUMetrics?

    /// Kernel memory pressure. Always returns a value. The state is
    /// `.unknown` and the percentage is 0 when both sysctl reads fail.
    func sampleMemoryPressure() -> MemoryPressureMetrics

    /// Cumulative non-loopback interface byte counters. Returns `nil`
    /// when the interface walk fails or when no usable interface exists.
    func sampleNetworkBytes() -> NetworkBytes?

    /// CPU and GPU die temperatures in °C (plan 2026-10-23-
    /// temp-menu-bar-metric, Phase 2). Returns `nil` when the whole
    /// read fails (no sensor source at all). A present sample can
    /// still carry nil subsystems: a nil `cpuCelsius` or
    /// `gpuCelsius` means that row is unreadable.
    func sampleTemperature() -> TemperatureMetrics?

    /// One full process scan (T1). Returns per PID: `pid`, `cpuTicks`
    /// (`ri_user_time + ri_system_time`), `startAbstime`
    /// (`ri_proc_start_abstime`), `exitAbstime` (`ri_proc_exit_abstime`),
    /// `physFootprint` (`ri_phys_footprint`), `residentSize`
    /// (`ri_resident_size`). PIDs whose `proc_pid_rusage` read failed
    /// (EPERM for other users' processes) are absent. Returns `nil`
    /// when the scan fails. One scan serves both rankings.
    func sampleProcesses() -> [RawProcessSample]?

    /// Display name for one PID (T7). Returns `nil` when the PID is
    /// gone or both the path and name reads fail.
    func resolveProcessName(pid: Int32) -> String?
}
