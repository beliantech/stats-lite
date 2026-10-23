//
//  MemoryPressureCardView.swift
//  StatsLite
//
//  Memory Pressure card per extension blueprint §2: header row with
//  capsule badge, 8 pt pressure gauge (VAC-21), 38 pt sparkline tinted
//  by level, Used line, 6 pt composition bar in a 4 pt rounded
//  container, and the breakdown line. Occupancy is always labeled
//  "Used"; the gauge and badge show kernel pressure.
//

import SwiftUI

struct MemoryPressureCardView: View {
    let monitor: SystemMonitor
    @Binding var expandedProcessCategory: ProcessCategory?

    private var memory: MemoryMetrics? { monitor.latestSnapshot?.memory }
    private var pressure: MemoryPressureMetrics? { monitor.latestSnapshot?.memoryPressure }

    private var state: MemoryPressureState {
        (pressure?.state ?? .unknown)
            .displayState(pressure: pressure?.pressurePercentage ?? 0)
    }

    private var fraction: Double { pressure?.pressurePercentage ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Memory Pressure")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                badge
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)

            gaugeBar
                .accessibilityHidden(true)

            SparklineView(
                values: monitor.memoryPressureHistory.values,
                tintColor: state.levelColor,
                capacity: monitor.sparklineCapacity
            )
            .equatable()

            SparklineTimeAxisView(duration: monitor.historyDuration).equatable()

            Text(usedLine)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)

            compositionBar
                .accessibilityHidden(true)

            Text(breakdownLine)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            TopProcessesDisclosureButton(
                isExpanded: expandedProcessCategory == .memory,
                usageState: processCueState,
                metricTitle: "Memory",
                action: {
                    PopoverContentView.toggleProcessCategory($expandedProcessCategory, to: .memory)
                }
            )

            if expandedProcessCategory == .memory {
                TopProcessesSectionView(
                    processes: monitor.topMemoryProcesses,
                    tintColor: processGaugeTint,
                    isLoading: monitor.isSamplingProcesses && monitor.topMemoryProcesses.isEmpty
                )
                .transition(.opacity)
            }
        }
        .metricCardStyle()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Badge (VAC-20)

    private var badge: some View {
        Text(state.displayName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(state.levelColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(state.levelColor.opacity(0.15)))
            .overlay(Capsule().stroke(state.levelColor.opacity(0.3), lineWidth: 0.5))
    }

    // MARK: - Pressure gauge (VAC-21): 8 pt bar, continuous 3 pt radius

    private var gaugeBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color(nsColor: .separatorColor).opacity(0.2))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(state.levelColor)
                    .frame(width: max(proxy.size.width * fraction, 0))
            }
        }
        .frame(height: 8)
    }

    // MARK: - Composition bar (VAC-8): App blue, Wired purple,
    // Compressed orange, Free quaternary, 6 pt in a 4 pt container.

    private var compositionBar: some View {
        GeometryReader { proxy in
            let total = max(Double(memory?.totalBytes ?? 0), 1)
            let width = proxy.size.width
            HStack(spacing: 1) {
                segment(.blue, width: width * Double(memory?.appMemoryBytes ?? 0) / total)
                segment(.purple, width: width * Double(memory?.wiredBytes ?? 0) / total)
                segment(.orange, width: width * Double(memory?.compressedBytes ?? 0) / total)
                Rectangle()
                    .fill(Color(nsColor: .quaternaryLabelColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(height: 6)
    }

    private func segment(_ color: Color, width: Double) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(width, 0))
    }

    // MARK: - Lines

    /// The disclosure cue from the display state (§4.4): unknown
    /// pressure maps to normal.
    private var processCueState: ProcessCueState {
        switch state {
        case .normal: .normal
        case .warning: .warning
        case .critical: .critical
        case .unknown: .normal
        }
    }

    /// Process gauge tint per state matrix: the card tint normally,
    /// systemOrange at warning, systemRed at critical (§4.4).
    private var processGaugeTint: Color {
        switch processCueState {
        case .normal: state.levelColor
        case .warning: Color(nsColor: .systemOrange)
        case .critical: Color(nsColor: .systemRed)
        }
    }

    private var usedLine: String {
        guard let memory else { return "Used: --% (-- / -- GB)" }
        let percent = Int((memory.usedPercentage * 100).rounded())
        let used = Double(memory.usedBytes) / 1_073_741_824
        let total = Double(memory.totalBytes) / 1_073_741_824
        return String(format: "Used: %d%% (%.1f / %.1f GB)", percent, used, total)
    }

    private var breakdownLine: String {
        let app = Double(memory?.appMemoryBytes ?? 0) / 1_073_741_824
        let wired = Double(memory?.wiredBytes ?? 0) / 1_073_741_824
        let compressed = Double(memory?.compressedBytes ?? 0) / 1_073_741_824
        return String(format: "App: %.1fG · Wired: %.1fG · Comp: %.1fG", app, wired, compressed)
    }

    private var summary: String {
        guard let memory else { return "Memory usage unavailable. Waiting for first sample." }
        let used = Double(memory.usedBytes) / 1_073_741_824
        let total = Double(memory.totalBytes) / 1_073_741_824
        let app = Double(memory.appMemoryBytes) / 1_073_741_824
        let wired = Double(memory.wiredBytes) / 1_073_741_824
        let compressed = Double(memory.compressedBytes) / 1_073_741_824
        let pressurePercent = Int((fraction * 100).rounded())
        return String(
            format: "Memory usage is %.1f gigabytes of %.1f gigabytes. Memory pressure is %@ at %d percent. App memory %.1f gigabytes. Wired memory %.1f gigabytes. Compressed memory %.1f gigabytes.",
            used,
            total,
            state.displayName,
            pressurePercent,
            app,
            wired,
            compressed
        )
    }
}
