//
//  MetricSamplerActor.swift
//  StatsLite
//
//  Toggle-aware sampling pass. The actor owns the previous CPU tick
//  sample so consecutive passes can compute deltas. A pass reads only
//  the metrics in the enabled set. A disabled CPU clears its tick base
//  so a later re-enable starts from a clean first sample.
//

import Foundation

actor MetricSamplerActor {

    private let provider: any SystemMetricsProvider
    private var previousCPUTicks: CPUTicks?

    init(provider: any SystemMetricsProvider) {
        self.provider = provider
    }

    /// One sampling pass. A snapshot member is non-nil only when its
    /// metric is enabled and the read succeeded. An empty enabled set
    /// reads nothing.
    func collectSnapshot(enabled: EnabledMetrics) -> SystemSnapshot {
        var cpu: CPUMetrics?
        var memory: MemoryMetrics?
        var memoryPressure: MemoryPressureMetrics?
        var gpu: GPUMetrics?

        if enabled.contains(.cpu) {
            // A failed read returns nil and keeps the tick base so the
            // next good read still has a valid delta reference.
            if let ticks = provider.sampleCPUTicks() {
                cpu = Self.computeCPU(previous: previousCPUTicks, current: ticks)
                previousCPUTicks = ticks
            }
        } else {
            previousCPUTicks = nil
        }

        // Memory pressure rides with the memory metric.
        if enabled.contains(.memory) {
            memory = provider.sampleMemory()
            memoryPressure = provider.sampleMemoryPressure()
        }

        if enabled.contains(.gpu) {
            gpu = provider.sampleGPU()
        }

        return SystemSnapshot(
            enabled: enabled,
            cpu: cpu,
            memory: memory,
            memoryPressure: memoryPressure,
            gpu: gpu
        )
    }

    // MARK: - CPU delta

    private static func computeCPU(
        previous: CPUTicks?,
        current: CPUTicks
    ) -> CPUMetrics {
        // The aggregate keeps its delta base even when the core count
        // changes, because the summed counters stay comparable.
        let total = MetricMath.computePercentages(
            previous: previous?.aggregate,
            current: current.aggregate
        )

        // Per-core history is invalid when the core count changes.
        // Each core then starts from nil and reports zero.
        var perCore: [Double]
        if let previous, previous.perCore.count == current.perCore.count {
            perCore = zip(previous.perCore, current.perCore).map { pair in
                MetricMath.computePercentages(previous: pair.0, current: pair.1)
            }
        } else {
            perCore = Array(repeating: 0, count: current.perCore.count)
        }

        return CPUMetrics(totalUsage: total, perCore: perCore)
    }
}
