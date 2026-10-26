//
//  MetricFormatters.swift
//  StatsLite
//
//  Display strings for the menu bar and the popover.
//

import Foundation

enum MetricFormatters {

    /// Formats a fraction in 0...1 as an integer percent string.
    /// Clamps values to 0...0.99 so the display clips to "99%".
    /// Returns natural unpadded text ("0%", "5%", "45%", "99%").
    /// Missing or non-finite values return "--%" (plan
    /// 2026-10-25-menubar-item-gap-uniform-minimum, T3 Appendix C).
    static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--%" }
        let clamped = min(max(value, 0), 0.99)
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

    /// Formats a CPU process-row fraction in 0...9.999 as a
    /// one-decimal percent-of-one-core, Activity Monitor style:
    /// "191.8%", "999.9%". Returns "--%" for a missing or non-finite
    /// value, like `percentTenth`. Clamps out-of-range values to
    /// 0...9.999 first. Only CPU Top Processes rows use it; CPU
    /// Total and GPU keep `percentTenth`'s 0...1 whole-machine
    /// semantics (plan 2026-10-24 R1, U1b).
    static func processPercentTenth(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--%" }
        let clamped = min(max(value, 0), 9.999)
        return String(format: "%.1f%%", clamped * 100)
    }

    /// Formats a whole-degree temperature reading: "84°", "-5°",
    /// "100°". Returns "--°" for a missing or non-finite reading,
    /// like percent's "--%" placeholder: "nan°" or "inf°" in the
    /// menu bar is a display defect. The provider clamps readings to
    /// -20...130 °C; this formatter only rounds.
    static func degrees(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--°" }
        return "\(Int(value.rounded()))°"
    }

    /// Formats bytes as GB with one decimal: "9.9 GB". Uses binary GB
    /// (1024³) to match how macOS reports physical memory.
    static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }

    /// Formats a transfer rate in bytes per second:
    /// integer KB/s while the rounded value stays under 100 KB/s;
    /// one-decimal MB/s below 9.95 MB/s; integer MB/s while the
    /// rounded value stays under 100 MB/s; one-decimal GB/s below
    /// 9.95 GB/s; integer GB/s while the rounded value stays under
    /// 100 GB/s; clamps at 99 GB/s. Decimals drop once values reach
    /// double digits, and rates transition to the next unit at 100,
    /// so no output mantissa exceeds two digits (for example: 400
    /// KB/s becomes "0.4 MB/s"). Returns "-- KB/s" for a missing,
    /// negative, or non-finite value.
    static func networkRate(_ bytesPerSecond: Double?) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite, bytesPerSecond >= 0 else {
            return "-- KB/s"
        }
        let kb = bytesPerSecond / 1024.0
        if kb.rounded() < 100.0 {
            return "\(Int(kb.rounded())) KB/s"
        }
        let mb = kb / 1024.0
        if mb < 9.95 {
            return String(format: "%.1f MB/s", mb)
        }
        if mb.rounded() < 100.0 {
            return "\(Int(mb.rounded())) MB/s"
        }
        let gb = mb / 1024.0
        if gb < 9.95 {
            return String(format: "%.1f GB/s", gb)
        }
        if gb.rounded() < 100.0 {
            return "\(Int(gb.rounded())) GB/s"
        }
        return "99 GB/s"
    }

    /// Formats history window duration into a compact sparkline axis anchor.
    /// Seconds under 60 render with 's' (for example: "-30s").
    /// Durations of 60 seconds or more render with 'm' (for example: "-1m", "-2m", "-5m").
    static func historyDurationAxis(_ seconds: TimeInterval) -> String {
        // Deviation from Blueprint (reviewer finding 2026-10-17): guard non-finite
        // input. Int(NaN) / Int(infinity) traps at runtime. No visual change for
        // the five valid durations.
        let totalSeconds = seconds.isFinite ? max(Int(seconds), 0) : 0
        if totalSeconds < 60 {
            return "-\(totalSeconds)s"
        }
        let minutes = totalSeconds / 60
        return "-\(minutes)m"
    }
}
