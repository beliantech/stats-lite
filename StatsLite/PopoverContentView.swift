//
//  PopoverContentView.swift
//  StatsLite
//
//  Popover panel: fixed 280 pt width, .regularMaterial background,
//  header with Settings and Quit, cards for enabled metrics only,
//  footer. The window sizes to its content via fixedSize; height is
//  never clamped, so the GPU card and the footer stay visible. 200 ms
//  ease-in-out transitions on metric and Top Processes changes.
//

import AppKit
import SwiftUI

struct PopoverContentView: View {
    let monitor: SystemMonitor
    let preferences: PreferencesStore
    var updateChecker: UpdateCheckService? = nil

    @Environment(\.openSettings) private var openSettings
    @State private var expandedProcessCategory: ProcessCategory? =
        Self.captureExpandedCategory()

    // MARK: - Capture verification hook (T-E, plan 2026-10-23)

    /// Verification hook for the T-E screenshot harness: the launch
    /// argument `--expand-processes <cpu|memory>` seeds the
    /// initial disclosure state so the harness can capture the
    /// expanded Top Processes lists (VAC-3…9, VAC-13 evidence).
    /// Inert in normal runs — production launches never pass the
    /// flag. This is a test hook, not a product feature; do not
    /// wire UI to it.
    static func captureExpandedCategory(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> ProcessCategory? {
        guard let index = arguments.firstIndex(of: "--expand-processes"),
              index + 1 < arguments.count else { return nil }
        switch arguments[index + 1] {
        case "cpu": return ProcessCategory.cpu
        case "memory": return ProcessCategory.memory
        default: return nil
        }
    }

    // MARK: - Accordion rule (R4, FT-1)

    /// Pure toggle rule for the shared accordion state (R4): tapping a
    /// card's disclosure expands that card and collapses any other
    /// open list in the same step; retapping the open card collapses
    /// to nil, which drives `stopProcessSampling()` (R3).
    static func toggledProcessCategory(
        _ current: ProcessCategory?,
        to category: ProcessCategory
    ) -> ProcessCategory? {
        current == category ? nil : category
    }

    /// Wiring seam for the disclosure action (FT-1 carry-over): the
    /// cards tap this with the popover's shared binding, so a tap on
    /// card B stores B and collapses card A in the same step.
    static func toggleProcessCategory(
        _ binding: Binding<ProcessCategory?>,
        to category: ProcessCategory
    ) {
        binding.wrappedValue = toggledProcessCategory(
            binding.wrappedValue,
            to: category
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .padding(.horizontal, 10)
                .padding(.top, 5)

            VStack(spacing: 6) {
                if let updateChecker,
                   let update = updateChecker.availableUpdate,
                   !updateChecker.isDismissed(version: update.version.description) {
                    UpdateBannerCardView(
                        updateVersion: "v\(update.version.description)",
                        releaseURL: update.releasePageURL,
                        onDismiss: {
                            updateChecker.dismiss(version: update.version.description)
                        }
                    )
                    .transition(.opacity)
                }
                if preferences.showCPU {
                    CPUCardView(
                        monitor: monitor,
                        expandedProcessCategory: $expandedProcessCategory
                    )
                    .transition(.opacity)
                }
                if preferences.showRAM {
                    MemoryPressureCardView(
                        monitor: monitor,
                        expandedProcessCategory: $expandedProcessCategory
                    )
                    .transition(.opacity)
                }
                if preferences.showGPU {
                    GPUCardView(
                        monitor: monitor
                    )
                    .transition(.opacity)
                }
                if preferences.showNetwork {
                    NetworkCardView(monitor: monitor)
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
        .animation(.easeInOut(duration: 0.2), value: preferences.showNetwork)
        .animation(.easeInOut(duration: 0.2), value: expandedProcessCategory)
        .onAppear {
            monitor.apply(preferences)
            // Capture hook: a seeded category starts its sampler
            // here because onChange never fires for the initial
            // @State value. Normal runs seed nil, so this branch
            // never runs outside the harness.
            if let seededCategory = expandedProcessCategory {
                monitor.startProcessSampling(category: seededCategory)
            }
        }
        // T5: teardown stops the lazy process sampler when the
        // popover content goes away.
        .onDisappear { monitor.stopProcessSampling() }
        // R3/T8: the disclosure drives the lazy sampler. Expanding
        // starts the category's loop; collapsing to nil stops it.
        // Popover only — the status item never runs this animation.
        .onChange(of: expandedProcessCategory) { _, category in
            if let category {
                monitor.startProcessSampling(category: category)
            } else {
                monitor.stopProcessSampling()
            }
        }
    }

    // MARK: - Header (28 pt, Storage, Activity Monitor, gear, and quit 24x24 targets)

    private var header: some View {
        HStack(spacing: 8) {
            Text("Stats Lite")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                openStorageSettings()
            } label: {
                Image(systemName: "internaldrive")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Self.storageButtonLabel)
            .accessibilityLabel(Self.storageButtonLabel)

            Button {
                openActivityMonitor()
            } label: {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Self.activityMonitorButtonLabel)
            .accessibilityLabel(Self.activityMonitorButtonLabel)

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
            .help("Quit Stats Lite")
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    // MARK: - Activity Monitor seams

    /// Bundle identifier for macOS Activity Monitor (VAC-11 launch path).
    static let activityMonitorBundleIdentifier = "com.apple.ActivityMonitor"

    /// Fallback app bundle path when the bundle identifier does not resolve.
    static let activityMonitorFallbackPath =
        "/System/Applications/Utilities/Activity Monitor.app"

    /// Tooltip and VoiceOver label for the header shortcut button (VAC-8/VAC-9).
    static let activityMonitorButtonLabel = "Open Activity Monitor"

    // MARK: - Storage seams

    /// URL string for the macOS System Settings Storage pane.
    static let storageSettingsURLString =
        "x-apple.systempreferences:com.apple.settings.Storage"

    /// Bundle identifier for macOS System Settings.
    static let systemSettingsBundleIdentifier = "com.apple.systempreferences"

    /// Fallback app bundle path when URL scheme handling fails.
    static let systemSettingsFallbackPath =
        "/System/Applications/System Settings.app"

    /// Tooltip and VoiceOver label for the Storage shortcut button.
    static let storageButtonLabel = "Open Storage Settings"

    // MARK: - Actions

    /// Opens macOS Activity Monitor via bundle identifier or fallback app bundle path.
    private func openActivityMonitor() {
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Self.activityMonitorBundleIdentifier
        ) {
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            NSWorkspace.shared.open(
                URL(fileURLWithPath: Self.activityMonitorFallbackPath)
            )
        }
    }

    /// Opens the macOS System Settings Storage pane. Falls back to launching
    /// System Settings by bundle identifier (or its path) when the URL has no
    /// handler: `NSWorkspace.shared.open` returns false in that case.
    private func openStorageSettings() {
        if let url = URL(string: Self.storageSettingsURLString),
           NSWorkspace.shared.open(url) {
            return
        }
        let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Self.systemSettingsBundleIdentifier
        ) ?? URL(fileURLWithPath: Self.systemSettingsFallbackPath)
        NSWorkspace.shared.openApplication(
            at: appURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    // MARK: - Footer (22 pt)

    private var footer: some View {
        HStack {
            Text("Updated every \(preferences.refreshInterval)s")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Spacer()
            Text(Self.versionLabel())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .accessibilityLabel(Self.versionAccessibilityLabel())
        }
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .padding(.bottom, 8)
    }

    // MARK: - Version helpers

    /// Pure formatting helper for display version and build number.
    static func versionLabel(version: String, build: String) -> String {
        "v\(version) (\(build))"
    }

    /// Version label from the bundle display version and build number.
    static func versionLabel(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return versionLabel(version: version, build: build)
    }

    /// Pure formatting helper for accessibility label.
    static func versionAccessibilityLabel(version: String, build: String) -> String {
        "Version \(version), build \(build)"
    }

    /// Accessibility description for assistive technology.
    static func versionAccessibilityLabel(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return versionAccessibilityLabel(version: version, build: build)
    }
}
