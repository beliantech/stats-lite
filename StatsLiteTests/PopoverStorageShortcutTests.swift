//
//  PopoverStorageShortcutTests.swift
//  StatsLiteTests
//
//  Popover header Storage shortcut (plan
//  2026-10-26-popover-storage-shortcut). The static seams must
//  resolve on the test host and the button copy must match the
//  tooltip and VoiceOver label.
//

import AppKit
import XCTest
@testable import StatsLite

final class PopoverStorageShortcutTests: XCTestCase {

    func testStorageSettingsURLIsValid() {
        let url = URL(string: PopoverContentView.storageSettingsURLString)
        XCTAssertNotNil(
            url,
            "Storage settings URL must be valid, got: \(PopoverContentView.storageSettingsURLString)"
        )
    }

    func testSystemSettingsBundleIdentifierResolves() {
        let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: PopoverContentView.systemSettingsBundleIdentifier
        )
        XCTAssertNotNil(
            url,
            "System Settings bundle identifier must resolve to an installed app, got: \(PopoverContentView.systemSettingsBundleIdentifier)"
        )
    }

    func testSystemSettingsFallbackPathExists() {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: PopoverContentView.systemSettingsFallbackPath),
            "System Settings fallback path must exist on disk, got: \(PopoverContentView.systemSettingsFallbackPath)"
        )
    }

    func testStorageButtonLabel() {
        XCTAssertEqual(
            PopoverContentView.storageButtonLabel,
            "Open Storage Settings"
        )
    }
}
