//
//  UpdateCheckRelaunchRestoreTests.swift
//  StatsLiteTests
//
//  Red phase for plan 2026-10-27-update-check-relaunch-and-retry-fix
//  (FM1-FM7). The service must stamp updateCheckLastCheckEpoch only
//  after the release resolves, write a release cache at
//  updateCheckCachedLatest on a successful network fetch, and restore
//  availableUpdate from that cache on the launch skip path
//  (0 <= gap < launchCheckMinGap). Key strings mirror
//  UpdateCheckService's constants and the new cache key; literals
//  avoid a main-actor-isolated global initializer. No network: every
//  path ends in a counting fake or the fixture.
//

import Foundation
import XCTest
@testable import StatsLite

private let fixtureKey = "STATSLITE_FAKE_UPDATE_VERSION"

/// UserDefaults keys owned by these tests, plus the reset helper. The
/// helper is a free function so the nonisolated setUp/tearDown
/// overrides can call it without an actor-isolation warning. The key
/// strings mirror UpdateCheckService's constants and the new
/// updateCheckCachedLatest cache key from the plan.
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
/// An optional delay keeps the fetch in flight so a test can observe
/// the stored epoch mid-check.
private final class CountingReleaseSource: UpdateReleaseSource,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var invocations = 0
    let release: ReleaseInfo?
    let delay: TimeInterval

    init(release: ReleaseInfo?, delay: TimeInterval = 0) {
        self.release = release
        self.delay = delay
    }

    func latestRelease() async -> ReleaseInfo? {
        lock.withLock { invocations += 1 }
        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
        }
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
        .appendingPathComponent("UpdateCheckRelaunchRestoreTests-\(UUID().uuidString)")
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
final class UpdateCheckRelaunchRestoreTests: XCTestCase {

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

    /// The raw release-cache value at updateCheckCachedLatest, in
    /// whichever encoding the service stores (Data or String).
    private func cachedLatestObject() -> Any? {
        UserDefaults.standard.object(forKey: "updateCheckCachedLatest")
    }

    // MARK: - FM1 epoch stamps only after a resolved release

