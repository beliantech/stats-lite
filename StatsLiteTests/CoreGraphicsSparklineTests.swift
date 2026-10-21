//
//  CoreGraphicsSparklineTests.swift
//  StatsLiteTests
//
//  RED phase for the Option B fix (plan 2026-10-21-popover-panel-fix,
//  decision_2026-10-21): replace the SwiftUI Canvas in SparklineView
//  and NetworkSparklineView with a CoreGraphics NSViewRepresentable /
//  NSView.draw path so the popover stops feeding the Metal redraw
//  pool, while the visuals stay pixel-equivalent.
//
//  These tests target the extraction API the green phase must build.
//  The API does not exist yet, so FM1-FM4 fail at compile level:
//
//    SparklineCGGeometry.points(values:capacity:rect:domainMax:)
//    SparklineCGGeometry.mirroredPoints(values:capacity:rect:domainMax:aboveBaseline:)
//    SparklineCGRenderer.drawSparkline(in:rect:values:capacity:domainMax:tintColor:)
//    SparklineCGRenderer.drawNetworkSparkline(in:rect:downloadValues:uploadValues:capacity:domainMax:downloadColor:uploadColor:)
//    CGSparklineView: NSViewRepresentable, Equatable
//        (values, tintColor, domainMax = 1.0, capacity)
//    CGNetworkSparklineView: NSViewRepresentable, Equatable
//        (downloadValues, uploadValues, domainMax, capacity)
//
//  FM1-FM3 pin the CURRENT Canvas math from SparklineView.swift
//  (plotPoints, suffix slice at :106) and NetworkSparklineView.swift
//  (mirroredPlotPoints, suffix slice at :139): fixed-step
//  right-anchored x, inset 1.5 pt padding, y-axis inversion for the
//  single series, half-height mirroring for the network series, and
//  the 0.0001 epsilon domain floor. FM4 mirrors the .equatable()
//  redraw contract at SparklineView.swift:16-25. FM5 (axis
//  regression guards) lives in SparklineTimeAxisGuardTests.swift
//  and stays green throughout.
//

import AppKit
import SwiftUI
import XCTest
@testable import StatsLite

@MainActor
final class CoreGraphicsSparklineTests: XCTestCase {

    // MARK: - Shared geometry constants (current Canvas math)

    /// Single-series chart: popover content width minus card padding,
    /// 38 pt tall (SparklineView .frame(height: 38)).
    private let cardRect = CGRect(x: 0, y: 0, width: 240, height: 38)

    /// Network chart: 240 pt wide, 56 pt tall
    /// (NetworkSparklineView .frame(height: 56)).
    private let networkRect = CGRect(x: 0, y: 0, width: 240, height: 56)

    /// Fixed padding the Canvas geometry insets by on every side.
    private let inset: CGFloat = 1.5

    /// Shared network domain the card passes in
    /// (`max(peakRate, 10 * 1024)`).
    private let networkDomain: Double = 10.0 * 1024.0

    // MARK: - Bitmap helpers (FM2/FM3 draw checks)

    /// Zeroed RGBA bitmap context. byteOrder32Big puts alpha at
    /// byte offset 3 of every pixel.
    private func makeBitmap(
        width: Int,
        height: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> CGContext {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            ),
            "bitmap context allocation failed",
            file: file,
            line: line
        )
        context.clear(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        return context
    }

    /// True when every pixel keeps alpha 0: nothing was drawn.
    private func isBlank(_ context: CGContext, width: Int, height: Int) -> Bool {
        guard let data = context.data else { return false }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let rowBytes = context.bytesPerRow
        for row in 0..<height {
            for column in 0..<width {
                if pixels[row * rowBytes + column * 4 + 3] != 0 { return false }
            }
        }
        return true
    }

