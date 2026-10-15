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

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(monitor: monitor, preferences: preferences)
        } label: {
            MenuBarItemView(monitor: monitor, preferences: preferences)
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
