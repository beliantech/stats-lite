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

    // MARK: - Network rate (VAC-N3, F11)

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
        // 94.9 MB/s now rounds to the integer branch: double digits
        // drop the decimal (appendix B §3).
        XCTAssertEqual(MetricFormatters.networkRate(94.9 * 1_048_576), "95 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(100 * 1_048_576), "100 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(119 * 1_048_576), "119 MB/s")
    }

    func testNetworkRateDropsDecimalsAtDoubleDigitBoundaries() {
        let mib = 1_048_576.0
        let gib = 1_073_741_824.0
        // 999.5 KB/s rounds up into the MB branch, never 1000 KB/s.
        XCTAssertEqual(MetricFormatters.networkRate(999.5 * 1024), "1.0 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(9.94 * mib), "9.9 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(9.95 * mib), "10 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(99.9 * mib), "100 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(999.4 * mib), "999 MB/s")
        XCTAssertEqual(MetricFormatters.networkRate(999.5 * mib), "1.0 GB/s")
        XCTAssertEqual(MetricFormatters.networkRate(9.95 * gib), "10 GB/s")
    }

    func testNetworkRateNeverExceedsThreeCharacterMantissa() {
        // F11 width guarantee by construction: the mantissa (the part
        // before the space) never exceeds 3 characters, so no output
        // can have a 4+ digit integer part or a 4-character decimal
        // such as "10.0" or "99.9". Sweeps 0…20 GB/s across every
        // formatter boundary ± epsilon.
        let pattern = #"^(--|\d{1,3}|\d\.\d) (KB|MB|GB)/s$"#
        let kib = 1024.0
        let mib = 1_048_576.0
        let gib = 1_073_741_824.0
        let boundaries: [Double] = [
            999 * kib, 999.5 * kib, 1000 * kib, // KB → MB border
            9.94 * mib, 9.95 * mib, 10 * mib,           // MB decimal cutoff
            99.4 * mib, 99.5 * mib, 100 * mib,          // old one-decimal clip
            999.4 * mib, 999.5 * mib, 1000 * mib,       // MB → GB border
            9.94 * gib, 9.95 * gib, 10 * gib            // GB decimal cutoff
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
                "rate \(rate) B/s produced \"\(output)\", whose mantissa exceeds 3 characters (F11)"
            )
        }
        XCTAssertNotNil(
            "-- KB/s".range(of: pattern, options: .regularExpression),
            "the missing-value placeholder must also fit the 3-character mantissa budget"
        )
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
