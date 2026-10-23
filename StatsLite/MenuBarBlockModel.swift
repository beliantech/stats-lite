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

/// Tint of a block value. Maps to Color in the stacked views.
enum MenuBarValueTint: Equatable {
    /// Normal usage and every MEM pressure state. Values render primary.
    case primary
    /// Unavailable (nil) value. Renders tertiary.
    case tertiary
    /// Usage at or above 80 %. Renders orange.
    case warning
    /// Usage at or above 95 %. Renders red.
    case critical
}

/// Metric category a block represents.
enum MenuBarBlockKind: Hashable {
    case cpu
    case ram
    case gpu
    case network
}

/// One stacked menu bar block. dotState carries the memory pressure
/// state for the MEM block, so its dot always renders. CPU and GPU
/// blocks keep dotState nil. The network block carries a second line:
/// secondaryValueText holds the download rate below the upload rate.
struct MenuBarBlock: Equatable {
    var kind: MenuBarBlockKind
    var label: String
    var dotState: MemoryPressureState?
    var valueText: String
    var valueTint: MenuBarValueTint
    var width: CGFloat
    var secondaryValueText: String? = nil
    var secondaryValueTint: MenuBarValueTint? = nil
}

/// Layout constants shared by the block builder, MenuBarLayout, and
/// the stacked views. Single source of truth for widths.
enum MenuBarLayout {
    /// Pinned width of every block. "100%" at 12 pt regular mono (33.78 pt)
    /// fits with 2.61 pt clearance per side, satisfying the >= 2.5 pt rule.
    static let blockWidth: CGFloat = 39
    /// Pinned width of the two-line network block. Fits the widest
    /// truncated rate string "999 MB/s" (42.91 pt) plus the 5 pt dot
    /// with 2.89 pt clearance (appendix B §1).
    static let networkBlockWidth: CGFloat = 50
    /// Pinned width of the two-line temperature block. Fits the
    /// widest row "GPU 100°" (44.19 pt at 9 pt regular mono) with
    /// 2.90 pt clearance per side, satisfying the >= 2.5 pt rule.
    /// Row text never resizes the block (VAC-9, never-resize
    /// invariant).
    static let tempBlockWidth: CGFloat = 50
    /// Pinned height of each line within a block. Two 11 pt rows yield
    /// a 22 pt block height that matches NSStatusBar.system.thickness
    /// and aligns line 1 and line 2 across standard and network blocks.
    static let rowHeight: CGFloat = 11
    /// Vertical shift applied to the value line in MenuBarBlockView.
    /// -1 pt opens the menu bar bottom gap from 0.96 pt to 1.96 pt
    /// and tightens the label-to-value gap (plan
    /// 2026-10-20-menu-bar-value-vertical-shift).
    static let valueYOffset: CGFloat = -1
    /// Gap between adjacent blocks.
    static let gap: CGFloat = 4
    /// Outer padding: leading 2 pt plus trailing 2 pt.
    static let padding: CGFloat = 2

    /// Total menu bar item length for the enabled metrics. Counts
    /// blocks plus inter-block gaps plus outer padding. The network
    /// block adds its own width. All metrics off leaves the padding
    /// alone (4 pt).
    static func length(
        showCPU: Bool,
        showRAM: Bool,
        showGPU: Bool,
        showNetwork: Bool = false
    ) -> CGFloat {
        let metricCount =
            (showCPU ? 1 : 0) + (showRAM ? 1 : 0) + (showGPU ? 1 : 0)
        let totalBlocks = metricCount + (showNetwork ? 1 : 0)
        let metricLength = CGFloat(metricCount) * blockWidth
        let networkLength = showNetwork ? networkBlockWidth : 0
        let gapsLength = CGFloat(max(totalBlocks - 1, 0)) * gap
        return 2 * padding + metricLength + networkLength + gapsLength
    }
}

/// Builds the visible blocks in CPU, MEM, GPU, NET order. Nil and
/// non-finite values become "--%" or "-- KB/s" with a tertiary tint.
/// Out-of-range values clamp through MetricFormatters.
enum MenuBarBlockBuilder {

    static func blocks(
        showCPU: Bool,
        showRAM: Bool,
        showGPU: Bool,
        showNetwork: Bool = false,
        cpuPercent: Double?,
        pressurePercent: Double?,
        pressureState: MemoryPressureState?,
        gpuPercent: Double?,
        downloadRate: Double? = nil,
        uploadRate: Double? = nil
    ) -> [MenuBarBlock] {
        var blocks: [MenuBarBlock] = []

        if showCPU {
            blocks.append(
                MenuBarBlock(
                    kind: .cpu,
                    label: "CPU",
                    dotState: nil,
                    valueText: MetricFormatters.percent(cpuPercent),
                    valueTint: usageTint(cpuPercent),
                    width: MenuBarLayout.blockWidth
                )
            )
        }

        if showRAM {
            let resolvedState = pressurePercent.map {
                (pressureState ?? .unknown).displayState(pressure: $0)
            } ?? .unknown
            blocks.append(
                MenuBarBlock(
                    kind: .ram,
                    label: "MEM",
                    dotState: resolvedState,
                    valueText: MetricFormatters.percent(pressurePercent),
                    // The number keeps the menu bar text color in
                    // every pressure state. The dot owns the state
                    // colors. Only a missing percent renders tertiary.
                    valueTint: pressurePercent == nil ? .tertiary : .primary,
                    width: MenuBarLayout.blockWidth
                )
            )
        }

        if showGPU {
            blocks.append(
                MenuBarBlock(
                    kind: .gpu,
                    label: "GPU",
                    dotState: nil,
                    valueText: MetricFormatters.percent(gpuPercent),
                    valueTint: usageTint(gpuPercent),
                    width: MenuBarLayout.blockWidth
                )
            )
        }

        if showNetwork {
            // The network block owns its red upload dot and blue
            // download dot in the view, so dotState stays nil and the
            // label stays empty. Only a missing rate renders tertiary.
            blocks.append(
                MenuBarBlock(
                    kind: .network,
                    label: "",
                    dotState: nil,
                    valueText: MetricFormatters.networkRate(uploadRate),
                    valueTint: uploadRate == nil ? .tertiary : .primary,
                    width: MenuBarLayout.networkBlockWidth,
                    secondaryValueText: MetricFormatters.networkRate(downloadRate),
                    secondaryValueTint: downloadRate == nil ? .tertiary : .primary
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
