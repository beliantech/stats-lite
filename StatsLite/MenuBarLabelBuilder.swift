//
//  MenuBarLabelBuilder.swift
//  StatsLite
//
//  Pure run builder for the single-Text menu bar label (blueprint
//  Path A). MenuBarExtra extracts only the first Text from its label
//  closure into the NSStatusBarButton title, so the whole label must
//  be one Text with attributed runs. This builder returns plain,
//  testable runs; MenuBarItemView maps each run style to a SwiftUI
//  font and color.
//

import Foundation

/// Tint of a usage value run. Maps to Color in MenuBarItemView.
enum MenuBarValueTint: Equatable {
    /// Normal usage. Values render primary.
    case primary
    /// Unavailable (nil) value. Renders tertiary.
    case tertiary
    /// Usage at or above 80 %. Renders orange.
    case warning
    /// Usage at or above 95 %. Renders red.
    case critical
}

/// How MenuBarItemView renders one run of the label text.
enum MenuBarRunStyle: Equatable {
    /// Category word: "CPU", "RAM", "GPU".
    case category
    /// A percent value, tinted by usage level.
    case value(MenuBarValueTint)
    /// The RAM pressure dot (U+25CF), tinted by pressure level.
    case ramDot(MemoryPressureState)
    /// The " · " gap between adjacent active slots.
    case separator
}

/// One contiguous run of label text with its render style.
struct MenuBarLabelRun: Equatable {
    var text: String
    var style: MenuBarRunStyle
}

/// Snapshot values and toggles that drive the label.
struct MenuBarLabelInput: Equatable {
    var showCPU: Bool
    var showRAM: Bool
    var showGPU: Bool
    var showLabels: Bool
    var cpuPercent: Double?
    var usedPercent: Double?
    var pressure: MemoryPressureState
    var gpuPercent: Double?
}

enum MenuBarLabelBuilder {

    /// Builds the run list for the label. Active slots appear in
    /// CPU, RAM, GPU order. A " · " separator run appears only
    /// between adjacent active slots. Nil values become "--%"
    /// with a tertiary tint. Out-of-range values clamp via
    /// MetricFormatters.percent.
    static func runs(_ input: MenuBarLabelInput) -> [MenuBarLabelRun] {
        var runs: [MenuBarLabelRun] = []

        func appendSeparator() {
            if !runs.isEmpty {
                runs.append(MenuBarLabelRun(text: " · ", style: .separator))
            }
        }

        if input.showCPU {
            appendSeparator()
            if input.showLabels {
                runs.append(MenuBarLabelRun(text: "CPU ", style: .category))
            }
            runs.append(
                MenuBarLabelRun(
                    text: MetricFormatters.percent(input.cpuPercent),
                    style: .value(usageTint(input.cpuPercent))
                )
            )
        }

        if input.showRAM {
            appendSeparator()
            if input.showLabels {
                runs.append(MenuBarLabelRun(text: "RAM ", style: .category))
            }
            runs.append(
                MenuBarLabelRun(text: "● ", style: .ramDot(input.pressure))
            )
            runs.append(
                MenuBarLabelRun(
                    text: MetricFormatters.percent(input.usedPercent),
                    style: .value(input.usedPercent == nil ? .tertiary : .primary)
                )
            )
        }

        if input.showGPU {
            appendSeparator()
            if input.showLabels {
                runs.append(MenuBarLabelRun(text: "GPU ", style: .category))
            }
            runs.append(
                MenuBarLabelRun(
                    text: MetricFormatters.percent(input.gpuPercent),
                    style: .value(usageTint(input.gpuPercent))
                )
            )
        }

        return runs
    }

    /// Plain string form of the label, for tests and previews.
    static func plainText(_ input: MenuBarLabelInput) -> String {
        runs(input).map(\.text).joined()
    }

    /// Warning tint on usage values. Unavailable numerals render
    /// tertiary, per extension §2. RAM used % stays primary: the dot
    /// carries the RAM health signal.
    private static func usageTint(_ value: Double?) -> MenuBarValueTint {
        guard let value else { return .tertiary }
        if value >= 0.95 { return .critical }
        if value >= 0.80 { return .warning }
        return .primary
    }
}
