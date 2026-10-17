//
//  SystemMonitor.swift
//  StatsLite
//
//  Main-actor UI state for the sampling loop. One task, one clock:
//  `restartSampling()` cancels the running task and starts a new one
//  that samples on tick zero, then sleeps at the configured interval.
//  A second task ticks the network every second on a fixed cadence
//  that `refreshInterval` never touches. Call `apply` after every
//  toggle or interval change. No Combine, no AsyncStream, no third
//  timer.
//

import Foundation
import Observation

@MainActor
@Observable
final class SystemMonitor {

    /// Result of the latest sampling pass. A member outside
    /// `enabledMetrics` is nil in this snapshot.
    private(set) var latestSnapshot: SystemSnapshot?

    /// Result of the latest network pass. nil while the network
    /// block is off and before the second pass of a session (F5).
    private(set) var latestNetwork: NetworkMetrics?

    /// Toggle set for the next pass. Set it, then call
    /// `restartSampling()`.
    var enabledMetrics: EnabledMetrics = .all

    /// Seconds between passes. Set it, then call `restartSampling()`.
    var refreshInterval: TimeInterval = 1.0

    /// Seconds of sparkline history kept per metric. Set it, then call
    /// `restartSampling()`.
    var historyDuration: TimeInterval = 60.0

    /// Effective sparkline sample count in steady state: the history
    /// window divided by the refresh interval, with a floor of 2.
    /// Mirrors the preference access in `recordHistory` below.
    var sparklineCapacity: Int {
        Swift.max(Int(historyDuration) / Swift.max(Int(refreshInterval), 1), 2)
    }

    /// Network sparkline sample count: the network loop ticks once
    /// per second regardless of `refreshInterval`, so the per-second
    /// density makes capacity equal the history window in seconds.
    var networkSparklineCapacity: Int {
        Swift.max(Int(historyDuration), 16)
    }

    /// Sparkline data, oldest first, one point per sampling pass.
    /// Buffers stay capped by `HistoryBuffer`.
    private(set) var cpuHistory = HistoryBuffer()
    private(set) var memoryPressureHistory = HistoryBuffer()
    private(set) var gpuHistory = HistoryBuffer()

    /// Network rate history, oldest first, one point per 1 s network
    /// tick. Trimmed per second (capacity equals the window in
    /// seconds) and cleared when the network loop stops.
    private(set) var networkUploadHistory = HistoryBuffer()
    private(set) var networkDownloadHistory = HistoryBuffer()

    private let sampler: MetricSamplerActor
    private var samplingTask: Task<Void, Never>?
    private var networkSamplingTask: Task<Void, Never>?
    private var showNetwork = false

    /// True while the sampling loop runs.
    var isSampling: Bool { samplingTask != nil }

    /// True while the 1 s network loop runs.
    var isNetworkSampling: Bool { networkSamplingTask != nil }

    /// Incremented each time `restartSampling()` starts a new
    /// standard loop. The FM11 tests assert that a network-only flip
    /// leaves this number untouched.
    private(set) var standardLoopGeneration = 0

    /// Number of network loops currently alive. The task increments
    /// it on start and decrements it on exit. The FM7 tests assert
    /// that rapid toggles settle at one, never higher.
    private(set) var activeNetworkLoopCount = 0

    init(provider: any SystemMetricsProvider = LiveSystemMetricsProvider()) {
        self.sampler = MetricSamplerActor(provider: provider)
    }

    /// Copies the toggle set, interval, history window, and network
    /// flag from the preferences store. Standard properties restart
    /// the standard loop when a value changed or no loop runs. A
    /// network-only change starts or stops only the network loop, so
    /// the standard loop and its delta bases survive (FM11). Safe to
    /// call on every appear and settings change.
    func apply(_ preferences: PreferencesStore) {
        let newEnabled = preferences.enabledMetrics
        let newInterval = TimeInterval(preferences.refreshInterval)
        let newHistory = TimeInterval(preferences.historyDuration)
        let standardChanged =
            newEnabled != enabledMetrics
            || newInterval != refreshInterval
            || newHistory != historyDuration
        let networkChanged = preferences.showNetwork != showNetwork

        enabledMetrics = newEnabled
        refreshInterval = newInterval
        historyDuration = newHistory
        showNetwork = preferences.showNetwork

        if standardChanged || !isSampling {
            restartSampling()
        }

        if networkChanged || (showNetwork && !isNetworkSampling) {
            if showNetwork {
                startNetworkSampling()
            } else {
                stopNetworkSampling()
            }
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

        standardLoopGeneration += 1
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

    /// Starts the 1 s network loop. The loop sleeps first, then
    /// samples and publishes, so the first pass only anchors and a
    /// rate appears from the second pass on (F5). The cadence is
    /// fixed on purpose: `refreshInterval` never applies here (D1).
    /// A running loop is left alone, so repeated applies never
    /// accumulate tasks (FM7).
    private func startNetworkSampling() {
        guard !isNetworkSampling else { return }

        networkSamplingTask = Task {
            self.activeNetworkLoopCount += 1
            defer { self.activeNetworkLoopCount -= 1 }

            let clock = ContinuousClock()
            while !Task.isCancelled {
                do {
                    try await clock.sleep(
                        for: .seconds(1),
                        tolerance: .milliseconds(150)
                    )
                } catch {
                    // Cancellation interrupts the sleep and ends the loop.
                    return
                }
                guard !Task.isCancelled else { return }

                let metrics = await self.sampler.sampleNetwork(enabled: true)
                // A cancel during the read must not publish into a
                // stopped state: stopNetworkSampling already cleared
                // the rate, and a late write would resurrect it.
                guard !Task.isCancelled else { return }
                self.latestNetwork = metrics

                // One point per tick, only for real rates. Nil
                // passes (first tick, rollback, timing
                // discontinuity) skip the append; no gaps, no fake
                // zeros. Trim follows the `recordHistory` pattern:
                // age window from `historyDuration`, capacity at
                // per-second density.
                if let metrics {
                    let age = Swift.max(self.historyDuration, 1)
                    let capacity = Swift.max(Int(self.historyDuration), 16)
                    let now = Date()
                    self.networkUploadHistory.append(
                        metrics.uploadBytesPerSecond,
                        at: now,
                        maxAge: age,
                        capacity: capacity
                    )
                    self.networkDownloadHistory.append(
                        metrics.downloadBytesPerSecond,
                        at: now,
                        maxAge: age,
                        capacity: capacity
                    )
                }
            }
        }
    }

    /// Cancels the network loop, drops the published rate, and
    /// clears the sampler delta base, so a later re-enable anchors
    /// from scratch and no off-gap rate spike appears (F6).
    private func stopNetworkSampling() {
        networkSamplingTask?.cancel()
        networkSamplingTask = nil
        latestNetwork = nil
        networkUploadHistory = HistoryBuffer()
        networkDownloadHistory = HistoryBuffer()
        Task { await self.sampler.clearNetworkBase() }
    }

    /// Cancels both loops. The last snapshot stays available for the
    /// UI.
    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
        networkSamplingTask?.cancel()
        networkSamplingTask = nil
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
