//
//  SparkleUpdaterControlling.swift
//  StatsLite
//
//  Coordinator seam over Sparkle (plan 2026-10-27 sparkle-updater,
//  T3a). Tests drive a recording fake through
//  SparkleUpdaterControlling and never construct Sparkle types. The
//  production adapter wraps SPUStandardUpdaterController. The launch
//  policy feeds `startingUpdater`: under `--open-popover` without
//  the fixture key the updater never starts, so the measurement
//  harness sees zero Sparkle network and XPC traffic.
//

import Foundation
import Sparkle

/// One Sparkle updater as the coordinator sees it. Both check entry
/// points map to Sparkle's user-initiated `checkForUpdates`; the
/// seam keeps the call sites (install CTA vs manual check)
/// distinguishable for tests.
@MainActor
protocol SparkleUpdaterControlling: AnyObject {

    /// True while the underlying updater can run checks.
    var isUpdaterRunning: Bool { get }

    /// Hands off to Sparkle's update flow (install path).
    func checkForUpdates()

    /// Hands off to Sparkle's update flow (manual check path).
    func checkForUpdatesInteractively()
}

/// Production adapter around SPUStandardUpdaterController. The
/// controller's delegates are weakly referenced, so the owner (the
/// AppDelegate through UpdateCheckService) must keep the user driver
/// delegate alive.
@MainActor
final class StandardSparkleUpdater: SparkleUpdaterControlling {

    private let controller: SPUStandardUpdaterController

    init(
        startingUpdater: Bool,
        userDriverDelegate: SPUStandardUserDriverDelegate?
    ) {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )
    }

    /// An unstarted updater reports false. Sparkle exposes no
    /// dedicated running flag, so canCheckForUpdates is the closest
    /// observable state.
    var isUpdaterRunning: Bool {
        controller.updater.canCheckForUpdates
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func checkForUpdatesInteractively() {
        controller.checkForUpdates(nil)
    }
}
