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
//  timer. Besides these, a lazy per-process task runs only while a
//  Top Processes disclosure is expanded (T4); it shares the sampler
//  actor and never restarts the standard loop.
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

    /// Top processes by instantaneous CPU % from the latest process
    /// scan (T3). Never on `SystemSnapshot`: the menu bar observes
    /// `latestSnapshot` and per-tick process data would churn it.
    private(set) var topCPUProcesses: [ProcessMetricItem] = []

    /// Top processes by memory footprint from the latest process scan
    /// (T3). Populates on the first scan pass (R6).
    private(set) var topMemoryProcesses: [ProcessMetricItem] = []

    /// The category whose disclosure is expanded, nil when every list
    /// is collapsed (R4 accordion state, mirror of the @State in
    /// PopoverContentView).
    private(set) var activeProcessCategory: ProcessCategory?

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
    private var processSamplingTask: Task<Void, Never>?
    private var showNetwork = false

    /// True while the sampling loop runs.
    var isSampling: Bool { samplingTask != nil }

    /// True while the 1 s network loop runs.
    var isNetworkSampling: Bool { networkSamplingTask != nil }

    /// True while the lazy per-process loop has not yet published
    /// its first CPU ranking (R3/R5 bootstrap window): set by
    /// `startProcessSampling`, cleared when the first pass carries
    /// CPU rows or when sampling stops. The disclosure renders
    /// `Sampling top processes…` only while this is true AND the
    /// active category's list is still empty — a memory expand
    /// publishes rows on tick 0 (R6) and must not be masked until
    /// +250 ms. That is the T-D view contract:
    /// `isSamplingProcesses && processes.isEmpty` for the active
    /// category (VAC-13, FT-4). Steady-state ticks after the first
    /// publish leave the flag false; loop liveness lives on
    /// `processSamplingTask` (T4).
    private(set) var isSamplingProcesses = false

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

    /// Cancels every loop: standard, network, and lazy
    /// per-process. The last snapshot stays available for the UI;
    /// process lists, the active category, and the process delta
    /// base clear with the sampler (T5).
    func stop() {
        stopProcessSampling()
        samplingTask?.cancel()
        samplingTask = nil
        networkSamplingTask?.cancel()
        networkSamplingTask = nil
    }

    // MARK: - Process sampling lifecycle (plan 2026-10-23, T4/T5)

    /// Starts the lazy per-process loop for an expanded disclosure
    /// (R3/T4). One task scans on tick zero, sleeps a single 250 ms
    /// warm-up, then follows `refreshInterval` (§3 bootstrap, R5).
    /// Memory publishes on the first scan (R6); CPU publishes from
    /// the warm-up scan on, and the first non-empty CPU ranking
    /// closes the loading window (`isSamplingProcesses`). `.gpu`
    /// expands only the unavailable container and never samples
    /// (R7): it stops the loop instead. A running loop is left
    /// alone, so an accordion category switch never restarts it,
    /// and neither start nor stop touches the standard loop (T4).
    func startProcessSampling(category: ProcessCategory) {
        activeProcessCategory = category
        guard category != .gpu else {
            // R7: no scans for GPU. Stop any running sampler so no
            // stale ranking outlives the switch; the recorded
            // category still mirrors the expanded disclosure.
            stopProcessSampling()
            activeProcessCategory = category
            return
        }
        guard processSamplingTask == nil else { return }

        // Loading-line contract for T-D: render `Sampling top
        // processes…` only while `isSamplingProcesses` is true AND the
        // active category's list is empty. Memory rows exist at tick 0
        // (R6), so the flag alone never masks them.
        isSamplingProcesses = true
        processSamplingTask = Task {
            let clock = ContinuousClock()
            var isFirstPass = true
            while !Task.isCancelled {
                let result = await self.sampler.sampleProcesses()
                // A cancel during the read must not publish into a
                // stopped state: stopProcessSampling already cleared
                // the lists, and a late write would resurrect them.
                guard !Task.isCancelled else { return }
                if let result {
                    // Memory ranks on the first scan (R6); CPU needs
                    // the warm-up scan for its delta (R5). A nil scan
                    // keeps the last lists and the base.
                    self.topMemoryProcesses = result.topMemory
                    self.topCPUProcesses = result.topCPU
                    if !result.topCPU.isEmpty {
                        self.isSamplingProcesses = false
                    }
                }
                do {
                    if isFirstPass {
                        // One 250 ms warm-up sleep after the anchoring
                        // pass, then refreshInterval cadence (§3).
                        isFirstPass = false
                        try await clock.sleep(
                            for: .milliseconds(250),
                            tolerance: .milliseconds(50)
                        )
                    } else {
                        try await clock.sleep(
                            for: .seconds(self.refreshInterval),
                            tolerance: .milliseconds(150)
                        )
                    }
                } catch {
                    // Cancellation interrupts the sleep and ends the loop.
                    return
                }
            }
        }
    }

    /// Stops the loop, closes the loading window, clears the
    /// published lists and the active category, and drops the
    /// sampler delta base, so a later expand anchors from scratch and
    /// no off-gap CPU delta appears (T5, mirrors
    /// `stopNetworkSampling`). Called on collapse-to-nil,
    /// `popoverDidClose`, and `onDisappear`.
    func stopProcessSampling() {
        processSamplingTask?.cancel()
        processSamplingTask = nil
        isSamplingProcesses = false
        activeProcessCategory = nil
        topCPUProcesses = []
        topMemoryProcesses = []
        Task { await self.sampler.clearProcessBase() }
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
