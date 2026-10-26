//
//  UpdateCheckServicePersistenceTests.swift
//  StatsLiteTests
//
//  Dismiss round-trip and start() idempotence (plan
//  2026-10-20-in-app-update-check, T1) plus the release cache from
//  plan 2026-10-27-update-check-relaunch-and-retry-fix. These tests
//  clear the three UserDefaults.standard keys around each run.
//  The release source is always a fake; no network.
//

import Foundation
import XCTest
@testable import StatsLite

/// UserDefaults keys owned by these tests, plus the reset helper. The
/// helper is a free function so the nonisolated setUp/tearDown
/// overrides can call it without an actor-isolation warning. The key
/// strings mirror UpdateCheckService's constants; literals avoid a
/// main-actor-isolated global initializer.
private let serviceKeys = [
    "updateCheckDismissedVersion",
    "updateCheckLastCheckEpoch",
    "updateCheckCachedLatest",
]

private func clearServiceKeys() {
    for key in serviceKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// Fake source that counts invocations and returns a canned release.
private final class CountingReleaseSource: UpdateReleaseSource, @unchecked Sendable {
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
/// display version, so the service reads a known current version
/// instead of depending on the test host Info.plist.
private func makeTestBundle(shortVersion: String) throws -> Bundle {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("UpdateCheckServiceTests-\(UUID().uuidString)")
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
final class UpdateCheckServicePersistenceTests: XCTestCase {

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

    // MARK: - Dismiss round-trip

    @MainActor
    func testDismissRoundTripPersistsNormalizedVersion() async throws {
        let source = CountingReleaseSource(release: try makeRelease(tag: "v9.9.9"))
        let bundle = try makeTestBundle(shortVersion: "1.0.0")
        let service = UpdateCheckService(source: source, bundle: bundle)

        service.start()
        await waitUntil { service.availableUpdate != nil }
        XCTAssertEqual(
            service.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("9.9.9"))
        )

        service.dismiss(version: "v9.9.9")

        XCTAssertNil(service.availableUpdate, "dismiss clears the prompted update")
        XCTAssertTrue(service.isDismissed(version: "9.9.9"))
        XCTAssertTrue(service.isDismissed(version: "v9.9.9"))
        XCTAssertEqual(
            UserDefaults.standard.string(
                forKey: UpdateCheckService.dismissedVersionKey
            ),
            "9.9.9",
            "the stored key is the normalized description with no v prefix"
        )
    }

    @MainActor
    func testIsDismissedIsFalseWhenNoVersionWasDismissed() throws {
        let service = UpdateCheckService(
            source: CountingReleaseSource(release: nil),
            bundle: try makeTestBundle(shortVersion: "1.0.0")
        )
        XCTAssertFalse(service.isDismissed(version: "1.2.3"))
    }

    // MARK: - start() idempotence

    @MainActor
    func testStartCalledTwiceRunsOneCheckLoop() async throws {
        let source = CountingReleaseSource(release: nil)
        let service = UpdateCheckService(
            source: source,
            bundle: try makeTestBundle(shortVersion: "1.0.0")
        )

        service.start()
        service.start()

        await waitUntil { source.invocationCount >= 1 }
        // One loop runs one launch check. Give a hypothetical second
        // loop a beat to misbehave before the assertion.
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(
            source.invocationCount,
            1,
            "a second start() must not spawn a second check loop"
        )
        XCTAssertNil(
            service.availableUpdate,
            "a nil source result leaves availableUpdate untouched"
        )
    }
}
