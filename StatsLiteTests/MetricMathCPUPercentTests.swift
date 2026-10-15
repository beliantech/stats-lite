//
//  MetricMathCPUPercentTests.swift
//  StatsLiteTests
//
//  CPU % math: first sample, zero delta, counter rollover, clamping.
//  The math is pure, so every case is a fixed pair of tick samples.
//

import XCTest
@testable import StatsLite

final class MetricMathCPUPercentTests: XCTestCase {

    func testFirstSampleReturnsZero() {
        let current = CoreTickSample(user: 100, system: 50, idle: 800, nice: 0)
        XCTAssertEqual(MetricMath.computePercentages(previous: nil, current: current), 0.0)
    }

    func testZeroDeltaReturnsZero() {
        let previous = CoreTickSample(user: 100, system: 50, idle: 800, nice: 0)
        let current = CoreTickSample(user: 100, system: 50, idle: 800, nice: 0)
        XCTAssertEqual(MetricMath.computePercentages(previous: previous, current: current), 0.0)
    }

    func testCounterRolloverReturnsZero() {
        // The current total is smaller than the previous total, so the
        // counters wrapped and the delta is unusable.
        let previous = CoreTickSample(user: 1_000, system: 500, idle: 8_000, nice: 0)
        let current = CoreTickSample(user: 1, system: 1, idle: 2, nice: 0)
        XCTAssertEqual(MetricMath.computePercentages(previous: previous, current: current), 0.0)
    }

    func testBusyShareIsComputedFromDeltas() {
        // busy delta = 100, total delta = 200 → 50 %.
        let previous = CoreTickSample(user: 100, system: 100, idle: 800, nice: 0)
        let current = CoreTickSample(user: 150, system: 150, idle: 900, nice: 0)
        XCTAssertEqual(
            MetricMath.computePercentages(previous: previous, current: current),
            0.5,
            accuracy: 1e-9
        )
    }

    func testNiceTicksCountAsBusy() {
        // busy delta = 100 (nice only), total delta = 100 → 100 %.
        let previous = CoreTickSample(user: 0, system: 0, idle: 900, nice: 100)
        let current = CoreTickSample(user: 0, system: 0, idle: 900, nice: 200)
        XCTAssertEqual(
            MetricMath.computePercentages(previous: previous, current: current),
            1.0,
            accuracy: 1e-9
        )
    }

    func testResultClampsToUnitRange() {
        // busy delta (60) exceeds total delta (10) → clamped to 1.
        let over = MetricMath.computePercentages(
            previous: CoreTickSample(user: 0, system: 0, idle: 100, nice: 0),
            current: CoreTickSample(user: 60, system: 0, idle: 50, nice: 0)
        )
        XCTAssertEqual(over, 1.0)

        // busy delta (-40) is negative while total delta is positive → clamped to 0.
        let under = MetricMath.computePercentages(
            previous: CoreTickSample(user: 50, system: 0, idle: 50, nice: 0),
            current: CoreTickSample(user: 10, system: 0, idle: 100, nice: 0)
        )
        XCTAssertEqual(under, 0.0)
    }

    func testOutputStaysInRangeForLongSizedDeltas() {
        let previous = CoreTickSample(user: 0, system: 0, idle: 0, nice: 0)
        let current = CoreTickSample(user: 4, system: 2, idle: 94, nice: 0)
        let usage = MetricMath.computePercentages(previous: previous, current: current)
        XCTAssertGreaterThanOrEqual(usage, 0.0)
        XCTAssertLessThanOrEqual(usage, 1.0)
        XCTAssertEqual(usage, 0.06, accuracy: 1e-9)
    }
}
