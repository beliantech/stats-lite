//
//  SparkleUpdateCoordinatorTests.swift
//  StatsLiteTests
//
//  Sparkle coordinator seam (plan 2026-10-27 sparkle-updater, T3a).
//  ISC-3: a scheduled discovery publishes availableUpdate and a
//  scheduled show is refused outside immediate focus, so no window
//  steals focus. ISC-5: the launch policy maps `--open-popover`
//  without the fixture key to startingUpdater false. Every test runs
//  without network: coordinator methods take a recording fake
//  through SparkleUpdaterControlling, and the delegate translation
//  is exercised through internal plain-value methods (no SUAppcastItem
//  construction, no Sparkle import).
//

import Foundation
import XCTest
@testable import StatsLite

/// Recording fake for the Sparkle seam. Counts each entry point so a
/// test can prove which coordinator path forwarded.
@MainActor
private final class RecordingSparkleUpdater: SparkleUpdaterControlling {
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

@MainActor
final class SparkleUpdateCoordinatorTests: XCTestCase {

    private let notesURL = URL(
        string: "https://example.com/releases/2.0.0"
    )!

    private func makeService(
        updater: (any SparkleUpdaterControlling)? = nil,
        environment: [String: String] = [:],
        activateApp: @escaping () -> Void = {}
    ) -> UpdateCheckService {
        UpdateCheckService(
            environment: environment,
            updater: updater,
            activateApp: activateApp
        )
    }

    // MARK: - ISC-3: scheduled discovery and immediate focus

    func testISC3ScheduledDiscoverySetsAvailableUpdate() throws {
        let service = makeService()

        service.publishAvailableUpdate(
            displayVersion: "2.0.0",
            releaseNotesURL: notesURL
        )

        XCTAssertEqual(
            service.availableUpdate,
            ReleaseInfo(
                version: try XCTUnwrap(SemanticVersion("2.0.0")),
                releasePageURL: notesURL
            ),
            "scheduled discovery must publish display version and release notes URL"
        )
    }

    func testISC3ScheduledShowingRefusedWhenNotInImmediateFocus() {
        let service = makeService()

        XCTAssertFalse(
            service.scheduledUpdateShouldShow(
                displayVersion: "2.0.0",
                immediateFocus: false
            ),
            "a scheduled show outside immediate focus must not steal focus"
        )
    }

    func testISC3ScheduledShowingAllowedWhenInImmediateFocus() {
        let service = makeService()

        XCTAssertTrue(
            service.scheduledUpdateShouldShow(
                displayVersion: "2.0.0",
                immediateFocus: true
            )
        )
    }

    func testISC3GentleScheduledRemindersSupported() {
        let service = makeService()

        XCTAssertTrue(
            service.supportsGentleScheduledUpdateReminders,
            "gentle scheduled reminders must be declared"
        )
    }

    func testISC3MalformedDisplayVersionDoesNotPublish() {
        let service = makeService()

        service.publishAvailableUpdate(
            displayVersion: "not-a-version",
            releaseNotesURL: notesURL
        )

        XCTAssertNil(
            service.availableUpdate,
            "an unparsable display version must not publish a banner"
        )
    }

    func testISC3MissingReleaseNotesURLDoesNotPublish() {
        let service = makeService()

        service.publishAvailableUpdate(
            displayVersion: "2.0.0",
            releaseNotesURL: nil
        )

        XCTAssertNil(
            service.availableUpdate,
            "an item without a release notes URL must not publish a banner"
        )
    }

    // MARK: - Dismissal per version

    func testDismissedVersionSuppressesScheduledPublicationAndShowing() {
        let service = makeService()
        service.dismiss(version: "v2.0.0")

        service.publishAvailableUpdate(
            displayVersion: "2.0.0",
            releaseNotesURL: notesURL
        )

        XCTAssertNil(
            service.availableUpdate,
            "a dismissed version must not republish through the scheduled path"
        )
        XCTAssertFalse(
            service.scheduledUpdateShouldShow(
                displayVersion: "2.0.0",
                immediateFocus: true
            ),
            "a dismissed version must not schedule a show even in focus"
        )
    }

    func testDismissedVersionStillForwardsInteractiveCheck() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(updater: updater)
        service.dismiss(version: "2.0.0")

        service.checkForUpdatesInteractively()

        XCTAssertEqual(
            updater.checkForUpdatesInteractivelyCount,
            1,
            "a manual interactive check must reach the seam regardless of dismissal"
        )
    }

    // MARK: - ISC-5: startingUpdater policy

    func testISC5SkipCheckPolicyMapsToStartingUpdaterFalse() {
        XCTAssertFalse(
            UpdateCheckLaunchPolicy.startingUpdater(
                arguments: ["--open-popover"],
                environment: [:]
            ),
            "ISC-5: --open-popover without the fixture key must not start the updater"
        )
        XCTAssertTrue(
            UpdateCheckLaunchPolicy.startingUpdater(
                arguments: [],
                environment: [:]
            )
        )
        XCTAssertTrue(
            UpdateCheckLaunchPolicy.startingUpdater(
                arguments: ["--open-popover"],
                environment: ["STATSLITE_FAKE_UPDATE_VERSION": "9.9.9"]
            ),
            "the fixture key overrides the harness skip"
        )
    }

    // MARK: - FM7: XCTest launch markers keep Sparkle inert

