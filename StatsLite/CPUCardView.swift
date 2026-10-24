//
//  CPUCardView.swift
//  StatsLite
//
//  CPU card per the base blueprint: header with title and value,
//  38 pt sparkline, per-core disclosure with an optional
//  two-column core grid (+80 pt).
//

import SwiftUI

struct CPUCardView: View {
    let monitor: SystemMonitor
    let preferences: PreferencesStore
    @Binding var coresExpanded: Bool
    @Binding var expandedProcessCategory: ProcessCategory?

    private var cpu: CPUMetrics? { monitor.latestSnapshot?.cpu }
    private var coreCount: Int { cpu?.perCore.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("CPU Total")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(MetricFormatters.percentTenth(cpu?.totalUsage))
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(cpu == nil ? Color(nsColor: .tertiaryLabelColor) : Color.primary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cpuSummary)

            if cpu == nil {
                Text("Waiting for first sample")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            SparklineView(
                values: monitor.cpuHistory.values,
                tintColor: sparkTint,
                capacity: monitor.sparklineCapacity
            )
            .equatable()

            SparklineTimeAxisView(duration: monitor.historyDuration).equatable()

            if preferences.showCoreBreakdown {
                disclosure
            }

            if coresExpanded {
                coreGrid
                    .transition(.opacity)
            }

            TopProcessesDisclosureButton(
                isExpanded: expandedProcessCategory == .cpu,
                usageState: cpuCueState,
                metricTitle: "CPU Total",
                action: {
                    PopoverContentView.toggleProcessCategory($expandedProcessCategory, to: .cpu)
                }
            )

            if expandedProcessCategory == .cpu {
                TopProcessesSectionView(
                    processes: monitor.topCPUProcesses,
                    tintColor: processGaugeTint,
                    isLoading: monitor.isSamplingProcesses && monitor.topCPUProcesses.isEmpty,
                    gaugeBasis: .maxNormalized,
                    showsHelperGapCaption: true
                )
                .transition(.opacity)
            }
        }
        .metricCardStyle()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Disclosure

    private var disclosure: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                coresExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: coresExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text("Cores Breakdown (\(coreCount) Cores)")
                    .font(.system(size: 10, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var coreGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 4
        ) {
            ForEach(Array((cpu?.perCore ?? []).enumerated()), id: \.offset) { index, value in
                coreRow(index: index, value: value)
            }
        }
    }

    private func coreRow(index: Int, value: Double) -> some View {
        HStack(spacing: 4) {
            Text("Core \(index + 1)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(nsColor: .separatorColor).opacity(0.4))
                    Capsule()
                        .fill(coreColor(value))
                        .frame(width: max(proxy.size.width * value, 2))
                }
            }
            .frame(height: 5)
            Text(MetricFormatters.percent(value))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)
        }
    }

    // MARK: - Derived state

    /// The disclosure cue from the same window average that tints
    /// the sparkline: at or above 80 % warning, at or above 95 %
    /// critical (VAC-4; boundaries match coreColor exactly).
    private var cpuCueState: ProcessCueState {
        let values = monitor.cpuHistory.values
        guard !values.isEmpty else { return .normal }
        let average = values.reduce(0, +) / Double(values.count)
        if average >= 0.95 { return .critical }
        if average >= 0.80 { return .warning }
        return .normal
    }

    /// Process gauge tint per state matrix: card tint normally,
    /// systemOrange at warning, systemRed at critical (§4.4).
    private var processGaugeTint: Color {
        switch cpuCueState {
        case .normal: .blue
        case .warning: Color(nsColor: .systemOrange)
        case .critical: Color(nsColor: .systemRed)
        }
    }

    /// Blue normally, amber when the window average is at or above
    /// 80 % (the coreColor orange boundary), per the base blueprint
    /// state matrix.
    private var sparkTint: Color {
        let values = monitor.cpuHistory.values
        guard !values.isEmpty else { return .blue }
        let average = values.reduce(0, +) / Double(values.count)
        return average >= 0.80 ? .orange : .blue
    }

    private func coreColor(_ value: Double) -> Color {
        if value >= 0.95 { return .red }
        if value >= 0.80 { return .orange }
        return .blue
    }

    private var cpuSummary: String {
        guard let cpu else { return "CPU usage unavailable. Waiting for first sample." }
        let percent = Int((cpu.totalUsage * 100).rounded())
        return "CPU usage is \(percent) percent."
    }
}
