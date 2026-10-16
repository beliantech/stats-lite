//
//  SystemMetricsParsing.swift
//  StatsLite
//
//  Pure mapping from raw kernel values to domain types. No sysctl and
//  no IOKit calls here, so every mapping rule stays unit testable.
//

import Foundation

/// One interface row from the getifaddrs walk, mapped by the live
/// provider. The byte counters come from `if_data` and stay optional
/// because not every interface family carries them.
struct NetworkInterfaceRow: Sendable, Equatable {
    var isLoopback: Bool
    var bytesIn: Int64?
    var bytesOut: Int64?
}

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

    // MARK: - Network interface rows (loopback exclusion, F4)

    /// Sums the non-loopback byte counters into `NetworkBytes`.
    /// Returns `nil` when the row list is empty, when every row is
    /// loopback, when any non-loopback row lacks a counter, when any
    /// counter is negative, or when the sum overflows UInt64. The
    /// sum runs in unsigned 64-bit, so two `Int64.max` rows do not
    /// trap.
    static func networkBytes(from rows: [NetworkInterfaceRow]) -> NetworkBytes? {
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var counted = 0

        for row in rows where !row.isLoopback {
            guard let rowIn = row.bytesIn, let rowOut = row.bytesOut,
                  rowIn >= 0, rowOut >= 0
            else { return nil }

            let (sumIn, overflowIn) = bytesIn.addingReportingOverflow(UInt64(rowIn))
            let (sumOut, overflowOut) = bytesOut.addingReportingOverflow(UInt64(rowOut))
            guard !overflowIn, !overflowOut else { return nil }

            bytesIn = sumIn
            bytesOut = sumOut
            counted += 1
        }

        guard counted > 0 else { return nil }
        return NetworkBytes(bytesIn: bytesIn, bytesOut: bytesOut)
    }
}
