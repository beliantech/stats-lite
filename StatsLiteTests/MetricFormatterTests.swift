//
//  MetricFormatterTests.swift
//  StatsLiteTests
//
//  Display strings: integer percent with "--%" for missing values,
//  and GB with one decimal.
//

import XCTest
@testable import StatsLite

final class MetricFormatterTests: XCTestCase {

    func testPercentFormatsMissingValueAsDoubleDash() {
        XCTAssertEqual(MetricFormatters.percent(nil), "--%")
    }

    func testPercentFormatsIntegerValues() {
        XCTAssertEqual(MetricFormatters.percent(0), "0%")
        XCTAssertEqual(MetricFormatters.percent(1), "100%")
        XCTAssertEqual(MetricFormatters.percent(0.144), "14%")
        XCTAssertEqual(MetricFormatters.percent(0.618), "62%")
    }

    func testPercentClampsOutOfRangeValues() {
        XCTAssertEqual(MetricFormatters.percent(-0.5), "0%")
        XCTAssertEqual(MetricFormatters.percent(1.5), "100%")
    }

    func testPercentFormatsNonFiniteValueAsDoubleDash() {
        XCTAssertEqual(MetricFormatters.percent(.nan), "--%")
    }

    func testGigabytesFormatsOneDecimal() {
        let gib: UInt64 = 1_073_741_824
        XCTAssertEqual(MetricFormatters.gigabytes(0), "0.0 GB")
        XCTAssertEqual(MetricFormatters.gigabytes(gib), "1.0 GB")
        XCTAssertEqual(MetricFormatters.gigabytes(5_905_580_032), "5.5 GB")
        XCTAssertEqual(MetricFormatters.gigabytes(10_630_044_058), "9.9 GB")
        XCTAssertEqual(MetricFormatters.gigabytes(16 * gib), "16.0 GB")
    }
}
