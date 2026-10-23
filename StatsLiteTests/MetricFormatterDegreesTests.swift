//
//  MetricFormatterDegreesTests.swift
//  StatsLiteTests
//
//  Degrees formatter (plan 2026-10-23-temp-menu-bar-metric, Phase 1):
//  the per-row value in "CPU 84°" / "GPU 61°". Whole-degree rounding,
//  "--°" placeholder for a missing or non-finite reading (FM-T2-3).
//

import XCTest
@testable import StatsLite

final class MetricFormatterDegreesTests: XCTestCase {

    func testDegreesFormatsWholeValues() {
        XCTAssertEqual(MetricFormatters.degrees(84), "84°")
        XCTAssertEqual(MetricFormatters.degrees(61), "61°")
    }

    func testDegreesRoundsToWholeDegree() {
        XCTAssertEqual(MetricFormatters.degrees(83.6), "84°", "rounds up to the whole degree")
        XCTAssertEqual(MetricFormatters.degrees(83.4), "83°", "rounds down to the whole degree")
    }

    /// A nil value is both the unreadable-subsystem row (FM-T2-2
    /// CPU-only / GPU-only) and the both-nil return of the provider
    /// (FM-T2-4). Each row renders "--°", never "0°" and never an
    /// empty string.
    func testDegreesFormatsMissingValueAsPlaceholder() {
        XCTAssertEqual(MetricFormatters.degrees(nil), "--°")
    }

    func testDegreesFormatsNegativeValue() {
        XCTAssertEqual(MetricFormatters.degrees(-5), "-5°", "a plausible negative reading keeps its sign")
    }

    func testDegreesFormatsThreeDigitValue() {
        XCTAssertEqual(MetricFormatters.degrees(100), "100°", "3-digit values format in full")
    }

    func testDegreesFormatsNonFiniteValueAsPlaceholder() {
        // "nan°" or "inf°" in the menu bar is a display defect. The
        // formatter guards non-finite input itself, like percent does.
        XCTAssertEqual(MetricFormatters.degrees(.nan), "--°")
        XCTAssertEqual(MetricFormatters.degrees(.infinity), "--°")
        XCTAssertEqual(MetricFormatters.degrees(-Double.infinity), "--°")
    }
}
