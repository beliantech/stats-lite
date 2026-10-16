//
//  MenuBarLayoutTests.swift
//  StatsLiteTests
//
//  Red-phase tests for MenuBarLayout.length(showCPU:showRAM:showGPU:),
//  which does not exist yet. Constants from the plan
//  2026-10-15-menubar-stacked-fixed-width: each block pins 34 pt,
//  the gap between blocks is 4 pt, and outer padding is 2 pt per
//  side. Totals: 114 (three), 76 (any pair), 38 (single), 4 (off).
//

import XCTest
@testable import StatsLite

final class MenuBarLayoutTests: XCTestCase {

    private let accuracy: CGFloat = 0.0001

    func testAllThreeMetricsTotal114() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: true),
            114,
            accuracy: accuracy
        )
    }

    func testCPURAMPairTotal76() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: false),
            76,
            accuracy: accuracy
        )
    }

    func testCPUGPUPairTotal76() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: false, showGPU: true),
            76,
            accuracy: accuracy
        )
    }

    func testRAMGPUPairTotal76() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: false, showRAM: true, showGPU: true),
            76,
            accuracy: accuracy
        )
    }

    func testCPUSingleTotal38() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: false, showGPU: false),
            38,
            accuracy: accuracy
        )
    }

    func testRAMSingleTotal38() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: false, showRAM: true, showGPU: false),
            38,
            accuracy: accuracy
        )
    }

    func testGPUSingleTotal38() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: false, showRAM: false, showGPU: true),
            38,
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

    func testAllFourMetricsTotal168() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: true,
                showRAM: true,
                showGPU: true,
                showNetwork: true
            ),
            168,
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

    func testCPUPlusNetworkTotal92() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: true,
                showRAM: false,
                showGPU: false,
                showNetwork: true
            ),
            92,
            accuracy: accuracy
        )
    }

    func testNetworkOffKeepsThreeMetricTotal114() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: true,
                showRAM: true,
                showGPU: true,
                showNetwork: false
            ),
            114,
            accuracy: accuracy
        )
    }
}
