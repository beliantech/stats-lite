//
//  MetricTypes.swift
//  StatsLite
//
//  Pure value types for the three metrics: CPU, memory (with pressure),
//  and GPU. No IOKit/Mach calls here. Every type is Sendable so the
//  sampler actor can hand snapshots to the main actor safely.
//

import Foundation

/// Raw tick counters for one sample. `user`, `system`, and `nice` count
/// busy time, `idle` counts idle time. Values only make sense as a delta
/// against a previous sample of the same counter.
struct CoreTickSample: Sendable, Equatable {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64

    /// Sum of all tick counters.
    var total: UInt64 { user + system + idle + nice }

    /// Sum of the busy tick counters (user + system + nice).
    var busy: UInt64 { user + system + nice }
}

/// One `host_processor_info` sample: one tick entry per core plus the
/// sum across cores. The sampler uses `aggregate` for the total CPU %
/// and `perCore` for the per-core breakdown.
struct CPUTicks: Sendable, Equatable {
    /// One `CoreTickSample` per core, in kernel order.
    var perCore: [CoreTickSample]

    /// Sum of `perCore` across all cores.
    var aggregate: CoreTickSample

    /// Builds a sample and computes the aggregate sum.
    init(perCore: [CoreTickSample]) {
        self.perCore = perCore
        var sum = CoreTickSample(user: 0, system: 0, idle: 0, nice: 0)
        for core in perCore {
            sum.user += core.user
            sum.system += core.system
            sum.idle += core.idle
            sum.nice += core.nice
        }
        self.aggregate = sum
    }
}

/// CPU usage. Both values are fractions in 0...1, clamped at init.
struct CPUMetrics: Sendable, Equatable {
    /// Usage across all cores, 0...1.
    var totalUsage: Double

    /// Per-core usage, one fraction per core, each 0...1.
    var perCore: [Double]

    init(totalUsage: Double, perCore: [Double]) {
        self.totalUsage = Self.clamp(totalUsage)
        self.perCore = perCore.map(Self.clamp)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// RAM occupancy in bytes. `usedPercentage` is occupancy, never memory
/// pressure. Pressure comes only from the kernel pressure level.
struct MemoryMetrics: Sendable, Equatable {
    var usedBytes: UInt64
    var totalBytes: UInt64
    var appMemoryBytes: UInt64
    var wiredBytes: UInt64
    var compressedBytes: UInt64

    /// Share of total bytes in use, 0...1. Returns 0 when the total is unknown.
    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }
}

/// Kernel memory pressure level. Raw values match the sysctl values of
/// `kern.memorystatus_vm_pressure_level`.
enum MemoryPressureState: Int, Sendable, Equatable {
    case unknown = 0
    case normal = 1
    case warning = 2
    case critical = 4

    /// Label for badges and the popover: Normal, Warning, Critical, Unknown.
    var displayName: String {
        switch self {
        case .unknown: "Unknown"
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }

    /// Maps a raw sysctl level to a state. Unmapped values map to `.unknown`.
    init(rawLevel: Int) {
        self = MemoryPressureState(rawValue: rawLevel) ?? .unknown
    }
}

/// Kernel memory pressure. `pressurePercentage` is a fraction in 0...1.
struct MemoryPressureMetrics: Sendable, Equatable {
    var state: MemoryPressureState

    /// Kernel pressure figure, 0...1, clamped at init.
    var pressurePercentage: Double

    init(state: MemoryPressureState, pressurePercentage: Double) {
        self.state = state
        self.pressurePercentage = min(max(pressurePercentage, 0), 1)
    }

    /// Builds metrics from the state plus the optional kernel availability
    /// percent (`kern.memorystatus_level`). Pass `nil` when that read failed.
    init(state: MemoryPressureState, availabilityPercent: Double?) {
        self.init(
            state: state,
            pressurePercentage: MetricMath.computePressurePercentage(
                state: state,
                availabilityPercent: availabilityPercent
            )
        )
    }
}

/// GPU utilization per engine, each a fraction in 0...1.
/// The provider returns `nil` instead of this type when the GPU cannot
/// be read at all.
struct GPUMetrics: Sendable, Equatable {
    /// Whole-device utilization, 0...1. Required to build the type.
    var deviceUtilization: Double

    /// Renderer engine utilization, 0...1. Nil when the key is missing.
    var rendererUtilization: Double?

    /// Tiler engine utilization, 0...1. Nil when the key is missing.
    var tilerUtilization: Double?

    init(
        deviceUtilization: Double,
        rendererUtilization: Double? = nil,
        tilerUtilization: Double? = nil
    ) {
        self.deviceUtilization = Self.clamp(deviceUtilization)
        self.rendererUtilization = rendererUtilization.map(Self.clamp)
        self.tilerUtilization = tilerUtilization.map(Self.clamp)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// Which metrics the user turned on in Settings. Pressure rides with memory.
struct EnabledMetrics: OptionSet, Sendable, Equatable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let cpu = EnabledMetrics(rawValue: 1 << 0)
    static let memory = EnabledMetrics(rawValue: 1 << 1)
    static let gpu = EnabledMetrics(rawValue: 1 << 2)
    static let all: EnabledMetrics = [.cpu, .memory, .gpu]
}

/// Pure guard used by the monitor before it samples. An empty set is
/// rejected because at least one metric must stay enabled.
enum MonitorGuard {
    static func allowsSampling(_ enabled: EnabledMetrics) -> Bool {
        !enabled.isEmpty
    }
}

/// One sampling pass. A member is present only when its metric is in
/// `enabled`; members stay optional inside the enabled set because the
/// first sample after a restart has no previous ticks.
struct SystemSnapshot: Sendable, Equatable {
    var timestamp: Date
    var enabled: EnabledMetrics
    var cpu: CPUMetrics?
    var memory: MemoryMetrics?
    var memoryPressure: MemoryPressureMetrics?
    var gpu: GPUMetrics?

    init(
        timestamp: Date = Date(),
        enabled: EnabledMetrics,
        cpu: CPUMetrics? = nil,
        memory: MemoryMetrics? = nil,
        memoryPressure: MemoryPressureMetrics? = nil,
        gpu: GPUMetrics? = nil
    ) {
        self.timestamp = timestamp
        self.enabled = enabled
        self.cpu = enabled.contains(.cpu) ? cpu : nil
        self.memory = enabled.contains(.memory) ? memory : nil
        self.memoryPressure = enabled.contains(.memory) ? memoryPressure : nil
        self.gpu = enabled.contains(.gpu) ? gpu : nil
    }
}
