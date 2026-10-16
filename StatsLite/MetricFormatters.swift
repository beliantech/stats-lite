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

    /// Formats a transfer rate in bytes per second (VAC-N3, F11):
    /// integer KB/s while the rounded value stays under 1000 KB/s;
    /// one-decimal MB/s below 9.95 MB/s; integer MB/s while the
    /// rounded value stays under 1000 MB/s; one-decimal GB/s below
    /// 9.95 GB/s; integer GB/s at 9.95 GB/s and above. Decimals drop
    /// once values reach double digits, so no output mantissa exceeds
    /// three characters. Returns "-- KB/s" for a missing, negative,
    /// or non-finite value.
    static func networkRate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
            return "-- KB/s"
        }
        let kb = bytesPerSecond / 1024.0
        if kb.rounded() < 1000.0 {
            return "\(Int(kb.rounded())) KB/s"
        }
        let mb = kb / 1024.0
        if mb < 9.95 {
            return String(format: "%.1f MB/s", mb)
        }
        if mb.rounded() < 1000.0 {
            return "\(Int(mb.rounded())) MB/s"
        }
        let gb = mb / 1024.0
        if gb < 9.95 {
            return String(format: "%.1f GB/s", gb)
        }
        return "\(Int(gb.rounded())) GB/s"
    }
}
