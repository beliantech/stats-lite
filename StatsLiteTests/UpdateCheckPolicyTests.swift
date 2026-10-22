//
//  UpdateCheckPolicyTests.swift
//  StatsLiteTests
//
//  Pure prompt policy (plan 2026-10-20-in-app-update-check, ISC I1).
//  UpdateCheckPolicy.promptState(latest:current:dismissedVersion:) maps a
//  latest release, the installed version, and the stored dismissed version
//  to UpdatePromptState. No network, no UserDefaults, no view.
//

import Foundation
import XCTest
@testable import StatsLite

final class UpdateCheckPolicyTests: XCTestCase {

    private let releaseURL = URL(
        string: "https://github.com/beliantech/stats-lite/releases/tag/v1.2.0"
    )!

    private func makeRelease(tag: String) throws -> ReleaseInfo {
        let version = try XCTUnwrap(SemanticVersion(tag))
        return ReleaseInfo(version: version, releasePageURL: releaseURL)
    }

    private func makeVersion(_ string: String) throws -> SemanticVersion {
        return try XCTUnwrap(SemanticVersion(string))
    }

    // MARK: - State table

    func testNewerAndNotDismissedPrompts() throws {
        let latest = try makeRelease(tag: "v1.2.0")
        let current = try makeVersion("1.1.0")
        let state = UpdateCheckPolicy.promptState(
            latest: latest,
            current: current,
            dismissedVersion: nil
        )
        XCTAssertEqual(state, .prompt(latest))
    }

    func testEqualVersionsProduceNone() throws {
        let latest = try makeRelease(tag: "v1.1.0")
        let current = try makeVersion("1.1.0")
        let state = UpdateCheckPolicy.promptState(
            latest: latest,
            current: current,
            dismissedVersion: nil
        )
        XCTAssertEqual(state, .none)
    }

    func testOlderLatestProducesNone() throws {
        let latest = try makeRelease(tag: "v1.0.0")
        let current = try makeVersion("1.1.0")
        let state = UpdateCheckPolicy.promptState(
            latest: latest,
            current: current,
            dismissedVersion: nil
        )
        XCTAssertEqual(state, .none)
    }

    func testNewerWithDismissedMatchingVersionProducesNone() throws {
        let latest = try makeRelease(tag: "v1.1.0")
        let current = try makeVersion("1.0.0")
        let state = UpdateCheckPolicy.promptState(
            latest: latest,
            current: current,
            dismissedVersion: "1.1.0"
        )
        XCTAssertEqual(state, .none)
    }

    func testNewerWithDismissedOlderVersionStillPrompts() throws {
        let latest = try makeRelease(tag: "v1.2.0")
        let current = try makeVersion("1.0.0")
        let state = UpdateCheckPolicy.promptState(
            latest: latest,
            current: current,
            dismissedVersion: "1.1.0"
        )
        XCTAssertEqual(state, .prompt(latest))
    }

    // MARK: - Dismissal comparison ignores a leading "v" on either side

    func testDismissedValueWithLeadingVPrefixMatchesLatest() throws {
        let latest = try makeRelease(tag: "1.2.0")
        let current = try makeVersion("1.0.0")
        let state = UpdateCheckPolicy.promptState(
            latest: latest,
            current: current,
            dismissedVersion: "v1.2.0"
        )
        XCTAssertEqual(state, .none)
    }

    func testDismissedValueWithoutPrefixMatchesVPrefixedLatestTag() throws {
        let latest = try makeRelease(tag: "v1.2.0")
        let current = try makeVersion("1.0.0")
        let state = UpdateCheckPolicy.promptState(
            latest: latest,
            current: current,
            dismissedVersion: "1.2.0"
        )
        XCTAssertEqual(state, .none)
    }
}