    /// A launch check with a nil source result must leave the stored
    /// epoch at its old value. Red phase: performCheck() stamps the
    /// epoch before the source call, so the old value is gone.
    @MainActor
    func testFailedFetchLeavesStoredEpochUnchanged() async throws {
        let oldEpoch = Date().timeIntervalSince1970 - 4000
        UserDefaults.standard.set(
            oldEpoch,
            forKey: UpdateCheckService.lastCheckEpochKey
        )
        let source = CountingReleaseSource(release: nil)
        let service = UpdateCheckService(
            source: source,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        service.start()
        await waitUntil { source.invocationCount >= 1 }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertGreaterThanOrEqual(
            source.invocationCount,
            1,
            "a stale epoch must run the launch check"
        )
        XCTAssertEqual(
            UserDefaults.standard.double(
                forKey: UpdateCheckService.lastCheckEpochKey
            ),
            oldEpoch,
            "a nil source result must not stamp the epoch"
        )
        XCTAssertNil(
            service.availableUpdate,
            "a nil source result leaves availableUpdate untouched"
        )
    }

    // MARK: - FM2 relaunch restore from cache

    /// Service 1 fetches a newer release and stores the cache.
    /// Service 2 starts seconds later inside the 300 s launch floor
    /// against the same UserDefaults. Red phase: the skip path has no
    /// restore, so service 2 shows nothing.
    @MainActor
    func testRelaunchWithinLaunchFloorRestoresAvailableUpdateFromCache() async throws {
        let first = CountingReleaseSource(
            release: try makeRelease(tag: "9.9.9")
        )
        let serviceOne = UpdateCheckService(
            source: first,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        serviceOne.start()
        await waitUntil { serviceOne.availableUpdate != nil }
        XCTAssertEqual(
            serviceOne.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("9.9.9"))
        )

        let second = CountingReleaseSource(release: nil)
        let serviceTwo = UpdateCheckService(
            source: second,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        serviceTwo.start()
        await waitUntil(timeout: 1) { serviceTwo.availableUpdate != nil }

        XCTAssertEqual(
            serviceTwo.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("9.9.9")),
            "a relaunch inside the launch floor must restore the cached release"
        )
        XCTAssertEqual(
            second.invocationCount,
            0,
            "the restore path must not reach the network"
        )
    }

    // MARK: - FM3 dismissal beats the restore path

    /// Service 1 fetches 9.9.9. A first relaunch restores it, the
    /// user dismisses it, and the next relaunch must keep it hidden.
    /// Red phase: the skip path has no restore, so the first relaunch
    /// already shows nothing.
    @MainActor
    func testDismissedCachedVersionStaysHiddenAcrossRelaunch() async throws {
        let first = CountingReleaseSource(
            release: try makeRelease(tag: "9.9.9")
        )
        let serviceOne = UpdateCheckService(
            source: first,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        serviceOne.start()
        await waitUntil { serviceOne.availableUpdate != nil }
        XCTAssertEqual(
            serviceOne.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("9.9.9"))
        )

        let restore = CountingReleaseSource(release: nil)
        let serviceRestore = UpdateCheckService(
            source: restore,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        serviceRestore.start()
        await waitUntil(timeout: 1) { serviceRestore.availableUpdate != nil }
        XCTAssertEqual(
            serviceRestore.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("9.9.9")),
            "the first relaunch must restore the cached release"
        )
        XCTAssertEqual(
            restore.invocationCount,
            0,
            "the restore path must not reach the network"
        )

        serviceRestore.dismiss(version: "9.9.9")
        XCTAssertTrue(serviceRestore.isDismissed(version: "9.9.9"))

        let second = CountingReleaseSource(release: nil)
        let serviceTwo = UpdateCheckService(
            source: second,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        serviceTwo.start()
        await waitUntil(timeout: 1) { serviceTwo.availableUpdate != nil }
        XCTAssertNil(
            serviceTwo.availableUpdate,
            "a dismissed cached release must stay hidden after relaunch"
        )
        XCTAssertEqual(
            second.invocationCount,
            0,
            "the restore path must not reach the network"
        )
    }

    // MARK: - FM4 epoch stamps on a resolved release

    /// The launch fetch resolves after 600 ms. The stored epoch must
    /// keep its old value while the fetch is in flight and change
    /// only after the release resolves. Red phase: performCheck()
    /// stamps the epoch before the source call, so the in-flight
    /// assertion fails. The fixture leg then proves a fixture launch
    /// stamps the epoch too.
    @MainActor
    func testSuccessfulCheckStampsEpochAfterResolveForNetworkAndFixture() async throws {
        let oldEpoch = Date().timeIntervalSince1970 - 4000
        UserDefaults.standard.set(
            oldEpoch,
            forKey: UpdateCheckService.lastCheckEpochKey
        )
        let source = CountingReleaseSource(
            release: try makeRelease(tag: "9.9.9"),
            delay: 0.6
        )
        let service = UpdateCheckService(
            source: source,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        service.start()
        await waitUntil { source.invocationCount >= 1 }
        // The fake counts, then sleeps 600 ms, so the fetch is in
        // flight now.
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(
            UserDefaults.standard.double(
                forKey: UpdateCheckService.lastCheckEpochKey
            ),
            oldEpoch,
            "the epoch must wait for the release to resolve"
        )

        await waitUntil { service.availableUpdate != nil }
        let networkEpoch = UserDefaults.standard.double(
            forKey: UpdateCheckService.lastCheckEpochKey
        )
        XCTAssertGreaterThan(
            networkEpoch,
            oldEpoch,
            "a resolved network release must stamp the epoch"
        )

        // Fixture leg: a fixture launch stamps the epoch and never
        // reaches the source.
        try? await Task.sleep(for: .milliseconds(50))
        let fixtureSource = CountingReleaseSource(release: nil)
        let fixtureService = UpdateCheckService(
            source: fixtureSource,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [fixtureKey: "9.9.9"]
        )

        fixtureService.start()
        await waitUntil { fixtureService.availableUpdate != nil }
        let fixtureEpoch = UserDefaults.standard.double(
            forKey: UpdateCheckService.lastCheckEpochKey
        )
        XCTAssertGreaterThan(
            fixtureEpoch,
            networkEpoch,
            "a resolved fixture release must stamp the epoch"
        )
        XCTAssertEqual(
            fixtureSource.invocationCount,
            0,
            "the fixture must bypass the source entirely"
        )
    }

    // MARK: - FM5 stale cache does not prompt

    /// Service 1 fetches an older release: nothing prompts, but the
    /// successful fetch still writes the cache. Service 2 relaunches
    /// inside the launch floor with a newer install than the cache.
    /// Red phase: the successful fetch never writes the cache, so the
    /// cache assertion fails.
    @MainActor
    func testStaleCachedReleaseDoesNotPromptAfterRelaunch() async throws {
        let first = CountingReleaseSource(
            release: try makeRelease(tag: "1.0.0")
        )
        let serviceOne = UpdateCheckService(
            source: first,
            bundle: try makeTestBundle(shortVersion: "1.1.1"),
            environment: [:]
        )

        serviceOne.start()
        await waitUntil { first.invocationCount >= 1 }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertGreaterThanOrEqual(
            first.invocationCount,
            1,
            "a stale epoch must run the launch check"
        )
        XCTAssertNil(
            serviceOne.availableUpdate,
            "an older latest release must not prompt"
        )
        XCTAssertNotNil(
            cachedLatestObject(),
            "a successful network fetch must write the release cache"
        )

        let second = CountingReleaseSource(release: nil)
        let serviceTwo = UpdateCheckService(
            source: second,
            bundle: try makeTestBundle(shortVersion: "1.1.1"),
            environment: [:]
        )

        serviceTwo.start()
        await waitUntil(timeout: 1) { serviceTwo.availableUpdate != nil }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertNil(
            serviceTwo.availableUpdate,
            "a cached release older than the install must not prompt"
        )
        XCTAssertEqual(
            second.invocationCount,
            0,
            "the skip path must not reach the network"
        )
    }

    // MARK: - FM6 fixture does not pollute the cache

    /// Service 1 fetches 1.2.3 over the network and writes the cache.
    /// A fixture launch then prompts for 9.9.9. The stored cache must
    /// survive the fixture launch unchanged, so a later real launch
    /// restores 1.2.3 and not the fixture value. Red phase: the
    /// successful fetch never writes the cache, so the capture fails.
    @MainActor
    func testFixtureCheckLeavesReleaseCacheUnchanged() async throws {
        let first = CountingReleaseSource(
            release: try makeRelease(tag: "1.2.3")
        )
        let serviceOne = UpdateCheckService(
            source: first,
            bundle: try makeTestBundle(shortVersion: "1.1.1"),
            environment: [:]
        )

        serviceOne.start()
        await waitUntil { serviceOne.availableUpdate != nil }
        XCTAssertEqual(
            serviceOne.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("1.2.3"))
        )
        let before = cachedLatestObject()
        XCTAssertNotNil(
            before,
            "a successful network fetch must write the release cache"
        )

        let fixtureSource = CountingReleaseSource(release: nil)
        let fixtureService = UpdateCheckService(
            source: fixtureSource,
            bundle: try makeTestBundle(shortVersion: "1.1.1"),
            environment: [fixtureKey: "9.9.9"]
        )

        fixtureService.start()
        await waitUntil { fixtureService.availableUpdate != nil }
        XCTAssertEqual(
            fixtureService.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("9.9.9"))
        )
        XCTAssertEqual(
            fixtureSource.invocationCount,
            0,
            "the fixture must bypass the source entirely"
        )

        let after = cachedLatestObject()
        if let cached = before as? Data {
            XCTAssertEqual(
                after as? Data,
                cached,
                "a fixture launch must not rewrite the release cache"
            )
        } else if let cached = before as? String {
            XCTAssertEqual(
                after as? String,
                cached,
                "a fixture launch must not rewrite the release cache"
            )
        } else if before != nil {
            XCTFail("the release cache must hold Data or String")
        }
    }

    // MARK: - FM7 clock skew runs the check, not the restore path

    /// A stored epoch in the future (gap < 0) counts as stale: the
    /// launch check runs against the network. The cache from an
    /// earlier successful fetch exists, but the skew path must not
    /// restore from it. A nil fetch must not rewrite the future
    /// epoch. Red phase: performCheck() stamps the epoch before the
    /// source call, so the future epoch is overwritten, and the cache
    /// is never written.
    @MainActor
    func testFutureStoredEpochRunsCheckAndSkipsCacheRestore() async throws {
        // Seed the cache with one real successful fetch.
        let seed = CountingReleaseSource(
            release: try makeRelease(tag: "9.9.9")
        )
        let seedService = UpdateCheckService(
            source: seed,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        seedService.start()
        await waitUntil { seedService.availableUpdate != nil }
        XCTAssertEqual(
            seedService.availableUpdate?.version,
            try XCTUnwrap(SemanticVersion("9.9.9"))
        )
        XCTAssertNotNil(
            cachedLatestObject(),
            "a successful network fetch must write the release cache"
        )

        // Clock moved back: the stored epoch sits in the future.
        let futureEpoch = Date().timeIntervalSince1970 + 4000
        UserDefaults.standard.set(
            futureEpoch,
            forKey: UpdateCheckService.lastCheckEpochKey
        )

        let source = CountingReleaseSource(release: nil)
        let service = UpdateCheckService(
            source: source,
            bundle: try makeTestBundle(shortVersion: "1.0.0"),
            environment: [:]
        )

        service.start()
        await waitUntil { source.invocationCount >= 1 }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertGreaterThanOrEqual(
            source.invocationCount,
            1,
            "a future stored epoch must still run the launch check"
        )
        XCTAssertNil(
            service.availableUpdate,
            "the clock-skew path must not restore from the cache"
        )
        XCTAssertEqual(
            UserDefaults.standard.double(
                forKey: UpdateCheckService.lastCheckEpochKey
            ),
            futureEpoch,
            "a nil source result must not rewrite the stored epoch"
        )
    }
}
