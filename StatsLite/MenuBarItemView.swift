//
//  MenuBarItemView.swift
//  StatsLite
//
//  3-slot menu bar label. Only enabled slots render. Per COMB width
//  table: 4 pt container padding, 14 pt per separator, monospaced
//  digits, fixedSize, one line. The RAM slot is a 6 pt pressure dot
//  plus used percent. GPU shows --% when the sample is nil.
//

import SwiftUI

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

struct MenuBarItemView: View {
    let monitor: SystemMonitor
    let preferences: PreferencesStore

    private var snapshot: SystemSnapshot? { monitor.latestSnapshot }

    var body: some View {
        HStack(spacing: 4) {
            if preferences.showCPU {
                cpuSlot
                if preferences.showRAM || preferences.showGPU {
                    separator
                }
            }
            if preferences.showRAM {
                ramSlot
                if preferences.showGPU {
                    separator
                }
            }
            if preferences.showGPU {
                gpuSlot
            }
        }
        .padding(.horizontal, 4)
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(compositeLabel)
        .onAppear { monitor.apply(preferences) }
        .onChange(of: preferences.enabledMetrics) { monitor.apply(preferences) }
        .onChange(of: preferences.refreshInterval) { monitor.apply(preferences) }
        .onChange(of: preferences.historyDuration) { monitor.apply(preferences) }
    }

    // MARK: - Slots

    private var cpuSlot: some View {
        HStack(spacing: 2) {
            if preferences.showLabels {
                categoryLabel("CPU")
            }
            let value = snapshot?.cpu?.totalUsage
            valueText(MetricFormatters.percent(value), color: usageColor(value))
        }
    }

    private var ramSlot: some View {
        HStack(spacing: 3) {
            if preferences.showLabels {
                categoryLabel("RAM")
            }
            Circle()
                .fill(pressureState.levelColor)
                .frame(width: 6, height: 6)
                .help("Memory Pressure: \(pressureState.displayName)")
                .accessibilityLabel("Memory pressure is \(pressureState.displayName.lowercased())")
            let used = snapshot?.memory?.usedPercentage
            valueText(MetricFormatters.percent(used), color: used == nil ? tertiaryLabel : .primary)
        }
    }

    private var gpuSlot: some View {
        HStack(spacing: 2) {
            if preferences.showLabels {
                categoryLabel("GPU")
            }
            let value = snapshot?.gpu?.deviceUtilization
            valueText(MetricFormatters.percent(value), color: usageColor(value))
        }
    }

    private func categoryLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func valueText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium).monospacedDigit())
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.2), value: text)
    }

    private var separator: some View {
        Text("·")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.tertiary)
    }

    // MARK: - Derived state

    /// Warning tint on usage values. Unavailable numerals render
    /// tertiary, per extension §2. RAM used % stays primary: the dot
    /// carries the RAM health signal.
    private func usageColor(_ value: Double?) -> Color {
        guard let value else { return tertiaryLabel }
        if value >= 0.95 { return .red }
        if value >= 0.80 { return .orange }
        return .primary
    }

    private var tertiaryLabel: Color { Color(nsColor: .tertiaryLabelColor) }

    private var pressureState: MemoryPressureState {
        let pressure = snapshot?.memoryPressure
        return (pressure?.state ?? .unknown)
            .displayState(pressure: pressure?.pressurePercentage ?? 0)
    }

    private var compositeLabel: String {
        MenuBarAccessibility.compositeLabel(
            showCPU: preferences.showCPU,
            showRAM: preferences.showRAM,
            showGPU: preferences.showGPU,
            cpuPercent: snapshot?.cpu?.totalUsage ?? 0,
            usedPercent: snapshot?.memory?.usedPercentage ?? 0,
            pressure: pressureState,
            gpuPercent: snapshot?.gpu?.deviceUtilization
        )
    }
}
