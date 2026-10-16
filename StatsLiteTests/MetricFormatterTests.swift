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

    // MARK: - Network rate (VAC-7)

    func testNetworkRateFormatsKBRangeAsInteger() {
        XCTAssertEqual(MetricFormatters.networkRate(0), "0 KB/s")
        XCTAssertEqual(MetricFormatters.networkRate(10 * 1024), "10 KB/s")
        XCTAssertEqual(MetricFormatters.networkRate(720 * 1024), "720 KB/s")
        XCTAssertEqual(MetricFormatters.networkRate(999 * 1024), "999 KB/s")
    }

    func testNetworkRateFormatsMBRange() {
        // Exactly 1000 KB/s leaves the KB branch and shows 1.0 MB/s.
        XCTAssertEqual(MetricFormatters.networkRate(1_048_576), "1.0 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(1.6 * 1_048_576), "1.6 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(94.9 * 1_048_576), "94.9 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(100 * 1_048_576), "100 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(119 * 1_048_576), "119 MB/s")
    }

    func testNetworkRateFormatsGBRange() {
        // Exactly 1024 MB/s shows 1.0 GB/s.
        XCTAssertEqual(MetricFormatters.networkRate(1_073_741_824), "1.0 GB/s")
        XCTAssertEqual(MetricFormatters.networkRate(1.2 * 1_073_741_824), "1.2 GB/s")
    }

    func testNetworkRateReturnsPlaceholderForMissingAndNonFiniteValues() {
        XCTAssertEqual(MetricFormatters.networkRate(nil), "-- KB/s")
        XCTAssertEqual(MetricFormatters.networkRate(-1), "-- KB/s")
        XCTAssertEqual(MetricFormatters.networkRate(-0.5 * 1024), "-- KB/s")
        XCTAssertEqual(MetricFormatters.networkRate(.infinity), "-- KB/s")
        XCTAssertEqual(MetricFormatters.networkRate(-Double.infinity), "-- KB/s")
        XCTAssertEqual(MetricFormatters.networkRate(.nan), "-- KB/s")
    }
}
