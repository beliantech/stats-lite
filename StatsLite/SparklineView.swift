//
//  SparklineView.swift
//  StatsLite
//
//  38 pt sparkline drawn with Canvas and Path only. No Charts import,
//  no axes, no tick labels. Fixed step, right-anchored: the newest
//  sample sits at the right edge, the line grows leftward until the
//  buffer reaches capacity, and a single point draws a dot.
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
        Canvas { context, size in
            guard size.width > 2, size.height > 2 else { return }

            let points = SparklineView.plotPoints(
                values: values,
                capacity: capacity,
                size: size,
                domainMax: domainMax
            )
            guard !points.isEmpty else { return }

            var line = Path()
            if points.count == 1 {
                let pt = points[0]
                line.move(to: pt)
                line.addLine(to: pt)
            } else {
                for (index, pt) in points.enumerated() {
                    if index == 0 {
                        line.move(to: pt)
                    } else {
                        line.addLine(to: pt)
                    }
                }
            }

            // Area fill below the line: tint 0.25 at the top to 0.02
            // at the bottom. Fill bounds clamp strictly to the line span.
            if points.count > 1 {
                var area = line
                let rightPt = points[points.count - 1]
                let leftPt = points[0]
                area.addLine(to: CGPoint(x: rightPt.x, y: size.height))
                area.addLine(to: CGPoint(x: leftPt.x, y: size.height))
                area.closeSubpath()

                context.fill(
                    area,
                    with: .linearGradient(
                        Gradient(colors: [tintColor.opacity(0.25), tintColor.opacity(0.02)]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )
            }

            context.stroke(
                line,
                with: .color(tintColor),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 38)
        .accessibilityHidden(true)
    }

    /// Maps sample values to canvas points with the fixed-step,
    /// right-anchored geometry. The body renders exactly these points.
    /// The function is internal so unit tests verify the math without
    /// rendering.
    static func plotPoints(
        values: [Double],
        capacity: Int,
        size: CGSize,
        domainMax: Double
    ) -> [CGPoint] {
        let inset: CGFloat = 1.5
        let plotWidth = size.width - inset * 2
        let plotHeight = size.height - inset * 2
        let denominator = Double(max(capacity - 1, 1))
        let dx = plotWidth / CGFloat(denominator)

        // Clamp rendering slice to at most capacity points.
        let renderValues = values.count > capacity ? Array(values.suffix(capacity)) : values
        let count = renderValues.count

        return renderValues.enumerated().map { index, value in
            let x = (size.width - inset) - CGFloat(count - 1 - index) * dx
            let fraction = min(max(value, 0), max(domainMax, 0.0001)) / max(domainMax, 0.0001)
            let y = inset + (1 - CGFloat(fraction)) * plotHeight
            return CGPoint(x: x, y: min(max(y, inset), size.height - inset))
        }
    }
}
