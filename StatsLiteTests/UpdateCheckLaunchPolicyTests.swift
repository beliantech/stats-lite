//
//  UpdateCheckLaunchPolicyTests.swift
//  StatsLiteTests
//
//  Launch policy fixture (plan 2026-10-20-in-app-update-check, T2b).
//  The service-fixture section was rewritten for T3b against the
//  coordinator seam: start() seeds the fixture synchronously after
//  the GitHub poller retirement, so no fake source or test bundle
//  exists in this file. Key strings mirror UpdateCheckService's
//  constants; literals avoid a main-actor-isolated global
//  initializer. No network.
//

import Foundation
import XCTest
@testable import StatsLite

private let fixtureKey = "STATSLITE_FAKE_UPDATE_VERSION"
private let releasesURLString =
    "https://github.com/beliantech/stats-lite/releases"

/// UserDefaults keys owned by these tests, plus the reset helper. The
/// helper is a free function so setUp/tearDown can call it without an
/// actor-isolation warning.
private let serviceKeys = [
    "updateCheckDismissedVersion",
]

private func clearServiceKeys() {
    for key in serviceKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@MainActor
final class UpdateCheckLaunchPolicyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearServiceKeys()
    }

    override func tearDown() {
        clearServiceKeys()
        super.tearDown()
    }

    // MARK: - skipCheck

    /// Harness purity: the popover flag with no fixture key skips the
    /// check even when other environment keys are present.
    func testSkipCheckIsTrueWhenPopoverFlagHasNoFixture() {
        let arguments = [
            "/Applications/StatsLite.app/Contents/MacOS/StatsLite",
            "--open-popover",
        ]
        XCTAssertTrue(
            UpdateCheckLaunchPolicy.skipCheck(
                arguments: arguments,
                environment: ["PATH": "/usr/bin"]
            )
        )
    }

    /// The fixture key overrides the flag skip. This is what makes
    /// banner captures possible under the measurement harness.
    func testFixtureKeyOverridesPopoverSkip() {
        let arguments = [
            "/Applications/StatsLite.app/Contents/MacOS/StatsLite",
            "--open-popover",
        ]
        XCTAssertFalse(
            UpdateCheckLaunchPolicy.skipCheck(
                arguments: arguments,
                environment: [fixtureKey: "9.9.9"]
            )
        )
    }

    /// Fixture key without the flag does not skip: the check runs.
    func testFixtureKeyWithoutFlagDoesNotSkip() {
        XCTAssertFalse(
            UpdateCheckLaunchPolicy.skipCheck(
                arguments: ["/Applications/StatsLite.app/Contents/MacOS/StatsLite"],
                environment: [fixtureKey: "9.9.9"]
            )
        )
    }

    /// No flag and no fixture does not skip: normal launch runs the
    /// check.
    func testNoFlagAndNoFixtureDoesNotSkip() {
        XCTAssertFalse(
            UpdateCheckLaunchPolicy.skipCheck(
                arguments: ["/Applications/StatsLite.app/Contents/MacOS/StatsLite"],
                environment: [:]
            )
        )
    }

    /// The flag matches an exact argument element only. The substring
    /// `--open-popover-hold` is a different flag and does not count.
    func testPopoverFlagSubstringDoesNotCountAsFlag() {
        XCTAssertFalse(
            UpdateCheckLaunchPolicy.skipCheck(
                arguments: [
                    "/Applications/StatsLite.app/Contents/MacOS/StatsLite",
                    "--open-popover-hold",
                ],
                environment: [:]
            )
        )
    }

    // MARK: - fixtureRelease

    /// A plain three-part version parses into the fixture release
    /// with the public releases page URL.
    func testFixtureReleaseParsesPlainVersion() throws {
        let release = try XCTUnwrap(
            UpdateCheckLaunchPolicy.fixtureRelease(
                environment: [fixtureKey: "9.9.9"]
            )
        )
        XCTAssertEqual(
            release.version,
            try XCTUnwrap(SemanticVersion("9.9.9"))
        )
        XCTAssertEqual(
            release.releasePageURL,
            try XCTUnwrap(URL(string: releasesURLString))
        )
    }

    /// One leading "v" is allowed, matching SemanticVersion rules.
    func testFixtureReleaseParsesVPrefixedVersion() throws {
        let release = try XCTUnwrap(
            UpdateCheckLaunchPolicy.fixtureRelease(
                environment: [fixtureKey: "v9.9.9"]
            )
        )
        XCTAssertEqual(
            release.version,
            try XCTUnwrap(SemanticVersion("9.9.9"))
        )
    }

    /// Values that fail the SemanticVersion parse produce nil: the
    /// fixture then behaves as absent.
    func testFixtureReleaseRejectsMalformedValues() {
        for value in ["garbage", "", "1.2"] {
            XCTAssertNil(
                UpdateCheckLaunchPolicy.fixtureRelease(
                    environment: [fixtureKey: value]
                ),
                "fixture value \(value) must not parse"
            )
        }
    }

    /// A missing key means no fixture. Unrelated keys do not count.
    func testFixtureReleaseIsNilWithoutKey() {
        XCTAssertNil(
            UpdateCheckLaunchPolicy.fixtureRelease(environment: [:])
        )
        XCTAssertNil(
            UpdateCheckLaunchPolicy.fixtureRelease(
                environment: ["STATSLITE_FAKE_UPDATE_TAG": "9.9.9"]
            )
        )
    }

    // MARK: - Service fixture behavior

    /// With the fixture in the injected environment, start() seeds
    /// the banner synchronously and never touches the Sparkle seam.
    @MainActor
    func testServiceFixtureSeedsBannerWithoutTouchingUpdaterSeam() {
        let updater = SeededUpdaterSpy()
        let service = UpdateCheckService(
            environment: [fixtureKey: "9.9.9"],
            updater: updater
        )

        service.start()

        XCTAssertEqual(
            service.availableUpdate?.version,
            SemanticVersion("9.9.9"),
            "the fixture must seed the banner at start()"
        )
        XCTAssertEqual(
            service.availableUpdate?.releasePageURL,
            URL(string: releasesURLString)
        )
        XCTAssertEqual(
            updater.totalCheckCount,
            0,
            "the fixture must not touch the Sparkle seam"
        )
    }

    /// A stored dismissal of the fixture version keeps the banner
    /// hidden: dismissal wins over the fixture.
    @MainActor
    func testDismissedFixtureVersionStaysHidden() {
        UserDefaults.standard.set(
            "9.9.9",
            forKey: UpdateCheckService.dismissedVersionKey
        )
        let updater = SeededUpdaterSpy()
        let service = UpdateCheckService(
            environment: [fixtureKey: "9.9.9"],
            updater: updater
        )

        service.start()

        XCTAssertNil(
            service.availableUpdate,
            "a stored dismissal beats the fixture"
        )
        XCTAssertEqual(
            updater.totalCheckCount,
            0,
            "the fixture must not touch the Sparkle seam"
        )
    }
}

/// Seam spy: counts every entry point so a test can prove the
/// fixture path never reaches Sparkle.
@MainActor
private final class SeededUpdaterSpy: SparkleUpdaterControlling {
    private(set) var isUpdaterRunning = false
    private(set) var checkForUpdatesCount = 0
    private(set) var checkForUpdatesInteractivelyCount = 0

    func checkForUpdates() {
        checkForUpdatesCount += 1
    }

    func checkForUpdatesInteractively() {
        checkForUpdatesInteractivelyCount += 1
    }

    var totalCheckCount: Int {
        checkForUpdatesCount + checkForUpdatesInteractivelyCount
    }
}
