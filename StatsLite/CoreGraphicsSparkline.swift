//
//  CoreGraphicsSparkline.swift
//  StatsLite
//
//  CoreGraphics sparkline path (plan 2026-10-21-popover-panel-fix,
//  decision_2026-10-21): the metric-card charts render through
//  NSView.draw instead of a SwiftUI drawing context, so the popover
//  stops feeding the Metal redraw pool (step2a evidence: removing
//  the SwiftUI drawing context dropped sustained re-lock, tail
//  185 -> 34 MB). Every visual parameter stays identical to the
//  previous rendering: 1.5 pt inset, fixed-step right-anchored
//  points, 1.5 pt round strokes, the 0.5 pt separator baseline at
//  0.35 opacity, and the same gradient stops (0.25 -> 0.02 single
//  series, 0.22 -> 0.04 mirrored series).
//

import AppKit
import SwiftUI

// MARK: - Geometry

/// Point mapping for the metric-card charts. Rect-relative,
/// right-anchored, fixed step: the newest sample sits at
/// `rect.maxX - inset`, x steps back by
/// `plotWidth / max(capacity - 1, 1)`, and more than `capacity`
/// samples keep only the newest `capacity`. The math matches the
/// former in-view plot functions, which remain as thin delegates so
/// the existing geometry tests keep their call shape.
enum SparklineCGGeometry {

    /// Maps one series of `0...domainMax` samples to points in
    /// `rect`. The domain floors at 0.0001 so a zero domain never
    /// divides by zero. y inverts: `domainMax` sits at the top
    /// inset, zero sits at the bottom inset.
    static func points(
        values: [Double],
        capacity: Int,
        rect: CGRect,
        domainMax: Double
    ) -> [CGPoint] {
        let inset: CGFloat = 1.5
        let plotWidth = rect.width - inset * 2
        let plotHeight = rect.height - inset * 2
        let denominator = Double(max(capacity - 1, 1))
        let dx = plotWidth / CGFloat(denominator)
        let domain = max(domainMax, 0.0001)

        // Clamp rendering slice to at most capacity points.
        let renderValues = values.count > capacity ? Array(values.suffix(capacity)) : values
        let count = renderValues.count

        return renderValues.enumerated().map { index, value in
            let x = rect.maxX - inset - CGFloat(count - 1 - index) * dx
            let fraction = min(max(value, 0), domain) / domain
            let y = rect.minY + inset + (1 - CGFloat(fraction)) * plotHeight
            return CGPoint(x: x, y: min(max(y, rect.minY + inset), rect.maxY - inset))
        }
    }

    /// Maps one mirrored network series to points in `rect`. Zero
    /// sits exactly on the baseline (`rect.minY + rect.height / 2`);
    /// the full domain reaches the rect top for upload
    /// (`aboveBaseline`) or the rect bottom for download. Values
    /// clamp to `0...domainMax`, so a negative input never deflects
    /// past the baseline. Each series slices its own values array.
    static func mirroredPoints(
        values: [Double],
        capacity: Int,
        rect: CGRect,
        domainMax: Double,
        aboveBaseline: Bool
    ) -> [CGPoint] {
        let inset: CGFloat = 1.5
        let plotWidth = rect.width - inset * 2
        let denominator = Double(max(capacity - 1, 1))
        let dx = plotWidth / CGFloat(denominator)
        let domain = max(domainMax, 0.0001)
        let halfHeight = rect.height / 2

        // Clamp rendering slice to at most capacity points.
        let renderValues = values.count > capacity ? Array(values.suffix(capacity)) : values
        let count = renderValues.count

        return renderValues.enumerated().map { index, value in
            let x = rect.maxX - inset - CGFloat(count - 1 - index) * dx
            let fraction = min(max(value, 0), domain) / domain
            let baseY: CGFloat = aboveBaseline
                ? halfHeight * (1 - CGFloat(fraction))
                : halfHeight * (1 + CGFloat(fraction))
            return CGPoint(x: x, y: rect.minY + baseY)
        }
    }
}

// MARK: - Renderer

/// Strokes and fills for the metric-card charts. The output matches
/// the former in-view drawing code parameter for parameter: same
/// line widths, caps, joins, gradient stops, and opacities.
enum SparklineCGRenderer {

