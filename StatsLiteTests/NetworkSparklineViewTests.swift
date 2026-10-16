//
//  NetworkSparklineViewTests.swift
//  StatsLiteTests
//
//  Mirrored dual-series geometry for the network chart: upload maps
//  into the upper half (Y = 28 -> 0), download into the lower half
//  (Y = 28 -> 56), zero sits exactly on the baseline, values clamp
//  to domainMax, and the Equatable contract stays tight so
//  `.equatable()` skips redundant redraws. The coordinate math lives
//  in `NetworkSparklineView.mirroredPlotPoints` so the tests verify
//  it without rendering (same pattern as SparklineView.plotPoints).
//

import SwiftUI
import XCTest
@testable import StatsLite

@MainActor
final class NetworkSparklineViewTests: XCTestCase {

    /// Popover network chart size: 240 pt wide, 56 pt tall.
    private let size = CGSize(width: 240, height: 56)

    /// Central baseline sits at half the chart height (VAC-6: Y = 28).
    private let halfHeight: CGFloat = 28

    /// X inset, same fixed-step pattern as SparklineView.plotPoints.
    private let inset: CGFloat = 1.5

    /// size.width - 2 * inset.
    private var plotWidth: CGFloat { size.width - inset * 2 }

    /// 10 KB/s floor, the shared domainMax the card passes in.
    private let domainMax = 10.0 * 1024.0

    private func uploadPoints(
        values: [Double],
        capacity: Int = 30,
        domainMax: Double? = nil
    ) -> [CGPoint] {
        NetworkSparklineView.mirroredPlotPoints(
            values: values,
            capacity: capacity,
            size: size,
            domainMax: domainMax ?? self.domainMax,
            halfHeight: halfHeight,
            aboveBaseline: true
        )
    }

    private func downloadPoints(
        values: [Double],
        capacity: Int = 30,
        domainMax: Double? = nil
    ) -> [CGPoint] {
        NetworkSparklineView.mirroredPlotPoints(
            values: values,
            capacity: capacity,
            size: size,
            domainMax: domainMax ?? self.domainMax,
            halfHeight: halfHeight,
            aboveBaseline: false
        )
    }

    // MARK: - VAC-8: zero renders on the baseline

    func testZeroValuesSitExactlyOnTheBaseline() {
        let upload = uploadPoints(values: [0, 0, 0])
        let download = downloadPoints(values: [0, 0, 0])

        XCTAssertEqual(upload.count, 3, "zero samples still plot")
        for point in upload {
            XCTAssertEqual(
                point.y, halfHeight, accuracy: 1e-9,
                "zero upload must sit exactly on the baseline, no deflection"
            )
        }
        for point in download {
            XCTAssertEqual(
                point.y, halfHeight, accuracy: 1e-9,
                "zero download must sit exactly on the baseline, no deflection"
            )
        }
    }

    // MARK: - VAC-7: mirrored zones

    func testUploadStaysInUpperHalf() {
        let values = [0.0, domainMax / 2, domainMax, domainMax * 2]
        let points = uploadPoints(values: values)

        XCTAssertEqual(points.count, 4)
        for (index, point) in points.enumerated() {
            XCTAssertLessThanOrEqual(
                point.y, halfHeight,
                "upload sample \(index) must never drop below the baseline"
            )
            XCTAssertGreaterThanOrEqual(
                point.y, 0,
                "upload sample \(index) must never leave the upper half upward"
            )
        }
        XCTAssertEqual(points[0].y, halfHeight, accuracy: 1e-9, "zero sits on the baseline")
        XCTAssertEqual(points[2].y, 0, accuracy: 1e-9, "domainMax reaches the chart top")
    }

    func testDownloadStaysInLowerHalf() {
        let values = [0.0, domainMax / 2, domainMax, domainMax * 2]
        let points = downloadPoints(values: values)

        XCTAssertEqual(points.count, 4)
        for (index, point) in points.enumerated() {
            XCTAssertGreaterThanOrEqual(
                point.y, halfHeight,
                "download sample \(index) must never rise above the baseline"
            )
            XCTAssertLessThanOrEqual(
                point.y, size.height,
                "download sample \(index) must never leave the lower half downward"
            )
        }
        XCTAssertEqual(points[0].y, halfHeight, accuracy: 1e-9, "zero sits on the baseline")
        XCTAssertEqual(
            points[2].y, size.height, accuracy: 1e-9,
            "domainMax reaches the chart bottom"
        )
    }

