//
//  TopProcessesView.swift
//  StatsLite
//
//  Top Processes disclosure views per plan 2026-10-23 §4.3/§4.4.
//  Rows: 18 pt single line — name 10 pt primary tail-truncated, PID
//  8.5 pt monospaced tertiary, a 44×5 pt capsule gauge, and a 9.5 pt
//  monospacedDigit value in a fixed 44 pt frame [AMD-4]. Loading and
//  empty states are static text lines, never a spinner [AMD-2]. The
//  collapsed cue is a 4 pt dot only — no process name while collapsed
//  [AMD-1].
//

import SwiftUI

/// Expanded list container: up to 5 rows, or one static placeholder
/// line while loading (VAC-13) or empty (R2b).
struct TopProcessesSectionView: View {
    let processes: [ProcessMetricItem]
    let tintColor: Color
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let placeholder = Self.placeholderText(
                processCount: processes.count,
                isLoading: isLoading
            ) {
                Text(placeholder)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    // State-matrix heights: 38 pt loading, 34 pt
                    // empty, each counting the 16 pt header and the
                    // card's 4 pt gap (§4.4).
                    .frame(height: isLoading ? 18 : 14)
            } else {
                ForEach(Array(processes.prefix(5))) { process in
                    row(for: process)
                }
            }
        }
    }

    /// The placeholder line for the section, nil when real rows
    /// render. R5/VAC-13: "Sampling top processes…" while the CPU
    /// bootstrap holds the first sample. R2b: "No process data
    /// available" when a scan returns zero processes. Loading wins
    /// only while the list is empty, per the T-C contract.
    static func placeholderText(processCount: Int, isLoading: Bool) -> String? {
        if isLoading && processCount == 0 {
            return "Sampling top processes…"
        }
        if processCount == 0 {
            return "No process data available"
        }
        return nil
    }

    /// The trailing PID text on every row (D1, Appendix D item 3):
    /// rows only ever carry a real resolved name now — an unnamed
    /// candidate drops from the pass instead of shipping the
    /// `Process NNNNN` fallback — so the suffix always renders.
    static func pidText(for process: ProcessMetricItem) -> String {
        "(\(process.pid))"
    }

    /// One row's accessibility label (§4.5): name, Process ID, value.
    static func rowLabel(for process: ProcessMetricItem) -> String {
        "\(process.name), Process ID \(process.pid), \(process.valueLabel)"
    }

    /// One process row: 18 pt line, 140 pt name+PID column, 44×5 pt
    /// gauge, 44 pt right-aligned value column (VAC-5/VAC-6/VAC-7).
    func row(for process: ProcessMetricItem) -> some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                Text(process.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(Self.pidText(for: process))
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(width: 140, alignment: .leading)

            gauge(for: process)

            Text(process.valueLabel)
                .font(.system(size: 9.5).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 44, alignment: .trailing)
        }
        .frame(height: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.rowLabel(for: process))
    }

    /// The 44×5 pt capsule gauge: separator track plus tinted fill
    /// with a 2 pt minimum. Hidden from VoiceOver (§4.5) — the value
    /// text is authoritative.
    private func gauge(for process: ProcessMetricItem) -> some View {
        let clamped = Swift.min(Swift.max(process.fraction, 0), 1)
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(nsColor: .separatorColor).opacity(0.3))
            Capsule()
                .fill(tintColor)
                .frame(width: Swift.max(44 * clamped, 2))
        }
        .frame(width: 44, height: 5)
        .accessibilityHidden(true)
    }
}

/// Collapsed/expanded disclosure row: 9 pt semibold chevron plus 10 pt
/// medium label, optional 4 pt cue dot while collapsed (VAC-3/VAC-4).
struct TopProcessesDisclosureButton: View {
    let isExpanded: Bool
    let usageState: ProcessCueState
    /// The parent metric title for the §4.5 label
    /// ("Top processes for CPU Total").
    let metricTitle: String
    /// The disclosure action: writes through the popover's shared
    /// accordion binding.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text("Top Processes")
                    .font(.system(size: 10, weight: .medium))
                // AMD-1: the collapsed high-use cue is the dot only,
                // never a process name (lazy sampling contract).
                if !isExpanded, let dotColor = cueDotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 4, height: 4)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
            .frame(height: 16)
        }
        .buttonStyle(.plain)
        // Built as a String value first: a literal interpolation
        // would store as a LocalizedStringKey format ("…%@") plus
        // argument, splitting the label in the accessibility tree.
        .accessibilityLabel(disclosureLabel)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint("Double-click to expand or collapse the top five active processes.")
    }

    /// The §4.5 accessibility label: "Top processes for CPU Total".
    private var disclosureLabel: String {
        "Top processes for \(metricTitle)"
    }

    /// The collapsed cue dot: amber at warning, red at critical,
    /// nothing at normal (VAC-4).
    private var cueDotColor: Color? {
        switch usageState {
        case .normal: nil
        case .warning: Color(nsColor: .systemOrange)
        case .critical: Color(nsColor: .systemRed)
        }
    }
}