    /// Draws the single-series chart into `context`. A line path
    /// over the points at 1.5 pt round stroke, with the area fill
    /// underneath: tint 0.25 at the top to 0.02 at the bottom,
    /// clamped to the line span and `rect.maxY`. A single point
    /// draws a dot. The size guard matches the old `width > 2,
    /// height > 2` short-circuit.
    static func drawSparkline(
        in context: CGContext,
        rect: CGRect,
        values: [Double],
        capacity: Int,
        domainMax: Double,
        tintColor: CGColor
    ) {
        guard rect.width > 2, rect.height > 2 else { return }

        let points = SparklineCGGeometry.points(
            values: values,
            capacity: capacity,
            rect: rect,
            domainMax: domainMax
        )
        guard !points.isEmpty else { return }

        let line = strokePath(points: points)

        if points.count > 1 {
            let area = fillPath(points: points, closingY: rect.maxY)
            drawGradient(
                in: context,
                area: area,
                from: withAlpha(tintColor, 0.25),
                to: withAlpha(tintColor, 0.02),
                start: CGPoint(x: rect.minX, y: rect.minY),
                end: CGPoint(x: rect.minX, y: rect.maxY)
            )
        }

        stroke(in: context, path: line, color: tintColor, width: 1.5)
    }

    /// Draws the mirrored dual-series network chart into `context`.
    /// The central baseline (separator color at 0.35 opacity, 0.5 pt)
    /// draws first and stays drawn with empty series. Each series
    /// fills onto the baseline (upload 0.22 -> 0.04 above, download
    /// 0.04 -> 0.22 below) under a 1.5 pt round stroke in its color.
    static func drawNetworkSparkline(
        in context: CGContext,
        rect: CGRect,
        downloadValues: [Double],
        uploadValues: [Double],
        capacity: Int,
        domainMax: Double,
        downloadColor: CGColor,
        uploadColor: CGColor
    ) {
        guard rect.width > 2, rect.height > 2 else { return }
        let halfHeight = rect.height / 2
        let baselineY = rect.minY + halfHeight

        // Central baseline: 0.5 pt separator color at 0.35 opacity,
        // drawn under the translucent fills.
        let baseline = CGMutablePath()
        baseline.move(to: CGPoint(x: rect.minX, y: baselineY))
        baseline.addLine(to: CGPoint(x: rect.maxX, y: baselineY))
        stroke(
            in: context,
            path: baseline,
            color: withAlpha(NSColor.separatorColor.cgColor, 0.35),
            width: 0.5
        )

        let series: [(values: [Double], aboveBaseline: Bool, color: CGColor)] = [
            (uploadValues, true, uploadColor),
            (downloadValues, false, downloadColor),
        ]

        for entry in series {
            let points = SparklineCGGeometry.mirroredPoints(
                values: entry.values,
                capacity: capacity,
                rect: rect,
                domainMax: domainMax,
                aboveBaseline: entry.aboveBaseline
            )
            guard !points.isEmpty else { continue }

            let line = strokePath(points: points)

            if points.count > 1 {
                let area = fillPath(points: points, closingY: baselineY)
                let opacities = entry.aboveBaseline
                    ? (start: 0.22, end: 0.04)
                    : (start: 0.04, end: 0.22)
                drawGradient(
                    in: context,
                    area: area,
                    from: withAlpha(entry.color, opacities.start),
                    to: withAlpha(entry.color, opacities.end),
                    start: CGPoint(
                        x: rect.minX,
                        y: entry.aboveBaseline ? rect.minY : baselineY
                    ),
                    end: CGPoint(
                        x: rect.minX,
                        y: entry.aboveBaseline ? baselineY : rect.maxY
                    )
                )
            }

            stroke(in: context, path: line, color: entry.color, width: 1.5)
        }
    }

    // MARK: Shared drawing helpers

    /// Builds the line path over the points. One point repeats at
    /// the same coordinate, so the round-cap stroke draws a dot
    /// instead of a full-width line.
    private static func strokePath(points: [CGPoint]) -> CGMutablePath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 1 {
            path.addLine(to: first)
        }
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    /// Builds the area path: the line closed down to `closingY`
    /// (rect bottom for the single series, the baseline for the
    /// mirrored series).
    private static func fillPath(points: [CGPoint], closingY: CGFloat) -> CGMutablePath {
        let area = strokePath(points: points)
        guard let last = points.last, let first = points.first else { return area }
        area.addLine(to: CGPoint(x: last.x, y: closingY))
        area.addLine(to: CGPoint(x: first.x, y: closingY))
        area.closeSubpath()
        return area
    }

