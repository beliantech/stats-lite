//
//  MetricTypes.swift
//  StatsLite
//
//  Pure value types for the metrics: CPU, memory (with pressure), GPU,
//  and network. No IOKit/Mach calls here. Every type is Sendable so the
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

/// CPU and GPU die temperatures in degrees Celsius (plan
/// 2026-10-23-temp-menu-bar-metric, Phase 1). A subsystem with no
/// readable sensor is nil, so the renderer maps that row to "--°".
struct TemperatureMetrics: Sendable, Equatable {
    /// CPU die temperature in °C. Nil when the CPU row is unreadable.
    var cpuCelsius: Double?

    /// GPU die temperature in °C. Nil when the GPU row is unreadable.
    var gpuCelsius: Double?

    init(cpuCelsius: Double?, gpuCelsius: Double?) {
        self.cpuCelsius = Self.sanitized(cpuCelsius)
        self.gpuCelsius = Self.sanitized(gpuCelsius)
    }

    /// A non-finite decode is not a reading: it maps to nil. The
    /// guard runs before the clamp because NaN survives a plain
    /// `min(max(value, -20), 130)`. A finite value clamps to the
    /// plausible -20...130 °C band (GPUMetrics clamp style).
    private static func sanitized(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(max(value, -20), 130)
    }
}

/// Cumulative byte counters for one network sample: bytes received and
/// bytes sent across all non-loopback interfaces. Like CPU ticks, the
/// values only make sense as a delta against a previous sample.
struct NetworkBytes: Sendable, Equatable {
    var bytesIn: UInt64
    var bytesOut: UInt64
}

/// Transfer rate in bytes per second, averaged over the measured
/// interval between the two samples that produced the delta.
struct NetworkMetrics: Sendable, Equatable {
    var downloadBytesPerSecond: Double
    var uploadBytesPerSecond: Double
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

    /// Temperature rides a separate insert from `showTemperature`
    /// (plan Phase 3): `.all` must not include it, so the default set
    /// never samples the SMC.
    static let temperature = EnabledMetrics(rawValue: 1 << 3)

    /// The default set. Temperature stays out: it rides the separate
    /// `showTemperature` insert (tests pin this).
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
    var temperature: TemperatureMetrics?

    /// Equality covers the metric payload only. `timestamp` changes on
    /// every tick, so it must not take part: `.onChange(of:)` fires only
    /// when an enabled metric value actually changed (AC-7). A missing
    /// `temperature` term would freeze the menu bar on temperature-only
    /// changes (plan Phase 3).
    static func == (lhs: SystemSnapshot, rhs: SystemSnapshot) -> Bool {
        lhs.enabled == rhs.enabled
            && lhs.cpu == rhs.cpu
            && lhs.memory == rhs.memory
            && lhs.memoryPressure == rhs.memoryPressure
            && lhs.gpu == rhs.gpu
            && lhs.temperature == rhs.temperature
    }

    init(
        timestamp: Date = Date(),
        enabled: EnabledMetrics,
        cpu: CPUMetrics? = nil,
        memory: MemoryMetrics? = nil,
        memoryPressure: MemoryPressureMetrics? = nil,
        gpu: GPUMetrics? = nil,
        temperature: TemperatureMetrics? = nil
    ) {
        self.timestamp = timestamp
        self.enabled = enabled
        self.cpu = enabled.contains(.cpu) ? cpu : nil
        self.memory = enabled.contains(.memory) ? memory : nil
        self.memoryPressure = enabled.contains(.memory) ? memoryPressure : nil
        self.gpu = enabled.contains(.gpu) ? gpu : nil
        self.temperature = enabled.contains(.temperature) ? temperature : nil
    }
}

// MARK: - Top Processes (plan 2026-10-23-top-processes-breakdown)

