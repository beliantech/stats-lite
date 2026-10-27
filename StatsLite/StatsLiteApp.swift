//
//  StatsLiteApp.swift
//  StatsLite
//
//  Menu bar agent entry point. MenuBarExtra is gone: it flattens its
//  label into NSStatusBarButton.title and cannot render the stacked
//  block layout. AppDelegate owns the shared SystemMonitor,
//  PreferencesStore, UpdateCheckService, and the
//  StatusItemController that manages the
//  NSStatusItem and the popover. LSUIElement in Info.plist keeps the
//  app out of the Dock. The Settings scene is unchanged.
//

import SwiftUI

@main
struct StatsLiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                preferences: appDelegate.preferences,
                monitor: appDelegate.monitor,
                launchAtLogin: appDelegate.launchAtLogin
            )
        }
    }
}

/// Owns the app-lifetime singletons and the menu bar status item.
/// Sampling starts at launch so the first snapshot does not wait for
/// a popover open.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let monitor = SystemMonitor()
    let preferences = PreferencesStore()
    let launchAtLogin = LaunchAtLoginService()
    let updateChecker = UpdateCheckService()

    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.apply(preferences)
        statusItemController = StatusItemController(
            monitor: monitor,
            preferences: preferences,
            updateChecker: updateChecker
        )
        configureSparkleUpdater()
        startUpdateCheckIfNeeded()
        applyCaptureAppearanceIfNeeded()
        startMeasurementHookIfNeeded()
    }

    // Sparkle wiring (plan 2026-10-27 sparkle-updater, T3a): the
    // launch policy decides whether the updater starts at all.
    // `--open-popover` without the fixture key keeps Sparkle inert,
    // so the measurement harness sees zero Sparkle network and XPC
    // traffic. The fixture key seeds the banner without any Sparkle
    // check.
    private func configureSparkleUpdater() {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        updateChecker.updater = StandardSparkleUpdater(
            startingUpdater: UpdateCheckLaunchPolicy.startingUpdater(
                arguments: arguments,
                environment: environment
            ),
            userDriverDelegate: updateChecker
        )
        updateChecker.seedFixtureAvailableUpdateIfNeeded()
    }

    // update check: skipped under `--open-popover` so the measurement
    // harness never triggers a network check. The
    // STATSLITE_FAKE_UPDATE_VERSION fixture key overrides the skip so
    // banner captures can run under the harness.
    private func startUpdateCheckIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        guard !UpdateCheckLaunchPolicy.skipCheck(
            arguments: arguments,
            environment: environment
        ) else { return }
        updateChecker.start()
    }

    // measurement support: `--open-popover` drives the automated
    // popover cycle for scripts/measure_popover_footprint.sh. Inert
    // without the flag. `--popover-cycles N` overrides the default 3
    // cycles; `--popover-hold N` overrides the default 5 s hold.
    private func startMeasurementHookIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--open-popover") else { return }
        let cycles = intValue("--popover-cycles", in: arguments) ?? 3
        let hold = intValue("--popover-hold", in: arguments) ?? 5
        statusItemController?.startMeasurementCycle(
            cycles: cycles,
            holdSeconds: Double(hold)
        )
    }

    private func intValue(_ flag: String, in arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: flag),
              index + 1 < arguments.count else { return nil }
        return Int(arguments[index + 1])
    }

    // Verification hook (T-E, plan 2026-10-23 screenshot evidence):
    // `--capture-appearance <dark|light>` forces this app's windows
    // into one appearance. The screenshot harness needs both
    // appearances, and scripts/capture_baseline.sh switches the
    // SYSTEM appearance through System Events, which fails with
    // -1743 under hosts that hold no Automation permission. This
    // hook keeps the capture per-app and needs no TCC grant. Inert
    // without the flag. Test hook, not a product feature.
    private func applyCaptureAppearanceIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--capture-appearance"),
              index + 1 < arguments.count else { return }
        switch arguments[index + 1] {
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        default: break
        }
        // NSApp.appearance does not reach NSPopover windows (they
        // attach to the system status-bar window), so the popover
        // gets the forced appearance directly.
        let forced: NSAppearance?
        switch arguments[index + 1] {
        case "dark": forced = NSAppearance(named: .darkAqua)
        case "light": forced = NSAppearance(named: .aqua)
        default: forced = nil
        }
        statusItemController?.applyCaptureAppearance(forced)
        // [capture-appearance] diagnostic line for the harness, same
        // pattern as the [measurement] hook lines.
        let effective = NSApp.effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua])?.rawValue ?? "nil"
        FileHandle.standardError.write(Data(
            "[capture-appearance] requested \(arguments[index + 1]) effective \(effective)\n".utf8
        ))
    }
}
