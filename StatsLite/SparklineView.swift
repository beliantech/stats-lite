//
//  SparklineView.swift
//  StatsLite
//
//  38 pt sparkline rendered by CoreGraphics through CGSparklineView,
//  so the popover stops feeding the Metal redraw pool. No Charts
//  import, no axes, no tick labels. Fixed step,
//  right-anchored: the newest sample sits at the right edge, the
//  line grows leftward until the buffer reaches capacity, and a
//  single point draws a dot.
//

import SwiftUI

struct SparklineView: View, Equatable {
    /// Point values, oldest first. Each value is a fraction in 0...1.
    /// Synthesized equality compares values, tintColor, domainMax, and
    /// capacity, so `.equatable()` at the call sites skips redraws on
    /// ticks that change none of them.
    let values: [Double]

    /// Line and gradient tint.
    let tintColor: Color

    /// Fixed vertical domain. 1.0 covers the 0...1 metric range.
    var domainMax: Double = 1.0

    /// Sample capacity representing the full horizontal chart window.
    /// Defines the fixed horizontal step: (width - 2 * inset) / (capacity - 1).
    /// Call sites pass `monitor.sparklineCapacity`; there is no
    /// hardcoded default.
    let capacity: Int

    var body: some View {
        CGSparklineView(
            values: values,
            tintColor: tintColor,
            domainMax: domainMax,
            capacity: capacity
        )
        .frame(height: 38)
        .accessibilityHidden(true)
    }

    /// Maps sample values to chart points with the fixed-step,
    /// right-anchored geometry. The math lives in
    /// `SparklineCGGeometry.points` so the size-based test call
    /// shape stays stable.
    static func plotPoints(
        values: [Double],
        capacity: Int,
        size: CGSize,
        domainMax: Double
    ) -> [CGPoint] {
        SparklineCGGeometry.points(
            values: values,
            capacity: capacity,
            rect: CGRect(origin: .zero, size: size),
            domainMax: domainMax
        )
    }
}