/// One per-process row from one full process scan. Raw Mach values
/// only: no formatting, no ranking. A PID whose `proc_pid_rusage`
/// read failed (EPERM for other users' processes) is absent from
/// the scan result (T1, T6).
struct RawProcessSample: Sendable, Equatable {
    /// Process identifier.
    var pid: Int32
    /// `ri_user_time + ri_system_time` in Mach absolute time units.
    var cpuTicks: UInt64
    /// `ri_proc_start_abstime`: rejects a reused PID (T2).
    var startAbstime: UInt64
    /// `ri_proc_exit_abstime`: non-zero marks a zombie (T6 skip).
    var exitAbstime: UInt64
    /// `ri_phys_footprint` in bytes: Activity Monitor "Memory" semantics.
    var physFootprint: UInt64
    /// `ri_resident_size` in bytes: fallback when the footprint is 0 (T6).
    var residentSize: UInt64
}

/// Anchor for one PID's CPU delta (T2): the tick counter, the
/// process-start stamp, and the sampling instant captured at the
/// previous accepted sample.
struct ProcessTickAnchor: Sendable, Equatable {
    /// Mach tick counter (`ri_user_time + ri_system_time`) at the anchor.
    var cpuTicks: UInt64
    /// `ri_proc_start_abstime` at the anchor: a mismatch means the PID
    /// was recycled and the anchor is stale.
    var startAbstime: UInt64
    /// The instant this anchor was taken: the CPU fraction divides by
    /// the time from here to the current pass, never a hard-coded 1 s.
    var instant: ContinuousClock.Instant
}

/// One ranked row in a Top Processes list (plan §4.3).
struct ProcessMetricItem: Sendable, Equatable, Identifiable {
    /// Process identifier; also the list identity (`id`).
    var pid: Int32
    /// Resolved display name (T7).
    var name: String
    /// Display fraction, Activity Monitor style. CPU: percent-of-one-core in
    /// 0...9.999 (≥100% allowed on multi-core machines, R1). Memory: of total RAM.
    var fraction: Double
    /// Display value: "191.8%" for CPU, "6.8 GB" or "780 MB" for memory.
    var valueLabel: String

    var id: Int32 { pid }

    /// One CPU row's display fraction, percent-of-one-core (R1): the
    /// tick delta scaled through the Mach timebase is the work in
    /// nanoseconds; dividing by the elapsed nanoseconds yields
    /// core-seconds per second. There is no core-count divisor —
    /// Activity Monitor reports the same per-core scale, so a busy
    /// process can exceed 1.0 (191.8%). Clamps 0...9.999, the
    /// formatter's "999.9%" ceiling. The timebase is passed in and
    /// nothing global is queried, so tests run deterministic on any
    /// architecture (plan 2026-10-24 R1, U1).
    static func cpuDisplayFraction(
        deltaTicks: UInt64,
        elapsedSeconds: Double,
        nanosecondsPerTick: Double
    ) -> Double {
        let computed = Double(deltaTicks) * nanosecondsPerTick / (elapsedSeconds * 1e9)
        return min(max(computed, 0), 9.999)
    }
}

/// One process scan's output (T1): a single scan serves both the CPU
/// and the memory rankings.
struct ProcessSampleResult: Sendable, Equatable {
    /// Top processes by instantaneous CPU %, descending, at most 5.
    /// Empty on the anchoring scan: CPU needs two samples (R5).
    var topCPU: [ProcessMetricItem]
    /// Top processes by memory footprint, descending, at most 5.
    /// Populated on the first scan (R6, no delta needed).
    var topMemory: [ProcessMetricItem]
}

/// Which card's Top Processes list is expanded (R4). The accordion
/// allows one open list at a time.
enum ProcessCategory: Sendable, Equatable {
    case cpu
    case memory
}

/// Collapsed-disclosure cue from the parent metric's usage level
/// (plan §4.3): three dot colors, one per case.
enum ProcessCueState: Sendable, Equatable {
    case normal
    case warning
    case critical
}
