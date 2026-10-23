//
//  TemperatureMetricsTests.swift
//  StatsLiteTests
//
//  Temperature value type (plan 2026-10-23-temp-menu-bar-metric,
//  Phase 1): subsystem-level clamp at init, mirror of the GPUMetrics
//  clamp style, and the CPU/GPU row matrix (FM-T2-1, FM-T2-2).
//

import XCTest
@testable import StatsLite

final class TemperatureMetricsTests: XCTestCase {

    // MARK: - FM-T2-1 init clamp

    func testInitClampsOutOfRangeSubsystemValues() {
        let hot = TemperatureMetrics(cpuCelsius: 200, gpuCelsius: 150)
        XCTAssertEqual(hot.cpuCelsius, 130, "values above 130 clamp at 130 °C")
        XCTAssertEqual(hot.gpuCelsius, 130, "values above 130 clamp at 130 °C")

        let frozen = TemperatureMetrics(cpuCelsius: -40, gpuCelsius: -100)
        XCTAssertEqual(frozen.cpuCelsius, -20, "values below -20 clamp at -20 °C")
        XCTAssertEqual(frozen.gpuCelsius, -20, "values below -20 clamp at -20 °C")
    }

    func testInitKeepsValuesInsidePlausibleRange() {
        let bounds = TemperatureMetrics(cpuCelsius: -20, gpuCelsius: 130)
        XCTAssertEqual(bounds.cpuCelsius, -20, "the lower bound stays untouched")
        XCTAssertEqual(bounds.gpuCelsius, 130, "the upper bound stays untouched")

        let typical = TemperatureMetrics(cpuCelsius: 84, gpuCelsius: 61)
        XCTAssertEqual(typical.cpuCelsius, 84)
        XCTAssertEqual(typical.gpuCelsius, 61)
    }

    func testInitStoresNonFiniteSubsystemValuesAsUnreadable() {
        // A non-finite SMC decode is not a reading. A GPUMetrics-style
        // `min(max(value, -20), 130)` lets NaN survive, so init must
        // guard non-finite input: the stored value becomes nil and the
        // renderer shows "--°". nil keeps the nil-contract; a surviving
        // NaN would reach the menu bar as "nan°".
        for nonFinite in [Double.nan, .infinity, -Double.infinity] {
            let metrics = TemperatureMetrics(
                cpuCelsius: nonFinite,
                gpuCelsius: nonFinite
            )
            XCTAssertNil(
                metrics.cpuCelsius,
                "cpu \(nonFinite) must not survive init"
            )
            XCTAssertNil(
                metrics.gpuCelsius,
                "gpu \(nonFinite) must not survive init"
            )
        }
    }

    func testInitClampsEachSubsystemIndependently() {
        let metrics = TemperatureMetrics(cpuCelsius: .nan, gpuCelsius: 61)
        XCTAssertNil(metrics.cpuCelsius, "a bad CPU read must not poison the GPU row")
        XCTAssertEqual(metrics.gpuCelsius, 61, "the GPU row keeps its reading")
    }

    func testInitKeepsMissingSubsystemNil() {
        let cpuOnly = TemperatureMetrics(cpuCelsius: 84, gpuCelsius: nil)
        XCTAssertNil(cpuOnly.gpuCelsius, "nil subsystem stays nil")

        let gpuOnly = TemperatureMetrics(cpuCelsius: nil, gpuCelsius: 61)
        XCTAssertNil(gpuOnly.cpuCelsius, "nil subsystem stays nil")
    }

    // MARK: - FM-T2-2 row matrix

    func testRowMatrixBothPresentExposesBothReadings() {
        let metrics = TemperatureMetrics(cpuCelsius: 84, gpuCelsius: 61)
        XCTAssertEqual(metrics.cpuCelsius, 84)
        XCTAssertEqual(metrics.gpuCelsius, 61)
        XCTAssertEqual(
            metrics,
            TemperatureMetrics(cpuCelsius: 84, gpuCelsius: 61),
            "equal readings must build equal values (Equatable)"
        )
    }

    func testRowMatrixCPUOnlyLeavesGPURowNil() {
        let metrics = TemperatureMetrics(cpuCelsius: 84, gpuCelsius: nil)
        XCTAssertEqual(metrics.cpuCelsius, 84)
        XCTAssertNil(metrics.gpuCelsius, "the GPU row renders '--°' from nil")
    }

    func testRowMatrixGPUOnlyLeavesCPURowNil() {
        let metrics = TemperatureMetrics(cpuCelsius: nil, gpuCelsius: 61)
        XCTAssertNil(metrics.cpuCelsius, "the CPU row renders '--°' from nil")
        XCTAssertEqual(metrics.gpuCelsius, 61)
    }

    func testRowMatrixNeitherIsBothRowsNil() {
        // The provider returns nil when neither subsystem is readable.
        // At type level the same state is two nil rows, and the
        // renderer maps each nil to the "--°" placeholder
        // (MetricFormatterDegreesTests, FM-T2-3).
        let metrics = TemperatureMetrics(cpuCelsius: nil, gpuCelsius: nil)
        XCTAssertNil(metrics.cpuCelsius)
        XCTAssertNil(metrics.gpuCelsius)
    }
}
