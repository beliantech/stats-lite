//
//  MenuBarLabelTests.swift
//  StatsLiteTests
//
//  Pure-logic checks for the menu bar accessibility label and the
//  pressure-level color derivation used by the UI.
//

import XCTest
@testable import StatsLite

final class MenuBarLabelTests: XCTestCase {

    // MARK: - Composite VoiceOver label

    func testCompositeLabelAllThreeMetrics() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            cpuPercent: 0.14,
            usedPercent: 0.62,
            pressure: .normal,
            gpuPercent: 0.28
        )
        XCTAssertEqual(
            label,
            "Stats Lite: CPU 14 percent, Memory Pressure Normal with 62 percent used, GPU 28 percent"
        )
    }

    func testCompositeLabelGPUUnavailable() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            cpuPercent: 0.14,
            usedPercent: 0.62,
            pressure: .warning,
            gpuPercent: nil
        )
        XCTAssertEqual(
            label,
            "Stats Lite: CPU 14 percent, Memory Pressure Warning with 62 percent used, GPU unavailable"
        )
    }

    func testCompositeLabelSingleMetricOmitsOtherParts() {
        let label = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: false,
            showGPU: false,
            cpuPercent: 0.5,
            usedPercent: 0,
            pressure: .normal,
            gpuPercent: nil
        )
        XCTAssertEqual(label, "Stats Lite: CPU 50 percent")
    }

    func testCompositeLabelRoundsAndClampsPercent() {
        let high = MenuBarAccessibility.compositeLabel(
            showCPU: true, showRAM: false, showGPU: false,
            cpuPercent: 1.8, usedPercent: 0, pressure: .normal, gpuPercent: nil
        )
        XCTAssertEqual(high, "Stats Lite: CPU 100 percent")

        let low = MenuBarAccessibility.compositeLabel(
            showCPU: true, showRAM: false, showGPU: false,
            cpuPercent: -0.2, usedPercent: 0, pressure: .normal, gpuPercent: nil
        )
        XCTAssertEqual(low, "Stats Lite: CPU 0 percent")
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

    // MARK: - Menu bar label builder (Path A, single Text)

    private func input(
        showCPU: Bool = true,
        showRAM: Bool = true,
        showGPU: Bool = true,
        showLabels: Bool = true,
        cpuPercent: Double? = 0.14,
        usedPercent: Double? = 0.62,
        pressure: MemoryPressureState = .normal,
        gpuPercent: Double? = 0.28
    ) -> MenuBarLabelInput {
        MenuBarLabelInput(
            showCPU: showCPU,
            showRAM: showRAM,
            showGPU: showGPU,
            showLabels: showLabels,
            cpuPercent: cpuPercent,
            usedPercent: usedPercent,
            pressure: pressure,
            gpuPercent: gpuPercent
        )
    }

    /// Tint of the CPU value run in a CPU-only label.
    private func cpuTint(_ value: Double?) -> MenuBarValueTint {
        let runs = MenuBarLabelBuilder.runs(
            input(showRAM: false, showGPU: false, cpuPercent: value)
        )
        guard runs.count == 2, case .value(let tint) = runs[1].style else {
            XCTFail("Expected category plus one value run, got \(runs)")
            return .primary
        }
        return tint
    }

    func testBuilderThreeMetricsWithLabels() {
        XCTAssertEqual(
            MenuBarLabelBuilder.plainText(input()),
            "CPU 14% · RAM ● 62% · GPU 28%"
        )
    }

    func testBuilderThreeMetricsLabelsOff() {
        XCTAssertEqual(
            MenuBarLabelBuilder.plainText(input(showLabels: false)),
            "14% · ● 62% · 28%"
        )
    }

    func testBuilderGPUNilShowsPlaceholderWithTertiaryTint() {
        let nilInput = input(gpuPercent: nil)
        XCTAssertEqual(
            MenuBarLabelBuilder.plainText(nilInput),
            "CPU 14% · RAM ● 62% · GPU --%"
        )
        let runs = MenuBarLabelBuilder.runs(nilInput)
        XCTAssertEqual(runs.last?.text, "--%")
        XCTAssertEqual(runs.last?.style, .value(.tertiary))
    }

    func testBuilderSingleMetricOmitsSeparators() {
        let cpuOnly = input(showRAM: false, showGPU: false, cpuPercent: 0.5)
        XCTAssertEqual(MenuBarLabelBuilder.plainText(cpuOnly), "CPU 50%")
        XCTAssertFalse(
            MenuBarLabelBuilder.runs(cpuOnly).contains { $0.style == .separator }
        )
    }

    func testBuilderSeparatorOnlyBetweenAdjacentActiveSlots() {
        let cpuGPU = input(showRAM: false)
        XCTAssertEqual(MenuBarLabelBuilder.plainText(cpuGPU), "CPU 14% · GPU 28%")
        XCTAssertEqual(
            MenuBarLabelBuilder.runs(cpuGPU).filter { $0.style == .separator }.count,
            1
        )

        let ramGPU = input(showCPU: false)
        XCTAssertEqual(MenuBarLabelBuilder.plainText(ramGPU), "RAM ● 62% · GPU 28%")
        XCTAssertEqual(
            MenuBarLabelBuilder.runs(ramGPU).filter { $0.style == .separator }.count,
            1
        )
    }

    func testBuilderAllMetricsOffProducesEmptyLabel() {
        let none = input(showCPU: false, showRAM: false, showGPU: false)
        XCTAssertEqual(MenuBarLabelBuilder.plainText(none), "")
        XCTAssertTrue(MenuBarLabelBuilder.runs(none).isEmpty)
    }

    func testBuilderUsageValueTints() {
        XCTAssertEqual(cpuTint(0.14), .primary)
        XCTAssertEqual(cpuTint(0.80), .warning)
        XCTAssertEqual(cpuTint(0.95), .critical)
        XCTAssertEqual(cpuTint(0.97), .critical)
        XCTAssertEqual(cpuTint(nil), .tertiary)
    }

    func testBuilderRAMValueStaysPrimaryRegardlessOfOccupancy() {
        let high = input(showCPU: false, showGPU: false, usedPercent: 0.99)
        XCTAssertEqual(MenuBarLabelBuilder.runs(high).last?.style, .value(.primary))

        let missing = input(showCPU: false, showGPU: false, usedPercent: nil)
        XCTAssertEqual(MenuBarLabelBuilder.runs(missing).last?.style, .value(.tertiary))
    }

    func testBuilderRAMDotCarriesPressureLevel() {
        let runs = MenuBarLabelBuilder.runs(
            input(showCPU: false, showGPU: false, pressure: .critical)
        )
        XCTAssertTrue(
            runs.contains(MenuBarLabelRun(text: "● ", style: .ramDot(.critical)))
        )
    }

    func testBuilderClampsOutOfRangeAndRejectsNaN() {
        let high = input(showRAM: false, showGPU: false, cpuPercent: 1.8)
        XCTAssertEqual(MenuBarLabelBuilder.runs(high).last?.text, "100%")

        let nan = input(showRAM: false, showGPU: false, cpuPercent: .nan)
        XCTAssertEqual(MenuBarLabelBuilder.runs(nan).last?.text, "--%")
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
