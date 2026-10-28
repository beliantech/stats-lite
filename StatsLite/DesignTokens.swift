//
//  DesignTokens.swift
//  StatsLite
//
//  Shared visual tokens from the design blueprints: pressure level
//  colors and the metric card container style.
//

import SwiftUI

extension MemoryPressureState {

    /// Level color for the menu bar dot, gauge bar, and sparkline:
    /// green / yellow / red per extension blueprint §2.
    /// Unknown maps to gray. The status pill badge reads the
    /// badge* tokens below instead.
    var levelColor: Color {
        switch self {
        case .normal: Color(nsColor: .systemGreen)
        case .warning: Color(nsColor: .systemYellow)
        case .critical: Color(nsColor: .systemRed)
        case .unknown: Color(nsColor: .systemGray)
        }
    }

    /// Foreground text color for the status pill badge.
    /// Meets WCAG 2.2 AA (>= 4.5:1) against `badgeBackgroundColor`
    /// across both light and dark appearances.
    var badgeTextColor: Color {
        switch self {
        case .normal:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? .systemGreen
                    : NSColor(srgbRed: 16/255.0, green: 108/255.0, blue: 42/255.0, alpha: 1.0)
            })
        case .warning:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? .systemYellow
                    : NSColor(srgbRed: 132/255.0, green: 68/255.0, blue: 0/255.0, alpha: 1.0)
            })
        case .critical:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(srgbRed: 255/255.0, green: 128/255.0, blue: 128/255.0, alpha: 1.0)
                    : NSColor(srgbRed: 168/255.0, green: 23/255.0, blue: 28/255.0, alpha: 1.0)
            })
        case .unknown:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(srgbRed: 184/255.0, green: 184/255.0, blue: 189/255.0, alpha: 1.0)
                    : NSColor(srgbRed: 69/255.0, green: 69/255.0, blue: 74/255.0, alpha: 1.0)
            })
        }
    }

    /// Background fill color for the status pill capsule.
    var badgeBackgroundColor: Color {
        switch self {
        case .warning, .critical:
            return levelColor.opacity(0.18)
        case .normal, .unknown:
            return levelColor.opacity(0.15)
        }
    }

    /// Border stroke color for the status pill capsule.
    var badgeBorderColor: Color {
        switch self {
        case .warning:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor.systemYellow.withAlphaComponent(0.35)
                    : NSColor(srgbRed: 132/255.0, green: 68/255.0, blue: 0/255.0, alpha: 0.30)
            })
        case .normal:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor.systemGreen.withAlphaComponent(0.35)
                    : NSColor(srgbRed: 16/255.0, green: 108/255.0, blue: 42/255.0, alpha: 0.25)
            })
        case .critical:
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(srgbRed: 255/255.0, green: 128/255.0, blue: 128/255.0, alpha: 0.35)
                    : NSColor(srgbRed: 168/255.0, green: 23/255.0, blue: 28/255.0, alpha: 0.25)
            })
        case .unknown:
            return levelColor.opacity(0.30)
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
    /// Unfilled track color for metric gauges and progress bars in popover cards.
    /// Matches the gray of the Free segment of the Used memory composition bar
    /// (`Color(nsColor: .quaternaryLabelColor)`), so the empty gauge track and the
    /// composition bar remainder read as one color.
    static let metricBarTrack = Color(nsColor: .quaternaryLabelColor)
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
