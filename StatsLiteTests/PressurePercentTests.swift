//
//  PressurePercentTests.swift
//  StatsLiteTests
//
//  Memory pressure percentage: kernel availability read, per-level
//  fallback when that read fails, and the unknown state.
//

import XCTest
@testable import StatsLite

final class PressurePercentTests: XCTestCase {

    func testPressureUsesAvailabilityReadWhenPresent() {
        // availability 40 % → pressure (100 - 40) / 100 = 0.6.
        XCTAssertEqual(
            MetricMath.computePressurePercentage(state: .normal, availabilityPercent: 40),
            0.6,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            MetricMath.computePressurePercentage(state: .warning, availabilityPercent: 20),
            0.8,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            MetricMath.computePressurePercentage(state: .critical, availabilityPercent: 5),
            0.95,
            accuracy: 1e-9
        )
    }

    func testPressureClampsAvailabilityToUnitRange() {
        // 150 % availability → pressure below 0 → clamped to 0.
        XCTAssertEqual(
            MetricMath.computePressurePercentage(state: .normal, availabilityPercent: 150),
            0.0
        )
        // -20 % availability → pressure above 1 → clamped to 1.
        XCTAssertEqual(
            MetricMath.computePressurePercentage(state: .critical, availabilityPercent: -20),
            1.0
        )
    }

    func testFallbackUsesFixedValuePerLevelWhenReadFailed() {
        XCTAssertEqual(
            MetricMath.computePressurePercentage(state: .normal, availabilityPercent: nil),
            0.15,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            MetricMath.computePressurePercentage(state: .warning, availabilityPercent: nil),
            0.65,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            MetricMath.computePressurePercentage(state: .critical, availabilityPercent: nil),
            0.90,
            accuracy: 1e-9
        )
    }

    func testUnknownStateReturnsZero() {
        XCTAssertEqual(
            MetricMath.computePressurePercentage(state: .unknown, availabilityPercent: nil),
            0.0
        )
        // An unknown level is unknown even when the availability read worked.
        XCTAssertEqual(
            MetricMath.computePressurePercentage(state: .unknown, availabilityPercent: 40),
            0.0
        )
    }
}
