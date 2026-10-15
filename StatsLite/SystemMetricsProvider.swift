//
//  SystemMetricsProvider.swift
//  StatsLite
//
//  Read-once access to the kernel counters behind the three metrics.
//  The sampler actor owns the previous-sample state; the provider only
//  reads the system. No method throws and no method crashes: a `nil`
//  return means the read failed or the source is unavailable.
//

/// Source of CPU, memory, GPU, and memory-pressure readings.
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
}
