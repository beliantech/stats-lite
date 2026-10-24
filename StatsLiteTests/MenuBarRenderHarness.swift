//
//  MenuBarRenderHarness.swift
//  StatsLiteTests
//
//  Offscreen render harness for the menu bar pixel VACs (plan
//  2026-10-24-menu-bar-offscreen-render-tests). It draws the real
//  block views through NSHostingView into an NSBitmapImageRep at a
//  pinned 2x scale over a fixed opaque 50 % gray background, then
//  exposes the luminance plane for ink measurements. The render is
//  fully in-process: no screen capture and no CGWindowList, so the
//  pixel VACs verify with the screen locked and the display asleep.
//  Live screen captures stay end-to-end spot checks only.
//

import AppKit
import SwiftUI

@MainActor
enum MenuBarRenderHarness {

    /// Pinned render scale (plan FM2): measurements run in bitmap
    /// pixels at 2x, never at the display's scale.
    static let scale: CGFloat = 2

    /// Fixed opaque background luminance: 50 % gray contrasts with
    /// dark-mode white text and light-mode black text, so ink
    /// extraction works under both forced appearances. Nonisolated
    /// so the nested Render can read it from measurement methods.
    nonisolated static let backgroundLuminance = 127.5

    /// One offscreen render: row-major luminance plane (0...255 per
    /// pixel) plus pixel dimensions.
    struct Render {
        let pixelsWide: Int
        let pixelsHigh: Int
        let luminance: [Double]

        /// Ink weight of one pixel: its distance from the fixed
        /// background luminance. Zero on background pixels.
        func ink(x: Int, y: Int) -> Double {
            abs(
                luminance[y * pixelsWide + x]
                    - MenuBarRenderHarness.backgroundLuminance
            )
        }

        /// Ink pixel count across the whole bitmap (the FM1 guard
        /// input: a blank render carries ~0).
        func inkPixelCount(threshold: Double) -> Int {
            var count = 0
            for y in 0..<pixelsHigh {
                for x in 0..<pixelsWide where ink(x: x, y: y) >= threshold {
                    count += 1
                }
            }
            return count
        }

        /// Every run of ink columns in the band, left to right.
        /// Glyphs and dots render as separate clusters because the
        /// spacing between row elements leaves empty columns.
        func inkClusters(
            yRange: Range<Int>,
            xRange: Range<Int>,
            threshold: Double
        ) -> [Range<Int>] {
            var clusters: [Range<Int>] = []
            var start: Int?
            for x in xRange {
                let hasInk = yRange.contains { ink(x: x, y: $0) >= threshold }
                if hasInk {
                    if start == nil { start = x }
                } else if let first = start {
                    clusters.append(first..<x)
                    start = nil
                }
            }
            if let first = start {
                clusters.append(first..<xRange.upperBound)
            }
            return clusters
        }

        /// First run of ink columns: the leftmost glyph cluster in
        /// the band (a subsystem label or an indicator dot),
        /// isolated from the row neighbor that follows it.
        func leftmostInkCluster(
            yRange: Range<Int>,
            xRange: Range<Int>,
            threshold: Double
        ) -> Range<Int>? {
            inkClusters(yRange: yRange, xRange: xRange, threshold: threshold)
                .first
        }

        /// Leftmost ink column in the band.
        func leftmostInkX(
            yRange: Range<Int>,
            xRange: Range<Int>,
            threshold: Double
        ) -> Int? {
            leftmostInkCluster(yRange: yRange, xRange: xRange, threshold: threshold)?
                .lowerBound
        }

        /// Rightmost ink column in the band.
        func rightmostInkX(
            yRange: Range<Int>,
            xRange: Range<Int>,
            threshold: Double
        ) -> Int? {
            for x in xRange.reversed()
            where yRange.contains(where: { ink(x: x, y: $0) >= threshold }) {
                return x
            }
            return nil
        }

        /// Sub-pixel top ink edge over the column band. Per column,
        /// the first row's ink coverage is extrapolated to zero
        /// against the fuller row below, clamped to [first,
        /// first+1). The band edge is the MINIMUM over columns:
        /// round glyph tops (C, G) and flat ones (CPU, MEM, GPU) are
        /// compared at their topmost ink, and columns whose ink
        /// starts deep (a letter's interior, value-ink bleed) cannot
        /// drag the edge down.
        func subpixelTopInkY(
            columns: Range<Int>,
            yRange: Range<Int>,
            threshold: Double
        ) -> Double? {
            var top: Double?
            for x in columns {
                guard let first = yRange.first(where: { ink(x: x, y: $0) >= threshold })
                else { continue }
                let firstMass = ink(x: x, y: first)
                let secondMass = yRange.contains(first + 1)
                    ? ink(x: x, y: first + 1)
                    : 0
                var edge = Double(first) + 1 - firstMass / secondMass
                if !edge.isFinite {
                    edge = Double(first) + 1
                }
                edge = min(max(edge, Double(first)), Double(first) + 1)
                if top == nil || edge < top! {
                    top = edge
                }
            }
            return top
        }