    /// True when any pixel in rows [firstRow, lastRowExclusive)
    /// carries alpha > 0. Row order flips with the context
    /// orientation, so callers pass symmetric row windows.
    private func hasVisiblePixel(
        _ context: CGContext,
        width: Int,
        firstRow: Int,
        lastRowExclusive: Int
    ) -> Bool {
        guard let data = context.data else { return false }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        let rowBytes = context.bytesPerRow
        for row in firstRow..<lastRowExclusive {
            for column in 0..<width {
                if pixels[row * rowBytes + column * 4 + 3] != 0 { return true }
            }
        }
        return false
    }

    // MARK: - FM1: the point sequence pins the current Canvas math

    func testFM1PointSequencesPinCurrentCanvasMath() {
        let capacity = 30
        let plotWidth = cardRect.width - inset * 2
        let plotHeight = cardRect.height - inset * 2
        let dx = plotWidth / CGFloat(capacity - 1)

        // Ascending ramp 0 ... 1 over a warm-up window.
        let ramp = [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]
        let points = SparklineCGGeometry.points(
            values: ramp,
            capacity: capacity,
            rect: cardRect,
            domainMax: 1.0
        )

        XCTAssertEqual(points.count, ramp.count, "FM1: every warm-up sample plots")
        for (index, point) in points.enumerated() {
            let expectedX = cardRect.maxX - inset
                - CGFloat(ramp.count - 1 - index) * dx
            let expectedY = inset + (1 - CGFloat(ramp[index])) * plotHeight
            XCTAssertEqual(
                point.x, expectedX, accuracy: 1e-9,
                "FM1: x must stay right-anchored with the fixed step dx, sample \(index)"
            )
            XCTAssertEqual(
                point.y, expectedY, accuracy: 1e-9,
                "FM1: y must invert like the Canvas math, sample \(index)"
            )
        }
        XCTAssertEqual(
            points[points.count - 1].x, cardRect.maxX - inset, accuracy: 1e-9,
            "FM1: the newest sample anchors at the right inset"
        )
        XCTAssertEqual(
            points[0].y, cardRect.maxY - inset, accuracy: 1e-9,
            "FM1: the minimum value sits at the rect bottom inset"
        )
        XCTAssertEqual(
            points[points.count - 1].y, cardRect.minY + inset, accuracy: 1e-9,
            "FM1: the maximum value sits at the rect top inset"
        )
        for index in 1..<points.count {
            XCTAssertLessThan(
                points[index].y, points[index - 1].y,
                "FM1: ascending values must rise in a y-down space, sample \(index)"
            )
        }

        // Points move with the rect origin: the mapping is
        // rect-relative, not size-only.
        let shifted = SparklineCGGeometry.points(
            values: ramp,
            capacity: capacity,
            rect: CGRect(x: 10, y: 4, width: 240, height: 38),
            domainMax: 1.0
        )
        XCTAssertEqual(shifted.count, points.count, "FM1: translation keeps the count")
        for (index, point) in shifted.enumerated() {
            XCTAssertEqual(
                point.x, points[index].x + 10, accuracy: 1e-9,
                "FM1: x follows the rect origin.x, sample \(index)"
            )
            XCTAssertEqual(
                point.y, points[index].y + 4, accuracy: 1e-9,
                "FM1: y follows the rect origin.y, sample \(index)"
            )
        }

        // Capacity suffix slice (SparklineView.swift:106): more
        // samples than capacity keep only the newest `capacity`
        // values, rescaled to the full width with fixed step
        // dx = plotWidth / (capacity - 1).
        let sliceCapacity = 5
        let overflow = (0..<10).map { Double($0) / 9.0 }
        let sliced = SparklineCGGeometry.points(
            values: overflow,
            capacity: sliceCapacity,
            rect: cardRect,
            domainMax: 1.0
        )
        let sliceDx = plotWidth / CGFloat(sliceCapacity - 1)

        XCTAssertEqual(sliced.count, sliceCapacity, "FM1: N > C renders only the newest C samples")
        XCTAssertEqual(sliced[0].x, cardRect.minX + inset, accuracy: 1e-9)
        XCTAssertEqual(
            sliced[sliceCapacity - 1].x, cardRect.maxX - inset, accuracy: 1e-9,
            "FM1: the slice spans the full active width"
        )
        XCTAssertEqual(
            sliced[0].y,
            inset + (1.0 - 5.0 / 9.0) * plotHeight,
            accuracy: 1e-9,
            "FM1: the first rendered sample is values[5] = 5/9, not values[0]"
        )
        XCTAssertEqual(
            sliced[sliceCapacity - 1].y, inset, accuracy: 1e-9,
            "FM1: the newest value 1.0 sits at the top inset"
        )
        for index in 1..<sliceCapacity {
            XCTAssertEqual(
                sliced[index].x - sliced[index - 1].x, sliceDx, accuracy: 1e-9,
                "FM1: the slice keeps the fixed step, sample \(index)"
            )
        }

        // Mirrored series (NetworkSparklineView.mirroredPlotPoints):
        // shared domain, zero exactly on the baseline, upload (above)
        // reaches the rect top at domainMax, download (below)
        // reaches the rect bottom. The baseline is rect.height / 2.
        let half = networkRect.height / 2
        let mirrorDx = (networkRect.width - inset * 2) / CGFloat(capacity - 1)
        let mirrorValues = [0.0, 2560, 5120, 7680, 10_240]

        let upload = SparklineCGGeometry.mirroredPoints(
            values: mirrorValues,
            capacity: capacity,
            rect: networkRect,
            domainMax: networkDomain,
            aboveBaseline: true
        )
        let download = SparklineCGGeometry.mirroredPoints(
            values: mirrorValues,
            capacity: capacity,
            rect: networkRect,
            domainMax: networkDomain,
            aboveBaseline: false
        )
        let expectedUploadY: [CGFloat] = [28, 21, 14, 7, 0]
        let expectedDownloadY: [CGFloat] = [28, 35, 42, 49, 56]

        XCTAssertEqual(upload.count, mirrorValues.count, "FM1: mirrored upload plots every sample")
        XCTAssertEqual(download.count, mirrorValues.count, "FM1: mirrored download plots every sample")
        for index in 0..<mirrorValues.count {
            let expectedX = networkRect.maxX - inset
                - CGFloat(mirrorValues.count - 1 - index) * mirrorDx
            XCTAssertEqual(
                upload[index].x, expectedX, accuracy: 1e-9,
                "FM1: mirrored x stays right-anchored, sample \(index)"
            )
            XCTAssertEqual(
                upload[index].y, expectedUploadY[index], accuracy: 1e-9,
                "FM1: upload maps f -> halfHeight * (1 - f), sample \(index)"
            )
            XCTAssertEqual(
                download[index].y, expectedDownloadY[index], accuracy: 1e-9,
                "FM1: download maps f -> halfHeight * (1 + f), sample \(index)"
            )
        }
        XCTAssertEqual(
            upload[0].y, half, accuracy: 1e-9,
            "FM1: zero upload sits exactly on the baseline"
        )
        XCTAssertEqual(
            upload[mirrorValues.count - 1].y, networkRect.minY, accuracy: 1e-9,
            "FM1: domainMax upload reaches the rect top"
        )
        XCTAssertEqual(
            download[download.count - 1].y, networkRect.maxY, accuracy: 1e-9,
            "FM1: domainMax download reaches the rect bottom"
        )

        // Mirrored capacity suffix slice (NetworkSparklineView.swift:139)
        // runs per series on its own values array.
        let mirrorSlice = (0..<10).map { Double($0) / 9.0 * networkDomain }
        let slicedUpload = SparklineCGGeometry.mirroredPoints(
            values: mirrorSlice,
            capacity: sliceCapacity,
            rect: networkRect,
            domainMax: networkDomain,
            aboveBaseline: true
        )
        XCTAssertEqual(slicedUpload.count, sliceCapacity, "FM1: mirrored N > C renders the newest C samples")
        XCTAssertEqual(
            slicedUpload[0].y,
            half * (1.0 - 5.0 / 9.0),
            accuracy: 1e-9,
            "FM1: the first mirrored sample is values[5] = 5/9 of the domain"
        )
        XCTAssertEqual(
            slicedUpload[sliceCapacity - 1].y, 0, accuracy: 1e-9,
            "FM1: the newest domainMax upload sits at the rect top"
        )
    }

