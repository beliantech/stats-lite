//
//  MenuBarLayoutTests.swift
//  StatsLiteTests
//
//  Pinned-length tests for MenuBarLayout.length(showCPU:showRAM:
//  showGPU:showNetwork:). Constants from the plan
//  2026-10-17-menu-bar-typography-and-block-width: each standard
//  block pins 39 pt, the network block pins 50 pt, the gap
//  between blocks is 4 pt, and outer padding is 2 pt per side.
//  Totals: 129 (three standards), 86 (any pair), 43 (single),
//  183 (all four), 97 (one standard + network), 54 (network
//  only), 4 (off).
//

import XCTest
@testable import StatsLite

final class MenuBarLayoutTests: XCTestCase {

    private let accuracy: CGFloat = 0.0001

    func testAllThreeMetricsTotal129() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: true),
            129,
            accuracy: accuracy
        )
    }

    func testCPURAMPairTotal86() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: true, showGPU: false),
            86,
            accuracy: accuracy
        )
    }

    func testCPUGPUPairTotal86() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: false, showGPU: true),
            86,
            accuracy: accuracy
        )
    }

    func testRAMGPUPairTotal86() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: false, showRAM: true, showGPU: true),
            86,
            accuracy: accuracy
        )
    }

    func testCPUSingleTotal43() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: true, showRAM: false, showGPU: false),
            43,
            accuracy: accuracy
        )
    }

    func testRAMSingleTotal43() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: false, showRAM: true, showGPU: false),
            43,
            accuracy: accuracy
        )
    }

    func testGPUSingleTotal43() {
        XCTAssertEqual(
            MenuBarLayout.length(showCPU: false, showRAM: false, showGPU: true),
            43,
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

    func testAllFourMetricsTotal183() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: true,
                showRAM: true,
                showGPU: true,
                showNetwork: true
            ),
            183,
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

    func testCPUPlusNetworkTotal97() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: true,
                showRAM: false,
                showGPU: false,
                showNetwork: true
            ),
            97,
            accuracy: accuracy
        )
    }

    func testNetworkOffKeepsThreeMetricTotal129() {
        XCTAssertEqual(
            MenuBarLayout.length(
                showCPU: true,
                showRAM: true,
                showGPU: true,
                showNetwork: false
            ),
            129,
            accuracy: accuracy
        )
    }
}
