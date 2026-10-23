//
//  PopoverActivityMonitorShortcutTests.swift
//  StatsLiteTests
//
//  Popover header Activity Monitor shortcut (plan
//  2026-10-24-popover-activity-monitor-shortcut). The static seams
//  must resolve on the test host and the button copy must match the
//  tooltip and VoiceOver label.
//

import AppKit
import XCTest
@testable import StatsLite

final class PopoverActivityMonitorShortcutTests: XCTestCase {

    func testActivityMonitorBundleIdentifierResolves() {
        let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: PopoverContentView.activityMonitorBundleIdentifier
        )
        XCTAssertNotNil(
            url,
            "Bundle identifier must resolve to an installed app, got: \(PopoverContentView.activityMonitorBundleIdentifier)"
        )
    }

    func testActivityMonitorFallbackPathExists() {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: PopoverContentView.activityMonitorFallbackPath),
            "Fallback app bundle path must exist on disk, got: \(PopoverContentView.activityMonitorFallbackPath)"
        )
    }

    func testActivityMonitorButtonLabel() {
        XCTAssertEqual(PopoverContentView.activityMonitorButtonLabel, "Open Activity Monitor")
    }
}
