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
            "Stats Lite: CPU 14 percent, Memory Pressure Normal at 25 percent, GPU 28 percent"
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
            "Stats Lite: CPU 14 percent, Memory Pressure Warning at 62 percent, GPU unavailable"
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
            "Stats Lite: CPU 14 percent, Memory Pressure unavailable, GPU 28 percent"
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
            "Stats Lite: CPU unavailable, Memory Pressure Warning at 68 percent, GPU 28 percent"
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
