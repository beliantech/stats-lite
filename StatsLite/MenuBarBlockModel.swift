//
//  MenuBarBlockModel.swift
//  StatsLite
//
//  Pure block model for the stacked menu bar label (plan
//  2026-10-15-menubar-stacked-fixed-width, Task 1). Each visible
//  metric renders as one block: category label on line 1, percent
//  value on line 2. Block widths are pinned to the widest content
//  ("100%"), so the menu bar item never resizes. MenuBarLayout
//  computes the total item length from the same constants.
//

import Foundation

/// Metric category a block represents.
enum MenuBarBlockKind: Equatable {
    case cpu
    case ram
    case gpu
}

/// One stacked menu bar block. The label is always present and the
/// struct carries no dot state: kind, label, value text, value tint,
/// and pinned width only.
struct MenuBarBlock: Equatable {
    var kind: MenuBarBlockKind
    var label: String
    var valueText: String
    var valueTint: MenuBarValueTint
    var width: CGFloat
}

/// Layout constants shared by the block builder, MenuBarLayout, and
/// the stacked views. Single source of truth for widths.
enum MenuBarLayout {
    /// Pinned width of every block. "100%" at the value font fits
    /// with clearance.
    static let blockWidth: CGFloat = 34
    /// Gap between adjacent blocks.
    static let gap: CGFloat = 4
    /// Outer padding: leading 2 pt plus trailing 2 pt.
    static let padding: CGFloat = 2

    /// Total menu bar item length for the enabled metrics. Counts
    /// blocks plus inter-block gaps plus outer padding. All metrics
    /// off leaves the padding alone (4 pt).
    static func length(
        showCPU: Bool,
        showRAM: Bool,
        showGPU: Bool
    ) -> CGFloat {
        let count =
            (showCPU ? 1 : 0) + (showRAM ? 1 : 0) + (showGPU ? 1 : 0)
        let blocksLength = CGFloat(count) * blockWidth
        let gapsLength = CGFloat(max(count - 1, 0)) * gap
        return 2 * padding + blocksLength + gapsLength
    }
}

/// Builds the visible blocks in CPU, RAM, GPU order. Nil and
/// non-finite values become "--%" with a tertiary tint.
/// Out-of-range values clamp through MetricFormatters.percent.
enum MenuBarBlockBuilder {

    static func blocks(
        showCPU: Bool,
        showRAM: Bool,
        showGPU: Bool,
        cpuPercent: Double?,
        usedPercent: Double?,
        gpuPercent: Double?
    ) -> [MenuBarBlock] {
        var blocks: [MenuBarBlock] = []

        if showCPU {
            blocks.append(
                MenuBarBlock(
                    kind: .cpu,
                    label: "CPU",
                    valueText: MetricFormatters.percent(cpuPercent),
                    valueTint: usageTint(cpuPercent),
                    width: MenuBarLayout.blockWidth
                )
            )
        }

        if showRAM {
            blocks.append(
                MenuBarBlock(
                    kind: .ram,
                    label: "RAM",
                    valueText: MetricFormatters.percent(usedPercent),
                    valueTint:
                        usedPercent == nil ? .tertiary : .primary,
                    width: MenuBarLayout.blockWidth
                )
            )
        }

        if showGPU {
            blocks.append(
                MenuBarBlock(
                    kind: .gpu,
                    label: "GPU",
                    valueText: MetricFormatters.percent(gpuPercent),
                    valueTint: usageTint(gpuPercent),
                    width: MenuBarLayout.blockWidth
                )
            )
        }

        return blocks
    }

    /// Warning tint on usage values: >= 95 % critical, >= 80 %
    /// warning, else primary. Unavailable values render tertiary.
    private static func usageTint(_ value: Double?) -> MenuBarValueTint {
        guard let value else { return .tertiary }
        if value >= 0.95 { return .critical }
        if value >= 0.80 { return .warning }
        return .primary
    }
}