    func testMirroredPairsAreSymmetricAcrossBaseline() {
        let values = [0.0, domainMax / 4, domainMax / 2, domainMax]
        let up = uploadPoints(values: values)
        let down = downloadPoints(values: values)

        for index in 0..<values.count {
            XCTAssertEqual(
                up[index].y + down[index].y,
                size.height,
                accuracy: 1e-9,
                "sample \(index): upload and download mirror around the baseline"
            )
            XCTAssertEqual(
                up[index].x, down[index].x,
                accuracy: 1e-9,
                "both series share the same x step"
            )
        }
    }

    func testMidDomainSitsAtHalfTheHalfHeight() {
        let up = uploadPoints(values: [domainMax / 2])
        let down = downloadPoints(values: [domainMax / 2])

        XCTAssertEqual(up[0].y, 14.0, accuracy: 1e-9, "half domain sits at Y = 14")
        XCTAssertEqual(down[0].y, 42.0, accuracy: 1e-9, "half domain sits at Y = 42")
    }

    // MARK: - Clamping

    func testValueAboveDomainMaxClampsToChartEdge() {
        let up = uploadPoints(values: [domainMax * 2, domainMax * 10])
        let down = downloadPoints(values: [domainMax * 2, domainMax * 10])

        XCTAssertEqual(up[0].y, 0, accuracy: 1e-9, "over-domain upload clamps to the top")
        XCTAssertEqual(up[1].y, 0, accuracy: 1e-9)
        XCTAssertEqual(
            down[0].y, size.height, accuracy: 1e-9,
            "over-domain download clamps to the bottom"
        )
        XCTAssertEqual(down[1].y, size.height, accuracy: 1e-9)
    }

    func testNegativeValueClampsToBaselineNotBeyond() {
        let up = uploadPoints(values: [-5000])
        let down = downloadPoints(values: [-5000])

        XCTAssertEqual(
            up[0].y, halfHeight, accuracy: 1e-9,
            "negative upload clamps to the baseline"
        )
        XCTAssertEqual(
            down[0].y, halfHeight, accuracy: 1e-9,
            "negative download clamps to the baseline"
        )
    }

    func testZeroDomainMaxUsesEpsilonFloor() {
        let up = uploadPoints(values: [1.0], domainMax: 0)
        let down = downloadPoints(values: [1.0], domainMax: 0)
        let zero = uploadPoints(values: [0.0], domainMax: 0)

        XCTAssertEqual(up[0].y, 0, accuracy: 1e-9, "epsilon keeps v = 1 at the top")
        XCTAssertEqual(down[0].y, size.height, accuracy: 1e-9)
        XCTAssertEqual(zero[0].y, halfHeight, accuracy: 1e-9, "zero stays on the baseline")
    }

    // MARK: - Right-anchored fixed-step horizontal geometry

    func testEmptyValuesProduceNoPoints() {
        XCTAssertTrue(uploadPoints(values: []).isEmpty, "N = 0 plots nothing")
        XCTAssertTrue(downloadPoints(values: []).isEmpty, "N = 0 plots nothing")
    }

    func testSingleSampleDrawsAtRightEdge() {
        let points = uploadPoints(values: [domainMax / 2])

        XCTAssertEqual(points.count, 1, "N = 1 renders one dot")
        XCTAssertEqual(
            points[0].x, size.width - inset, accuracy: 1e-9,
            "the dot anchors at x = width - 1.5"
        )
        let span = points[0].x - points[0].x
        XCTAssertEqual(span, 0, accuracy: 1e-9, "N = 1 must not stroke across the card")
    }