    /// Fills `area` with the vertical gradient from `start` to `end`
    /// in sRGB, the same space the previous rendering interpolated in.
    private static func drawGradient(
        in context: CGContext,
        area: CGPath,
        from startColor: CGColor,
        to endColor: CGColor,
        start: CGPoint,
        end: CGPoint
    ) {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let colors = [startColor, endColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors,
            locations: locations
        ) else { return }

        context.saveGState()
        context.addPath(area)
        context.clip()
        context.drawLinearGradient(gradient, start: start, end: end, options: [])
        context.restoreGState()
    }

    /// Strokes `path` with the given width; round cap and join on
    /// the series strokes, matching the previous stroke style.
    private static func stroke(
        in context: CGContext,
        path: CGPath,
        color: CGColor,
        width: CGFloat
    ) {
        context.saveGState()
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setStrokeColor(color)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    /// Scales alpha like the previous `.opacity(_)` modifier:
    /// multiply, do not replace.
    private static func withAlpha(_ color: CGColor, _ opacity: CGFloat) -> CGColor {
        color.copy(alpha: color.alpha * opacity) ?? color
    }
}

// MARK: - Single-series chart view

/// CoreGraphics wrapper for the card sparkline. `NSViewRepresentable`
/// plus `Equatable`: synthesized equality compares values,
/// tintColor, domainMax, and capacity, so `.equatable()` at the call
/// sites skips `updateNSView` on ticks that change none of them
/// (the redraw contract the former drawing-context views kept).
struct CGSparklineView: NSViewRepresentable, Equatable {
    /// Point values, oldest first. Each value is a fraction in 0...1.
    var values: [Double]

    /// Line and gradient tint.
    var tintColor: Color

    /// Fixed vertical domain. 1.0 covers the 0...1 metric range.
    var domainMax: Double = 1.0

    /// Sample capacity representing the full horizontal chart window.
    var capacity: Int

    func makeNSView(context: Context) -> CGSparklineNSView {
        CGSparklineNSView()
    }

    func updateNSView(_ nsView: CGSparklineNSView, context: Context) {
        nsView.values = values
        nsView.tintColor = tintColor
        nsView.domainMax = domainMax
        nsView.capacity = capacity
        nsView.needsDisplay = true
    }
}

/// Draws the single-series chart. Flipped, so the y-down point math
/// from `SparklineCGGeometry` lands upright in view coordinates.
final class CGSparklineNSView: NSView {
    var values: [Double] = []
    var tintColor: Color = .blue
    var domainMax: Double = 1.0
    var capacity: Int = 1

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        SparklineCGRenderer.drawSparkline(
            in: context,
            rect: bounds,
            values: values,
            capacity: capacity,
            domainMax: domainMax,
            tintColor: NSColor(tintColor).cgColor
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

// MARK: - Mirrored dual-series chart view

/// CoreGraphics wrapper for the network sparkline: download below
/// the central baseline, upload above it, one shared domain.
/// Synthesized equality covers downloadValues, uploadValues,
/// domainMax, and capacity, so `.equatable()` at the call sites
/// skips `updateNSView` while none of them change.
struct CGNetworkSparklineView: NSViewRepresentable, Equatable {
    /// Point values in bytes per second, oldest first.
    var downloadValues: [Double]

    /// Point values in bytes per second, oldest first.
    var uploadValues: [Double]

    /// Shared vertical domain for both series, in bytes per second.
    var domainMax: Double

    /// Sample capacity for the full horizontal window.
    var capacity: Int

    func makeNSView(context: Context) -> CGNetworkSparklineNSView {
        CGNetworkSparklineNSView()
    }

    func updateNSView(_ nsView: CGNetworkSparklineNSView, context: Context) {
        nsView.downloadValues = downloadValues
        nsView.uploadValues = uploadValues
        nsView.domainMax = domainMax
        nsView.capacity = capacity
        nsView.needsDisplay = true
    }
}

/// Draws the mirrored dual-series chart. Flipped, so the y-down
/// point math from `SparklineCGGeometry` lands upright.
final class CGNetworkSparklineNSView: NSView {
    var downloadValues: [Double] = []
    var uploadValues: [Double] = []
    var domainMax: Double = 1.0
    var capacity: Int = 1

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        SparklineCGRenderer.drawNetworkSparkline(
            in: context,
            rect: bounds,
            downloadValues: downloadValues,
            uploadValues: uploadValues,
            capacity: capacity,
            domainMax: domainMax,
            downloadColor: NSColor.systemBlue.cgColor,
            uploadColor: NSColor.systemRed.cgColor
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
