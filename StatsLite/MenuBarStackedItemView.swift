//
//  MenuBarStackedItemView.swift
//  StatsLite
//
//  Menu bar label as one stacked block per metric (blueprint): the
//  category label sits on line 1, the percent value on line 2, and
//  every block pins its width to MenuBarLayout.blockWidth, so the
//  status item never resizes. The network block is a dedicated
//  two-line view: red dot plus upload rate above blue dot plus
//  download rate, pinned to MenuBarLayout.networkBlockWidth. Blocks
//  come from MenuBarBlockBuilder — the single source of truth for
//  text, tint, and width. The MEM block carries a 4 pt pressure dot
//  left of the label. No frame height: the controller centers the
//  hosting view inside the status button. No .animation and no
//  .contentTransition anywhere on the status item path: transitions
//  stay discrete so RenderBox never re-rasterizes glyphs between
//  ticks (AC-11).
//

import SwiftUI

/// Optional hooks for the StatusItemController: preference changes
/// drive updateItemLength() plus updateAccessibility(), snapshot
/// changes drive updateAccessibility(). nil keeps the view usable
/// standalone (previews).
struct MenuBarStackedItemView: View {
    let monitor: SystemMonitor
    let preferences: PreferencesStore
    var onPreferencesChange: (() -> Void)? = nil
    var onSnapshotChange: (() -> Void)? = nil

    private var snapshot: SystemSnapshot? { monitor.latestSnapshot }

    var body: some View {
        HStack(alignment: .center, spacing: MenuBarLayout.gap) {
            ForEach(blocks, id: \.kind) { block in
                if block.kind == .network {
                    MenuBarNetworkBlockView(block: block)
                } else {
                    MenuBarBlockView(block: block)
                }
            }
        }
        .padding(.horizontal, MenuBarLayout.padding)
        .accessibilityHidden(true)
        .onAppear { monitor.apply(preferences) }
        .onChange(of: preferences.enabledMetrics) {
            monitor.apply(preferences)
            onPreferencesChange?()
        }
        .onChange(of: preferences.refreshInterval) {
            monitor.apply(preferences)
            onPreferencesChange?()
        }
        .onChange(of: preferences.historyDuration) {
            monitor.apply(preferences)
            onPreferencesChange?()
        }
        .onChange(of: preferences.showNetwork) {
            // showNetwork lives outside enabledMetrics (D3), so this
            // is the only path that starts or stops the network loop
            // and resizes the status item on a network toggle (FM12).
            monitor.apply(preferences)
            onPreferencesChange?()
        }
        .onChange(of: monitor.latestSnapshot) {
            onSnapshotChange?()
        }
        .onChange(of: monitor.latestNetwork) {
            // latestNetwork ticks every second while latestSnapshot
            // ticks at refreshInterval, so this is the only path
            // that refreshes the VoiceOver label on network data
            // (F9).
            onSnapshotChange?()
        }
    }

    /// Blocks for the enabled metrics in CPU, RAM, GPU, NET order,
    /// from the latest snapshot values.
    private var blocks: [MenuBarBlock] {
        MenuBarBlockBuilder.blocks(
            showCPU: preferences.showCPU,
            showRAM: preferences.showRAM,
            showGPU: preferences.showGPU,
            showNetwork: preferences.showNetwork,
            cpuPercent: snapshot?.cpu?.totalUsage,
            pressurePercent: snapshot?.memoryPressure?.pressurePercentage,
            pressureState: snapshot?.memoryPressure?.state,
            gpuPercent: snapshot?.gpu?.deviceUtilization,
            downloadRate: monitor.latestNetwork?.downloadBytesPerSecond,
            uploadRate: monitor.latestNetwork?.uploadBytesPerSecond
        )
    }
}

/// One metric block: category label on line 1, value on line 2.
/// Width pins to block.width so text changes never resize the item.
/// Internal so redraw-churn tests can walk its body tree.
struct MenuBarBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .center, spacing: 1) {
            HStack(alignment: .center, spacing: 2) {
                if let dotState = block.dotState {
                    Circle()
                        .fill(dotState.levelColor)
                        .frame(width: 4, height: 4)
                        .offset(y: -0.5)
                }
                Text(block.label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            Text(block.valueText)
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .frame(width: block.width)
    }

    private var valueColor: Color {
        switch block.valueTint {
        case .primary: .primary
        case .tertiary: Color(nsColor: .tertiaryLabelColor)
        case .warning: Color(nsColor: .systemOrange)
        case .critical: Color(nsColor: .systemRed)
        }
    }
}

/// Dedicated two-line network speed monitor block:
/// line 1 carries a 6 pt red indicator dot and the upload rate.
/// line 2 carries a 6 pt blue indicator dot and the download rate.
/// Width pins to block.width (50 pt), so rate string changes never
/// resize the item (VAC-N1). Transitions stay discrete: no
/// .animation and no .contentTransition modifiers (VAC-9).
struct MenuBarNetworkBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Line 1: Upload rate
            HStack(alignment: .center, spacing: 0) {
                Circle()
                    .fill(Color(nsColor: .systemRed))
                    .frame(width: 6, height: 6)

                Spacer(minLength: 1)

                Text(block.valueText)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }

            // Line 2: Download rate
            HStack(alignment: .center, spacing: 0) {
                Circle()
                    .fill(Color(nsColor: .systemBlue))
                    .frame(width: 6, height: 6)

                Spacer(minLength: 1)

                Text(block.secondaryValueText ?? "-- KB/s")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(secondaryValueColor)
                    .lineLimit(1)
            }
        }
        .frame(width: block.width)
    }

    private var valueColor: Color {
        switch block.valueTint {
        case .primary, .warning, .critical:
            Color.primary
        case .tertiary:
            Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var secondaryValueColor: Color {
        switch block.secondaryValueTint ?? block.valueTint {
        case .primary, .warning, .critical:
            Color.primary
        case .tertiary:
            Color(nsColor: .tertiaryLabelColor)
        }
    }
}
