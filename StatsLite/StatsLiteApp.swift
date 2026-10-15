//
//  StatsLiteApp.swift
//  StatsLite
//
//  Menu bar agent entry point. One MenuBarExtra (.window style) bound
//  to the monitor and the preferences store. LSUIElement in Info.plist
//  keeps the app out of the Dock. Escape and outside clicks close the
//  popover natively.
//

import SwiftUI

@main
struct StatsLiteApp: App {
    @State private var monitor = SystemMonitor()
    @State private var preferences = PreferencesStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverContentView(monitor: monitor, preferences: preferences)
        } label: {
            MenuBarItemView(monitor: monitor, preferences: preferences)
        }
        .menuBarExtraStyle(.window)
    }
}
