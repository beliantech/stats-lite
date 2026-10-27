//
//  RemoveCoresBreakdownTests.swift
//  StatsLiteTests
//
//  RED suite (plan 2026-10-24-remove-cores-breakdown): the Cores
//  Breakdown feature leaves the popover CPU card and Settings. One
//  test per removal site: the Settings toggle, the
//  PreferencesStore property, the CPU card disclosure and grid, and
//  the popover coresExpanded state. Absence checks use the same
//  Mirror string walk and source-token helpers the other suites use
//  (SettingsWindowTests, SparklineTimeAxisGuardTests); a sanity
//  assertion on a known surviving string keeps each absence check
//  from passing vacuously.
//
//  These tests fail while the feature still exists. Do not weaken
//  them in green.
//

import SwiftUI
import XCTest
@testable import StatsLite

/// UserDefaults keys owned by these tests, plus the reset helper.
/// Same isolation pattern as PreferencesStoreGuardTests; the names
/// stay file-private so the suites cannot collide.
private let removeCoresPreferencesKeys = [
    "showCPU",
    "showRAM",
    "showGPU",
    "showNetwork",
    "showTemperature",
    "refreshInterval",
    "historyDuration",
    "showCoreBreakdown",
]

private func clearRemoveCoresPreferencesKeys() {
    for key in removeCoresPreferencesKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@MainActor
final class RemoveCoresBreakdownTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearRemoveCoresPreferencesKeys()
    }

    override func tearDown() {
        clearRemoveCoresPreferencesKeys()
        super.tearDown()
    }

    // MARK: - Helpers (same walks as SettingsWindowTests /
    // SparklineTimeAxisGuardTests)

    /// Every String stored anywhere in a SwiftUI view value tree.
    /// Toggle and Picker labels are LocalizedStringKeys whose key
    /// Strings the reflection exposes.
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

    /// Every Mirror child label and every String in the reflected
    /// value tree. Property-absence checks need the labels: an
    /// @Observable or @State backing shows up as a stored property
    /// (for example `_showCoreBreakdown`), never as a body string.
    private func collectStoredNames(_ root: Any) -> [String] {
        var result: [String] = []

        func walk(_ value: Any, depth: Int) {
            guard depth < 40 else { return }
            for child in Mirror(reflecting: value).children {
                if let label = child.label {
                    result.append(label)
                }
                if let string = child.value as? String {
                    result.append(string)
                }
                walk(child.value, depth: depth + 1)
            }
        }

        walk(root, depth: 0)
        return result
    }

    // MARK: - Source helpers (same pattern as SparklineTimeAxisGuardTests)

    /// URL of a production source file relative to this test file.
    private func sourceURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
            .standardizedFileURL
    }

    private func loadSource(
        _ relativePath: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let data = try Data(contentsOf: sourceURL(relativePath))
        return try XCTUnwrap(
            String(data: data, encoding: .utf8),
            "\(relativePath) is not valid UTF-8",
            file: file,
            line: line
        )
    }

    /// Normalizes source text for token comparison: cuts `//`
    /// comments line by line, then removes every whitespace run.
    /// A missing token therefore never hides behind formatting.
    private func squashed(_ source: String) -> String {
        let withoutComments = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let comment = line.range(of: "//") else { return line }
                return line[line.startIndex..<comment.lowerBound]
            }
            .joined()
        return withoutComments
            .split(whereSeparator: { $0.isWhitespace })
            .joined()
    }

    // MARK: - Removal site 1: the Settings toggle

    /// The Settings window keeps the History Duration picker (the
    /// 2nd General row) and loses the Show Per-Core CPU Breakdown
    /// toggle. The sanity anchors are strings that survive the
    /// removal, so the absence check cannot pass because
    /// introspection found nothing.
    func testSettingsWindowNoLongerContainsCoreBreakdownToggle() {
        let view = SettingsView(
            preferences: PreferencesStore(),
            monitor: SystemMonitor(),
            launchAtLogin: LaunchAtLoginService(),
            updateChecker: UpdateCheckService()
        )
        let strings = collectViewStrings(view.body)

        XCTAssertTrue(
            strings.contains("Visible Metrics"),
            "View introspection failed: no known section header found."
        )
        XCTAssertTrue(
            strings.contains { $0.contains("History Duration") },
            "View introspection failed: the surviving History Duration picker was not found."
        )
        XCTAssertFalse(
            strings.contains { $0.contains("Show Per-Core CPU Breakdown") },
            "The Show Per-Core CPU Breakdown toggle was removed from Settings."
        )
    }

    // MARK: - Removal site 2: the PreferencesStore property

    /// `showCoreBreakdown` leaves PreferencesStore as a stored or
    /// @AppStorage-backed property. Both forms surface as a Mirror
    /// label containing the name; the storage key string goes with
    /// them. `refreshInterval` is the sanity anchor: it stays.
    func testPreferencesStoreHasNoShowCoreBreakdownProperty() {
        let store = PreferencesStore()
        let names = collectStoredNames(store)

        XCTAssertTrue(
            names.contains { $0.contains("refreshInterval") },
            "Store introspection failed: no known stored property was found."
        )
        XCTAssertFalse(
            names.contains { $0.contains("showCoreBreakdown") },
            "PreferencesStore must not keep a showCoreBreakdown property or storage key."
        )
    }

    // MARK: - Removal site 3: the CPU card disclosure and core grid

    /// The CPU card body keeps the header, sparkline, time axis, and
    /// Top Processes button. The disclosure button and the per-core
    /// grid go, so no value tree carries the Cores Breakdown label
    /// and no source token keeps the private helpers. The test pins
    /// the current CPUCardView initializer.
    func testCPUCardBodyHasNoCoreGridElements() throws {
        let card = CPUCardView(
            monitor: SystemMonitor(),
            expandedProcessCategory: Binding.constant(nil)
        )
        let strings = collectViewStrings(card.body)

        XCTAssertTrue(
            strings.contains("CPU Total"),
            "Card introspection failed: no known header string found."
        )
        XCTAssertFalse(
            strings.contains { $0.contains("Cores Breakdown") },
            "The CPU card body must not build the Cores Breakdown disclosure."
        )

        // Private helper names never surface in the value tree, so
        // the disclosure and grid identifiers are pinned as source
        // tokens instead. "Disclosure" in TopProcessesDisclosureButton
        // is a different token (capital D) and does not match.
        let cpuCardSource = squashed(try loadSource("StatsLite/CPUCardView.swift"))
        XCTAssertFalse(
            cpuCardSource.contains("coreGrid"),
            "CPUCardView.swift must not keep the coreGrid grid."
        )
        XCTAssertFalse(
            cpuCardSource.contains("coreCount"),
            "CPUCardView.swift must not keep the coreCount label count."
        )
        XCTAssertFalse(
            cpuCardSource.contains("disclosure"),
            "CPUCardView.swift must not keep the per-core disclosure."
        )
    }

    // MARK: - Removal site 4: the popover coresExpanded state

    /// The popover drops `@State coresExpanded` together with the
    /// CPUCardView binding and the ease-in-out animation value. The
    /// state surfaces as a Mirror backing label on the view value,
    /// so the check walks stored names. `expandedProcessCategory` is
    /// the sanity anchor: the shared accordion state stays.
    func testPopoverContentViewHasNoCoresExpandedState() {
        let view = PopoverContentView(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        let names = collectStoredNames(view)

        XCTAssertTrue(
            names.contains { $0.contains("expandedProcessCategory") },
            "Popover introspection failed: no known stored state was found."
        )
        XCTAssertFalse(
            names.contains { $0.contains("coresExpanded") },
            "PopoverContentView must not keep a coresExpanded state or binding."
        )
    }
}
