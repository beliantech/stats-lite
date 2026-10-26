//
//  MenuBarLayoutTests.swift
//  StatsLiteTests
//
//  Pinned-length tests for MenuBarLayout.length(showCPU:showRAM:
//  showGPU:showNetwork:). Constants from plan
//  2026-10-25-menubar-item-gap-uniform-minimum T3 (Appendix C):
//  each standard block pins 27 pt, the network block pins 50 pt,
//  and outer padding is 2 pt per side. The inter-block gap is 5 pt
//  (plan 2026-10-26-menubar-block-gap-5pt). Totals: 95 (three
//  standards), 63 (any pair), 31 (single), 150 (all four), 86
//  (one standard + network), 54 (network only), 4 (off), 191
//  (all five).
//

import XCTest
@testable import StatsLite

final class MenuBarLayoutTests: XCTestCase {

    private let accuracy: CGFloat = 0.0001

    func testAllThreeMetricsTotal95() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: true),
            95,
            accuracy: accuracy
        )
    }

    func testCPURAMPairTotal63() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: false),
            63,
            accuracy: accuracy
        )
    }

    func testCPUGPUPairTotal63() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: false, showGPU: true),
            63,
            accuracy: accuracy
        )
    }

    func testRAMGPUPairTotal63() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: false, showRAM: true, showGPU: true),
            63,
            accuracy: accuracy
        )
    }

    func testCPUSingleTotal31() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: false, showGPU: false),
            31,
            accuracy: accuracy
        )
    }

    func testRAMSingleTotal31() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: false, showRAM: true, showGPU: false),
            31,
            accuracy: accuracy
        )
    }

    func testGPUSingleTotal31() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: false, showRAM: false, showGPU: true),
            31,
            accuracy: accuracy
        )
    }

    func testAllMetricsOffIsPaddingOnly4() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: false, showRAM: false, showGPU: false),
            4,
            accuracy: accuracy
        )
    }

    // MARK: - Network block (VAC-N1, VAC-N4)

    func testNetworkBlockWidthIsPinnedTo50() {
        XCTAssertEqual(MenuBarLayout.networkBlockWidth, 50, accuracy: accuracy)
    }

    func testAllFourMetricsTotal150() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: true,
                showRAM: true,
                showGPU: true,
                showNetwork: true
            ),
            150,
            accuracy: accuracy
        )
    }

    func testNetworkOnlyTotal54() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: false,
                showRAM: false,
                showGPU: false,
                showNetwork: true
            ),
            54,
            accuracy: accuracy
        )
    }

    func testCPUPlusNetworkTotal86() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: true,
                showRAM: false,
                showGPU: false,
                showNetwork: true
            ),
            86,
            accuracy: accuracy
        )
    }

    func testNetworkOffKeepsThreeMetricTotal95() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: true,
                showRAM: true,
                showGPU: true,
                showNetwork: false
            ),
            95,
            accuracy: accuracy
        )
    }

    // MARK: - TEMP block width (VAC-21, VAC-22)

    /// The temperature block pins to 36 pt: the widest composite
    /// row "G 130°" measures 30.10 pt, so 36 pt gives 2.95 pt
    /// clearance per side and satisfies the >= 2.5 pt rule.
    func testTempBlockWidthIsPinnedTo36() {
        XCTAssertEqual(MenuBarLayout.tempBlockWidth, 36, accuracy: accuracy)
    }

    /// All five metrics (CPU, GPU, MEM, TEMP, NET) total 191 pt:
    /// 2 × 2 pt padding + 3 × 27 pt + 36 pt + 50 pt + 4 × 5 pt gap.
    func testAllFiveMetricsTotal191() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: true,
                showRAM: true,
                showGPU: true,
                showNetwork: true,
                showTemperature: true
            ),
            191,
            accuracy: accuracy
        )
    }
}
