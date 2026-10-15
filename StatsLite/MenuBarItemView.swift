//
//  MenuBarItemView.swift
//  StatsLite
//
//  Menu bar label as ONE single Text with attributed runs (blueprint
//  Path A). MenuBarExtra extracts only the first Text from its label
//  closure into the NSStatusBarButton title, so a multi-view HStack
//  drops every sibling view. One Text carries the whole label:
//  "CPU 14% · RAM ● 62% · GPU 28%" on one line. The RAM dot is a
//  U+25CF run tinted by pressure level. GPU shows --% when the
//  sample is nil. Runs come from MenuBarLabelBuilder; the composite
//  VoiceOver label comes from MenuBarAccessibility.
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
        Text(attributedLabel)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(compositeLabel)
            .contentTransition(.numericText())
            .animation(.easeInOut(duration: 0.2), value: attributedLabel)
            .onAppear { monitor.apply(preferences) }
            .onChange(of: preferences.enabledMetrics) { monitor.apply(preferences) }
            .onChange(of: preferences.refreshInterval) { monitor.apply(preferences) }
            .onChange(of: preferences.historyDuration) { monitor.apply(preferences) }
    }

    // MARK: - Attributed label

    private var labelInput: MenuBarLabelInput {
        MenuBarLabelInput(
            showCPU: preferences.showCPU,
            showRAM: preferences.showRAM,
            showGPU: preferences.showGPU,
            // Category labels are always on. The legacy builder input
            // stays until the stacked view replaces this one.
            showLabels: true,
            cpuPercent: snapshot?.cpu?.totalUsage,
            usedPercent: snapshot?.memory?.usedPercentage,
            pressure: pressureState,
            gpuPercent: snapshot?.gpu?.deviceUtilization
        )
    }

    /// One AttributedString for the whole label. Each run keeps the
    /// blueprint typography: 10 pt semibold secondary category
    /// labels, 11.5 pt medium monospacedDigit values, a pressure-tinted
    /// dot, and 10 pt bold tertiary separators.
    private var attributedLabel: AttributedString {
        var result = AttributedString()
        for run in MenuBarLabelBuilder.runs(labelInput) {
            var piece = AttributedString(run.text)
            switch run.style {
            case .category:
                piece.font = .system(size: 10, weight: .semibold)
                piece.foregroundColor = .secondary
            case .value(let tint):
                piece.font = .system(size: 11.5, weight: .medium).monospacedDigit()
                piece.foregroundColor = valueColor(tint)
            case .ramDot(let state):
                piece.font = .system(size: 8, weight: .bold)
                piece.foregroundColor = state.levelColor
            case .separator:
                piece.font = .system(size: 10, weight: .bold)
                piece.foregroundColor = Color(nsColor: .tertiaryLabelColor)
            }
            result.append(piece)
        }
        return result
    }

    private func valueColor(_ tint: MenuBarValueTint) -> Color {
        switch tint {
        case .primary: .primary
        case .tertiary: Color(nsColor: .tertiaryLabelColor)
        case .warning: Color(nsColor: .systemOrange)
        case .critical: Color(nsColor: .systemRed)
        }
    }

    // MARK: - Derived state

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
