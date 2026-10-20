//
//  UpdateCheckService.swift
//  StatsLite
//
//  Background update check. One task, one clock (SystemMonitor loop
//  style, no Timer/Combine): the loop checks on launch when the last
//  check is at least 300 s old, then sleeps 6 h between checks. Every
//  attempt stamps updateCheckLastCheckEpoch. A nil source result and
//  an unparsable current version are silent no-ops. A dismissed
//  version lives in UserDefaults as a normalized description.
//

import Foundation
import Observation

@MainActor
@Observable
final class UpdateCheckService {

    /// UserDefaults keys owned by this service.
    static let dismissedVersionKey = "updateCheckDismissedVersion"
    static let lastCheckEpochKey = "updateCheckLastCheckEpoch"

    /// Minimum age of the last check before the launch pass runs.
    /// A negative gap (clock moved back) counts as stale.
    static let launchCheckMinGap: TimeInterval = 300

    /// Seconds between checks after the launch pass.
    static let checkInterval: TimeInterval = 6 * 60 * 60

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
            if gap >= Self.launchCheckMinGap || gap < 0 {
                await self.performCheck()
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

    /// One check: stamp the epoch, resolve the current version, take
    /// the fixture release when the env key is set (no network), else
    /// ask the source, then apply the policy. An unparsable current
    /// version and a nil source result are silent.
    private func performCheck() async {
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: Self.lastCheckEpochKey
        )
        guard let current = Self.currentVersion(bundle: bundle) else { return }
        let latest: ReleaseInfo
        if let fixture = UpdateCheckLaunchPolicy.fixtureRelease(
            environment: environment
        ) {
            latest = fixture
        } else if let fetched = await source.latestRelease() {
            latest = fetched
        } else {
            return
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

    /// Installed version from the bundle display version.
    private static func currentVersion(bundle: Bundle) -> SemanticVersion? {
        guard let raw = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String else { return nil }
        return SemanticVersion(raw)
    }
}