    func testWarmupSpansRightAnchoredWithFixedStep() {
        let capacity = 30
        let values = [1024.0, 2048, 4096, 8192, 10_240]
        let dx = plotWidth / CGFloat(capacity - 1)

        let points = uploadPoints(values: values, capacity: capacity)

        XCTAssertEqual(points.count, values.count)
        XCTAssertEqual(
            points[points.count - 1].x, size.width - inset, accuracy: 1e-9,
            "the newest sample anchors at the right edge"
        )
        XCTAssertEqual(
            points[points.count - 1].x - points[0].x,
            CGFloat(values.count - 1) * dx,
            accuracy: 1e-9,
            "2 <= N < C spans (N-1) * dx"
        )
        for index in 1..<points.count {
            XCTAssertEqual(
                points[index].x - points[index - 1].x, dx, accuracy: 1e-9,
                "adjacent samples keep the fixed step dx"
            )
        }
    }

    func testFullCapacitySpansFullActiveWidth() {
        let capacity = 30
        let values = (0..<capacity).map { Double($0) / Double(capacity - 1) * domainMax }

        let points = downloadPoints(values: values, capacity: capacity)

        XCTAssertEqual(points.count, capacity)
        XCTAssertEqual(points[0].x, inset, accuracy: 1e-9, "N = C starts at the left inset")
        XCTAssertEqual(
            points[capacity - 1].x, size.width - inset, accuracy: 1e-9,
            "N = C ends at the right inset"
        )
        XCTAssertEqual(
            points[capacity - 1].x - points[0].x, plotWidth, accuracy: 1e-9,
            "N = C spans the full active width"
        )
    }

    func testOverflowSlicesToNewestCapacitySamples() {
        let capacity = 5
        let values = (0..<10).map { Double($0) / 9.0 * domainMax }

        let points = uploadPoints(values: values, capacity: capacity)

        XCTAssertEqual(points.count, capacity, "N > C renders only the newest C samples")
        XCTAssertEqual(points[0].x, inset, accuracy: 1e-9)
        XCTAssertEqual(points[capacity - 1].x, size.width - inset, accuracy: 1e-9)
        // values[5] = 5/9 of the domain, not values[0].
        let expectedFirstY = halfHeight * (1.0 - 5.0 / 9.0)
        XCTAssertEqual(points[0].y, expectedFirstY, accuracy: 1e-9, "slice keeps the newest samples")
    }

    // MARK: - Equatable contract for `.equatable()`

    func testEquatableIsTrueForEqualInputs() {
        let base = NetworkSparklineView(
            downloadValues: [0, 1024],
            uploadValues: [0, 2048],
            domainMax: 10_240,
            capacity: 30
        )
        let same = NetworkSparklineView(
            downloadValues: [0, 1024],
            uploadValues: [0, 2048],
            domainMax: 10_240,
            capacity: 30
        )

        XCTAssertEqual(base, same, "equal inputs must compare equal")
    }

    func testEquatableIsFalseForAnyChangedInput() {
        let base = NetworkSparklineView(
            downloadValues: [0, 1024],
            uploadValues: [0, 2048],
            domainMax: 10_240,
            capacity: 30
        )

        XCTAssertNotEqual(
            base,
            NetworkSparklineView(
                downloadValues: [0, 2048],
                uploadValues: [0, 2048],
                domainMax: 10_240,
                capacity: 30
            ),
            "a changed download value must invalidate"
        )
        XCTAssertNotEqual(
            base,
            NetworkSparklineView(
                downloadValues: [0, 1024],
                uploadValues: [0, 4096],
                domainMax: 10_240,
                capacity: 30
            ),
            "a changed upload value must invalidate"
        )
        XCTAssertNotEqual(
            base,
            NetworkSparklineView(
                downloadValues: [0, 1024],
                uploadValues: [0, 2048],
                domainMax: 20_480,
                capacity: 30
            ),
            "a changed domainMax must invalidate"
        )
        XCTAssertNotEqual(
            base,
            NetworkSparklineView(
                downloadValues: [0, 1024],
                uploadValues: [0, 2048],
                domainMax: 10_240,
                capacity: 60
            ),
            "a changed capacity must invalidate"
        )
    }
}
