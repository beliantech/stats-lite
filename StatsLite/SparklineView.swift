//
//  SparklineView.swift
//  StatsLite
//
//  38 pt sparkline drawn with Canvas and Path only. No Charts import,
//  no axes, no tick labels. A single point draws a flat line.
//

import SwiftUI

struct SparklineView: View {
    /// Point values, oldest first. Each value is a fraction in 0...1.
    let values: [Double]

    /// Line and gradient tint.
    let tintColor: Color

    /// Fixed vertical domain. 1.0 covers the 0...1 metric range.
    var domainMax: Double = 1.0

    var body: some View {
        Canvas { context, size in
            guard size.width > 2, size.height > 2 else { return }
            guard !values.isEmpty else { return }

            let inset: CGFloat = 1.5
            let plotHeight = size.height - inset * 2
            let denominator = Double(max(values.count - 1, 1))

            func point(at index: Int, value: Double) -> CGPoint {
                let x = inset + CGFloat(Double(index) / denominator) * (size.width - inset * 2)
                let fraction = min(max(value, 0), max(domainMax, 0.0001)) / max(domainMax, 0.0001)
                let y = inset + (1 - CGFloat(fraction)) * plotHeight
                return CGPoint(x: x, y: min(max(y, inset), size.height - inset))
            }

            var line = Path()
            if values.count == 1 {
                let y = point(at: 0, value: values[0]).y
                line.move(to: CGPoint(x: inset, y: y))
                line.addLine(to: CGPoint(x: size.width - inset, y: y))
            } else {
                for (index, value) in values.enumerated() {
                    let next = point(at: index, value: value)
                    if index == 0 {
                        line.move(to: next)
                    } else {
                        line.addLine(to: next)
                    }
                }
            }

            // Area fill below the line: tint 0.25 at the top to 0.02
            // at the bottom.
            var area = line
            area.addLine(to: CGPoint(x: size.width - inset, y: size.height))
            area.addLine(to: CGPoint(x: inset, y: size.height))
            area.closeSubpath()
            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [tintColor.opacity(0.25), tintColor.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            context.stroke(
                line,
                with: .color(tintColor),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 38)
        .accessibilityHidden(true)
    }
}
