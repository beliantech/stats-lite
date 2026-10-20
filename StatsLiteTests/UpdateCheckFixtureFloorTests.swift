//
//  UpdateCheckFixtureFloorTests.swift
//  StatsLiteTests
//
//  Launch-floor interaction with the fixture env key (plan
//  2026-10-20-in-app-update-check, T2c). Red phase: the 300 s floor in
//  UpdateCheckService.start() currently throttles the second capture
//  launch even when the fixture key is set, so
//  testFixtureIgnoresLaunchFloor fails until the service lets the
//  fixture bypass the floor. The other two tests pin the production
//  throttle paths so the fix cannot regress them. Key strings mirror
//  UpdateCheckService's constants; literals avoid a main-actor-
//  isolated global initializer. No network: every path ends in a
//  counting fake or the fixture.
//

import Foundation
import XCTest
@testable import StatsLite

private let fixtureKey = "STATSLITE_FAKE_UPDATE_VERSION"

/// UserDefaults keys owned by these tests, plus the reset helper. The
/// helper is a free function so the nonisolated setUp/tearDown
/// overrides can call it without an actor-isolation warning.
private let serviceKeys = [
    "updateCheckDismissedVersion",
    "updateCheckLastCheckEpoch",
]

private func clearServiceKeys() {
    for key in serviceKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// Fake source that counts invocations and returns a canned release.
private final class CountingReleaseSource: UpdateReleaseSource,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var invocations = 0
    let release: ReleaseInfo?

    init(release: ReleaseInfo?) {
        self.release = release
    }

    func latestRelease() async -> ReleaseInfo? {
        lock.withLock { invocations += 1 }
        return release
    }

    var invocationCount: Int {
        lock.withLock { invocations }
    }
}

/// Writes a throwaway bundle directory whose Info.plist pins the
/// display version (same approach as UpdateCheckServicePersistenceTests).
private func makeTestBundle(shortVersion: String) throws -> Bundle {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("UpdateCheckFixtureFloorTests-\(UUID().uuidString)")
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
final class UpdateCheckFixtureFloorTests: XCTestCase {

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

    private func makeRelease(tag: String) throws -> ReleaseInfo {
        let version = try XCTUnwrap(SemanticVersion(tag))
        return ReleaseInfo(
            version: version,
            releasePageURL: try XCTUnwrap(
                URL(string: "https://example.com/releases/\(tag)")
            )
        )
    }

    // MARK: - Fixture versus the 300 s launch floor

    /// The capture script relaunches the app about two minutes after
    /// the first launch. With a fresh epoch stored and the fixture key
    /// set, the launch check must still run and prompt for the
    /// fixture. The counting fake must never be reached.
    @MainActor
    func testFixtureIgnoresLaunchFloor() async throws {
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: UpdateCheckService.lastCheckEpochKey
        )
        let source = CountingReleaseSource(release: try makeRelease(tag: "0.0.1"))
        let service = UpdateCheckService(
            source: source,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [fixtureKey: "9.9.9"]
        )

        service.start()
        await waitUntil { service.availableUpdate != nil }
        // Give a hypothetical late source call a beat to misbehave
        // before the count assertion.
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(
            service.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("9.9.9")),
            "the fixture must bypass the launch floor"
        )
        XCTAssertEqual(
            source.invocationCount,
            0,
            "the fixture must bypass the source entirely"
        )
    }

    /// Production throttle with the fixture absent: a fresh epoch
    /// suppresses the launch check even though the fake source would
    /// return a promptable release. The fix must not break this path.
    @MainActor
    func testLaunchFloorStillThrottlesWithoutFixture() async throws {
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: UpdateCheckService.lastCheckEpochKey
        )
        let source = CountingReleaseSource(release: try makeRelease(tag: "5.0.0"))
        let service = UpdateCheckService(
            source: source,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        service.start()
        // Wait for a launch check that must never arrive, then assert
        // nothing happened.
        await waitUntil(timeout: 1) { source.invocationCount >= 1 }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(
            source.invocationCount,
            0,
            "a fresh epoch must throttle the launch check without the fixture"
        )
        XCTAssertNil(
            service.availableUpdate,
            "a throttled launch check leaves availableUpdate untouched"
        )
    }

    /// Complementary production path: with the fixture absent and the
    /// stored epoch stale, the launch check runs and the real source
    /// decides the prompt.
    @MainActor
    func testStaleEpochRunsRealCheckWithoutFixture() async throws {
        UserDefaults.standard.set(
            Date().timeIntervalSince1970 - 4000,
            forKey: UpdateCheckService.lastCheckEpochKey
        )
        let source = CountingReleaseSource(release: try makeRelease(tag: "1.5.0"))
        let service = UpdateCheckService(
            source: source,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        service.start()
        await waitUntil { service.availableUpdate != nil }

        XCTAssertGreaterThanOrEqual(
            source.invocationCount,
            1,
            "a stale epoch must run the real launch check"
        )
        XCTAssertEqual(
            service.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("1.5.0"))
        )
    }
}
