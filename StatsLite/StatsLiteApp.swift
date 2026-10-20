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
        startUpdateCheckIfNeeded()
        startMeasurementHookIfNeeded()
    }

    // update check: skipped under `--open-popover` so the measurement
    // harness never triggers a network check.
    private func startUpdateCheckIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard !arguments.contains("--open-popover") else { return }
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
}