    /// An XCTest host carries `XCTestConfigurationFilePath` in its
    /// environment. The live updater must not start there even
    /// without `--open-popover`: the placeholder EdDSA key raises a
    /// fatal Sparkle alert that deadlocks the test main thread.
    func testFM7XCTestConfigurationFilePathEnvironmentStopsUpdater() {
        XCTAssertFalse(
            UpdateCheckLaunchPolicy.startingUpdater(
                arguments: [
                    "/Applications/StatsLite.app/Contents/MacOS/StatsLite",
                ],
                environment: [
                    "XCTestConfigurationFilePath":
                        "/tmp/StatsLite-8B1F.xctestconfiguration",
                ]
            ),
            "FM7: an XCTest host must not start the live Sparkle updater"
        )
    }

    /// `XCTestSessionIdentifier` is the second XCTest marker. One of
    /// the two markers is set across Xcode versions, so both must
    /// stop the updater.
    func testFM7XCTestSessionIdentifierEnvironmentStopsUpdater() {
        XCTAssertFalse(
            UpdateCheckLaunchPolicy.startingUpdater(
                arguments: [
                    "/Applications/StatsLite.app/Contents/MacOS/StatsLite",
                ],
                environment: [
                    "XCTestSessionIdentifier": "4C9B1D2E-0000-0000-0000-000000000001",
                ]
            ),
            "FM7: an XCTest host must not start the live Sparkle updater"
        )
    }

    /// Production behavior stays unchanged: a normal launch with no
    /// test markers and no `--open-popover` starts the updater.
    func testFM7NormalLaunchStillStartsUpdater() {
        XCTAssertTrue(
            UpdateCheckLaunchPolicy.startingUpdater(
                arguments: [
                    "/Applications/StatsLite.app/Contents/MacOS/StatsLite",
                ],
                environment: ["PATH": "/usr/bin"]
            ),
            "a production launch must still start the updater"
        )
    }

    /// ISC-5 behavior is preserved under FM7: `--open-popover`
    /// without the fixture key still maps to startingUpdater false.
    func testFM7PopoverFlagWithoutFixtureStillStopsUpdater() {
        XCTAssertFalse(
            UpdateCheckLaunchPolicy.startingUpdater(
                arguments: [
                    "/Applications/StatsLite.app/Contents/MacOS/StatsLite",
                    "--open-popover",
                ],
                environment: [:]
            ),
            "ISC-5: --open-popover without the fixture key must not start the updater"
        )
    }

    func testISC5AdapterConstructedWithoutStartReportsUpdaterNotRunning() {
        let adapter = StandardSparkleUpdater(
            startingUpdater: false,
            userDriverDelegate: nil
        )

        XCTAssertFalse(
            adapter.isUpdaterRunning,
            "ISC-5: an adapter built with startingUpdater false must report not running"
        )
    }

    // MARK: - Fixture seeding

    func testFixtureSeedsAvailableUpdateWithoutTouchingUpdaterSeam() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(
            updater: updater,
            environment: ["STATSLITE_FAKE_UPDATE_VERSION": "9.9.9"]
        )

        service.seedFixtureAvailableUpdateIfNeeded()

        XCTAssertEqual(
            service.availableUpdate?.version,
            SemanticVersion("9.9.9"),
            "the fixture key must seed availableUpdate directly"
        )
        XCTAssertEqual(
            service.availableUpdate?.releasePageURL,
            URL(string: UpdateCheckLaunchPolicy.fixtureReleasePageURL),
            "the fixture seeds the canonical release page"
        )
        XCTAssertEqual(
            updater.totalCheckCount,
            0,
            "seeding must not start or touch the Sparkle updater"
        )
    }

    func testFixtureSeedRespectsDismissal() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(
            updater: updater,
            environment: ["STATSLITE_FAKE_UPDATE_VERSION": "9.9.9"]
        )
        service.dismiss(version: "9.9.9")

        service.seedFixtureAvailableUpdateIfNeeded()

        XCTAssertNil(
            service.availableUpdate,
            "a dismissed fixture version must not seed the banner"
        )
        XCTAssertEqual(updater.totalCheckCount, 0)
    }

    func testNoFixtureKeyLeavesAvailableUpdateUnseeded() {
        let service = makeService(environment: [:])

        service.seedFixtureAvailableUpdateIfNeeded()

        XCTAssertNil(service.availableUpdate)
    }

    // MARK: - Coordinator API forwarding

    func testInteractiveCheckForwardsToSeam() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(updater: updater)

        service.checkForUpdatesInteractively()

        XCTAssertEqual(updater.checkForUpdatesInteractivelyCount, 1)
        XCTAssertEqual(updater.checkForUpdatesCount, 0)
    }

    func testInstallUpdateActivatesAppAndForwardsToSeam() {
        let updater = RecordingSparkleUpdater()
        var activated = false
        let service = makeService(
            updater: updater,
            activateApp: { activated = true }
        )

        service.installUpdate()

        XCTAssertTrue(activated, "installUpdate must activate the app first")
        XCTAssertEqual(
            updater.checkForUpdatesCount,
            1,
            "installUpdate must hand off to the Sparkle checkForUpdates path"
        )
        XCTAssertEqual(updater.checkForUpdatesInteractivelyCount, 0)
    }

    func testCoordinatorActionsAreNoOpsWithoutASeam() {
        let service = makeService(updater: nil)

        service.installUpdate()
        service.checkForUpdatesInteractively()

        XCTAssertNil(service.availableUpdate)
    }
}
