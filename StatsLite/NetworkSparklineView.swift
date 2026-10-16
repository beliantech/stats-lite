//
//  NetworkSparklineView.swift
//  StatsLite
//
//  56 pt mirrored dual-series chart drawn with Canvas and Path only.
//  No Charts import. Upload fills above a central baseline
//  (systemRed), download below it (systemBlue). Both series share one
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
        Canvas { context, size in
            guard size.width > 2, size.height > 2 else { return }
            let halfHeight = size.height / 2

            // Central baseline: 0.5 pt separator color at 0.35
            // opacity (VAC-6), drawn under the translucent fills.
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: halfHeight))
            baseline.addLine(to: CGPoint(x: size.width, y: halfHeight))
            context.stroke(
                baseline,
                with: .color(Color(nsColor: .separatorColor).opacity(0.35)),
                style: StrokeStyle(lineWidth: 0.5)
            )

            let series: [(values: [Double], aboveBaseline: Bool, color: Color)] = [
                (uploadValues, true, Color(nsColor: .systemRed)),
                (downloadValues, false, Color(nsColor: .systemBlue)),
            ]

            for entry in series {
                let points = NetworkSparklineView.mirroredPlotPoints(
                    values: entry.values,
                    capacity: capacity,
                    size: size,
                    domainMax: domainMax,
                    halfHeight: halfHeight,
                    aboveBaseline: entry.aboveBaseline
                )
                guard !points.isEmpty else { continue }

                var line = Path()
                if points.count == 1 {
                    // A single point draws a dot, not a full-width stroke.
                    line.move(to: points[0])
                    line.addLine(to: points[0])
                } else {
                    for (index, point) in points.enumerated() {
                        if index == 0 {
                            line.move(to: point)
                        } else {
                            line.addLine(to: point)
                        }
                    }
                }

                // Area fill closed onto the baseline. Upload runs
                // 0.22 (top) -> 0.04 (baseline); download runs
                // 0.04 (baseline) -> 0.22 (bottom) (VAC-9).
                if points.count > 1 {
                    var area = line
                    let rightPoint = points[points.count - 1]
                    let leftPoint = points[0]
                    area.addLine(to: CGPoint(x: rightPoint.x, y: halfHeight))
                    area.addLine(to: CGPoint(x: leftPoint.x, y: halfHeight))
                    area.closeSubpath()

                    let colors = entry.aboveBaseline
                        ? [entry.color.opacity(0.22), entry.color.opacity(0.04)]
                        : [entry.color.opacity(0.04), entry.color.opacity(0.22)]
                    let startY: CGFloat = entry.aboveBaseline ? 0 : halfHeight
                    let endY: CGFloat = entry.aboveBaseline ? halfHeight : size.height

                    context.fill(
                        area,
                        with: .linearGradient(
                            Gradient(colors: colors),
                            startPoint: CGPoint(x: 0, y: startY),
                            endPoint: CGPoint(x: 0, y: endY)
                        )
                    )
                }

                context.stroke(
                    line,
                    with: .color(entry.color),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(height: 56)
        .accessibilityHidden(true)
    }

    /// Maps sample values to canvas points for one mirrored series
    /// with the fixed-step, right-anchored geometry. Zero maps to the
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
        let inset: CGFloat = 1.5
        let plotWidth = size.width - inset * 2
        let denominator = Double(Swift.max(capacity - 1, 1))
        let dx = plotWidth / CGFloat(denominator)
        let domain = Swift.max(domainMax, 0.0001)

        // Clamp rendering slice to at most capacity points.
        let renderValues = values.count > capacity ? Array(values.suffix(capacity)) : values
        let count = renderValues.count

        return renderValues.enumerated().map { index, value in
            let x = (size.width - inset) - CGFloat(count - 1 - index) * dx
            let fraction = Swift.min(Swift.max(value, 0), domain) / domain
            let y: CGFloat = aboveBaseline
                ? halfHeight * (1 - CGFloat(fraction))
                : halfHeight * (1 + CGFloat(fraction))
            return CGPoint(x: x, y: y)
        }
    }
}
