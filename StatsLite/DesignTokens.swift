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

// MARK: - Metric Popover Bar Tokens

extension CGFloat {
    /// Standard height for metric popover bars (memory pressure gauge and used memory composition bar).
    static let metricBarHeight: CGFloat = 6

    /// Corner radius for standard 6 pt metric popover bars.
    static let metricBarCornerRadius: CGFloat = 3
}

extension Color {
    /// Subtle track color for metric gauges and progress bars in popover cards.
    /// Blends into the card background across both dark and light appearances.
    static let metricBarTrack = Color(nsColor: .separatorColor).opacity(0.08)
}

/// Network indicator dot colors, shared by the status item block and
/// the popover legend. Upload stays systemRed. Download is adaptive:
/// systemCyan on dark aqua keeps contrast on blue-hued wallpapers,
/// systemBlue on aqua (plan 2026-10-20-network-dot-contrast-size).
extension Color {
    static let networkUpload = Color(nsColor: .systemRed)
    static let networkDownload = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? .systemCyan
            : .systemBlue
    })
}

/// Network indicator dot diameter. 5 pt matches the MEM dot-to-text
/// ratio and lands on a whole pixel at 2x Retina.
extension CGFloat {
    static let networkDotSize: CGFloat = 5
}

extension Color {
    /// Adaptive menu bar category label color: 80% white in dark appearance
    /// for crisp contrast on dark and colorful translucent menu bars,
    /// 75% black in light appearance for crisp contrast on light menu bars.
    static let menuBarLabel = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.80)
            : NSColor.black.withAlphaComponent(0.75)
    })
}

/// Menu bar metric category label style: 8 pt regular text with the
/// adaptive menuBarLabel foreground style and lineLimit(1).
struct MenuBarMetricLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 8, weight: .regular))
            .foregroundStyle(Color.menuBarLabel)
            .lineLimit(1)
    }
}

extension View {
    /// Applies the standard 8 pt regular typography and adaptive high-contrast
    /// color to a menu bar metric category label.
    func menuBarMetricLabel() -> some View {
        modifier(MenuBarMetricLabelStyle())
    }
}
