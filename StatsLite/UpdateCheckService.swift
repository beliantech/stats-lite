//
//  UpdateCheckService.swift
//  StatsLite
//
//  Update coordinator (plan 2026-10-27 sparkle-updater, T3a/T3b).
//  One @MainActor @Observable service owns the banner state
//  (availableUpdate), the install handoff (isHandingOff), the
//  interactive check state (isChecking), and the Sparkle seam
//  (SparkleUpdaterControlling). Gentle scheduled reminders publish
//  a banner through availableUpdate instead of a focus-stealing
//  Sparkle window. The STATSLITE_FAKE_UPDATE_VERSION fixture seeds
//  availableUpdate directly at start(), without starting Sparkle.
//
//  The GitHub poller is retired (T3b): no release source, no check
//  loop, no epoch stamp, no release cache. Sparkle owns the network
//  checks and the version comparison. A dismissed version lives in
//  UserDefaults as a normalized description.
//

import AppKit
import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class UpdateCheckService: NSObject, SPUStandardUserDriverDelegate {

    /// UserDefaults key owned by this service: the dismissed
    /// version, stored as a normalized description.
    static let dismissedVersionKey = "updateCheckDismissedVersion"

    /// Newest prompted release, or nil when nothing prompts.
    private(set) var availableUpdate: ReleaseInfo?

    /// True while an install handoff is in flight. The banner
    /// button disables on it, so a second click cannot start a
    /// second handoff. A fresh discovery or a dismiss re-arms it.
    private(set) var isHandingOff = false

    /// True while a user-initiated check runs. The Settings row
    /// shows the spinner and disables the button on it. Sparkle's
    /// session-finish callback resets it to the result state.
    private(set) var isChecking = false

    /// Sparkle seam. The AppDelegate injects the production adapter;
    /// tests inject a recording fake. Nil (the default for existing
    /// tests) makes every coordinator action a no-op.
    var updater: (any SparkleUpdaterControlling)?

    /// Closes the popover after an install handoff. The
    /// StatusItemController injects its own close, so the popover
    /// runs its normal popoverDidClose lifecycle. A no-op default
    /// keeps standalone service instances safe.
    var closePopover: () -> Void = {}

    private let environment: [String: String]
    private let activateApp: () -> Void

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        updater: (any SparkleUpdaterControlling)? = nil,
        activateApp: @escaping () -> Void = {
            NSApplication.shared.activate(ignoringOtherApps: true)
        },
        closePopover: @escaping () -> Void = {}
    ) {
        self.environment = environment
        self.updater = updater
        self.activateApp = activateApp
        self.closePopover = closePopover
        super.init()
    }

    // MARK: - Coordinator API (T3b UI call sites)

    /// Hands off to Sparkle's update flow for the banner CTA
    /// (blueprint Part 4, Flow 1): mark the handoff in flight, bring
    /// the app forward, close the popover, then call Sparkle so its
    /// window takes key focus. A second call while one is in flight
    /// is refused. Without a seam the whole handoff is a no-op.
    func installUpdate() {
        guard !isHandingOff, updater != nil else { return }
        isHandingOff = true
        activateApp()
        closePopover()
        updater?.checkForUpdates()
    }

    /// Hands off to Sparkle's user-initiated check (blueprint Part
    /// 4, Flow 2). Dismissal does not suppress it: an explicit user
    /// check always reaches Sparkle. One check at a time: a call
    /// while isChecking is true is refused. No seam: no-op, and
    /// isChecking stays false.
    func checkForUpdatesInteractively() {
        guard !isChecking, let updater else { return }
        isChecking = true
        updater.checkForUpdatesInteractively()
    }

    /// Sparkle calls this on the main thread when the update
    /// session finishes (alert dismissed, error shown, or
    /// up-to-date shown). Returns the Settings row to its result
    /// state. No Sparkle types cross the boundary, so the bridge
    /// hops through assumeIsolated.
    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated {
            isChecking = false
        }
    }

    /// Seeds availableUpdate from STATSLITE_FAKE_UPDATE_VERSION
    /// without starting Sparkle or touching the network. A dismissed
    /// fixture version stays unpublished. A seeded banner arms the
    /// install button.
    func seedFixtureAvailableUpdateIfNeeded() {
        guard let fixture = UpdateCheckLaunchPolicy.fixtureRelease(
            environment: environment
        ) else { return }
        guard !isDismissed(version: fixture.version.description) else {
            return
        }
        availableUpdate = fixture
        isHandingOff = false
    }

    /// Launch entry behind UpdateCheckLaunchPolicy.skipCheck: the
    /// harness `--open-popover` skip keeps the AppDelegate from
    /// calling this, so the harness sees no banner. With no fixture
    /// key the seed is a no-op. Synchronous, so a popover opened
    /// right after launch already sees the banner.
    func start() {
        seedFixtureAvailableUpdateIfNeeded()
    }

    // MARK: - Gentle scheduled update reminders (ISC-3)

    /// Declares gentle scheduled reminders: the delegate publishes a
    /// banner through availableUpdate instead of letting Sparkle
    /// show a focus-stealing window.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Sparkle calls this on the main thread for scheduled checks
    /// only. Immediate-focus state and dismissal are main-actor
    /// state, so the bridge hops through assumeIsolated.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        let displayVersion = update.displayVersionString
        return MainActor.assumeIsolated {
            scheduledUpdateShouldShow(
                displayVersion: displayVersion,
                immediateFocus: immediateFocus
            )
        }
    }

    /// Sparkle calls this on the main thread right before it would
    /// show an update. The publication decision is main-actor state,
    /// so the bridge hops through assumeIsolated. Only Sendable
    /// values cross the isolation boundary.
    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        let displayVersion = update.displayVersionString
        let releaseNotesURL = update.releaseNotesURL
        MainActor.assumeIsolated {
            publishAvailableUpdate(
                displayVersion: displayVersion,
                releaseNotesURL: releaseNotesURL
            )
        }
    }

    /// True when Sparkle may show a scheduled update itself. Returns
    /// false outside immediate focus so no window steals focus, and
    /// false for a dismissed version.
    func scheduledUpdateShouldShow(
        displayVersion: String,
        immediateFocus: Bool
    ) -> Bool {
        guard !isDismissed(version: displayVersion) else { return false }
        return immediateFocus
    }

    /// Publishes a banner from a discovered update and re-arms the
    /// install button. A malformed display version or a missing
    /// release notes URL is a silent no-op, and a dismissed version
    /// stays unpublished.
    func publishAvailableUpdate(
        displayVersion: String,
        releaseNotesURL: URL?
    ) {
        guard let version = SemanticVersion(displayVersion),
              let releaseNotesURL
        else { return }
        guard !isDismissed(version: version.description) else { return }
        availableUpdate = ReleaseInfo(
            version: version,
            releasePageURL: releaseNotesURL
        )
        isHandingOff = false
    }

    // MARK: - Dismissal

    /// True when the user dismissed this version. The stored value and
    /// the argument are both normalized (one leading "v" stripped).
    func isDismissed(version: String) -> Bool {
        guard let stored = UserDefaults.standard.string(
            forKey: Self.dismissedVersionKey
        ) else { return false }
        return UpdateCheckPolicy.normalizeDismissed(stored)
            == UpdateCheckPolicy.normalizeDismissed(version)
    }

    /// Stores the dismissed version, clears any prompted update, and
    /// re-arms the install button for a later discovery.
    func dismiss(version: String) {
        UserDefaults.standard.set(
            UpdateCheckPolicy.normalizeDismissed(version),
            forKey: Self.dismissedVersionKey
        )
        availableUpdate = nil
        isHandingOff = false
    }
}
