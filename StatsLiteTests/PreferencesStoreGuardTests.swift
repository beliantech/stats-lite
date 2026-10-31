//
//  PreferencesStoreGuardTests.swift
//  StatsLiteTests
//
//  Last-one-enabled guard: defaults enable all five metrics,
//  corrupted all-five-false keys reset to showCPU, and the didSet
//  guard re-enables a toggle that would leave zero metrics on.
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
    "showTemperature",
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

    func testDefaultsEnableAllFiveMetrics() {
        let store = PreferencesStore()

        XCTAssertTrue(store.showCPU)
        XCTAssertTrue(store.showRAM)
        XCTAssertTrue(store.showGPU)
        XCTAssertTrue(store.showTemperature)
        XCTAssertTrue(store.showNetwork)
        XCTAssertEqual(store.activeMetricCount, 5)
        XCTAssertEqual(store.enabledMetrics, .all.union(.temperature))
        XCTAssertEqual(store.refreshInterval, 1)
        XCTAssertEqual(store.historyDuration, 60)
    }

    // MARK: - Corrupted init

    func testAllFalseKeysResetToShowCPU() {
        UserDefaults.standard.set(false, forKey: "showCPU")
        UserDefaults.standard.set(false, forKey: "showRAM")
        UserDefaults.standard.set(false, forKey: "showGPU")
        UserDefaults.standard.set(false, forKey: "showTemperature")
        UserDefaults.standard.set(false, forKey: "showNetwork")

        let store = PreferencesStore()

        XCTAssertTrue(store.showCPU)
        XCTAssertFalse(store.showRAM)
        XCTAssertFalse(store.showGPU)
        XCTAssertFalse(store.showTemperature)
        XCTAssertFalse(store.showNetwork)
        XCTAssertEqual(store.activeMetricCount, 1)
        XCTAssertEqual(store.enabledMetrics, [.cpu])
    }

    // MARK: - didSet guard

    func testDisablingLastEnabledMetricReEnablesIt() {
        let store = PreferencesStore()

        store.showRAM = false
        store.showGPU = false
        store.showTemperature = false
        store.showNetwork = false
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
        store.showTemperature = false
        store.showNetwork = false
        store.showCPU = false

        // CPU re-enabled by the guard; RAM and GPU keep their state.
        XCTAssertTrue(store.showCPU)
        XCTAssertFalse(store.showRAM)
        XCTAssertFalse(store.showGPU)
    }

    func testDisablingOneOfFiveMetricsLeavesFourEnabled() {
        let store = PreferencesStore()

        store.showGPU = false

        XCTAssertFalse(store.showGPU)
        XCTAssertEqual(store.activeMetricCount, 4)
        XCTAssertEqual(store.enabledMetrics, [.cpu, .memory, .temperature])
    }

    // MARK: - Persistence

    func testToggleStatePersistsAcrossInstances() {
        let first = PreferencesStore()
        first.showGPU = false

        let second = PreferencesStore()
        XCTAssertFalse(second.showGPU)
        XCTAssertEqual(second.activeMetricCount, 4)
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
        XCTAssertEqual(store.activeMetricCount, 5)
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

    func testShowNetworkEntersActiveMetricCountButNotEnabledMetrics() {
        let store = PreferencesStore()
        XCTAssertEqual(
            store.activeMetricCount,
            5,
            "all five defaults count toward activeMetricCount"
        )

        store.showNetwork = false
        XCTAssertEqual(
            store.activeMetricCount,
            4,
            "the network participates in the five-metric count"
        )
        XCTAssertEqual(
            store.enabledMetrics,
            .all.union(.temperature),
            "the network samples outside enabledMetrics"
        )

        store.showNetwork = true
        XCTAssertEqual(
            store.activeMetricCount,
            5,
            "re-enabling the network restores the full count"
        )
    }

    /// The network row joins the last-one-enabled rule: its own
    /// toggle locks when it is the sole enabled metric, and a second
    /// metric releases the lock.
    func testShowNetworkParticipatesInToggleLock() {
        let store = PreferencesStore()
        store.showCPU = false
        store.showRAM = false
        store.showGPU = false
        store.showTemperature = false
        XCTAssertFalse(
            store.showGPU,
            "setup: the four non-network metrics turn off"
        )
        XCTAssertEqual(store.activeMetricCount, 1, "the network is the sole enabled metric")
        XCTAssertTrue(
            store.isToggleLocked(store.showNetwork),
            "the sole network toggle locks"
        )
        XCTAssertFalse(store.isToggleLocked(store.showCPU))

        // A core metric joins: the lock releases.
        store.showCPU = true
        XCTAssertEqual(store.activeMetricCount, 2, "the network and CPU count as two")
        XCTAssertFalse(store.isToggleLocked(store.showNetwork))
        XCTAssertFalse(store.isToggleLocked(store.showCPU))
    }
}
