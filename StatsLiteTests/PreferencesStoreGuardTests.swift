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
    "showNetwork",
    "refreshInterval",
    "historyDuration",
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
        XCTAssertEqual(store.enabledMetrics, .all.union(.temperature))
        XCTAssertEqual(store.refreshInterval, 1)
        XCTAssertEqual(store.historyDuration, 60)
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
        XCTAssertEqual(store.enabledMetrics, [.cpu, .temperature])
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
        XCTAssertEqual(store.enabledMetrics, [.cpu, .temperature])
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
        XCTAssertEqual(store.enabledMetrics, [.cpu, .memory, .temperature])
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

    // MARK: - Network toggle (F2, F10)

    func testShowNetworkDefaultsToTrue() {
        let store = PreferencesStore()

        XCTAssertTrue(
            store.showNetwork,
            "F2: NETWORK ships ON when the key is absent (fresh and existing installs)"
        )
        XCTAssertEqual(store.activeMetricCount, 3)
    }

    func testShowNetworkPersistsAcrossInstances() {
        let first = PreferencesStore()
        first.showNetwork = false

        let second = PreferencesStore()
        XCTAssertFalse(second.showNetwork, "F2: an opt-out survives a restart")

        second.showNetwork = true

        let third = PreferencesStore()
        XCTAssertTrue(third.showNetwork)
    }

    func testShowNetworkDoesNotChangeActiveMetricCountOrEnabledMetrics() {
        let store = PreferencesStore()
        store.showNetwork = false

        XCTAssertEqual(store.activeMetricCount, 3, "F10/D4: network never enters the count")
        XCTAssertEqual(store.enabledMetrics, .all.union(.temperature))

        store.showRAM = false
        store.showGPU = false
        store.showNetwork = true

        XCTAssertEqual(
            store.activeMetricCount,
            1,
            "count still counts only CPU/RAM/GPU while network is ON"
        )
        XCTAssertEqual(store.enabledMetrics, [.cpu, .temperature])
    }

    /// The lock helper counts only the three standard metrics, so the
    /// network setting never changes a lock result. The sole standard
    /// toggle keeps its lock (SettingsWindowTests pins that exact
    /// assertion), and the network row carries no lock state: D7 gives
    /// it no .disabled modifier at all (F10).
    func testShowNetworkDoesNotAffectStandardToggleLock() {
        let store = PreferencesStore()
        store.showRAM = false
        store.showGPU = false
        XCTAssertEqual(store.activeMetricCount, 1)

        store.showNetwork = true
        XCTAssertTrue(store.isToggleLocked(store.showCPU), "the sole standard toggle stays locked")
        XCTAssertFalse(store.isToggleLocked(store.showRAM))
        XCTAssertFalse(store.isToggleLocked(store.showGPU))

        store.showNetwork = false
        XCTAssertTrue(
            store.isToggleLocked(store.showCPU),
            "flipping showNetwork changes no lock result"
        )
        XCTAssertFalse(store.isToggleLocked(store.showGPU))
    }
}
