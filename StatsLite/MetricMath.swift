//
//  MetricMath.swift
//  StatsLite
//
//  Pure math. No sysctl, no IOKit, no state. Every function is
//  deterministic for a given input.
//

enum MetricMath {

    /// CPU usage between two consecutive tick samples, 0...1.
    ///
    /// Returns 0 when `previous` is nil (first sample), when the total
    /// delta is 0 (rapid restart produced identical counters), and when
    /// the counters rolled over (`current.total < previous.total`).
    static func computePercentages(
        previous: CoreTickSample?,
        current: CoreTickSample
    ) -> Double {
        guard let previous else { return 0 }
        let totalDelta =
            Int64(clamping: current.total) - Int64(clamping: previous.total)
        // Covers both zero delta and counter rollover.
        guard totalDelta > 0 else { return 0 }
        let busyDelta =
            Int64(clamping: current.busy) - Int64(clamping: previous.busy)
        let fraction = Double(busyDelta) / Double(totalDelta)
        return min(max(fraction, 0), 1)
    }

    /// Memory pressure figure, 0...1.
    ///
    /// The kernel availability percent comes from
    /// `kern.memorystatus_level`; pressure = (100 - availability) / 100.
    /// When that read failed (`availabilityPercent` is nil), use the fixed
    /// value for the level: normal 0.15, warning 0.65, critical 0.90.
    /// An unknown level returns 0.
    static func computePressurePercentage(
        state: MemoryPressureState,
        availabilityPercent: Double?
    ) -> Double {
        guard state != .unknown else { return 0 }
        guard let availabilityPercent else {
            switch state {
            case .normal: return 0.15
            case .warning: return 0.65
            case .critical: return 0.90
            case .unknown: return 0
            }
        }
        let pressure = (100 - availabilityPercent) / 100
        return min(max(pressure, 0), 1)
    }
}
