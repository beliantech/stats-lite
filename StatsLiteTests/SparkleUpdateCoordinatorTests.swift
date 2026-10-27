//
//  SparkleUpdateCoordinatorTests.swift
//  StatsLiteTests
//
//  Sparkle coordinator seam (plan 2026-10-27 sparkle-updater, T3a)
//  plus the T3b UI-facing contract: install handoff in-flight state,
//  popover-close/activate ordering, the interactive-check state
//  machine, and start() as the fixture seed path that replaces the
//  retired GitHub poller. ISC-3: a scheduled discovery publishes
//  availableUpdate and a scheduled show is refused outside immediate
//  focus, so no window steals focus. ISC-5: the launch policy maps
//  `--open-popover` without the fixture key to startingUpdater
//  false. Every test runs without network: coordinator methods take
//  a recording fake through SparkleUpdaterControlling, and the
//  delegate translation is exercised through internal plain-value
//  methods (no SUAppcastItem construction, no Sparkle import).
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

    /// Seam callback so a test can log the handoff order.
    var onCheckForUpdates: (() -> Void)?

    /// Coordinator state at the moment a seam call happens. A test
    /// sets this after the service exists.
    var stateProbe: (@MainActor () -> Bool)?

    /// isChecking observed inside checkForUpdatesInteractively().
    private(set) var stateObservedDuringInteractiveCheck: Bool?

    func checkForUpdates() {
        checkForUpdatesCount += 1
        onCheckForUpdates?()
    }

    func checkForUpdatesInteractively() {
        checkForUpdatesInteractivelyCount += 1
        stateObservedDuringInteractiveCheck = stateProbe?()
    }

    var totalCheckCount: Int {
        checkForUpdatesCount + checkForUpdatesInteractivelyCount
    }
}

@MainActor
final class SparkleUpdateCoordinatorTests: XCTestCase {

    /// UserDefaults keys this class writes through dismiss(). XCTest
    /// shares one UserDefaults store across the class, so a dismissal
    /// from one test would suppress the fixture banner of a later
    /// test. setUp and tearDown reset the keys around every test.
    private static let sharedServiceKeys = [
        "updateCheckDismissedVersion",
        "updateCheckLastCheckEpoch",
        "updateCheckCachedLatest",
    ]

    override func setUp() {
        super.setUp()
        for key in Self.sharedServiceKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in Self.sharedServiceKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    private let notesURL = URL(
        string: "https://example.com/releases/2.0.0"
    )!

    private func makeService(
        updater: (any SparkleUpdaterControlling)? = nil,
        environment: [String: String] = [:],
        activateApp: @escaping () -> Void = {},
        closePopover: @escaping () -> Void = {}
    ) -> UpdateCheckService {
        UpdateCheckService(
            environment: environment,
            updater: updater,
            activateApp: activateApp,
            closePopover: closePopover
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

    // MARK: - T3b: install handoff contract (blueprint Part 4, Flow 1)

    /// The banner CTA marks the coordinator in flight on the first
    /// click, and a second click while the handoff is in flight is
    /// refused: no second activate, no second popover close, no
    /// second Sparkle call.
    func testInstallHandoffMarksInFlightAndRefusesSecondConcurrentInstall() {
        let updater = RecordingSparkleUpdater()
        var activations = 0
        var closes = 0
        let service = makeService(
            updater: updater,
            activateApp: { activations += 1 },
            closePopover: { closes += 1 }
        )

        XCTAssertFalse(service.isHandingOff, "the banner starts armed")

        service.installUpdate()

        XCTAssertTrue(
            service.isHandingOff,
            "install handoff must mark the coordinator in flight for the disabled button"
        )
        XCTAssertEqual(activations, 1)
        XCTAssertEqual(closes, 1)
        XCTAssertEqual(updater.checkForUpdatesCount, 1)

        service.installUpdate()

        XCTAssertEqual(activations, 1, "a second concurrent install must be refused")
        XCTAssertEqual(closes, 1, "a second concurrent install must not close again")
        XCTAssertEqual(
            updater.checkForUpdatesCount,
            1,
            "a second concurrent install must not reach Sparkle again"
        )
    }

    /// Blueprint Part 4 Flow 1 order: activate the app, close the
    /// popover, then hand off to Sparkle. One path, inside
    /// installUpdate().
    func testInstallHandoffActivatesClosesPopoverThenHandsOffToSparkle() {
        let updater = RecordingSparkleUpdater()
        var events: [String] = []
        updater.onCheckForUpdates = { events.append("sparkle") }
        let service = makeService(
            updater: updater,
            activateApp: { events.append("activate") },
            closePopover: { events.append("close") }
        )

        service.installUpdate()

        XCTAssertEqual(
            events,
            ["activate", "close", "sparkle"],
            "blueprint Part 4 Flow 1: activate, close popover, then Sparkle handoff"
        )
    }

    /// Without a seam there is no Sparkle window to hand off to, so
    /// the whole handoff stays a no-op and the button stays armed.
    func testInstallHandoffIsNoOpWithoutASeam() {
        var activations = 0
        var closes = 0
        let service = makeService(
            updater: nil,
            activateApp: { activations += 1 },
            closePopover: { closes += 1 }
        )

        service.installUpdate()

        XCTAssertFalse(service.isHandingOff, "no seam, no handoff")
        XCTAssertEqual(activations, 0)
        XCTAssertEqual(closes, 0)
    }

    /// The handoff disables the button; it does not clear the
    /// banner state, so a popover reopen shows the same update with
    /// the button still disabled.
    func testInstallHandoffKeepsAvailableUpdateForReopenedPopover() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(updater: updater)
        service.publishAvailableUpdate(
            displayVersion: "2.0.0",
            releaseNotesURL: notesURL
        )

        service.installUpdate()

        XCTAssertTrue(service.isHandingOff)
        XCTAssertNotNil(
            service.availableUpdate,
            "install handoff must not clear the published banner"
        )
    }

    /// A fresh discovery re-arms the install button after an
    /// earlier handoff.
    func testPublishReArmsInstallHandoff() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(updater: updater)
        service.publishAvailableUpdate(
            displayVersion: "2.0.0",
            releaseNotesURL: notesURL
        )
        service.installUpdate()
        XCTAssertTrue(service.isHandingOff)

        service.publishAvailableUpdate(
            displayVersion: "3.0.0",
            releaseNotesURL: notesURL
        )

        XCTAssertFalse(
            service.isHandingOff,
            "a newly published update must re-arm the install button"
        )
    }

    /// Dismissing the update clears the in-flight flag with it: no
    /// banner, no disabled button left behind.
    func testDismissClearsInstallHandoff() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(updater: updater)
        service.publishAvailableUpdate(
            displayVersion: "2.0.0",
            releaseNotesURL: notesURL
        )
        service.installUpdate()
        XCTAssertTrue(service.isHandingOff)

        service.dismiss(version: "2.0.0")

        XCTAssertFalse(
            service.isHandingOff,
            "dismiss must clear the in-flight handoff with the banner"
        )
    }

