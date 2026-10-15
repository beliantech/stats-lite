//
//  MenuBarBlockBuilderTests.swift
//  StatsLiteTests
//
//  Red-phase tests for the stacked menu bar block model (plan
//  2026-10-15-mem-pressure-dot, Task 1/3). Targets the MEM label,
//  the memory-pressure percent value, the MEM dot state, and the
//  pressure value tint. The builder takes pressurePercent and
//  pressureState in place of usedPercent. CPU and GPU blocks keep
//  dotState nil and their existing behavior.
//

import XCTest
@testable import StatsLite

final class MenuBarBlockBuilderTests: XCTestCase {

    /// Pinned per-block width from the plan constants table.
    private let blockWidth: CGFloat = 34

    private func blocks(
        showCPU: Bool = true,
        showRAM: Bool = true,
        showGPU: Bool = true,
        cpuPercent: Double? = 0.20,
        pressurePercent: Double? = 0.50,
        pressureState: MemoryPressureState? = .normal,
        gpuPercent: Double? = 0.30
    ) -> [MenuBarBlock] {
        MenuBarBlockBuilder.blocks(
            showCPU: showCPU,
            showRAM: showRAM,
            showGPU: showGPU,
            cpuPercent: cpuPercent,
            pressurePercent: pressurePercent,
            pressureState: pressureState,
            gpuPercent: gpuPercent
        )
    }

    // MARK: - Enabled metrics → blocks

