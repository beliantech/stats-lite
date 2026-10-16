//
//  SparklineViewTests.swift
//  StatsLiteTests
//
//  AC-9: fixed-step right-anchored geometry. AC-10: capacity derived
//  from historyDuration and refreshInterval. The coordinate math lives
//  in SparklineView.plotPoints so the tests verify it without
//  rendering.
//

import SwiftUI
import XCTest
@testable import StatsLite

@MainActor
final class SparklineViewTests: XCTestCase {

    /// Popover sparkline size: 240 pt content width, 38 pt height.
    private let size = CGSize(width: 240, height: 38)
    private let inset: CGFloat = 1.5

    /// size.width - 2 * inset.
    private var plotWidth: CGFloat { size.width - inset * 2 }

    // MARK: - AC-9: geometry

    func testZeroSamplesProduceNoPath() {
        let points = SparklineView.plotPoints(
            values: [],
            capacity: 30,
            size: size,
            domainMax: 1.0
        )
        XCTAssertTrue(points.isEmpty, "N = 0 must produce no stroke and no fill")
    }

    func testSingleSampleDrawsDotAtRightEdgeNotFullWidthStroke() {
        let points = SparklineView.plotPoints(
            values: [0.5],
            capacity: 30,
            size: size,
            domainMax: 1.0
        )

        XCTAssertEqual(points.count, 1, "N = 1 renders one dot")
        let dot = points[0]
        XCTAssertEqual(dot.x, size.width - inset, accuracy: 1e-9, "dot anchors at x = width - 1.5")
        XCTAssertEqual(dot.y, 19.0, accuracy: 1e-9, "0.5 of the domain sits at mid height")

        // A stroke built from one repeated point spans zero width, so
        // no full-width flat line can be drawn.
        let span = points[points.count - 1].x - points[0].x
        XCTAssertEqual(span, 0, accuracy: 1e-9, "N = 1 must not stroke across the card width")
    }

    func testWarmupSpansRightAnchoredWithFixedStep() {
        let capacity = 30
        let values = [0.1, 0.2, 0.3, 0.4, 0.5]
        let n = values.count
        let dx = plotWidth / CGFloat(capacity - 1)

        let points = SparklineView.plotPoints(
            values: values,
            capacity: capacity,
            size: size,
            domainMax: 1.0
        )

        XCTAssertEqual(points.count, n)
        XCTAssertEqual(
            points[n - 1].x,
            size.width - inset,
            accuracy: 1e-9,
            "the newest sample anchors at the right edge"
        )
        XCTAssertEqual(
            points[n - 1].x - points[0].x,
            CGFloat(n - 1) * dx,
            accuracy: 1e-9,
            "2 <= N < C spans (N-1) * dx"
        )
        XCTAssertGreaterThan(
            points[0].x - inset,
            0,
            "the region left of the warm-up span stays empty"
        )
        for index in 1..<n {
            XCTAssertEqual(
                points[index].x - points[index - 1].x,
                dx,
                accuracy: 1e-9,
                "adjacent samples keep the fixed step dx"
            )
        }
    }

    func testFullCapacitySpansFullActiveWidth() {
        let capacity = 30
        let values = (0..<capacity).map { Double($0) / Double(capacity - 1) }

        let points = SparklineView.plotPoints(
            values: values,
            capacity: capacity,
            size: size,
            domainMax: 1.0
        )

        XCTAssertEqual(points.count, capacity)
        XCTAssertEqual(points[0].x, inset, accuracy: 1e-9, "N = C starts at the left inset")
        XCTAssertEqual(
            points[capacity - 1].x,
            size.width - inset,
            accuracy: 1e-9,
            "N = C ends at the right inset"
        )
        XCTAssertEqual(
            points[capacity - 1].x - points[0].x,
            plotWidth,
            accuracy: 1e-9,
            "N = C spans the full active width"
        )
    }

    func testOverflowSlicesToNewestCapacitySamples() {
        let capacity = 5
        let values = (0..<10).map { Double($0) / 9.0 }
        let dx = plotWidth / CGFloat(capacity - 1)

        let points = SparklineView.plotPoints(
            values: values,
            capacity: capacity,
            size: size,
            domainMax: 1.0
        )

        XCTAssertEqual(points.count, capacity, "N > C renders only the newest C samples")
        XCTAssertEqual(points[0].x, inset, accuracy: 1e-9)
        XCTAssertEqual(points[capacity - 1].x, size.width - inset, accuracy: 1e-9)
        XCTAssertEqual(
            points[capacity - 1].x - points[0].x,
            plotWidth,
            accuracy: 1e-9,
            "the slice spans the full active width"
        )
        // The first rendered sample is values[5] = 5/9 (the suffix
        // slice), not values[0] = 0.
        let expectedFirstY = inset + (1.0 - 5.0 / 9.0) * (size.height - inset * 2)
        XCTAssertEqual(points[0].y, expectedFirstY, accuracy: 1e-9, "slice keeps the newest samples")
        XCTAssertEqual(
            points[capacity - 1].y,
            inset,
            accuracy: 1e-9,
            "the newest value (1.0) sits at the top inset"
        )
        for index in 1..<capacity {
            XCTAssertEqual(points[index].x - points[index - 1].x, dx, accuracy: 1e-9)
        }
    }

