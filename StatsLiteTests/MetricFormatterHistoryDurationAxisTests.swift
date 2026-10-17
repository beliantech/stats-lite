//
//  MetricFormatterHistoryDurationAxisTests.swift
//  StatsLiteTests
//
//  History window duration for the shared sparkline time axis:
//  human units ("-30s", "-1m", "-5m"), never raw "-120s".
//  Pins MetricFormatters.historyDurationAxis (plan ISC-2, T1).
//

import XCTest
@testable import StatsLite

final class MetricFormatterHistoryDurationAxisTests: XCTestCase {

    // MARK: - Duration settings (plan State & Duration Matrix)

    func testHistoryDurationAxisFormatsAllDurationSettings() {
        XCTAssertEqual(MetricFormatters.historyDurationAxis(30), "-30s")
        XCTAssertEqual(MetricFormatters.historyDurationAxis(60), "-1m")
        XCTAssertEqual(MetricFormatters.historyDurationAxis(120), "-2m")
        XCTAssertEqual(MetricFormatters.historyDurationAxis(180), "-3m")
        XCTAssertEqual(MetricFormatters.historyDurationAxis(300), "-5m")
    }

    // MARK: - Under-60-seconds branch

    func testHistoryDurationAxisUsesSecondsUnderSixty() {
        XCTAssertEqual(MetricFormatters.historyDurationAxis(45), "-45s")
        XCTAssertEqual(MetricFormatters.historyDurationAxis(0), "-0s")
    }

    // MARK: - Negative clamp

    func testHistoryDurationAxisClampsNegativeSecondsToZero() {
        XCTAssertEqual(MetricFormatters.historyDurationAxis(-5), "-0s")
    }

    // MARK: - Non-finite guard (Int(NaN) traps at runtime)

    func testHistoryDurationAxisReturnsZeroSecondsForNonFiniteInput() {
        XCTAssertEqual(MetricFormatters.historyDurationAxis(.nan), "-0s")
        XCTAssertEqual(MetricFormatters.historyDurationAxis(.infinity), "-0s")
    }
}
