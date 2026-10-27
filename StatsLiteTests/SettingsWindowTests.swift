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

/// Seam spy for the checking-state test: counts every Sparkle entry
/// point so the test can prove the Settings row drives the
/// coordinator path.
@MainActor
private final class SettingsUpdateSeamSpy: SparkleUpdaterControlling {
    private(set) var isUpdaterRunning = false
    private(set) var checkForUpdatesCount = 0
    private(set) var checkForUpdatesInteractivelyCount = 0

    func checkForUpdates() {
        checkForUpdatesCount += 1
    }

    func checkForUpdatesInteractively() {
        checkForUpdatesInteractivelyCount += 1
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

    /// Every node's exact type name in a SwiftUI view value tree,
    /// found via Mirror. Exact names (not substrings) keep a generic
    /// parameter list that merely mentions a type from counting as a
    /// rendered node.
    private func collectNodeTypeNames(_ root: Any) -> [String] {
        var result: [String] = []

        func walk(_ value: Any, depth: Int) {
            guard depth < 40 else { return }
            result.append(String(describing: type(of: value)))
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
            launchAtLogin: LaunchAtLoginService(),
            updateChecker: UpdateCheckService()
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
            launchAtLogin: LaunchAtLoginService(),
            updateChecker: UpdateCheckService()
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
            launchAtLogin: LaunchAtLoginService(),
            updateChecker: UpdateCheckService()
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

    // MARK: - Software Update row (VAC-11, blueprint Parts 3/4)

    /// VAC-11: the "Software Update" row lives in General as row 4,
    /// directly below Launch at Login and above the Visible Metrics
    /// header.
    func testSoftwareUpdateRowSitsBelowLaunchAtLoginAndAboveVisibleMetrics() throws {
        let view = SettingsView(
            preferences: PreferencesStore(),
            monitor: SystemMonitor(),
            launchAtLogin: LaunchAtLoginService(),
            updateChecker: UpdateCheckService()
        )
        let strings = collectViewStrings(view.body)

        // Sanity checks: the reflection must find the neighboring
        // rows and section header or the order checks pass vacuously.
        XCTAssertTrue(
            strings.contains(where: { $0.contains("Launch at Login") }),
            "View introspection failed: no Launch at Login row found."
        )
        XCTAssertTrue(
            strings.contains("Visible Metrics"),
            "View introspection failed: no Visible Metrics header found."
        )

        let loginIndex = try XCTUnwrap(
            strings.firstIndex(where: { $0.contains("Launch at Login") }),
            "sanity"
        )
        let updateIndex = try XCTUnwrap(
            strings.firstIndex(where: { $0.contains("Software Update") }),
            "VAC-11: the Software Update row must exist"
        )
        let visibleIndex = try XCTUnwrap(
            strings.firstIndex(of: "Visible Metrics"),
            "sanity"
        )

        XCTAssertLessThan(
            loginIndex,
            updateIndex,
            "VAC-11: Software Update must sit below Launch at Login."
        )
        XCTAssertLessThan(
            updateIndex,
            visibleIndex,
            "VAC-11: Software Update must precede Visible Metrics."
        )
    }

    /// VAC-12 plus the blueprint Part 2 copy table: label, button,
    /// tooltip, and VoiceOver label all verbatim.
    func testSoftwareUpdateRowCopyMatchesBlueprintPart2() {
        let view = SettingsView(
            preferences: PreferencesStore(),
            monitor: SystemMonitor(),
            launchAtLogin: LaunchAtLoginService(),
            updateChecker: UpdateCheckService()
        )
        let strings = collectViewStrings(view.body)

        XCTAssertTrue(
            strings.contains("Software Update"),
            "VAC-12: the row label must read 'Software Update'; found \(strings)"
        )
        XCTAssertTrue(
            strings.contains("Check for Updates…"),
            "the button must read 'Check for Updates…'; found \(strings)"
        )
        XCTAssertTrue(
            strings.contains("Check for new versions of Stats Lite"),
            "the button tooltip must match the blueprint; found \(strings)"
        )
        XCTAssertTrue(
            strings.contains("Check for software updates"),
            "the button VoiceOver label must match the blueprint; found \(strings)"
        )
    }

    /// VAC-13: the inline ProgressView (announced as "Checking for
    /// updates") exists only while the coordinator is checking. The
    /// button keeps its copy in both states; its disabled flag reads
    /// the same isChecking property the coordinator contract pins.
    func testCheckingStateShowsProgressAndIdleHidesIt() {
        let idleView = SettingsView(
            preferences: PreferencesStore(),
            monitor: SystemMonitor(),
            launchAtLogin: LaunchAtLoginService(),
            updateChecker: UpdateCheckService()
        )
        let idleStrings = collectViewStrings(idleView.body)
        XCTAssertTrue(
            idleStrings.contains("Check for Updates…"),
            "sanity: the button must exist while idle"
        )
        XCTAssertFalse(
            collectNodeTypeNames(idleView.body)
                .contains("ProgressView<EmptyView, EmptyView>"),
            "VAC-13: no spinner node while idle"
        )

        let spy = SettingsUpdateSeamSpy()
        let checker = UpdateCheckService(environment: [:], updater: spy)
        checker.checkForUpdatesInteractively()
        XCTAssertEqual(
            spy.checkForUpdatesInteractivelyCount,
            1,
            "sanity: the same seam path the button calls must report checking"
        )
        XCTAssertTrue(checker.isChecking)

        let checkingView = SettingsView(
            preferences: PreferencesStore(),
            monitor: SystemMonitor(),
            launchAtLogin: LaunchAtLoginService(),
            updateChecker: checker
        )
        let checkingTypes = collectNodeTypeNames(checkingView.body)

        // Exact node types (not substring matches): the Optional
        // generic parameter names "ProgressView" in both states, so
        // only the concrete node proves the branch rendered. The
        // composite pins controlSize(.small) plus the accessibility
        // attachment that carries the "Checking for updates" label
        // (SwiftUI keeps that label out of Mirror-reachable value
        // storage; the attachment modifier is its carrier).
        XCTAssertTrue(
            checkingTypes.contains("ProgressView<EmptyView, EmptyView>"),
            "VAC-13: the spinner node must render while checking"
        )
        XCTAssertTrue(
            checkingTypes.contains(
                "ModifiedContent<ModifiedContent<ProgressView<EmptyView, EmptyView>, "
                    + "_EnvironmentKeyWritingModifier<ControlSize>>, "
                    + "AccessibilityAttachmentModifier>"
            ),
            "VAC-13: the spinner must carry controlSize(.small) and its "
                + "accessibility label attachment while checking"
        )
        XCTAssertTrue(
            collectViewStrings(checkingView.body).contains("Check for Updates…"),
            "the button stays in the row while checking (disabled)"
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
