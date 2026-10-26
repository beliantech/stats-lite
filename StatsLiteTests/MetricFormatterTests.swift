//
//  MetricFormatterTests.swift
//  StatsLiteTests
//
//  Display strings: natural unpadded integer percent clipped at
//  99 (T3 contract, plan 2026-10-25-menubar-item-gap-uniform-
//  minimum, Appendix C) — "0%", "45%", "99%" — with "--%" for
//  missing values, and GB with one decimal.
//

import XCTest
@testable import StatsLite

final class MetricFormatterTests: XCTestCase {

    func testPercentFormatsMissingValueAsHyphens() {
        XCTAssertEqual(MetricFormatters.percent(nil), "--%")
    }

    func testPercentFormatsIntegerValues() {
        XCTAssertEqual(MetricFormatters.percent(0), "0%")
        XCTAssertEqual(MetricFormatters.percent(1), "99%")
        XCTAssertEqual(MetricFormatters.percent(0.144), "14%")
        XCTAssertEqual(MetricFormatters.percent(0.618), "62%")
    }

    func testPercentClampsOutOfRangeValues() {
        XCTAssertEqual(MetricFormatters.percent(-0.5), "0%")
        XCTAssertEqual(MetricFormatters.percent(1.5), "99%")
    }

    func testPercentFormatsNonFiniteValueAsHyphens() {
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

    // MARK: - Network rate (ISC-2, FM1)

    func testNetworkRateFormatsKBRangeAsInteger() {
        XCTAssertEqual(MetricFormatters.networkRate(0), "0 KB/s")
        XCTAssertEqual(MetricFormatters.networkRate(10 * 1024), "10 KB/s")
        // 720 KB/s leaves the KB branch once the rounded value
        // reaches 100: it shows as one-decimal MB/s (ISC-2).
        XCTAssertEqual(MetricFormatters.networkRate(720 * 1024), "0.7 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(999 * 1024), "1.0 MB/s")
    }

    func testNetworkRateFormatsMBRange() {
        // Exactly 1 MiB/s leaves the KB branch and shows 1.0 MB/s.
        XCTAssertEqual(MetricFormatters.networkRate(1_048_576), "1.0 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(1.6 * 1_048_576), "1.6 MB/s")
        // 94.9 MB/s rounds to the integer branch: double digits
        // drop the decimal (appendix B §3).
        XCTAssertEqual(MetricFormatters.networkRate(94.9 * 1_048_576), "95 MB/s")
        // 100 MB/s leaves the MB branch and shows one-decimal GB/s
        // (ISC-2).
        XCTAssertEqual(MetricFormatters.networkRate(100 * 1_048_576), "0.1 GB/s")
        XCTAssertEqual(MetricFormatters.networkRate(119 * 1_048_576), "0.1 GB/s")
    }

    func testNetworkRateDropsDecimalsAtDoubleDigitBoundaries() {
        let mib = 1_048_576.0
        let gib = 1_073_741_824.0
        // 999.5 KB/s rounds up into the MB branch, never 1000 KB/s.
        XCTAssertEqual(MetricFormatters.networkRate(999.5 * 1024), "1.0 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(9.94 * mib), "9.9 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(9.95 * mib), "10 MB/s")
        // 99.9 MB/s rounds to 100 MB/s, which leaves the MB branch
        // for one-decimal GB/s (ISC-2).
        XCTAssertEqual(MetricFormatters.networkRate(99.9 * mib), "0.1 GB/s")
        // 999.4 MB/s leaves the MB branch for one-decimal GB/s
        // (ISC-2).
        XCTAssertEqual(MetricFormatters.networkRate(999.4 * mib), "1.0 GB/s")
        XCTAssertEqual(MetricFormatters.networkRate(999.5 * mib), "1.0 GB/s")
        XCTAssertEqual(MetricFormatters.networkRate(9.95 * gib), "10 GB/s")
    }

    func testNetworkRateNeverExceedsTwoDigitMantissa() {
        // ISC-2 (FM1) width guarantee by construction: the mantissa
        // (the part before the space) never exceeds two digits, so no
        // output can carry a 3+ digit integer part or a decimal on a
        // double-digit value such as "10.0". Units switch at 100 and
        // the GB ceiling clamps at 99, so no mantissa grows past two
        // digits. Sweeps 0…20 GB/s across every switch point ±
        // epsilon.
        let pattern = #"^(--|\d{1,2}|\d\.\d) (KB|MB|GB)/s$"#
        let kib = 1024.0
        let mib = 1_048_576.0
        let gib = 1_073_741_824.0
        let boundaries: [Double] = [
            99.4 * kib, 99.5 * kib, 100 * kib,  // KB → MB switch at 100
            99.4 * mib, 99.5 * mib, 100 * mib,  // MB → GB switch at 100
            99.4 * gib, 99.5 * gib, 100 * gib   // GB ceiling clamp
        ]
        var sweep: [Double] = [0]
        for boundary in boundaries {
            sweep.append(contentsOf: [
                boundary - 1, boundary - 0.001, boundary,
                boundary + 0.001, boundary + 1
            ])
        }
        var value = 512 * kib
        while value <= 20 * gib {
            sweep.append(value)
            value += gib / 1013.0
        }

        for rate in sweep {
            let output = MetricFormatters.networkRate(rate)
            XCTAssertNotNil(
                output.range(of: pattern, options: .regularExpression),
                "rate \(rate) B/s produced \"\(output)\", whose mantissa exceeds two digits (ISC-2, FM1)"
            )
        }
        XCTAssertNotNil(
            "-- KB/s".range(of: pattern, options: .regularExpression),
            "the missing-value placeholder must also fit the two-digit mantissa budget (ISC-2, FM1)"
        )
    }

    func testNetworkRateSwitchesUnitsAtHundredAndClampsAt99GBPerSecond() {
        // ISC-2 (FM1): units switch at 100, so no mantissa exceeds
        // two digits; the GB ceiling clamps at 99 GB/s.
        let mib = 1_048_576.0
        let gib = 1_073_741_824.0
        XCTAssertEqual(MetricFormatters.networkRate(99.4 * 1024), "99 KB/s")
        XCTAssertEqual(MetricFormatters.networkRate(99.5 * 1024), "0.1 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(400 * 1024), "0.4 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(999 * 1024), "1.0 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(99.4 * mib), "99 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(99.5 * mib), "0.1 GB/s")
        XCTAssertEqual(MetricFormatters.networkRate(400 * mib), "0.4 GB/s")
        XCTAssertEqual(MetricFormatters.networkRate(99.5 * gib), "99 GB/s")
        XCTAssertEqual(MetricFormatters.networkRate(512 * gib), "99 GB/s")
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
