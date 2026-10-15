//
//  MenuBarBlockBuilderTests.swift
//  StatsLiteTests
//
//  Red-phase tests for the stacked menu bar block model (plan
//  2026-10-15-menubar-stacked-fixed-width, Task 1/3). Targets
//  MenuBarBlock and MenuBarBlockBuilder.blocks, which do not exist
//  yet. The category label is always present: the builder takes no
//  showLabels input at all. No RAM dot exists anywhere.
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
        usedPercent: Double? = 0.50,
        gpuPercent: Double? = 0.30
    ) -> [MenuBarBlock] {
        MenuBarBlockBuilder.blocks(
            showCPU: showCPU,
            showRAM: showRAM,
            showGPU: showGPU,
            cpuPercent: cpuPercent,
            usedPercent: usedPercent,
            gpuPercent: gpuPercent
        )
    }

    // MARK: - Enabled metrics → blocks

    func testAllThreeEnabledProducesThreeBlocksWithLabels() {
        let result = blocks()
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.label), ["CPU", "RAM", "GPU"])
        XCTAssertEqual(result.map(\.kind), [.cpu, .ram, .gpu])
    }

    func testSingleEnabledMetricProducesExactlyOneBlock() {
        let cpuOnly = blocks(showCPU: true, showRAM: false, showGPU: false)
        XCTAssertEqual(cpuOnly.count, 1)
        XCTAssertEqual(cpuOnly.map(\.label), ["CPU"])

        let ramOnly = blocks(showCPU: false, showRAM: true, showGPU: false)
        XCTAssertEqual(ramOnly.count, 1)
        XCTAssertEqual(ramOnly.map(\.label), ["RAM"])

        let gpuOnly = blocks(showCPU: false, showRAM: false, showGPU: true)
        XCTAssertEqual(gpuOnly.count, 1)
        XCTAssertEqual(gpuOnly.map(\.label), ["GPU"])
    }

    func testEveryEnabledCombinationProducesCorrectCountAndOrder() {
        // All 8 on/off combinations, CPU → RAM → GPU order.
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

    func testRAMValueFormatsAsWholePercent() {
        let ram = blocks(showCPU: false, showGPU: false, usedPercent: 0.62)
        XCTAssertEqual(ram[0].valueText, "62%")

        let missing = blocks(showCPU: false, showGPU: false, usedPercent: nil)
        XCTAssertEqual(missing[0].valueText, "--%")
    }

    // MARK: - Value tints

    private func cpuTint(_ value: Double?) -> MenuBarValueTint {
        blocks(showRAM: false, showGPU: false, cpuPercent: value)[0].valueTint
    }

    private func gpuTint(_ value: Double?) -> MenuBarValueTint {
        blocks(showCPU: false, showRAM: false, gpuPercent: value)[0].valueTint
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

    func testRAMValueTintStaysPrimaryRegardlessOfOccupancy() {
        let high = blocks(
            showCPU: false, showGPU: false, usedPercent: 0.99
        )
        XCTAssertEqual(high[0].valueTint, .primary)

        let warningBand = blocks(
            showCPU: false, showGPU: false, usedPercent: 0.85
        )
        XCTAssertEqual(warningBand[0].valueTint, .primary)

        let missing = blocks(
            showCPU: false, showGPU: false, usedPercent: nil
        )
        XCTAssertEqual(missing[0].valueTint, .tertiary)
    }

    // MARK: - Pinned width and no-dot amendments

    func testEveryBlockHasPinnedWidth() {
        let result = blocks()
        for block in result {
            XCTAssertEqual(block.width, blockWidth)
        }
        let empty = blocks(showCPU: false, showRAM: false, showGPU: false)
        XCTAssertTrue(empty.isEmpty)
    }

    /// The RAM block carries the percent value only. MenuBarBlock has
    /// no dot state: this expected value is built from kind, label,
    /// valueText, valueTint, and width, and must compare equal. A dot
    /// field on the struct breaks this test at compile time.
    func testRAMBlockHasNoDotState() {
        let ram = blocks(showCPU: false, showGPU: false, usedPercent: 0.62)
        XCTAssertEqual(ram.count, 1)
        XCTAssertEqual(
            ram[0],
            MenuBarBlock(
                kind: .ram,
                label: "RAM",
                valueText: "62%",
                valueTint: .primary,
                width: 34
            )
        )
        XCTAssertFalse(ram[0].valueText.contains("●"))
    }
}
