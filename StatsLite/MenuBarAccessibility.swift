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
        cpuPercent: Double,
        usedPercent: Double,
        pressure: MemoryPressureState,
        gpuPercent: Double?
    ) -> String {
        var parts: [String] = []
        if showCPU {
            parts.append("CPU \(wholePercent(cpuPercent)) percent")
        }
        if showRAM {
            parts.append(
                "Memory Pressure \(pressure.displayName) with \(wholePercent(usedPercent)) percent used"
            )
        }
        if showGPU {
            parts.append(gpuPercent.map { "GPU \(wholePercent($0)) percent" } ?? "GPU unavailable")
        }
        return "Stats Lite: " + parts.joined(separator: ", ")
    }

    private static func wholePercent(_ value: Double) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }
}
