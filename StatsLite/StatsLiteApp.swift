//
//  StatsLiteApp.swift
//  StatsLite
//
//  Menu bar agent entry point. One MenuBarExtra (.window style) bound
//  to the monitor and the preferences store, plus the Settings scene.
//  LSUIElement in Info.plist
//  keeps the app out of the Dock. Escape and outside clicks close the
//  popover natively.
//

import SwiftUI

@main
struct StatsLiteApp: App {
    @State private var monitor = SystemMonitor()
    @State private var preferences = PreferencesStore()
    @State private var launchAtLogin = LaunchAtLoginService()

    /// MenuBarExtra extracts the label text into the status button
    /// title and can skip label onAppear. Start the sampling loop at
    /// launch so the first snapshot does not wait for the popover.
    init() {
        let monitor = SystemMonitor()
        let preferences = PreferencesStore()
        _monitor = State(initialValue: monitor)
        _preferences = State(initialValue: preferences)
        _launchAtLogin = State(initialValue: LaunchAtLoginService())
        monitor.apply(preferences)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(monitor: monitor, preferences: preferences)
        } label: {
            MenuBarStackedItemView(monitor: monitor, preferences: preferences)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                preferences: preferences,
                monitor: monitor,
                launchAtLogin: launchAtLogin
            )
        }
    }
}
