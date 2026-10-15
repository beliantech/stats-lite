//
//  MetricFormatters.swift
//  StatsLite
//
//  Display strings for the menu bar and the popover.
//

import Foundation

enum MetricFormatters {

    /// Formats a fraction in 0...1 as an integer percent: "14%", "100%".
    /// Returns "--%" for a missing or non-finite value. Clamps out-of-range
    /// values to 0...1 first.
    static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--%" }
        let clamped = min(max(value, 0), 1)
        return "\(Int((clamped * 100).rounded()))%"
    }

    /// Formats a fraction in 0...1 as one-decimal percent: "24.0%".
    /// Returns "--%" for a missing or non-finite value. Clamps
    /// out-of-range values to 0...1 first. Popover card values use it.
    static func percentTenth(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--%" }
        let clamped = min(max(value, 0), 1)
        return String(format: "%.1f%%", clamped * 100)
    }

    /// Formats bytes as GB with one decimal: "9.9 GB". Uses binary GB
    /// (1024³) to match how macOS reports physical memory.
    static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }
}
