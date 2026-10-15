//
//  DesignTokens.swift
//  StatsLite
//
//  Shared visual tokens from the design blueprints: pressure level
//  colors and the metric card container style.
//

import SwiftUI

extension MemoryPressureState {

    /// Level color for the menu bar dot, gauge bar, badge, and
    /// sparkline: green / yellow / red per extension blueprint §2.
    /// Unknown maps to gray.
    var levelColor: Color {
        switch self {
        case .normal: Color(nsColor: .systemGreen)
        case .warning: Color(nsColor: .systemYellow)
        case .critical: Color(nsColor: .systemRed)
        case .unknown: Color(nsColor: .systemGray)
        }
    }

    /// Display state for badges and dot colors. A known kernel level
    /// wins. When the level is unknown, the pressure figure decides
    /// with the Activity Monitor thresholds: normal below 60 %,
    /// warning 60...80 %, critical above 80 %.
    func displayState(pressure: Double) -> MemoryPressureState {
        switch self {
        case .unknown:
            if pressure > 0.80 { return .critical }
            if pressure >= 0.60 { return .warning }
            return .normal
        default:
            return self
        }
    }
}

/// Metric card container: 8 pt continuous radius, 0.5 pt separator
/// border, control background at 0.65 fill, 10 pt padding.
struct MetricCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
            )
    }
}

extension View {
    func metricCardStyle() -> some View {
        modifier(MetricCardStyle())
    }
}
