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

    private let sampler: MetricSamplerActor
    private var samplingTask: Task<Void, Never>?

    init(provider: any SystemMetricsProvider = LiveSystemMetricsProvider()) {
        self.sampler = MetricSamplerActor(provider: provider)
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
}