    // MARK: - FM2: empty, single, and flat inputs stay safe

    func testFM2EmptySingleAndFlatInputsStaySafe() {
        // Empty: no crash, nothing to draw.
        let empty = SparklineCGGeometry.points(
            values: [],
            capacity: 30,
            rect: cardRect,
            domainMax: 1.0
        )
        XCTAssertTrue(empty.isEmpty, "FM2: N = 0 must produce no points")

        // Single point: no division by zero, one dot at the right edge.
        let single = SparklineCGGeometry.points(
            values: [0.5],
            capacity: 30,
            rect: cardRect,
            domainMax: 1.0
        )
        XCTAssertEqual(single.count, 1, "FM2: N = 1 renders one dot")
        XCTAssertEqual(single[0].x, cardRect.maxX - inset, accuracy: 1e-9)
        XCTAssertEqual(single[0].y, 19.0, accuracy: 1e-9, "FM2: 0.5 of the domain sits at mid height")
        XCTAssertTrue(single[0].x.isFinite && single[0].y.isFinite, "FM2: the dot stays finite")

        // The step denominator floors at 1 for capacity <= 1.
        let tinyCapacity = SparklineCGGeometry.points(
            values: [0.5],
            capacity: 1,
            rect: cardRect,
            domainMax: 1.0
        )
        XCTAssertEqual(tinyCapacity.count, 1, "FM2: capacity 1 still plots")
        XCTAssertTrue(
            tinyCapacity[0].x.isFinite && tinyCapacity[0].y.isFinite,
            "FM2: capacity 1 must not divide by zero"
        )

        // A zero domain keeps the 0.0001 epsilon floor.
        let zeroDomain = SparklineCGGeometry.points(
            values: [1.0],
            capacity: 30,
            rect: cardRect,
            domainMax: 0
        )
        XCTAssertEqual(zeroDomain.count, 1, "FM2: a zero domain still plots")
        XCTAssertEqual(
            zeroDomain[0].y, inset, accuracy: 1e-9,
            "FM2: the epsilon floor keeps v = 1 at the top"
        )
        XCTAssertTrue(zeroDomain[0].y.isFinite, "FM2: zero domain must not divide by zero")

        // Flat values: every point finite, no NaN/inf, all on one row.
        let flatValues = [0.7, 0.7, 0.7]
        let flat = SparklineCGGeometry.points(
            values: flatValues,
            capacity: 30,
            rect: cardRect,
            domainMax: 1.0
        )
        XCTAssertEqual(flat.count, flatValues.count, "FM2: flat samples still plot")
        for (index, point) in flat.enumerated() {
            XCTAssertTrue(
                point.x.isFinite && point.y.isFinite,
                "FM2: flat sample \(index) must stay finite, got \(point)"
            )
        }
        for index in 1..<flat.count {
            XCTAssertEqual(
                flat[index].y, flat[0].y, accuracy: 1e-12,
                "FM2: flat values sit on one horizontal row, sample \(index)"
            )
        }

        // Mirrored flat values stay finite too.
        let flatMirrored = SparklineCGGeometry.mirroredPoints(
            values: [5000, 5000, 5000],
            capacity: 30,
            rect: networkRect,
            domainMax: networkDomain,
            aboveBaseline: false
        )
        XCTAssertEqual(flatMirrored.count, 3, "FM2: mirrored flat samples still plot")
        for (index, point) in flatMirrored.enumerated() {
            XCTAssertTrue(
                point.x.isFinite && point.y.isFinite,
                "FM2: mirrored flat sample \(index) must stay finite, got \(point)"
            )
        }

        // Draw contract: empty draws nothing, a single value draws a
        // dot, and the Canvas size guard (width/height > 2) still
        // short-circuits.
        let tint = CGColor(red: 0, green: 0.478, blue: 1, alpha: 1)

        let emptyCanvas = try? makeBitmap(width: 240, height: 38)
        XCTAssertNotNil(emptyCanvas, "FM2: bitmap allocation")
        if let emptyCanvas {
            SparklineCGRenderer.drawSparkline(
                in: emptyCanvas,
                rect: cardRect,
                values: [],
                capacity: 30,
                domainMax: 1.0,
                tintColor: tint
            )
            XCTAssertTrue(
                isBlank(emptyCanvas, width: 240, height: 38),
                "FM2: empty values must draw nothing"
            )
        }

        let dotCanvas = try? makeBitmap(width: 240, height: 38)
        XCTAssertNotNil(dotCanvas, "FM2: bitmap allocation")
        if let dotCanvas {
            SparklineCGRenderer.drawSparkline(
                in: dotCanvas,
                rect: cardRect,
                values: [0.5],
                capacity: 30,
                domainMax: 1.0,
                tintColor: tint
            )
            XCTAssertTrue(
                hasVisiblePixel(dotCanvas, width: 240, firstRow: 0, lastRowExclusive: 38),
                "FM2: a single value must draw a dot"
            )
        }

        let tinyCanvas = try? makeBitmap(width: 2, height: 2)
        XCTAssertNotNil(tinyCanvas, "FM2: bitmap allocation")
        if let tinyCanvas {
            SparklineCGRenderer.drawSparkline(
                in: tinyCanvas,
                rect: CGRect(x: 0, y: 0, width: 2, height: 2),
                values: [0.5],
                capacity: 30,
                domainMax: 1.0,
                tintColor: tint
            )
            XCTAssertTrue(
                isBlank(tinyCanvas, width: 2, height: 2),
                "FM2: the size guard (width/height > 2) must draw nothing at 2 x 2 pt"
            )
        }
    }