    func testValueBelowZeroClampsToBottomInset() {
        let points = SparklineView.plotPoints(
            values: [-0.5, 0.5],
            capacity: 30,
            size: size,
            domainMax: 1.0
        )

        XCTAssertEqual(
            points[0].y,
            size.height - inset,
            accuracy: 1e-9,
            "v < 0 clamps to the bottom inset"
        )
    }

    func testValueAboveDomainMaxClampsToTopInset() {
        let points = SparklineView.plotPoints(
            values: [2.0, 0.5],
            capacity: 30,
            size: size,
            domainMax: 1.0
        )

        XCTAssertEqual(points[0].y, inset, accuracy: 1e-9, "v > domainMax clamps to the top inset")
    }

    func testZeroDomainMaxUsesEpsilonFloor() {
        let high = SparklineView.plotPoints(
            values: [1.0],
            capacity: 30,
            size: size,
            domainMax: 0
        )
        let low = SparklineView.plotPoints(
            values: [0.0],
            capacity: 30,
            size: size,
            domainMax: 0
        )

        XCTAssertEqual(
            high[0].y,
            inset,
            accuracy: 1e-9,
            "the 0.0001 epsilon keeps v = 1 at the top instead of dividing by zero"
        )
        XCTAssertEqual(low[0].y, size.height - inset, accuracy: 1e-9)
    }

    // MARK: - AC-9: Equatable

    func testEquatableIsTrueForEqualValuesTintAndCapacity() {
        let base = SparklineView(values: [0.1, 0.2], tintColor: .blue, capacity: 30)
        let same = SparklineView(values: [0.1, 0.2], tintColor: .blue, capacity: 30)

        XCTAssertEqual(base, same, "equal values, tint, and capacity must compare equal")
    }

    func testEquatableIsFalseForAnyChangedInput() {
        let base = SparklineView(values: [0.1, 0.2], tintColor: .blue, capacity: 30)

        XCTAssertNotEqual(
            base,
            SparklineView(values: [0.1, 0.3], tintColor: .blue, capacity: 30),
            "a changed value must invalidate"
        )
        XCTAssertNotEqual(
            base,
            SparklineView(values: [0.1, 0.2], tintColor: .red, capacity: 30),
            "a changed tint must invalidate"
        )
        XCTAssertNotEqual(
            base,
            SparklineView(values: [0.1, 0.2], tintColor: .blue, capacity: 60),
            "a changed capacity must invalidate"
        )
        XCTAssertNotEqual(
            base,
            SparklineView(values: [0.1, 0.2], tintColor: .blue, domainMax: 2.0, capacity: 30),
            "a changed domainMax must invalidate"
        )
    }

    // MARK: - AC-10: preference-derived capacity

    func testSparklineCapacityForEveryHistoryAndIntervalCombination() {
        // historyDuration x refreshInterval -> expected capacity.
        // The table covers all 5 history windows x 4 intervals.
        // 60 s at 1 s must stay 60: no silent truncation to 30.
        let expected: [(history: Int, interval: Int, capacity: Int)] = [
            (30, 1, 30),
            (30, 2, 15),
            (30, 3, 10),
            (30, 5, 6),
            (60, 1, 60),
            (60, 2, 30),
            (60, 3, 20),
            (60, 5, 12),
            (120, 1, 120),
            (120, 2, 60),
            (120, 3, 40),
            (120, 5, 24),
            (180, 1, 180),
            (180, 2, 90),
            (180, 3, 60),
            (180, 5, 36),
            (300, 1, 300),
            (300, 2, 150),
            (300, 3, 100),
            (300, 5, 60),
        ]

        for combo in expected {
            let monitor = SystemMonitor(provider: FakeSystemMetricsProvider())
            monitor.historyDuration = TimeInterval(combo.history)
            monitor.refreshInterval = TimeInterval(combo.interval)

            XCTAssertEqual(
                monitor.sparklineCapacity,
                combo.capacity,
                "capacity for historyDuration \(combo.history) s and refreshInterval \(combo.interval) s"
            )

            // At N = capacity the sparkline reaches 100 % active card
            // width: no empty region on either side.
            let capacity = monitor.sparklineCapacity
            let values = (0..<capacity).map { Double($0) / Double(capacity - 1) }
            let points = SparklineView.plotPoints(
                values: values,
                capacity: capacity,
                size: size,
                domainMax: 1.0
            )
            XCTAssertEqual(points[0].x, inset, accuracy: 1e-9, "left edge reaches the inset")
            XCTAssertEqual(
                points[capacity - 1].x,
                size.width - inset,
                accuracy: 1e-9,
                "right edge reaches the inset"
            )
        }
    }

    func testSparklineCapacityHasFloorOfTwoSamples() {
        let monitor = SystemMonitor(provider: FakeSystemMetricsProvider())
        monitor.historyDuration = 2
        monitor.refreshInterval = 5

        XCTAssertEqual(monitor.sparklineCapacity, 2, "the step denominator needs at least 2 samples")
    }
}
