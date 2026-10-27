//
//  UpdateCheckService.swift
//  StatsLite
//
//  Background update check. One task, one clock (SystemMonitor loop
//  style, no Timer/Combine): the loop checks on launch when the last
//  check is at least 300 s old, then sleeps 24 h between checks. A
//  resolved release stamps updateCheckLastCheckEpoch, and a resolved
//  network release also lands in the updateCheckCachedLatest cache so
//  a relaunch inside the launch floor restores the banner from it. A
//  nil source result and an unparsable current version are silent
//  no-ops. A dismissed version lives in UserDefaults as a normalized
//  description.
//
//  Sparkle coordinator layer (plan 2026-10-27 sparkle-updater,
//  T3a): the service also conforms to SPUStandardUserDriverDelegate
//  and owns the SparkleUpdaterControlling seam. Gentle scheduled
//  reminders publish a banner through availableUpdate instead of a
//  focus-stealing Sparkle window. The STATSLITE_FAKE_UPDATE_VERSION
//  fixture seeds availableUpdate directly, without starting
//  Sparkle.
//

import AppKit
import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class UpdateCheckService: NSObject, SPUStandardUserDriverDelegate {

    /// UserDefaults keys owned by this service. The cached-latest key
    /// holds a two-field JSON object (tag_name, html_url) written by
    /// a successful network fetch.
    static let dismissedVersionKey = "updateCheckDismissedVersion"
    static let lastCheckEpochKey = "updateCheckLastCheckEpoch"
    static let cachedLatestKey = "updateCheckCachedLatest"

    /// Minimum age of the last check before the launch pass runs.
    /// A negative gap (clock moved back) counts as stale.
    static let launchCheckMinGap: TimeInterval = 300

    /// Seconds between checks after the launch pass.
    static let checkInterval: TimeInterval = 24 * 60 * 60

    /// Newest prompted release, or nil when nothing prompts. A failed
    /// check leaves the value untouched.
    private(set) var availableUpdate: ReleaseInfo?

    /// Sparkle seam. The AppDelegate injects the production adapter;
    /// tests inject a recording fake. Nil (the default for existing
    /// tests) makes every coordinator action a no-op.
    var updater: (any SparkleUpdaterControlling)?

    private let source: any UpdateReleaseSource
    private let bundle: Bundle
    private let environment: [String: String]
    private let activateApp: () -> Void
    private var checkTask: Task<Void, Never>?

    init(
        source: any UpdateReleaseSource = GitHubReleaseSource(),
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        updater: (any SparkleUpdaterControlling)? = nil,
        activateApp: @escaping () -> Void = {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    ) {
        self.source = source
        self.bundle = bundle
        self.environment = environment
        self.updater = updater
        self.activateApp = activateApp
        super.init()
    }

    // MARK: - Coordinator API (T3b UI call sites)

    /// Brings the app forward and hands off to Sparkle's update
    /// flow. The banner CTA calls this; the popover close at the
    /// call site is T3b.
    func installUpdate() {
        activateApp()
        updater?.checkForUpdates()
    }

    /// Hands off to Sparkle's user-initiated check. Dismissal does
    /// not suppress it: an explicit user check always reaches
    /// Sparkle.
    func checkForUpdatesInteractively() {
        updater?.checkForUpdatesInteractively()
    }

    /// Seeds availableUpdate from STATSLITE_FAKE_UPDATE_VERSION
    /// without starting Sparkle or touching the network. A dismissed
    /// fixture version stays unpublished. Capture scripts call this
    /// through the AppDelegate at launch.
    func seedFixtureAvailableUpdateIfNeeded() {
        guard let fixture = UpdateCheckLaunchPolicy.fixtureRelease(
            environment: environment
        ) else { return }
        guard !isDismissed(version: fixture.version.description) else {
            return
        }
        availableUpdate = fixture
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

    /// Publishes a banner from a discovered update. A malformed
    /// display version or a missing release notes URL is a silent
    /// no-op, and a dismissed version stays unpublished.
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
    }

    /// Starts the check loop once. A second call while the loop runs
    /// is a no-op.
    func start() {
        guard checkTask == nil else { return }
        checkTask = Task {
            let clock = ContinuousClock()
            let lastCheck = UserDefaults.standard.double(
                forKey: Self.lastCheckEpochKey
            )
            let gap = Date().timeIntervalSince1970 - lastCheck
            // The fixture env key bypasses the launch floor so capture
            // scripts get a prompt on every relaunch.
            let fixtureOverride = UpdateCheckLaunchPolicy.fixtureRelease(
                environment: self.environment
            ) != nil
            if gap >= Self.launchCheckMinGap || gap < 0 || fixtureOverride {
                await self.performCheck()
            } else {
                // Inside the launch floor: no network, but a relaunch
                // must still restore the banner from the cached
                // release. A missing or corrupt cache is a no-op.
                self.restoreAvailableUpdateFromCache()
            }
            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: .seconds(Self.checkInterval))
                } catch {
                    // Cancellation interrupts the sleep and ends the loop.
                    return
                }
                await self.performCheck()
            }
        }
    }

    /// True when the user dismissed this version. The stored value and
    /// the argument are both normalized (one leading "v" stripped).
    func isDismissed(version: String) -> Bool {
        guard let stored = UserDefaults.standard.string(
            forKey: Self.dismissedVersionKey
        ) else { return false }
        return UpdateCheckPolicy.normalizeDismissed(stored)
            == UpdateCheckPolicy.normalizeDismissed(version)
    }

    /// Stores the dismissed version and clears any prompted update.
    func dismiss(version: String) {
        UserDefaults.standard.set(
            UpdateCheckPolicy.normalizeDismissed(version),
            forKey: Self.dismissedVersionKey
        )
        availableUpdate = nil
    }

    /// One check: resolve the current version, take the fixture
    /// release when the env key is set (no network), else ask the
    /// source, then stamp the epoch, cache a network release, and
    /// apply the policy. An unparsable current version and a nil
    /// source result are silent and leave the stored epoch alone.
    private func performCheck() async {
        guard let current = Self.currentVersion(bundle: bundle) else { return }
        let latest: ReleaseInfo
        let fromNetwork: Bool
        if let fixture = UpdateCheckLaunchPolicy.fixtureRelease(
            environment: environment
        ) {
            latest = fixture
            fromNetwork = false
        } else if let fetched = await source.latestRelease() {
            latest = fetched
            fromNetwork = true
        } else {
            // No release resolved: leave the epoch untouched so the
            // next launch can retry instead of waiting out the floor.
            return
        }
        // The epoch stamps only after the release resolves, so a
        // failed launch check does not block the retry.
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: Self.lastCheckEpochKey
        )
        // The cache holds only network releases: a fixture launch
        // must not pollute the restore path of a later real launch.
        if fromNetwork {
            Self.storeCachedLatest(latest)
        }
        let dismissed = UserDefaults.standard.string(
            forKey: Self.dismissedVersionKey
        )
        switch UpdateCheckPolicy.promptState(
            latest: latest,
            current: current,
            dismissedVersion: dismissed
        ) {
        case .none:
            availableUpdate = nil
        case .prompt(let release):
            availableUpdate = release
        }
    }

    /// Restores availableUpdate from the cached release on the
    /// launch skip path, mirroring the performCheck() policy: set on
    /// .prompt, clear on .none, silent when the cache or the current
    /// version does not parse.
    private func restoreAvailableUpdateFromCache() {
        guard let current = Self.currentVersion(bundle: bundle),
              let latest = Self.cachedLatestRelease()
        else { return }
        let dismissed = UserDefaults.standard.string(
            forKey: Self.dismissedVersionKey
        )
        switch UpdateCheckPolicy.promptState(
            latest: latest,
            current: current,
            dismissedVersion: dismissed
        ) {
        case .none:
            availableUpdate = nil
        case .prompt(let release):
            availableUpdate = release
        }
    }

    /// Writes a resolved network release as a two-field JSON payload
    /// under the cached-latest key.
    private static func storeCachedLatest(_ release: ReleaseInfo) {
        struct Payload: Codable {
            let tag_name: String
            let html_url: String
        }
        let payload = Payload(
            tag_name: release.version.description,
            html_url: release.releasePageURL.absoluteString
        )
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: cachedLatestKey)
        }
    }

    /// Cached release from the two-field JSON payload, or nil when
    /// the key is missing, the JSON is malformed, or a field fails
    /// to parse (cache miss, silent).
    private static func cachedLatestRelease() -> ReleaseInfo? {
        struct Payload: Decodable {
            let tag_name: String
            let html_url: String
        }
        guard let data = UserDefaults.standard.data(forKey: cachedLatestKey),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let version = SemanticVersion(payload.tag_name),
              let url = URL(string: payload.html_url)
        else { return nil }
        return ReleaseInfo(version: version, releasePageURL: url)
    }

    /// Installed version from the bundle display version.
    private static func currentVersion(bundle: Bundle) -> SemanticVersion? {
        guard let raw = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String else { return nil }
        return SemanticVersion(raw)
    }
}