    func testAllThreeEnabledProducesThreeBlocksWithLabels() {
        let result = blocks()
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.label), ["CPU", "MEM", "GPU"])
        XCTAssertEqual(result.map(\.kind), [.cpu, .ram, .gpu])
    }

    func testSingleEnabledMetricProducesExactlyOneBlock() {
        let cpuOnly = blocks(showCPU: true, showRAM: false, showGPU: false)
        XCTAssertEqual(cpuOnly.count, 1)
        XCTAssertEqual(cpuOnly.map(\.label), ["CPU"])

        let ramOnly = blocks(showCPU: false, showRAM: true, showGPU: false)
        XCTAssertEqual(ramOnly.count, 1)
        XCTAssertEqual(ramOnly.map(\.label), ["MEM"])

        let gpuOnly = blocks(showCPU: false, showRAM: false, showGPU: true)
        XCTAssertEqual(gpuOnly.count, 1)
        XCTAssertEqual(gpuOnly.map(\.label), ["GPU"])
    }

    func testEveryEnabledCombinationProducesCorrectCountAndOrder() {
        // All 8 on/off combinations, CPU → MEM → GPU order.
        let cases: [(cpu: Bool, ram: Bool, gpu: Bool, expected: [MenuBarBlockKind])] = [
            (false, false, false, []),
            (true, false, false, [.cpu]),
            (false, true, false, [.ram]),
            (false, false, true, [.gpu]),
            (true, true, false, [.cpu, .ram]),
            (true, false, true, [.cpu, .gpu]),
            (false, true, true, [.ram, .gpu]),
            (true, true, true, [.cpu, .ram, .gpu]),
        ]

        for testCase in cases {
            let result = blocks(
                showCPU: testCase.cpu,
                showRAM: testCase.ram,
                showGPU: testCase.gpu
            )
            XCTAssertEqual(
                result.map(\.kind),
                testCase.expected,
                "Combination CPU:\(testCase.cpu) RAM:\(testCase.ram) GPU:\(testCase.gpu)"
            )
        }
    }

    // MARK: - Value formatting

    func testValuesFormatAsWholePercent() {
        XCTAssertEqual(
            blocks(cpuPercent: 0.20, gpuPercent: 0.20)[0].valueText,
            "20%"
        )
        XCTAssertEqual(
            blocks(cpuPercent: nil, gpuPercent: nil)[0].valueText,
            "--%"
        )
        XCTAssertEqual(
            blocks(cpuPercent: 1.0, gpuPercent: 1.0)[0].valueText,
            "100%"
        )
    }

    func testOutOfRangeValuesClampToFull() {
        XCTAssertEqual(
            blocks(cpuPercent: 1.5, gpuPercent: 1.5)[0].valueText,
            "100%"
        )
    }

    func testNaNValueShowsPlaceholder() {
        XCTAssertEqual(
            blocks(cpuPercent: .nan, gpuPercent: .nan)[0].valueText,
            "--%"
        )
    }

    func testMEMValueFormatsPressurePercent() {
        let mem = blocks(
            showCPU: false, showGPU: false, pressurePercent: 0.25
        )
        XCTAssertEqual(mem[0].valueText, "25%")

        let full = blocks(
            showCPU: false, showGPU: false, pressurePercent: 1.0
        )
        XCTAssertEqual(full[0].valueText, "100%")

        let missing = blocks(
            showCPU: false, showGPU: false, pressurePercent: nil
        )
        XCTAssertEqual(missing[0].valueText, "--%")
    }

    // MARK: - Value tints

    private func cpuTint(_ value: Double?) -> MenuBarValueTint {
        blocks(showRAM: false, showGPU: false, cpuPercent: value)[0].valueTint
    }

    private func gpuTint(_ value: Double?) -> MenuBarValueTint {
        blocks(showCPU: false, showRAM: false, gpuPercent: value)[0].valueTint
    }

    private func memTint(
        pressurePercent: Double?,
        pressureState: MemoryPressureState?
    ) -> MenuBarValueTint {
        blocks(
            showCPU: false,
            showRAM: true,
            showGPU: false,
            pressurePercent: pressurePercent,
            pressureState: pressureState
        )[0].valueTint
    }

    func testCPUValueTintThresholds() {
        XCTAssertEqual(cpuTint(0.14), .primary)
        XCTAssertEqual(cpuTint(0.79), .primary)
        XCTAssertEqual(cpuTint(0.80), .warning)
        XCTAssertEqual(cpuTint(0.94), .warning)
        XCTAssertEqual(cpuTint(0.95), .critical)
        XCTAssertEqual(cpuTint(1.0), .critical)
        XCTAssertEqual(cpuTint(nil), .tertiary)
    }

    func testGPUValueTintThresholds() {
        XCTAssertEqual(gpuTint(0.28), .primary)
        XCTAssertEqual(gpuTint(0.79), .primary)
        XCTAssertEqual(gpuTint(0.80), .warning)
        XCTAssertEqual(gpuTint(0.94), .warning)
        XCTAssertEqual(gpuTint(0.95), .critical)
        XCTAssertEqual(gpuTint(1.0), .critical)
        XCTAssertEqual(gpuTint(nil), .tertiary)
    }

    func testMEMValueTintEscalatesWithPressureState() {
        XCTAssertEqual(
            memTint(pressurePercent: 0.25, pressureState: .normal), .green
        )
        XCTAssertEqual(
            memTint(pressurePercent: 0.0, pressureState: .normal), .green
        )
        XCTAssertEqual(
            memTint(pressurePercent: 0.68, pressureState: .warning), .warning
        )
        XCTAssertEqual(
            memTint(pressurePercent: 0.88, pressureState: .critical), .critical
        )
        XCTAssertEqual(
            memTint(pressurePercent: 1.0, pressureState: .critical), .critical
        )
    }

    func testMEMValueTintIsTertiaryWhenPercentMissing() {
        XCTAssertEqual(
            memTint(pressurePercent: nil, pressureState: .normal), .tertiary
        )
        XCTAssertEqual(
            memTint(pressurePercent: nil, pressureState: .warning), .tertiary
        )
        XCTAssertEqual(
            memTint(pressurePercent: nil, pressureState: .critical), .tertiary
        )
        XCTAssertEqual(
            memTint(pressurePercent: nil, pressureState: nil), .tertiary
        )
    }

    // MARK: - Pinned width

    func testEveryBlockHasPinnedWidth() {
        let result = blocks()
        for block in result {
            XCTAssertEqual(block.width, blockWidth)
        }
        let empty = blocks(showCPU: false, showRAM: false, showGPU: false)
        XCTAssertTrue(empty.isEmpty)
    }

    // MARK: - Dot state

    func testCPUGPUBlocksHaveNoDotState() {
        let result = blocks()
        XCTAssertNil(result[0].dotState)
        XCTAssertNil(result[2].dotState)
    }

    func testMEMDotStateUsesPressureStateWhenKnown() {
        XCTAssertEqual(
            blocks(
                showCPU: false, showGPU: false,
                pressurePercent: 0.25, pressureState: .normal
            )[0].dotState,
            .normal
        )
        XCTAssertEqual(
            blocks(
                showCPU: false, showGPU: false,
                pressurePercent: 0.68, pressureState: .warning
            )[0].dotState,
            .warning
        )
        XCTAssertEqual(
            blocks(
                showCPU: false, showGPU: false,
                pressurePercent: 0.88, pressureState: .critical
            )[0].dotState,
            .critical
        )
    }

    func testMEMDotStateDerivesFromPercentWhenStateMissing() {
        XCTAssertEqual(
            blocks(
                showCPU: false, showGPU: false,
                pressurePercent: 0.25, pressureState: nil
            )[0].dotState,
            .normal
        )
        XCTAssertEqual(
            blocks(
                showCPU: false, showGPU: false,
                pressurePercent: 0.70, pressureState: nil
            )[0].dotState,
            .warning
        )
        XCTAssertEqual(
            blocks(
                showCPU: false, showGPU: false,
                pressurePercent: 0.90, pressureState: nil
            )[0].dotState,
            .critical
        )
    }

    func testMEMDotStateNeverNil() {
        // With both inputs missing no pressure data exists, so the
        // dot resolves to .unknown (systemGray), not .normal
        // (green). The dot stays present.
        let empty = blocks(
            showCPU: false, showGPU: false,
            pressurePercent: nil, pressureState: nil
        )
        XCTAssertEqual(empty.count, 1)
        XCTAssertNotNil(empty[0].dotState)
        XCTAssertEqual(empty[0].dotState, .unknown)
    }

    // MARK: - Full MEM block equality

    func testMEMBlockCarriesLabelValueTintAndDotTogether() {
        let ram = blocks(
            showCPU: false, showGPU: false,
            pressurePercent: 0.62, pressureState: .normal
        )
        XCTAssertEqual(ram.count, 1)
        XCTAssertEqual(
            ram[0],
            MenuBarBlock(
                kind: .ram,
                label: "MEM",
                dotState: .normal,
                valueText: "62%",
                valueTint: .green,
                width: 34
            )
        )
        XCTAssertFalse(ram[0].valueText.contains("●"))
    }
}
