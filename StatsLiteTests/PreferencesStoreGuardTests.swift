//
//  PreferencesStoreGuardTests.swift
//  StatsLiteTests
//
//  Last-one-enabled guard: defaults enable all metrics, corrupted
//  all-false keys reset to showCPU, and the didSet guard re-enables a
//  toggle that would leave zero metrics on.
//

import XCTest
@testable import StatsLite

/// UserDefaults keys owned by these tests, plus the reset helper. The
/// helper is a free function so the nonisolated setUp/tearDown
/// overrides can call it without an actor-isolation warning.
private let preferencesKeys = [
    "showCPU",
    "showRAM",
    "showGPU",
    "refreshInterval",
    "historyDuration",
    "showLabels",
    "showCoreBreakdown",
]

private func clearPreferencesKeys() {
    for key in preferencesKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@MainActor
final class PreferencesStoreGuardTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearPreferencesKeys()
    }

    override func tearDown() {
        clearPreferencesKeys()
        super.tearDown()
    }

    // MARK: - Defaults

    func testDefaultsEnableAllThreeMetrics() {
        let store = PreferencesStore()

        XCTAssertTrue(store.showCPU)
        XCTAssertTrue(store.showRAM)
        XCTAssertTrue(store.showGPU)
        XCTAssertEqual(store.activeMetricCount, 3)
        XCTAssertEqual(store.enabledMetrics, .all)
        XCTAssertEqual(store.refreshInterval, 2)
        XCTAssertEqual(store.historyDuration, 60)
        XCTAssertTrue(store.showLabels)
        XCTAssertTrue(store.showCoreBreakdown)
    }

    // MARK: - Corrupted init

    func testAllFalseKeysResetToShowCPU() {
        UserDefaults.standard.set(false, forKey: "showCPU")
        UserDefaults.standard.set(false, forKey: "showRAM")
        UserDefaults.standard.set(false, forKey: "showGPU")

        let store = PreferencesStore()

        XCTAssertTrue(store.showCPU)
        XCTAssertFalse(store.showRAM)
        XCTAssertFalse(store.showGPU)
        XCTAssertEqual(store.activeMetricCount, 1)
        XCTAssertEqual(store.enabledMetrics, [.cpu])
    }

    // MARK: - didSet guard

    func testDisablingLastEnabledMetricReEnablesIt() {
        let store = PreferencesStore()

        store.showRAM = false
        store.showGPU = false
        XCTAssertEqual(store.activeMetricCount, 1)

        // The last one must not turn off.
        store.showCPU = false

        XCTAssertTrue(store.showCPU)
        XCTAssertEqual(store.activeMetricCount, 1)
        XCTAssertEqual(store.enabledMetrics, [.cpu])
    }

    func testDisablingOneOfTwoMetricsStaysDisabled() {
        let store = PreferencesStore()

        store.showRAM = false
        store.showGPU = false
        store.showCPU = false

        // CPU re-enabled by the guard; RAM and GPU keep their state.
        XCTAssertTrue(store.showCPU)
        XCTAssertFalse(store.showRAM)
        XCTAssertFalse(store.showGPU)
    }

    func testDisablingOneOfThreeMetricsStaysDisabled() {
        let store = PreferencesStore()

        store.showGPU = false

        XCTAssertFalse(store.showGPU)
        XCTAssertEqual(store.activeMetricCount, 2)
        XCTAssertEqual(store.enabledMetrics, [.cpu, .memory])
    }

    // MARK: - Persistence

    func testToggleStatePersistsAcrossInstances() {
        let first = PreferencesStore()
        first.showGPU = false

        let second = PreferencesStore()
        XCTAssertFalse(second.showGPU)
        XCTAssertEqual(second.activeMetricCount, 2)
    }

    func testIntervalAndHistoryPersistAcrossInstances() {
        let first = PreferencesStore()
        first.refreshInterval = 5
        first.historyDuration = 30

        let second = PreferencesStore()
        XCTAssertEqual(second.refreshInterval, 5)
        XCTAssertEqual(second.historyDuration, 30)
    }
}
