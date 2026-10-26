//
//  MenuBarAccessibilityTests.swift
//  StatsLiteTests
//
//  Pure-logic checks for the menu bar accessibility label and the
//  pressure-level color derivation used by the UI. The composite
//  label reports the memory-pressure percent ("at 25 percent") and
//  marks a missing percent as unavailable. The block builder has
//  its own suite.
//

import XCTest
@testable import StatsLite

final class MenuBarAccessibilityTests: XCTestCase {

    // MARK: - Composite VoiceOver label

    func testCompositeLabelAllThreeMetrics() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            cpuPercent: 0.14,
            pressurePercent: 0.25,
            pressure: .normal,
            gpuPercent: 0.28
        )
        XCTAssertEqual(
            label,
            "Stats Lite: CPU 14 percent, GPU 28 percent, Memory Pressure Normal at 25 percent"
        )
    }

    func testCompositeLabelGPUUnavailable() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            cpuPercent: 0.14,
            pressurePercent: 0.62,
            pressure: .warning,
            gpuPercent: nil
        )
        XCTAssertEqual(
            label,
            "Stats Lite: CPU 14 percent, GPU unavailable, Memory Pressure Warning at 62 percent"
        )
    }

    func testCompositeLabelMemoryPressureUnavailable() {
        // A missing percent wins over the state: no figure, no claim.
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            cpuPercent: 0.14,
            pressurePercent: nil,
            pressure: .critical,
            gpuPercent: 0.28
        )
        XCTAssertEqual(
            label,
            "Stats Lite: CPU 14 percent, GPU 28 percent, Memory Pressure unavailable"
        )
    }

    func testCompositeLabelCPUUnavailable() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            cpuPercent: nil,
            pressurePercent: 0.68,
            pressure: .warning,
            gpuPercent: 0.28
        )
        XCTAssertEqual(
            label,
            "Stats Lite: CPU unavailable, GPU 28 percent, Memory Pressure Warning at 68 percent"
        )
    }

    func testCompositeLabelSingleMetricOmitsOtherParts() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: false,
            showGPU: false,
            cpuPercent: 0.5,
            pressurePercent: nil,
            pressure: .normal,
            gpuPercent: nil
        )
        XCTAssertEqual(label, "Stats Lite: CPU 50 percent")
    }

    func testCompositeLabelRoundsAndClampsPercent() {
        let high = MenuBarAccessibility.compositeLabel(
            showCPU: true, showRAM: false, showGPU: false,
            cpuPercent: 1.8, pressurePercent: nil, pressure: .normal, gpuPercent: nil
        )
        XCTAssertEqual(high, "Stats Lite: CPU 100 percent")

        let low = MenuBarAccessibility.compositeLabel(
            showCPU: true, showRAM: false, showGPU: false,
            cpuPercent: -0.2, pressurePercent: nil, pressure: .normal, gpuPercent: nil
        )
        XCTAssertEqual(low, "Stats Lite: CPU 0 percent")

        let pressureHigh = MenuBarAccessibility.compositeLabel(
            showCPU: false, showRAM: true, showGPU: false,
            cpuPercent: nil, pressurePercent: 1.8, pressure: .normal, gpuPercent: nil
        )
        XCTAssertEqual(
            pressureHigh,
            "Stats Lite: Memory Pressure Normal at 100 percent"
        )

        let pressureLow = MenuBarAccessibility.compositeLabel(
            showCPU: false, showRAM: true, showGPU: false,
            cpuPercent: nil, pressurePercent: -0.2, pressure: .normal, gpuPercent: nil
        )
        XCTAssertEqual(
            pressureLow,
            "Stats Lite: Memory Pressure Normal at 0 percent"
        )
    }

    // MARK: - Pressure display state thresholds

    func testUnknownStateDerivesFromPressureThresholds() {
        XCTAssertEqual(MemoryPressureState.unknown.displayState(pressure: 0.2), .normal)
        XCTAssertEqual(MemoryPressureState.unknown.displayState(pressure: 0.6), .warning)
        XCTAssertEqual(MemoryPressureState.unknown.displayState(pressure: 0.8), .warning)
        XCTAssertEqual(MemoryPressureState.unknown.displayState(pressure: 0.81), .critical)
    }

    func testKnownStateWinsOverPressureFigure() {
        XCTAssertEqual(MemoryPressureState.critical.displayState(pressure: 0.1), .critical)
        XCTAssertEqual(MemoryPressureState.normal.displayState(pressure: 0.95), .normal)
    }

    // MARK: - Network segment (VAC-C10)

    func testCompositeLabelWithNetworkRates() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            showNetwork: true,
            cpuPercent: 0.14,
            pressurePercent: 0.25,
            pressure: .normal,
            gpuPercent: 0.28,
            downloadRate: 720 * 1024,
            uploadRate: 10 * 1024
        )
        XCTAssertEqual(
            label,
            "Stats Lite: CPU 14 percent, "
                + "GPU 28 percent, Memory Pressure Normal at 25 percent, "
                + "Network Upload 10 KB/s, Download 720 KB/s"
        )
    }

    func testCompositeLabelNetworkUnavailableWhenRatesMissing() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            showNetwork: true,
            cpuPercent: 0.14,
            pressurePercent: 0.25,
            pressure: .normal,
            gpuPercent: 0.28,
            downloadRate: nil,
            uploadRate: nil
        )
        XCTAssertEqual(
            label,
            "Stats Lite: CPU 14 percent, "
                + "GPU 28 percent, Memory Pressure Normal at 25 percent, "
                + "Network unavailable"
        )
    }

    func testCompositeLabelNetworkOnly() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: false,
            showRAM: false,
            showGPU: false,
            showNetwork: true,
            cpuPercent: nil,
            pressurePercent: nil,
            pressure: .normal,
            gpuPercent: nil,
            downloadRate: 1.6 * 1_048_576,
            uploadRate: 22 * 1024
        )
        XCTAssertEqual(
            label,
            "Stats Lite: Network Upload 22 KB/s, Download 1.6 MB/s"
        )
    }

    func testCompositeLabelNetworkFollowsCPUWhenOtherMetricsOff() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: false,
            showGPU: false,
            showNetwork: true,
            cpuPercent: 0.5,
            pressurePercent: nil,
            pressure: .normal,
            gpuPercent: nil,
            downloadRate: 720 * 1024,
            uploadRate: 10 * 1024
        )
        XCTAssertEqual(
            label,
            "Stats Lite: CPU 50 percent, Network Upload 10 KB/s, Download 720 KB/s"
        )
    }

    func testCompositeLabelIgnoresRatesWhenNetworkOff() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            showNetwork: false,
            cpuPercent: 0.14,
            pressurePercent: 0.25,
            pressure: .normal,
            gpuPercent: 0.28,
            downloadRate: 720 * 1024,
            uploadRate: 10 * 1024
        )
        XCTAssertEqual(
            label,
            "Stats Lite: CPU 14 percent, GPU 28 percent, Memory Pressure Normal at 25 percent"
        )
    }

    // MARK: - Card value formatter (one decimal percent)

    func testPercentTenthFormats() {
        XCTAssertEqual(MetricFormatters.percentTenth(0.24), "24.0%")
        XCTAssertEqual(MetricFormatters.percentTenth(1.0), "100.0%")
        XCTAssertEqual(MetricFormatters.percentTenth(0.0), "0.0%")
        XCTAssertEqual(MetricFormatters.percentTenth(nil), "--%")
        XCTAssertEqual(MetricFormatters.percentTenth(.nan), "--%")
        XCTAssertEqual(MetricFormatters.percentTenth(1.5), "100.0%")
    }
}
