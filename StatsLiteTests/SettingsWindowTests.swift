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
