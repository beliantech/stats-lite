//
//  StatsLiteApp.swift
//  StatsLite
//
//  Menu bar agent entry point. The shell shows one menu bar slot and an
//  empty window. Real content arrives in later tasks.
//

import SwiftUI

@main
struct StatsLiteApp: App {
    var body: some Scene {
        MenuBarExtra {
            Text("Stats Lite")
        } label: {
            Text("Stats Lite")
        }
        .menuBarExtraStyle(.window)
    }
}