    // MARK: - FM3: dual series scale independently, slice per series

    func testFM3DualSeriesScaleIndependentlyWithPerSeriesSlicing() {
        let half = networkRect.height / 2
        let capacity = 30

        // Independent inputs under one shared domain: each series
        // maps through its own values array.
        let uploadValues = [0.0, networkDomain / 4, networkDomain / 2]
        let downloadValues = [networkDomain / 2, networkDomain, 0.0]

        let upload = SparklineCGGeometry.mirroredPoints(
            values: uploadValues,
            capacity: capacity,
            rect: networkRect,
            domainMax: networkDomain,
            aboveBaseline: true
        )
        let download = SparklineCGGeometry.mirroredPoints(
            values: downloadValues,
            capacity: capacity,
            rect: networkRect,
            domainMax: networkDomain,
            aboveBaseline: false
        )

        XCTAssertEqual(upload.count, uploadValues.count, "FM3: upload plots its own array")
        XCTAssertEqual(download.count, downloadValues.count, "FM3: download plots its own array")
        let expectedUploadY: [CGFloat] = [28, 21, 14]
        let expectedDownloadY: [CGFloat] = [42, 56, 28]
        for index in 0..<uploadValues.count {
            XCTAssertEqual(
                upload[index].y, expectedUploadY[index], accuracy: 1e-9,
                "FM3: upload scales independently, sample \(index)"
            )
            XCTAssertEqual(
                download[index].y, expectedDownloadY[index], accuracy: 1e-9,
                "FM3: download scales independently, sample \(index)"
            )
            XCTAssertLessThanOrEqual(
                upload[index].y, half,
                "FM3: upload must stay in the upper half, sample \(index)"
            )
            XCTAssertGreaterThanOrEqual(
                download[index].y, half,
                "FM3: download must stay in the lower half, sample \(index)"
            )
            XCTAssertEqual(
                upload[index].x, download[index].x, accuracy: 1e-9,
                "FM3: both series share the x step, sample \(index)"
            )
        }

        // A changed download input must not move the upload output.
        let uploadAgain = SparklineCGGeometry.mirroredPoints(
            values: uploadValues,
            capacity: capacity,
            rect: networkRect,
            domainMax: networkDomain,
            aboveBaseline: true
        )
        for index in 0..<upload.count {
            XCTAssertEqual(
                uploadAgain[index].x, upload[index].x, accuracy: 1e-12,
                "FM3: an unchanged upload input must reproduce its points, sample \(index)"
            )
            XCTAssertEqual(
                uploadAgain[index].y, upload[index].y, accuracy: 1e-12,
                "FM3: an unchanged upload input must reproduce its points, sample \(index)"
            )
        }
        let downloadChanged = SparklineCGGeometry.mirroredPoints(
            values: [networkDomain, networkDomain / 2, networkDomain / 4, networkDomain / 3],
            capacity: capacity,
            rect: networkRect,
            domainMax: networkDomain,
            aboveBaseline: false
        )
        XCTAssertEqual(downloadChanged.count, 4, "FM3: a new download input re-maps fully")

        // Per-series slicing: each series slices its own array to
        // the newest `capacity` samples (NetworkSparklineView.swift:139).
        let sliceCapacity = 5
        let overflowUpload = (0..<10).map { Double($0) / 9.0 * networkDomain }
        let shortDownload = [0.0, networkDomain / 2, networkDomain]

        let slicedUpload = SparklineCGGeometry.mirroredPoints(
            values: overflowUpload,
            capacity: sliceCapacity,
            rect: networkRect,
            domainMax: networkDomain,
            aboveBaseline: true
        )
        let unslicedDownload = SparklineCGGeometry.mirroredPoints(
            values: shortDownload,
            capacity: sliceCapacity,
            rect: networkRect,
            domainMax: networkDomain,
            aboveBaseline: false
        )

        XCTAssertEqual(slicedUpload.count, sliceCapacity, "FM3: a long series slices to the newest samples")
        XCTAssertEqual(
            slicedUpload[0].y,
            half * (1.0 - 5.0 / 9.0),
            accuracy: 1e-9,
            "FM3: the sliced upload starts at values[5] = 5/9, not values[0]"
        )
        XCTAssertEqual(
            slicedUpload[sliceCapacity - 1].y, 0, accuracy: 1e-9,
            "FM3: the newest upload sample sits at the top"
        )
        XCTAssertEqual(
            unslicedDownload.count, shortDownload.count,
            "FM3: a series below capacity must not slice"
        )
        let unslicedDx = (networkRect.width - inset * 2) / CGFloat(sliceCapacity - 1)
        XCTAssertEqual(
            unslicedDownload[unslicedDownload.count - 1].x,
            networkRect.maxX - inset,
            accuracy: 1e-9,
            "FM3: the newest download sample anchors at the right inset"
        )
        XCTAssertEqual(
            unslicedDownload[unslicedDownload.count - 1].x - unslicedDownload[0].x,
            CGFloat(shortDownload.count - 1) * unslicedDx,
            accuracy: 1e-9,
            "FM3: the warm-up download span keeps the fixed step"
        )

        // Draw contract for the dual series: with both series empty
        // the renderer still draws the central baseline (current
        // Canvas behavior, VAC-6) and no series strokes.
        let baselineCanvas = try? makeBitmap(width: 240, height: 56)
        XCTAssertNotNil(baselineCanvas, "FM3: bitmap allocation")
        if let baselineCanvas {
            SparklineCGRenderer.drawNetworkSparkline(
                in: baselineCanvas,
                rect: networkRect,
                downloadValues: [],
                uploadValues: [],
                capacity: capacity,
                domainMax: networkDomain,
                downloadColor: NSColor.systemBlue.cgColor,
                uploadColor: NSColor.systemRed.cgColor
            )
            XCTAssertTrue(
                hasVisiblePixel(baselineCanvas, width: 240, firstRow: 20, lastRowExclusive: 36),
                "FM3: the central baseline must stay drawn with empty series"
            )
            XCTAssertFalse(
                hasVisiblePixel(baselineCanvas, width: 240, firstRow: 0, lastRowExclusive: 12),
                "FM3: empty upload must draw nothing above the baseline"
            )
            XCTAssertFalse(
                hasVisiblePixel(baselineCanvas, width: 240, firstRow: 44, lastRowExclusive: 56),
                "FM3: empty download must draw nothing below the baseline"
            )
        }
    }

