//
//  SystemMonitorNetworkTests.swift
//  StatsLiteTests
//
//  Loop-lifecycle tests for the 1 s network sampling loop. A
//  network-only preference flip must start or stop only the network
//  task and must never restart the standard sampling loop (FM11).
//  Ten rapid flips must leave exactly one network loop running
//  (FM7). Turning the network off must clear the published rate and
//  the sampler delta base, so a re-enable anchors from scratch (F6).
//

import XCTest
@testable import StatsLite

@MainActor
final class SystemMonitorNetworkTests: XCTestCase {

    // MARK: - Helpers

    /// Polls `condition` every 20 ms until it holds or `timeout`
    /// passes. Returns whether the condition held.
    @discardableResult
    private func waitUntil(
        timeout: TimeInterval = 3,
        _ condition: () -> Bool
    ) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    /// Monitor, fake provider, and preferences wired together. The
    /// refresh interval sits at 5 s so a restarted standard loop
    /// would take an immediate tick-zero read that the untouched
    /// loop does not take inside the short assertion windows below.
    private func makeMonitor() -> (SystemMonitor, FakeSystemMetricsProvider, PreferencesStore) {
        let provider = FakeSystemMetricsProvider(
            cpuTicks: CPUTicks(perCore: [
                CoreTickSample(user: 100, system: 50, idle: 1000, nice: 0),
            ]),
            networkBytes: NetworkBytes(bytesIn: 1_000_000, bytesOut: 1_000_000)
        )
        let monitor = SystemMonitor(provider: provider)
        let preferences = PreferencesStore()
        preferences.refreshInterval = 5
        return (monitor, provider, preferences)
    }

    // MARK: - FM11: a network-only flip keeps the standard loop

    func testNetworkOnlyFlipDoesNotRestartStandardLoop() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        monitor.apply(preferences)
        XCTAssertTrue(monitor.isSampling)
        XCTAssertTrue(monitor.isNetworkSampling)

        let firstPass = try await waitUntil { provider.cpuSampleCount >= 1 }
        XCTAssertTrue(firstPass, "the standard loop takes its tick-zero pass")

        let generation = monitor.standardLoopGeneration
        let cpuReadsAtFlip = provider.cpuSampleCount

        // Network off: only the network task stops.
        preferences.showNetwork = false
        monitor.apply(preferences)

        XCTAssertEqual(
            monitor.standardLoopGeneration,
            generation,
            "FM11: a network-only flip must not restart the standard loop"
        )
        XCTAssertFalse(monitor.isNetworkSampling, "the network task stops on flip-off")
        XCTAssertNil(monitor.latestNetwork, "the published rate clears on flip-off")

        // A restarted loop takes an immediate tick-zero CPU read.
        // The untouched loop keeps its 5 s cadence and reads nothing
        // inside this window.
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(
            provider.cpuSampleCount,
            cpuReadsAtFlip,
            "FM11: the standard loop keeps its cadence across a network flip"
        )

        // Network on: only the network task starts again.
        preferences.showNetwork = true
        monitor.apply(preferences)

        XCTAssertEqual(
            monitor.standardLoopGeneration,
            generation,
            "FM11: re-enabling the network must not restart the standard loop"
        )
        XCTAssertTrue(monitor.isNetworkSampling, "the network task restarts on flip-on")

        // Vacuity guard: a standard property change must bump the
        // generation, so the two equalities above prove something.
        preferences.historyDuration = 120
        monitor.apply(preferences)
        XCTAssertEqual(
            monitor.standardLoopGeneration,
            generation + 1,
            "a standard property change restarts the standard loop"
        )

        monitor.stop()
    }

    // MARK: - FM7: rapid flips leave exactly one network loop

    func testTenRapidNetworkFlipsLeaveExactlyOneRunningLoop() async throws {
        let (monitor, _, preferences) = makeMonitor()
        monitor.apply(preferences)

        // Ten flips with no await between them: off, on, off, on, ...
        // ending with the network on.
        for flip in 0..<10 {
            preferences.showNetwork = !flip.isMultiple(of: 2)
            monitor.apply(preferences)
        }
        XCTAssertTrue(monitor.isNetworkSampling, "the last flip leaves the network on")

        // Every cancelled loop must exit. Exactly one survivor stays:
        // task accumulation would push the count above 1, a broken
        // stop would drain it to 0.
        let settled = try await waitUntil(timeout: 5) { monitor.activeNetworkLoopCount == 1 }
        XCTAssertTrue(settled, "FM7: exactly one network loop survives ten rapid flips")
        XCTAssertTrue(monitor.isNetworkSampling)

        monitor.stop()
        let drained = try await waitUntil(timeout: 5) { monitor.activeNetworkLoopCount == 0 }
        XCTAssertTrue(drained, "stop() drains the network loop")
    }

    // MARK: - F6: network off clears the rate and the base

    func testNetworkOffClearsLatestNetworkAndBase() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        monitor.apply(preferences)

        // Pass one anchors (nil), pass two publishes a rate.
        let published = try await waitUntil(timeout: 5) { monitor.latestNetwork != nil }
        XCTAssertTrue(published, "the second network pass publishes a rate")

        // Off: the task stops and the published rate clears at once.
        preferences.showNetwork = false
        monitor.apply(preferences)

        XCTAssertNil(monitor.latestNetwork, "F6: turning the network off clears the rate")
        XCTAssertFalse(monitor.isNetworkSampling, "F6: turning the network off stops the task")

        // Re-enable with jumped counters. A surviving base would rate
        // the off-gap on the first pass; a cleared base anchors again.
        provider.networkBytes = NetworkBytes(bytesIn: 50_000_000, bytesOut: 40_000_000)
        preferences.showNetwork = true
        monitor.apply(preferences)

        let readsAtReenable = provider.networkSampleCount
        let nextPass = try await waitUntil(timeout: 5) {
            provider.networkSampleCount > readsAtReenable
        }
        XCTAssertTrue(nextPass, "the restarted loop reads the provider again")

        // Let the publish hop land, then check the first-pass result.
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(
            monitor.latestNetwork,
            "F6: the first pass after re-enable anchors instead of rating the off-gap"
        )

        let republished = try await waitUntil(timeout: 5) { monitor.latestNetwork != nil }
        XCTAssertTrue(republished, "the second pass after re-enable publishes a fresh rate")

        monitor.stop()
    }
}
