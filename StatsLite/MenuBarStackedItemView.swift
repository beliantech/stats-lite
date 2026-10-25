//
//  MenuBarStackedItemView.swift
//  StatsLite
//
//  Menu bar label as one stacked block per metric (blueprint): the
//  category label sits on line 1, the percent value on line 2, and
//  every standard block pins to MenuBarLayout.standardBlockWidth,
//  so block positions freeze across digit boundaries (plan
//  2026-10-25-menubar-item-gap-uniform-minimum, T2 S1). Values are
//  fixed 3-digit strings ("045%", "100%", "−−−%"), so the ink
//  gap between blocks stays uniform at MenuBarLayout.gap.
//  MenuBarLayout blockWidth remains the length budget summed by
//  MenuBarLayout.length, so the status item length never changes.
//  The root HStack centers the block group in the slot, so the
//  leftover width splits symmetrically around the group. The
//  network block is a dedicated two-line view: networkUpload dot
//  plus upload rate above networkDownload dot plus download rate,
//  pinned to MenuBarLayout.networkBlockWidth. Blocks
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
                } else if block.kind == .temp {
                    MenuBarTempBlockView(block: block)
                } else {
                    MenuBarBlockView(block: block)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
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

    /// Blocks for the enabled metrics in CPU, RAM, GPU, TEMP, NET
    /// order, from the latest snapshot values.
    private var blocks: [MenuBarBlock] {
        MenuBarBlockBuilder.blocks(
            showCPU: preferences.showCPU,
            showRAM: preferences.showRAM,
            showGPU: preferences.showGPU,
            showNetwork: preferences.showNetwork,
            showTemperature: preferences.showTemperature,
            cpuPercent: snapshot?.cpu?.totalUsage,
            pressurePercent: snapshot?.memoryPressure?.pressurePercentage,
            pressureState: snapshot?.memoryPressure?.state,
            gpuPercent: snapshot?.gpu?.deviceUtilization,
            temperature: snapshot?.temperature,
            downloadRate: monitor.latestNetwork?.downloadBytesPerSecond,
            uploadRate: monitor.latestNetwork?.uploadBytesPerSecond
        )
    }
}

/// One metric block: category label on line 1, value on line 2.
/// Width pins to MenuBarLayout.standardBlockWidth so block
/// positions freeze across value changes; value text is fixed
/// 3-digit, so the ink gap to the next block stays uniform (plan
/// 2026-10-25-menubar-item-gap-uniform-minimum, T2 S1). block.width
/// is only the length budget in MenuBarLayout.length, and the item
/// length never changes. Trailing alignment pins both lines flush
/// to the block right edge. Internal so redraw-churn tests can
/// walk its body tree.
struct MenuBarBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                if let dotState = block.dotState {
                    Circle()
                        .fill(dotState.levelColor)
                        .frame(width: 4, height: 4)
                        .offset(y: -0.5)
                }
                Text(block.label)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(height: MenuBarLayout.rowHeight)
            Text(block.valueText)
                .font(.system(size: 12, weight: .regular).monospacedDigit())
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .frame(height: MenuBarLayout.rowHeight)
                .offset(y: MenuBarLayout.valueYOffset)
        }
        .frame(width: MenuBarLayout.standardBlockWidth, alignment: .trailing)
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
/// line 1 carries a 5 pt red indicator dot (Color.networkUpload) and
/// the upload rate.
/// line 2 carries a 5 pt adaptive indicator dot
/// (Color.networkDownload: systemCyan in dark mode, systemBlue in
/// light) and the download rate.
/// Width pins to block.width (50 pt), so rate string changes never
/// resize the item (VAC-N1). Transitions stay discrete: no
/// .animation and no .contentTransition modifiers (VAC-9).
struct MenuBarNetworkBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Line 1: Upload rate
            HStack(alignment: .center, spacing: 0) {
                Circle()
                    .fill(Color.networkUpload)
                    .frame(width: CGFloat.networkDotSize, height: CGFloat.networkDotSize)

                Spacer(minLength: 1)

                Text(block.valueText)
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)

            // Line 2: Download rate
            HStack(alignment: .center, spacing: 0) {
                Circle()
                    .fill(Color.networkDownload)
                    .frame(width: CGFloat.networkDotSize, height: CGFloat.networkDotSize)

                Spacer(minLength: 1)

                Text(block.secondaryValueText ?? "-- KB/s")
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(secondaryValueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)
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

/// Dedicated two-line temperature monitor block:
/// line 1 displays label "C" in 8 pt regular secondary text plus
/// the CPU reading in 9 pt monospacedDigit text.
/// line 2 displays label "G" in 8 pt regular secondary text plus
/// the GPU reading in 9 pt monospacedDigit text.
/// Each row displays "--°" and tints tertiary when its subsystem is
/// unreadable — the block never hides per tick (VAC-4) and never
/// shows a fake 0°.
/// Width pins to block.width (MenuBarLayout.tempBlockWidth), so
/// value changes never resize the item (VAC-9).
/// Transitions stay discrete: no .animation and no
/// .contentTransition modifiers (VAC-5).
struct MenuBarTempBlockView: View {
    let block: MenuBarBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Line 1: CPU die temperature
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(block.label)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .offset(y: -0.5)

                Text(block.valueText)
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)

            // Line 2: GPU die temperature
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(block.secondaryLabel ?? "G")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .offset(y: -0.5)

                Text(block.secondaryValueText ?? "--°")
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(secondaryValueColor)
                    .lineLimit(1)
            }
            .frame(height: MenuBarLayout.rowHeight)
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
