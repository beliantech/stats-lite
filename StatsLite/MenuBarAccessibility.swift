//
//  MenuBarAccessibility.swift
//  StatsLite
//
//  Pure builder for the composite VoiceOver label of the menu bar
//  item. Moved verbatim out of MenuBarItemView when the single-Text
//  label path was retired (plan 2026-10-15-menubar-stacked-fixed-
//  width, Task 3). The AppKit status button owns the VoiceOver label.
//

import Foundation

/// Pure builder for the composite VoiceOver label of the menu bar item.
enum MenuBarAccessibility {
    static func compositeLabel(
        showCPU: Bool,
        showRAM: Bool,
        showGPU: Bool,
        showNetwork: Bool = false,
        cpuPercent: Double?,
        pressurePercent: Double?,
        pressure: MemoryPressureState,
        gpuPercent: Double?,
        downloadRate: Double? = nil,
        uploadRate: Double? = nil
    ) -> String {
        var parts: [String] = []
        if showCPU {
            if let cpuPercent {
                parts.append("CPU \(wholePercent(cpuPercent)) percent")
            } else {
                parts.append("CPU unavailable")
            }
        }
        if showRAM {
            if let pressurePercent {
                parts.append(
                    "Memory Pressure \(pressure.displayName) at \(wholePercent(pressurePercent)) percent"
                )
            } else {
                parts.append("Memory Pressure unavailable")
            }
        }
        if showGPU {
            parts.append(gpuPercent.map { "GPU \(wholePercent($0)) percent" } ?? "GPU unavailable")
        }
        if showNetwork {
            // latestNetwork is one optional pair: both rates arrive
            // together or the block reads "unavailable".
            if let downloadRate, let uploadRate {
                parts.append(
                    "Network Download \(MetricFormatters.networkRate(downloadRate)), "
                        + "Upload \(MetricFormatters.networkRate(uploadRate))"
                )
            } else {
                parts.append("Network unavailable")
            }
        }
        return "Stats Lite: " + parts.joined(separator: ", ")
    }

    private static func wholePercent(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }
}