        /// Intensity-weighted sub-pixel centroid y over the columns.
        func centroidY(
            columns: Range<Int>,
            yRange: Range<Int>,
            threshold: Double
        ) -> Double? {
            var mass = 0.0
            var weighted = 0.0
            for y in yRange {
                for x in columns {
                    let weight = ink(x: x, y: y)
                    guard weight >= threshold else { continue }
                    mass += weight
                    weighted += weight * (Double(y) + 0.5)
                }
            }
            guard mass > 0 else { return nil }
            return weighted / mass
        }

        /// Intensity-weighted sub-pixel centroid y of the leftmost
        /// glyph cluster in the band.
        func leftmostClusterCentroidY(
            yRange: Range<Int>,
            xRange: Range<Int>,
            threshold: Double
        ) -> Double? {
            guard
                let cluster = leftmostInkCluster(
                    yRange: yRange,
                    xRange: xRange,
                    threshold: threshold
                )
            else { return nil }
            return centroidY(columns: cluster, yRange: yRange, threshold: threshold)
        }

        /// Mean luminance of the ink pixels over the columns (the
        /// ISC-5 appearance probe reads it on value-text ink).
        func meanInkLuminance(
            columns: Range<Int>,
            yRange: Range<Int>,
            threshold: Double
        ) -> Double? {
            var sum = 0.0
            var count = 0
            for y in yRange {
                for x in columns {
                    guard ink(x: x, y: y) >= threshold else { continue }
                    sum += luminance[y * pixelsWide + x]
                    count += 1
                }
            }
            guard count > 0 else { return nil }
            return sum / Double(count)
        }
    }

    /// Offscreen window that pins the backing scale. A detached
    /// NSHostingView renders on a 1x grid: sub-pixel offsets
    /// quantize to whole points and a -0.5 pt offset renders as
    /// zero (plan FM1/FM2 — verified by the offset transfer
    /// probe). The fixed 2x override keeps the render scale pinned
    /// to the bitmap scale on any machine.
    private final class FixedScaleWindow: NSWindow {
        let fixedScale: CGFloat

        init(contentRect: NSRect, scale: CGFloat) {
            self.fixedScale = scale
            super.init(
                contentRect: contentRect,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            isReleasedWhenClosed = false
            backgroundColor = .black
        }

        override var backingScaleFactor: CGFloat { fixedScale }
    }

    /// Renders `view` at 2x into a bitmap under the forced
    /// appearance, over the fixed gray background.
    static func render<V: View>(
        _ view: V,
        appearance: NSAppearance.Name
    ) -> Render {
        let hosting = NSHostingView(
            rootView: view.background(Color(white: 0.5))
        )
        hosting.appearance = NSAppearance(named: appearance)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)

        // The window carries the 2x scale; the hosting view must
        // live in it or SwiftUI lays out on the 1x grid.
        let window = FixedScaleWindow(
            contentRect: NSRect(origin: .zero, size: size),
            scale: scale
        )
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        defer { window.contentView = nil }

        let pixelsWide = Int((size.width * scale).rounded())
        let pixelsHigh = Int((size.height * scale).rounded())
        guard
            pixelsWide > 0,
            pixelsHigh > 0,
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelsWide,
                pixelsHigh: pixelsHigh,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            preconditionFailure(
                "MenuBarRenderHarness: cannot allocate a \(pixelsWide)x\(pixelsHigh) bitmap"
            )
        }
        bitmap.size = NSSize(width: size.width, height: size.height)
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)

        var luminance = [Double](repeating: 0, count: pixelsWide * pixelsHigh)
        for y in 0..<pixelsHigh {
            for x in 0..<pixelsWide {
                let color = (bitmap.colorAt(x: x, y: y) ?? .black)
                    .usingColorSpace(.deviceRGB) ?? .black
                luminance[y * pixelsWide + x] =
                    (0.2126 * color.redComponent
                        + 0.7152 * color.greenComponent
                        + 0.0722 * color.blueComponent) * 255
            }
        }
        return Render(
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            luminance: luminance
        )
    }
}
