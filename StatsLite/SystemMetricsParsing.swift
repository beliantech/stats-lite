//
//  SystemMetricsParsing.swift
//  StatsLite
//
//  Pure mapping from raw kernel values to domain types. No sysctl and
//  no IOKit calls here, so every mapping rule stays unit testable.
//

import Foundation

enum SystemMetricsParsing {

    /// Maps raw sysctl reads to pressure metrics.
    ///
    /// - Parameters:
    ///   - rawLevel: `kern.memorystatus_vm_pressure_level` (1 normal,
    ///     2 warning, 4 critical). `nil` when the read failed. Unknown
    ///     values map to `.unknown`.
    ///   - availabilityLevel: `kern.memorystatus_level`, percent free
    ///     (0...100). `nil` when the read failed. A failed read falls
    ///     back to the fixed per-level value inside
    ///     `MemoryPressureMetrics`.
    static func pressureMetrics(
        rawLevel: Int32?,
        availabilityLevel: Int32?
    ) -> MemoryPressureMetrics {
        MemoryPressureMetrics(
            state: rawLevel.map { MemoryPressureState(rawLevel: Int($0)) } ?? .unknown,
            availabilityPercent: availabilityLevel.map(Double.init)
        )
    }

    /// Averages `PerformanceStatistics` device reports into one
    /// `GPUMetrics` value.
    ///
    /// Each element is one device's `PerformanceStatistics` dictionary.
    /// The `"Device Utilization %"` key is an `Int` percent (0...100).
    /// The average runs over the reports that carry the key, and the
    /// result is clamped to 0...1 by `GPUMetrics`. Returns `nil` when no
    /// report carries the device key (no GPU, or unsupported hardware).
    /// Renderer and tiler keys are optional and average the same way.
    static func gpuMetrics(fromStatistics statistics: [[String: Any]]) -> GPUMetrics? {
        let devices = statistics.compactMap { $0["Device Utilization %"] as? Int }
        guard !devices.isEmpty else { return nil }

        let renderers = statistics.compactMap { $0["Renderer Utilization %"] as? Int }
        let tilers = statistics.compactMap { $0["Tiler Utilization %"] as? Int }

        return GPUMetrics(
            deviceUtilization: averageFraction(of: devices),
            rendererUtilization: renderers.isEmpty ? nil : averageFraction(of: renderers),
            tilerUtilization: tilers.isEmpty ? nil : averageFraction(of: tilers)
        )
    }

    /// Mean of percent values (0...100) as a fraction. The sum runs in
    /// `Double`, so a corrupt value cannot overflow the accumulator.
    private static func averageFraction(of percents: [Int]) -> Double {
        let total = percents.reduce(0.0) { $0 + Double($1) }
        return total / Double(percents.count) / 100.0
    }
}
