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

import Foundation
import Observation

@MainActor
@Observable
final class UpdateCheckService {

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

    private let source: any UpdateReleaseSource
    private let bundle: Bundle
    private let environment: [String: String]
    private var checkTask: Task<Void, Never>?

    init(
        source: any UpdateReleaseSource = GitHubReleaseSource(),
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.source = source
        self.bundle = bundle
        self.environment = environment
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
