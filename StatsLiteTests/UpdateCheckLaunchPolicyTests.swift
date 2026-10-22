//
//  UpdateCheckLaunchPolicyTests.swift
//  StatsLiteTests
//
//  Launch policy fixture (plan 2026-10-20-in-app-update-check, T2b).
//  Red phase: `UpdateCheckLaunchPolicy` and the service `environment:`
//  init parameter do not exist yet, so this file fails to compile
//  until green. Key strings mirror UpdateCheckService's constants;
//  literals avoid a main-actor-isolated global initializer. No
//  network: the fixture and a nil-returning counting fake own every
//  path.
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
    "updateCheckLastCheckEpoch",
]

private func clearServiceKeys() {
    for key in serviceKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// Fake source that counts invocations and always returns nil. A
/// non-zero count proves a path reached the network.
private final class NilCountingReleaseSource: UpdateReleaseSource,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var invocations = 0

    func latestRelease() async -> ReleaseInfo? {
        lock.withLock { invocations += 1 }
        return nil
    }

    var invocationCount: Int {
        lock.withLock { invocations }
    }
}

/// Writes a throwaway bundle directory whose Info.plist pins the
/// display version (same approach as UpdateCheckServicePersistenceTests).
private func makeTestBundle(shortVersion: String) throws -> Bundle {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("UpdateCheckLaunchPolicyTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    let plist: [String: Any] = ["CFBundleShortVersionString": shortVersion]
    let plistData = try PropertyListSerialization.data(
        fromPropertyList: plist,
        format: .xml,
        options: 0
    )
    try plistData.write(to: directory.appendingPathComponent("Info.plist"))
    return try XCTUnwrap(Bundle(path: directory.path))
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

    /// Polls until the condition holds or the timeout elapses.
    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
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

    /// With the fixture in the injected environment, the launch check
    /// prompts for 9.9.9 and never touches the release source.
    @MainActor
    func testServiceFixturePromptsWithoutTouchingSource() async throws {
        let source = NilCountingReleaseSource()
        let bundle = try makeTestBundle(shortVersion: "1.0.0")
        let service = UpdateCheckService(
            source: source,
            bundle: bundle,
            environment: [fixtureKey: "9.9.9"]
        )

        service.start()
        await waitUntil { service.availableUpdate != nil }
        // Give a hypothetical late source call a beat to misbehave
        // before the count assertion.
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(
            service.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("9.9.9"))
        )
        XCTAssertEqual(
            service.availableUpdate?.releasePageURL,
            try XCTUnwrap(URL(string: releasesURLString))
        )
        XCTAssertEqual(
            source.invocationCount,
            0,
            "the fixture must bypass the source entirely"
        )
    }

    /// A stored dismissal of the fixture version keeps the banner
    /// hidden: dismissal wins over the fixture.
    @MainActor
    func testDismissedFixtureVersionStaysHidden() async throws {
        UserDefaults.standard.set(
            "9.9.9",
            forKey: UpdateCheckService.dismissedVersionKey
        )
        let source = NilCountingReleaseSource()
        let bundle = try makeTestBundle(shortVersion: "1.0.0")
        let service = UpdateCheckService(
            source: source,
            bundle: bundle,
            environment: [fixtureKey: "9.9.9"]
        )

        service.start()
        // The launch check stamps the epoch when it runs. Wait for the
        // stamp, then leave a beat for a hypothetical late prompt.
        await waitUntil {
            UserDefaults.standard.double(
                forKey: UpdateCheckService.lastCheckEpochKey
            ) > 0
        }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertNil(
            service.availableUpdate,
            "a stored dismissal beats the fixture"
        )
        XCTAssertEqual(
            source.invocationCount,
            0,
            "the fixture must bypass the source entirely"
        )
    }
}