    // MARK: - FM4: value-holder equality mirrors the redraw contract

    /// Compile-time proof that the holder is the representable
    /// wrapper, so `.equatable()` at the call sites can skip
    /// `updateNSView` exactly like the current `.equatable()` on
    /// Canvas views skips the redraw (SparklineView.swift:16-25).
    private func requireNSViewRepresentable<T: NSViewRepresentable>(_ view: T) {}

    func testFM4ValueHolderEqualityMatchesRedrawContract() {
        let base = CGSparklineView(values: [0.1, 0.2], tintColor: .blue, capacity: 30)
        let same = CGSparklineView(values: [0.1, 0.2], tintColor: .blue, capacity: 30)
        XCTAssertEqual(
            base, same,
            "FM4: unchanged inputs must compare equal so the wrapper skips the redraw"
        )
        XCTAssertNotEqual(
            base,
            CGSparklineView(values: [0.1, 0.3], tintColor: .blue, capacity: 30),
            "FM4: a changed value must invalidate"
        )
        XCTAssertNotEqual(
            base,
            CGSparklineView(values: [0.2, 0.1], tintColor: .blue, capacity: 30),
            "FM4: a reordered values array must invalidate"
        )
        XCTAssertNotEqual(
            base,
            CGSparklineView(values: [0.1, 0.2], tintColor: .red, capacity: 30),
            "FM4: a changed tint must invalidate"
        )
        XCTAssertNotEqual(
            base,
            CGSparklineView(values: [0.1, 0.2], tintColor: .blue, domainMax: 2.0, capacity: 30),
            "FM4: a changed domainMax must invalidate"
        )
        XCTAssertNotEqual(
            base,
            CGSparklineView(values: [0.1, 0.2], tintColor: .blue, capacity: 60),
            "FM4: a changed capacity must invalidate"
        )

        let netBase = CGNetworkSparklineView(
            downloadValues: [0, 1024],
            uploadValues: [0, 2048],
            domainMax: networkDomain,
            capacity: 30
        )
        let netSame = CGNetworkSparklineView(
            downloadValues: [0, 1024],
            uploadValues: [0, 2048],
            domainMax: networkDomain,
            capacity: 30
        )
        XCTAssertEqual(
            netBase, netSame,
            "FM4: unchanged network inputs must compare equal"
        )
        XCTAssertNotEqual(
            netBase,
            CGNetworkSparklineView(
                downloadValues: [0, 2048],
                uploadValues: [0, 2048],
                domainMax: networkDomain,
                capacity: 30
            ),
            "FM4: a changed download value must invalidate"
        )
        XCTAssertNotEqual(
            netBase,
            CGNetworkSparklineView(
                downloadValues: [0, 1024],
                uploadValues: [0, 4096],
                domainMax: networkDomain,
                capacity: 30
            ),
            "FM4: a changed upload value must invalidate"
        )
        XCTAssertNotEqual(
            netBase,
            CGNetworkSparklineView(
                downloadValues: [0, 1024],
                uploadValues: [0, 2048],
                domainMax: networkDomain * 2,
                capacity: 30
            ),
            "FM4: a changed network domainMax must invalidate"
        )
        XCTAssertNotEqual(
            netBase,
            CGNetworkSparklineView(
                downloadValues: [0, 1024],
                uploadValues: [0, 2048],
                domainMax: networkDomain,
                capacity: 60
            ),
            "FM4: a changed network capacity must invalidate"
        )

        // The wrappers must be NSViewRepresentable and support the
        // `.equatable()` call-site form.
        requireNSViewRepresentable(base)
        requireNSViewRepresentable(netBase)
        _ = CGSparklineView(values: [], tintColor: .blue, capacity: 30).equatable()
        _ = CGNetworkSparklineView(
            downloadValues: [],
            uploadValues: [],
            domainMax: networkDomain,
            capacity: 30
        ).equatable()
    }
}
