//
//  NetworkSparklineView.swift
//  StatsLite
//
//  56 pt mirrored dual-series chart rendered by CoreGraphics through
//  CGNetworkSparklineView, so the popover stops feeding the Metal
//  redraw pool. No Charts import. Upload fills above a central
//  baseline (systemRed), download below it (systemBlue). Both series share one
//  domainMax so the mirror stays honest, and a zero rate sits exactly
//  on the baseline with no deflection. The coordinate math lives in
//  `mirroredPlotPoints` so unit tests verify it without rendering
//  (same pattern as SparklineView.plotPoints).
//

import SwiftUI

struct NetworkSparklineView: View, Equatable {
    /// Point values in bytes per second, oldest first.
    let downloadValues: [Double]

    /// Point values in bytes per second, oldest first.
    let uploadValues: [Double]

    /// Shared vertical domain for both series, in bytes per second.
    /// Call sites pass `max(peakRate, 10 * 1024)`; the epsilon floor
    /// inside the geometry guards a zero domain.
    let domainMax: Double

    /// Sample capacity for the full horizontal window: one sample per
    /// second, so capacity equals the history window in seconds.
    /// Call sites pass `monitor.networkSparklineCapacity`.
    let capacity: Int

    var body: some View {
        CGNetworkSparklineView(
            downloadValues: downloadValues,
            uploadValues: uploadValues,
            domainMax: domainMax,
            capacity: capacity
        )
        .frame(height: 56)
        .accessibilityHidden(true)
    }

    /// Maps sample values to chart points for one mirrored series
    /// with the fixed-step, right-anchored geometry. The math lives
    /// in `SparklineCGGeometry.mirroredPoints`; this size-based
    /// wrapper keeps the existing test call shape. Zero maps to the
    /// baseline (`halfHeight`); the full domain maps to the chart top
    /// for upload (`y = 0`) or the chart bottom for download
    /// (`y = 2 * halfHeight`). Values clamp to `0...domainMax`, so a
    /// negative input never deflects past the baseline.
    static func mirroredPlotPoints(
        values: [Double],
        capacity: Int,
        size: CGSize,
        domainMax: Double,
        halfHeight: CGFloat,
        aboveBaseline: Bool
    ) -> [CGPoint] {
        SparklineCGGeometry.mirroredPoints(
            values: values,
            capacity: capacity,
            rect: CGRect(x: 0, y: 0, width: size.width, height: halfHeight * 2),
            domainMax: domainMax,
            aboveBaseline: aboveBaseline
        )
    }
}
