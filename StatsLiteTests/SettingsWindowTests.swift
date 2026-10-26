//
//  SettingsWindowTests.swift
//  StatsLiteTests
//
//  Settings window helpers: the sole-ON toggle lock that backs the
//  disabled state in the Visible Metrics section, and the version
//  footer built from bundle info.
//

import XCTest
@testable import StatsLite

/// UserDefaults keys owned by these tests, plus the reset helper.
/// Mirrors the PreferencesStoreGuardTests pattern; both are private
/// to their file, so the names do not collide.
private let settingsPreferencesKeys = [
    "showCPU",
    "showRAM",
    "showGPU",
    "refreshInterval",
    "historyDuration",
]

private func clearSettingsPreferencesKeys() {
    for key in settingsPreferencesKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@MainActor
final class SettingsWindowTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearSettingsPreferencesKeys()
    }

    override func tearDown() {
        clearSettingsPreferencesKeys()
        super.tearDown()
    }

    // MARK: - Sole-ON toggle lock (VAC-24)

    func testSoleEnabledToggleIsLocked() {
        let store = PreferencesStore()
        store.showRAM = false
        store.showGPU = false

        XCTAssertEqual(store.activeMetricCount, 1)
        XCTAssertTrue(store.isToggleLocked(store.showCPU))
        XCTAssertFalse(store.isToggleLocked(store.showRAM))
        XCTAssertFalse(store.isToggleLocked(store.showGPU))
    }

    func testSoleEnabledToggleIsRAMWhenOthersOff() {
        let store = PreferencesStore()
        store.showCPU = false
        store.showGPU = false

        XCTAssertEqual(store.activeMetricCount, 1)
        XCTAssertTrue(store.isToggleLocked(store.showRAM))
        XCTAssertFalse(store.isToggleLocked(store.showCPU))
    }

    func testNoToggleLockedWhileTwoMetricsEnabled() {
        let store = PreferencesStore()
        store.showGPU = false

        XCTAssertEqual(store.activeMetricCount, 2)
        XCTAssertFalse(store.isToggleLocked(store.showCPU))
        XCTAssertFalse(store.isToggleLocked(store.showRAM))
        XCTAssertFalse(store.isToggleLocked(store.showGPU))
    }

    func testNoToggleLockedWhenAllThreeEnabled() {
        let store = PreferencesStore()

        XCTAssertEqual(store.activeMetricCount, 3)
        XCTAssertFalse(store.isToggleLocked(store.showCPU))
        XCTAssertFalse(store.isToggleLocked(store.showRAM))
        XCTAssertFalse(store.isToggleLocked(store.showGPU))
    }

    // MARK: - No Show Category Labels toggle (showLabels removed)

    /// Every String stored anywhere in a SwiftUI view value tree,
    /// found via Mirror. Toggle labels are LocalizedStringKeys whose
    /// key Strings the reflection exposes.
    private func collectViewStrings(_ root: Any) -> [String] {
        var result: [String] = []

        func walk(_ value: Any, depth: Int) {
            guard depth < 40 else { return }
            if let string = value as? String {
                result.append(string)
            }
            for child in Mirror(reflecting: value).children {
                walk(child.value, depth: depth + 1)
            }
        }

        walk(root, depth: 0)
        return result
    }

    func testSettingsViewHasNoShowCategoryLabelsToggle() {
        let view = SettingsView(
            preferences: PreferencesStore(),
            monitor: SystemMonitor(),
            launchAtLogin: LaunchAtLoginService()
        )
        let strings = collectViewStrings(view.body)

        // Sanity check: the reflection must find known strings or
        // the absence check below passes vacuously.
        XCTAssertTrue(
            strings.contains("Visible Metrics"),
            "View introspection failed: no known section header found."
        )
        XCTAssertFalse(
            strings.contains("Show Category Labels"),
            "The Show Category Labels toggle was removed with showLabels."
        )
    }

    // MARK: - General row order (plan 2026-10-26-settings-history-duration-general)

    /// General carries the three control rows in declaration order:
    /// Refresh Interval, then History Duration, then Launch at Login,
    /// all before Visible Metrics. The emptied Display Options
    /// section is gone, and the form keeps exactly one History
    /// Duration label. Order assertions use the same Mirror string
    /// walk + firstIndex idiom as
    /// MenuBarTempBlockTests.testSettingsViewHasTemperatureToggleBetweenGPUAndNetwork.
    func testGeneralSectionRowOrderAndNoDisplayOptionsSection() throws {
        let view = SettingsView(
            preferences: PreferencesStore(),
            monitor: SystemMonitor(),
            launchAtLogin: LaunchAtLoginService()
        )
        let strings = collectViewStrings(view.body)

        // Sanity checks: the reflection must find the neighboring
        // rows and section header, or the checks below pass
        // vacuously.
        XCTAssertTrue(
            strings.contains("Visible Metrics"),
            "View introspection failed: no known section header found."
        )
        XCTAssertTrue(
            strings.contains(where: { $0.contains("Refresh Interval") }),
            "View introspection failed: no Refresh Interval row found."
        )
        XCTAssertTrue(
            strings.contains(where: { $0.contains("Launch at Login") }),
            "View introspection failed: no Launch at Login row found."
        )

        let refreshIndex = try XCTUnwrap(
            strings.firstIndex(where: { $0.contains("Refresh Interval") }),
            "sanity"
        )
        let historyIndex = try XCTUnwrap(
            strings.firstIndex(where: { $0.contains("History Duration") }),
            "History Duration must be a row of the Settings form."
        )
        let loginIndex = try XCTUnwrap(
            strings.firstIndex(where: { $0.contains("Launch at Login") }),
            "sanity"
        )
        let visibleMetricsIndex = try XCTUnwrap(
            strings.firstIndex(of: "Visible Metrics"),
            "sanity"
        )

        XCTAssertLessThan(
            refreshIndex,
            historyIndex,
            "History Duration must sit below Refresh Interval in General."
        )
        XCTAssertLessThan(
            historyIndex,
            loginIndex,
            "History Duration must sit above Launch at Login in General."
        )
        XCTAssertLessThan(
            loginIndex,
            visibleMetricsIndex,
            "General (all three rows) must precede Visible Metrics."
        )

        XCTAssertFalse(
            strings.contains(where: { $0.contains("Display Options") }),
            "The Display Options section was removed with its last control."
        )

        let historyLabels = strings.filter { $0.contains("History Duration") }
        XCTAssertEqual(
            historyLabels.count,
            1,
            "The form must carry exactly one History Duration label; found: \(historyLabels)"
        )
    }

    // MARK: - Visible Metrics row order (plan
    // 2026-10-25-settings-visible-metrics-order)

    /// The Visible Metrics section lists the five toggles in the
    /// same order the menu bar displays them: CPU Utilization, GPU
    /// Utilization, Memory Pressure (RAM), Temperature, Network
    /// Throughput. Order assertions use the same Mirror string walk
    /// + firstIndex idiom as
    /// MenuBarTempBlockTests.testSettingsViewHasTemperatureToggleBetweenGPUAndNetwork.
    func testVisibleMetricsRowOrderMatchesMenuBarOrder() throws {
        let view = SettingsView(
            preferences: PreferencesStore(),
            monitor: SystemMonitor(),
            launchAtLogin: LaunchAtLoginService()
        )
        let strings = collectViewStrings(view.body)

        // Sanity checks: the reflection must find all five rows or
        // the order assertions below pass vacuously.
        let labels = [
            "CPU Utilization",
            "GPU Utilization",
            "Memory Pressure (RAM)",
            "Temperature",
            "Network Throughput",
        ]
        for label in labels {
            XCTAssertTrue(
                strings.contains(label),
                "View introspection failed: no \(label) row found."
            )
        }

        var indices: [Int] = []
        for label in labels {
            let index = try XCTUnwrap(
                strings.firstIndex(of: label),
                "sanity"
            )
            indices.append(index)
        }

        for (pairIndex, label) in zip(0..<(labels.count - 1), labels) {
            XCTAssertLessThan(
                indices[pairIndex],
                indices[pairIndex + 1],
                "\(labels[pairIndex + 1]) must sit below \(label) "
                    + "in Visible Metrics (menu bar order parity)."
            )
        }
    }

    // MARK: - Version footer

    func testVersionLabelReadsBundleInfo() {
        let label = SettingsView.versionLabel()

        let pattern = #"^Stats Lite v[0-9][0-9.]* \(Build [0-9]+\)$"#
        XCTAssertNotNil(
            label.range(of: pattern, options: .regularExpression),
            "Version label must read 'Stats Lite v<version> (Build <n>)', got: \(label)"
        )
    }
}
