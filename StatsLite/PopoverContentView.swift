//
//  PopoverContentView.swift
//  StatsLite
//
//  Popover panel: fixed 280 pt width, .regularMaterial background,
//  header with Settings and Quit, cards for enabled metrics only,
//  footer. The window sizes to its content via fixedSize; height is
//  never clamped, so the GPU card and the footer stay visible. 200 ms
//  ease-in-out transitions on metric and core-toggle changes.
//

import AppKit
import SwiftUI

struct PopoverContentView: View {
    let monitor: SystemMonitor
    let preferences: PreferencesStore

    @Environment(\.openSettings) private var openSettings
    @State private var coresExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .padding(.horizontal, 10)
                .padding(.top, 5)

            VStack(spacing: 6) {
                if preferences.showCPU {
                    CPUCardView(
                        monitor: monitor,
                        preferences: preferences,
                        coresExpanded: $coresExpanded
                    )
                    .transition(.opacity)
                }
                if preferences.showRAM {
                    MemoryPressureCardView(monitor: monitor)
                        .transition(.opacity)
                }
                if preferences.showGPU {
                    GPUCardView(monitor: monitor)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 5)
            .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 10)

            footer
        }
        .frame(width: 280)
        .fixedSize(horizontal: true, vertical: true)
        .background(.regularMaterial)
        .animation(.easeInOut(duration: 0.2), value: preferences.activeMetricCount)
        .animation(.easeInOut(duration: 0.2), value: coresExpanded)
        .onAppear { monitor.apply(preferences) }
    }

    // MARK: - Header (28 pt, gear and quit 24x24 targets)

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.needle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)
            Text("StatsLite")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Quit StatsLite")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: - Footer (22 pt)

    private var footer: some View {
        HStack {
            Text("Updated every \(preferences.refreshInterval)s")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
            Text("macOS Native")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .padding(.bottom, 8)
    }
}
