//
//  SettingsView.swift
//  StatsLite
//
//  Settings scene content: a grouped 380x340 form with General
//  and Visible Metrics sections plus the version footer.
//  Controls write to PreferencesStore; onChange calls
//  SystemMonitor.apply so every change takes effect live.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore
    var monitor: SystemMonitor
    var launchAtLogin: LaunchAtLoginService
    var updateChecker: UpdateCheckService

    var body: some View {
        VStack(spacing: 0) {
            Form {
                generalSection
                visibleMetricsSection
            }
            .formStyle(.grouped)

            Text(Self.versionLabel())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
        .frame(width: 380, height: 340)
        .onAppear {
            launchAtLogin.refresh()
            monitor.apply(preferences)
        }
        .onChange(of: preferences.enabledMetrics) { monitor.apply(preferences) }
        .onChange(of: preferences.refreshInterval) { monitor.apply(preferences) }
        .onChange(of: preferences.historyDuration) { monitor.apply(preferences) }
        .onChange(of: preferences.showNetwork) { monitor.apply(preferences) }
    }

    // MARK: - General (VAC-11)

    private var generalSection: some View {
        Section("General") {
            refreshIntervalRow
            historyDurationRow
            launchAtLoginRow
            checkForUpdatesRow
        }
    }

    // MARK: - Software Update (blueprint Parts 3/4, VAC-12/13)

    /// Row 4 of General: label, spinner while the coordinator
    /// checks, and the manual-check button that disables while
    /// isChecking is true.
    private var checkForUpdatesRow: some View {
        HStack {
            Text("Software Update")
            Spacer()
            if updateChecker.isChecking {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Checking for updates")
            }
            Button("Check for Updates…") {
                updateChecker.checkForUpdatesInteractively()
            }
            .disabled(updateChecker.isChecking)
            .help("Check for new versions of Stats Lite")
            .accessibilityLabel("Check for software updates")
        }
    }

    private var historyDurationRow: some View {
        Picker("History Duration", selection: $preferences.historyDuration) {
            Text("30 s").tag(30)
            Text("1 min").tag(60)
            Text("2 min").tag(120)
            Text("3 min").tag(180)
            Text("5 min").tag(300)
        }
    }

    private var refreshIntervalRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Picker("Refresh Interval", selection: $preferences.refreshInterval) {
                Text("1 s").tag(1)
                Text("2 s").tag(2)
                Text("3 s").tag(3)
                Text("5 s").tag(5)
            }
            .accessibilityHint("Network throughput always refreshes at 1-second intervals.")

            Text("Network throughput always refreshes at 1-second intervals.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var launchAtLoginRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Toggle("Launch at Login", isOn: launchAtLoginBinding)
                .disabled(loginItemLocked)

            if let hint = loginHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Visible Metrics (VAC-23, VAC-24)

    private var visibleMetricsSection: some View {
        Section {
            Toggle("CPU Utilization", isOn: $preferences.showCPU)
                .disabled(preferences.isToggleLocked(preferences.showCPU))
            Toggle("GPU Utilization", isOn: $preferences.showGPU)
                .disabled(preferences.isToggleLocked(preferences.showGPU))
            Toggle("Memory Pressure (RAM)", isOn: $preferences.showRAM)
                .disabled(preferences.isToggleLocked(preferences.showRAM))
            // No .disabled on this row either: like network,
            // temperature stays out of isToggleLocked (F10/plan
            // Phase 3 carve-out).
            Toggle("Temperature", isOn: $preferences.showTemperature)
            // No .disabled on this row: isToggleLocked counts only
            // the three standard metrics, so the network toggle must
            // never inherit the lock (F10).
            Toggle("Network Throughput", isOn: $preferences.showNetwork)
        } header: {
            Text("Visible Metrics")
        } footer: {
            Text("At least one metric must remain enabled.")
        }
    }

    // MARK: - Launch at login

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: {
                launchAtLogin.state == .enabled
                    || launchAtLogin.state == .approvalNeeded
            },
            set: { turnOn in
                if turnOn {
                    launchAtLogin.register()
                } else {
                    launchAtLogin.unregister()
                }
            }
        )
    }

    /// True while macOS must act before the toggle can change again:
    /// approval is pending or the service is unavailable. The app
    /// never retries on its own.
    private var loginItemLocked: Bool {
        switch launchAtLogin.state {
        case .approvalNeeded, .unavailable:
            return true
        case .enabled, .disabled, .notRegistered:
            return false
        }
    }

    /// Hint under the toggle. `.requiresApproval` points at System
    /// Settings; a failed action surfaces its error message.
    private var loginHint: String? {
        switch launchAtLogin.state {
        case .approvalNeeded:
            return "Waiting for your approval in System Settings > General > Login Items."
        case .unavailable(let message):
            return message
        case .enabled, .disabled, .notRegistered:
            return launchAtLogin.errorMessage
        }
    }

    // MARK: - Version footer

    /// Version label from the bundle display version and build number.
    static func versionLabel(bundle: Bundle = .main) -> String {
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Stats Lite v\(version) (Build \(build))"
    }
}
