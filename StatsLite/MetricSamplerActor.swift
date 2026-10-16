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

    /// Network delta base: the last accepted byte counters plus the
    /// clock instant they were read at. Rate math needs both.
    private var previousNetworkSample: (bytes: NetworkBytes, instant: ContinuousClock.Instant)?

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

    // MARK: - Network rate sampling

    /// One network pass at instant `now`. Disabled returns nil and
    /// clears the base without reading the provider. A failed read
    /// returns nil and keeps the base. The first sample only anchors.
    /// Elapsed time outside 0.001...2.5 s and a counter rollback
    /// discard the delta, re-anchor, and return nil. Everything else
    /// returns delta bytes divided by the measured elapsed seconds,
    /// never a hard-coded 1.0 s (D5).
    func sampleNetwork(
        enabled: Bool,
        now: ContinuousClock.Instant = .now
    ) -> NetworkMetrics? {
        guard enabled else {
            // Disable drops the base, so a later re-enable starts from
            // a fresh first sample and no gap spike can appear (FM6).
            previousNetworkSample = nil
            return nil
        }

        // A failed read returns nil and keeps the base: only one pass
        // is lost, and the next good read still has its predecessor
        // (FM5).
        guard let current = provider.sampleNetworkBytes() else { return nil }

        defer { previousNetworkSample = (current, now) }

        guard let previous = previousNetworkSample else {
            // First sample: a cumulative counter must never be divided
            // by one second (FM2).
            return nil
        }

        let elapsed = now - previous.instant
        guard elapsed > .milliseconds(1), elapsed <= .seconds(2.5) else {
            // Too close together, zero, negative, or a sleep/wake gap:
            // re-anchor and emit no diluted or infinite rate (FM3, FM4).
            // The 2.5 s cap is the ratified discontinuity threshold.
            return nil
        }

        guard current.bytesIn >= previous.bytes.bytesIn,
              current.bytesOut >= previous.bytes.bytesOut
        else {
            // Counter rollback (interface reset): re-anchor instead of
            // wrapping an unsigned subtraction (FM1).
            return nil
        }

        let components = elapsed.components
        let elapsedSeconds = Double(components.seconds)
            + Double(components.attoseconds) / 1e18
        return NetworkMetrics(
            downloadBytesPerSecond: Double(current.bytesIn - previous.bytes.bytesIn)
                / elapsedSeconds,
            uploadBytesPerSecond: Double(current.bytesOut - previous.bytes.bytesOut)
                / elapsedSeconds
        )
    }

    /// Drops the network delta base. The next enabled sample anchors
    /// again and returns nil.
    func clearNetworkBase() {
        previousNetworkSample = nil
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