    // MARK: - T3b: interactive check state (blueprint Part 4, Flow 2)

    /// Idle before the check. The seam spy observes isChecking true
    /// while the handoff is in flight (the Settings button would be
    /// disabled with the spinner up). The session-finish delegate
    /// callback returns the coordinator to the result state.
    func testInteractiveCheckTransitionsIdleCheckingAndFinishResets() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(updater: updater)
        updater.stateProbe = { service.isChecking }

        XCTAssertFalse(service.isChecking, "idle before the check")

        service.checkForUpdatesInteractively()

        XCTAssertEqual(
            updater.stateObservedDuringInteractiveCheck,
            true,
            "the seam must see isChecking true while the check is in flight"
        )
        XCTAssertTrue(
            service.isChecking,
            "the checking state persists until the update session finishes"
        )

        service.standardUserDriverWillFinishUpdateSession()

        XCTAssertFalse(
            service.isChecking,
            "the finished session returns the coordinator to the result state"
        )
        XCTAssertEqual(updater.checkForUpdatesInteractivelyCount, 1)
    }

    /// One interactive check at a time: a second call while the
    /// first is in flight is refused.
    func testInteractiveCheckRefusesConcurrentSecondCheck() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(updater: updater)

        service.checkForUpdatesInteractively()
        service.checkForUpdatesInteractively()

        XCTAssertEqual(
            updater.checkForUpdatesInteractivelyCount,
            1,
            "a concurrent second interactive check must be refused"
        )
        XCTAssertTrue(service.isChecking)
    }

    /// Without a seam no check runs, so the coordinator never enters
    /// the checking state.
    func testInteractiveCheckIsNoOpWithoutASeam() {
        let service = makeService(updater: nil)

        service.checkForUpdatesInteractively()

        XCTAssertFalse(
            service.isChecking,
            "no seam, no checking state"
        )
    }

    // MARK: - T3b: start() seeds the fixture (GitHub poller retired)

    /// start() is the launch entry the AppDelegate keeps behind the
    /// `--open-popover` skip. It seeds the fixture banner
    /// synchronously and never touches the Sparkle seam.
    func testStartSeedsFixtureWithoutTouchingUpdaterSeam() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(
            updater: updater,
            environment: ["STATSLITE_FAKE_UPDATE_VERSION": "9.9.9"]
        )

        service.start()

        XCTAssertEqual(
            service.availableUpdate?.version,
            SemanticVersion("9.9.9"),
            "start() must seed the fixture banner synchronously"
        )
        XCTAssertEqual(
            service.availableUpdate?.releasePageURL,
            URL(string: UpdateCheckLaunchPolicy.fixtureReleasePageURL)
        )
        XCTAssertEqual(
            updater.totalCheckCount,
            0,
            "start() must not touch the Sparkle seam"
        )
    }

    func testStartWithoutFixtureSeedsNothing() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(updater: updater, environment: [:])

        service.start()

        XCTAssertNil(
            service.availableUpdate,
            "no fixture key, no banner"
        )
        XCTAssertEqual(updater.totalCheckCount, 0)
    }

    func testStartTwiceKeepsOneSeededBanner() {
        let updater = RecordingSparkleUpdater()
        let service = makeService(
            updater: updater,
            environment: ["STATSLITE_FAKE_UPDATE_VERSION": "9.9.9"]
        )

        service.start()
        service.start()

        XCTAssertEqual(service.availableUpdate?.version, SemanticVersion("9.9.9"))
        XCTAssertEqual(
            updater.totalCheckCount,
            0,
            "a second start() must not reach the seam either"
        )
    }
}
