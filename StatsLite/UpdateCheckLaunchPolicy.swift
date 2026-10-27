//
//  UpdateCheckLaunchPolicy.swift
//  StatsLite
//
//  Launch-time update check decision plus the capture fixture.
//  Foundation only, pure: no bundle, no UserDefaults, no network.
//  The fixture env key (STATSLITE_FAKE_UPDATE_VERSION) overrides the
//  `--open-popover` harness skip so banner captures can run under
//  scripts/capture_baseline.sh.
//

import Foundation

enum UpdateCheckLaunchPolicy {

    /// Environment key that injects a fake latest release.
    static let fixtureVersionKey = "STATSLITE_FAKE_UPDATE_VERSION"

    /// Release page carried by the fixture release.
    static let fixtureReleasePageURL =
        "https://github.com/beliantech/stats-lite/releases"

    /// True when the measurement harness launched the app with the
    /// exact `--open-popover` argument and no fixture key is set. The
    /// fixture key overrides the skip.
    static func skipCheck(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        guard arguments.contains("--open-popover") else { return false }
        return environment[fixtureVersionKey] == nil
    }

    /// True when the production Sparkle controller must be created
    /// with startingUpdater true. ISC-5: `--open-popover` without
    /// the fixture key maps to false, so the harness runs with zero
    /// Sparkle network and XPC traffic. FM7: an XCTest host carries
    /// `XCTestConfigurationFilePath` or `XCTestSessionIdentifier`
    /// in its environment; the live updater never starts there,
    /// because the placeholder EdDSA key raises a fatal Sparkle
    /// alert that deadlocks the test main thread.
    static func startingUpdater(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        if environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        if environment["XCTestSessionIdentifier"] != nil {
            return false
        }
        return !skipCheck(arguments: arguments, environment: environment)
    }

    /// Fixture release from the environment key. Returns nil when the
    /// key is absent or the value fails the SemanticVersion parse.
    static func fixtureRelease(
        environment: [String: String]
    ) -> ReleaseInfo? {
        guard let raw = environment[fixtureVersionKey],
              let version = SemanticVersion(raw)
        else { return nil }
        return ReleaseInfo(
            version: version,
            releasePageURL: URL(string: fixtureReleasePageURL)!
        )
    }
}
