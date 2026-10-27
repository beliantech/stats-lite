//
//  SparkleConfigurationTests.swift
//  StatsLiteTests
//
//  Sparkle 2 build-configuration contract (plan 2026-10-27-sparkle-auto-update).
//  The generated app Info.plist must carry the Sparkle feed URL, EdDSA public
//  key, and update-check policy. The built app bundle must contain the
//  embedded Sparkle.framework.
//

import Foundation
import XCTest

final class SparkleConfigurationTests: XCTestCase {

    private let expectedFeedURL =
        "https://github.com/beliantech/stats-lite/releases/latest/download/appcast.xml"

    /// Sparkle reads these keys with objectForInfoDictionaryKey: and accepts
    /// both plist-native and string forms. The test mirrors that contract.
    private func plistBool(_ key: String) -> Bool? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else { return nil }
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        if let text = value as? String {
            switch text.uppercased() {
            case "YES", "TRUE", "1": return true
            case "NO", "FALSE", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private func plistInt(_ key: String) -> Int? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else { return nil }
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }

    // MARK: - Info.plist keys

    func testInfoPlistContainsSUFeedURL() {
        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        XCTAssertEqual(
            feedURL,
            expectedFeedURL,
            "SUFeedURL must point at the GitHub releases appcast"
        )
    }

    func testInfoPlistContainsNonEmptySUPublicEDKey() {
        let edKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        XCTAssertNotNil(edKey, "SUPublicEDKey must exist in the app Info.plist")
        XCTAssertFalse(
            edKey?.isEmpty ?? true,
            "SUPublicEDKey must not be empty (placeholder value is acceptable for now)"
        )
    }

    func testInfoPlistEnablesAutomaticChecksWithDailyInterval() {
        XCTAssertEqual(
            plistBool("SUEnableAutomaticChecks"),
            true,
            "SUEnableAutomaticChecks must be true"
        )
        XCTAssertEqual(
            plistInt("SUScheduledCheckInterval"),
            86_400,
            "SUScheduledCheckInterval must be one day in seconds"
        )
        XCTAssertEqual(
            plistBool("SUAutomaticallyUpdate"),
            false,
            "SUAutomaticallyUpdate must be false; the user confirms installs"
        )
    }

    // MARK: - Embedded framework

    func testAppBundleContainsEmbeddedSparkleFramework() {
        let sparkleURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Frameworks/Sparkle.framework")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: sparkleURL.path),
            "Built app bundle must contain Contents/Frameworks/Sparkle.framework at \(sparkleURL.path)"
        )
    }
}
