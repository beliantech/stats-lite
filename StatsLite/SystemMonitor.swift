//
//  SystemMonitor.swift
//  StatsLite
//
//  Main-actor UI state for the sampling loop. One task, one clock:
//  `restartSampling()` cancels the running task and starts a new one
//  that samples on tick zero, then sleeps at the configured interval.
//  Call it after every toggle or interval change. No Combine, no
//  AsyncStream, no second timer.
//

import Foundation
import Observation

@MainActor
@Observable
final class SystemMonitor {

    /// Result of the latest sampling pass. A member outside
    /// `enabledMetrics` is nil in this snapshot.
    private(set) var latestSnapshot: SystemSnapshot?

    /// Toggle set for the next pass. Set it, then call
    /// `restartSampling()`.
    var enabledMetrics: EnabledMetrics = .all

    /// Seconds between passes. Set it, then call `restartSampling()`.
    var refreshInterval: TimeInterval = 2.0

    /// Seconds of sparkline history kept per metric. Set it, then call
    /// `restartSampling()`.
    var historyDuration: TimeInterval = 60.0

    /// Effective sparkline sample count in steady state: the history
    /// window divided by the refresh interval, with a floor of 2.
    /// Mirrors the preference access in `recordHistory` below.
    var sparklineCapacity: Int {
        Swift.max(Int(historyDuration) / Swift.max(Int(refreshInterval), 1), 2)
    }

    /// Sparkline data, oldest first, one point per sampling pass.
    /// Buffers stay capped by `HistoryBuffer`.
    private(set) var cpuHistory = HistoryBuffer()
    private(set) var memoryPressureHistory = HistoryBuffer()
    private(set) var gpuHistory = HistoryBuffer()

    private let sampler: MetricSamplerActor
    private var samplingTask: Task<Void, Never>?

    /// True while the sampling loop runs.
    var isSampling: Bool { samplingTask != nil }

    init(provider: any SystemMetricsProvider = LiveSystemMetricsProvider()) {
        self.sampler = MetricSamplerActor(provider: provider)
    }

    /// Copies the toggle set, interval, and history window from the
    /// preferences store. Restarts the loop when a value changed or no
    /// loop runs. Safe to call on every appear and settings change.
    func apply(_ preferences: PreferencesStore) {
        let newEnabled = preferences.enabledMetrics
        let newInterval = TimeInterval(preferences.refreshInterval)
        let newHistory = TimeInterval(preferences.historyDuration)
        let changed =
            newEnabled != enabledMetrics
            || newInterval != refreshInterval
            || newHistory != historyDuration

        enabledMetrics = newEnabled
        refreshInterval = newInterval
        historyDuration = newHistory

        if changed || !isSampling {
            restartSampling()
        }
    }

    /// Cancels the current loop and starts a new one. The new loop
    /// samples immediately (tick zero), then sleeps `refreshInterval`
    /// seconds per pass with a 150 ms tolerance. An empty enabled set
    /// starts no loop, per `MonitorGuard`.
    func restartSampling() {
        samplingTask?.cancel()

        guard MonitorGuard.allowsSampling(enabledMetrics) else {
            samplingTask = nil
            return
        }

        samplingTask = Task {
            let clock = ContinuousClock()
            while !Task.isCancelled {
                let snapshot = await self.sampler.collectSnapshot(
                    enabled: self.enabledMetrics
                )
                guard !Task.isCancelled else { return }
                self.latestSnapshot = snapshot
                self.recordHistory(snapshot)

                do {
                    try await clock.sleep(
                        for: .seconds(self.refreshInterval),
                        tolerance: .milliseconds(150)
                    )
                } catch {
                    // Cancellation interrupts the sleep and ends the loop.
                    return
                }
            }
        }
    }

    /// Cancels the loop. The last snapshot stays available for the UI.
    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }

    /// Appends one point per enabled metric. The age window and the
    /// count cap come from `historyDuration` and `HistoryBuffer`.
    private func recordHistory(_ snapshot: SystemSnapshot) {
        let age = Swift.max(historyDuration, 1)
        let capacity = Swift.max(Int(historyDuration) * 2, 16)

        if let cpu = snapshot.cpu {
            cpuHistory.append(
                cpu.totalUsage,
                at: snapshot.timestamp,
                maxAge: age,
                capacity: capacity
            )
        }
        if let pressure = snapshot.memoryPressure {
            memoryPressureHistory.append(
                pressure.pressurePercentage,
                at: snapshot.timestamp,
                maxAge: age,
                capacity: capacity
            )
        }
        if let gpu = snapshot.gpu {
            gpuHistory.append(
                gpu.deviceUtilization,
                at: snapshot.timestamp,
                maxAge: age,
                capacity: capacity
            )
        }
    }
}
