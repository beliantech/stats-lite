//
//  StatsLiteApp.swift
//  StatsLite
//
//  Menu bar agent entry point. MenuBarExtra is gone: it flattens its
//  label into NSStatusBarButton.title and cannot render the stacked
//  block layout. AppDelegate owns the shared SystemMonitor,
//  PreferencesStore, and the StatusItemController that manages the
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

    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.apply(preferences)
        statusItemController = StatusItemController(
            monitor: monitor,
            preferences: preferences
        )
    }
}
