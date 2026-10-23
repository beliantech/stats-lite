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

    /// Per-PID CPU delta anchors for process sampling (T2): Mach tick
    /// counter plus `ri_proc_start_abstime` for PID-reuse rejection.
    private var processAnchors: [Int32: ProcessTickAnchor] = [:]

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
        var temperature: TemperatureMetrics?

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

        // Temperature is instantaneous (plan Phase 3): no delta base.
        // A disabled temperature never reaches the provider.
        if enabled.contains(.temperature) {
            temperature = provider.sampleTemperature()
        }

        return SystemSnapshot(
            enabled: enabled,
            cpu: cpu,
            memory: memory,
            memoryPressure: memoryPressure,
            gpu: gpu,
            temperature: temperature
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

    // MARK: - Process sampling (plan 2026-10-23, T2/T6)

    /// Mach timebase: nanoseconds per Mach tick, read once and cached.
    /// CPU fractions scale tick deltas through it (T6).
    private static let nanosecondsPerTick: Double = {
        var timebase = mach_timebase_info()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom)
    }()

    /// One process pass at instant `now`: one scan serves both
    /// rankings (T1). Returns `nil` when the scan fails and keeps the
    /// delta base, so the next good pass still has its predecessor.
    ///
    /// CPU rows publish only for PIDs that already hold an anchor:
    /// the first pass anchors every PID and ranks memory only (R5).
    /// A start-stamp mismatch (recycled PID), a tick-counter rollback,
    /// or a non-positive elapsed time reports 0 for that pass and
    /// re-anchors (P3, P5). The fraction is
    /// delta ticks x timebase / (elapsed ns x cores), clamped 0...1
    /// (T6). `pid <= 0` rows and zombies (`exitAbstime != 0`) never
    /// enter a ranking, and a PID that vanishes from the scan drops
    /// its anchor (T6, P6). Memory ranks the top 5 by footprint with a
    /// resident-size fallback and no delta (R6). One pass resolves
    /// names for the union of both top-5 lists, and a top candidate
    /// whose name never resolves drops from that pass's list instead
    /// of shipping the `Process NNNNN` fallback (D1, Appendix D
    /// items 1-2). The scan loop allocates no `String`: names, value
    /// labels, and publication happen after the top-5 prefixes (T7).
    func sampleProcesses(now: ContinuousClock.Instant = .now) -> ProcessSampleResult? {
        guard let samples = provider.sampleProcesses() else { return nil }

        // Attribution filters (T6), de-duplicated so one scan cannot
        // rank or anchor the same PID twice.
        var seenPids: Set<Int32> = []
        let live = samples.filter { sample in
            guard sample.pid > 0, sample.exitAbstime == 0 else { return false }
            return seenPids.insert(sample.pid).inserted
        }

        // A PID that vanished from the scan (EPERM, exited) drops its
        // anchor: no stale delta can surface when it returns (P6).
        processAnchors = processAnchors.filter { seenPids.contains($0.key) }

        let timebase = Self.nanosecondsPerTick
        let cores = Double(ProcessInfo.processInfo.activeProcessorCount)
        let totalRAM = Double(ProcessInfo.processInfo.physicalMemory)

        var cpuRows: [CPURankingRow] = []
        var memoryCandidates: [MemoryCandidate] = []

        for sample in live {
            // A PID without a prior anchor measures this pass for the
            // first time: it anchors and publishes no CPU row yet.
            if let anchor = processAnchors[sample.pid] {
                var fraction = 0.0
                if anchor.startAbstime == sample.startAbstime,
                   sample.cpuTicks >= anchor.cpuTicks {
                    let elapsed = now - anchor.instant
                    let components = elapsed.components
                    let seconds = Double(components.seconds)
                        + Double(components.attoseconds) / 1e18
                    if seconds > 0 {
                        let deltaTicks = Double(sample.cpuTicks - anchor.cpuTicks)
                        let computed = deltaTicks * timebase / (seconds * 1e9 * cores)
                        fraction = min(max(computed, 0), 1)
                    }
                }
                // Mismatch or rollback falls through with fraction 0:
                // a re-anchor, never a stale or wrapped delta (P3, P5).
                cpuRows.append(
                    CPURankingRow(pid: sample.pid, fraction: fraction)
                )
            }
            processAnchors[sample.pid] = ProcessTickAnchor(
                cpuTicks: sample.cpuTicks,
                startAbstime: sample.startAbstime,
                instant: now
            )

            // Memory: footprint is the Activity Monitor figure; a
            // zero footprint falls back to resident size (T6, P8).
            let bytes = sample.physFootprint > 0
                ? sample.physFootprint
                : sample.residentSize
            memoryCandidates.append(
                MemoryCandidate(pid: sample.pid, bytes: bytes)
            )
        }

        // Descending rank, PID as the deterministic tie-breaker;
        // at most 5 rows per list (VAC-8).
        let topCPU = cpuRows
            .sorted { lhs, rhs in
                lhs.fraction == rhs.fraction
                    ? lhs.pid < rhs.pid
                    : lhs.fraction > rhs.fraction
            }
            .prefix(5)
        let topMemory = memoryCandidates
            .sorted { lhs, rhs in
                lhs.bytes == rhs.bytes
                    ? lhs.pid < rhs.pid
                    : lhs.bytes > rhs.bytes
            }
            .prefix(5)

        // One pass resolves the union of the top-5 CPU and top-5
        // memory PIDs: at most 10 distinct lookups, no early stop,
        // dedup across the lists via `nameByPid`. CPU leads the
        // iteration order but holds no exclusive budget, so the
        // memory list can no longer starve (D1, Appendix D item 1;
        // §10 attribution confirmed H1: the old lookups<8 /
        // resolved<5 budget stopped after the CPU five).
        var nameByPid: [Int32: String] = [:]
        for pid in topCPU.map(\.pid) + topMemory.map(\.pid) {
            guard nameByPid[pid] == nil else { continue }
            if let name = provider.resolveProcessName(pid: pid), !name.isEmpty {
                nameByPid[pid] = name
            }
        }

        // A candidate whose name never resolves drops from this pass's
        // list; `Process NNNNN` never publishes (Appendix D item 2).
        // The PID exited or became unreadable between scan and lookup,
        // so the row heals or disappears on the next pass (item 4).
        let topMemoryItems = topMemory.compactMap { candidate -> ProcessMetricItem? in
            guard let name = nameByPid[candidate.pid] else { return nil }
            return ProcessMetricItem(
                pid: candidate.pid,
                name: name,
                fraction: Double(candidate.bytes) / totalRAM,
                valueLabel: Self.memoryValueLabel(candidate.bytes)
            )
        }
        let topCPUItems = topCPU.compactMap { row -> ProcessMetricItem? in
            guard let name = nameByPid[row.pid] else { return nil }
            return ProcessMetricItem(
                pid: row.pid,
                name: name,
                fraction: row.fraction,
                valueLabel: MetricFormatters.percentTenth(row.fraction)
            )
        }

        return ProcessSampleResult(topCPU: topCPUItems, topMemory: topMemoryItems)
    }

    /// Drops the per-PID process delta base, so the next pass anchors
    /// from scratch (T5, mirrors `clearNetworkBase`).
    func clearProcessBase() {
        processAnchors = [:]
    }

    /// One PID's memory value for the ranking: a named type keeps the
    /// sort closures simple to type-check.
    private struct MemoryCandidate: Sendable {
        var pid: Int32
        var bytes: UInt64
    }

    /// One memory row's display value: one-decimal GB from 1 GiB up
    /// ("6.8 GB"), integer MB below ("780 MB") (plan §4.3).
    private static func memoryValueLabel(_ bytes: UInt64) -> String {
        let gibibyte: Double = 1_073_741_824
        if Double(bytes) >= gibibyte {
            return String(format: "%.1f GB", Double(bytes) / gibibyte)
        }
        let mebibyte: Double = 1_048_576
        return "\(Int((Double(bytes) / mebibyte).rounded())) MB"
    }

    /// One CPU ranking row before name resolution: pid and fraction
    /// only. The scan loop builds these without touching a `String`
    /// (T7); value labels and the published `ProcessMetricItem` are
    /// built after the top-5 prefix, once a name resolved (D1
    /// Appendix D items 1-2).
    private struct CPURankingRow: Sendable {
        var pid: Int32
        var fraction: Double
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
