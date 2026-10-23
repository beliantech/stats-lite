//
//  SystemMonitorProcessSamplingTests.swift
//  StatsLiteTests
//
//  RED suite (plan 2026-10-23-top-processes-breakdown, T-A / G1):
//  lazy process-sampling lifecycle on SystemMonitor. start/stop exist
//  and drive the fake provider, starting must not restart the
//  standard loop (standardLoopGeneration isolation), collapse-to-nil
//  stops the sampler and clears the published lists with zero further
//  provider reads (FT-2), stop clears the delta base, and both close
//  paths (popoverDidClose and view disappearance) stop the sampler.
//
//  Every test fails against the RED stubs: startProcessSampling is a
//  no-op, so no process read ever happens.
//

import AppKit
import SwiftUI
import XCTest
@testable import StatsLite

@MainActor
final class SystemMonitorProcessSamplingTests: XCTestCase {

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
    /// would take an immediate tick-zero read that the untouched loop
    /// does not take inside the short assertion windows (same pattern
    /// as SystemMonitorNetworkTests).
    private func makeMonitor() -> (SystemMonitor, FakeSystemMetricsProvider, PreferencesStore) {
        let provider = FakeSystemMetricsProvider(
            cpuTicks: CPUTicks(perCore: [
                CoreTickSample(user: 100, system: 50, idle: 1000, nice: 0),
            ]),
            networkBytes: NetworkBytes(bytesIn: 1_000_000, bytesOut: 1_000_000)
        )
        provider.processSamples = [
            RawProcessSample(
                pid: 42,
                cpuTicks: 10_000,
                startAbstime: 1_000,
                exitAbstime: 0,
                physFootprint: 536_870_912,
                residentSize: 536_870_912
            ),
        ]
        provider.processNames[42] = "FixtureProcess"
        let monitor = SystemMonitor(provider: provider)
        let preferences = PreferencesStore()
        preferences.refreshInterval = 5
        // Pin the shared persisted value: UserDefaults.standard is
        // shared by every suite class, and the vacuity guard in L2
        // must see an explicit change, not whatever a prior test left.
        preferences.historyDuration = 60
        return (monitor, provider, preferences)
    }

    // MARK: - L1: start reads the provider and records the category

    func testStartProcessSamplingReadsProviderAndPublishesCategory() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        monitor.apply(preferences)

        monitor.startProcessSampling(category: .cpu)
        let started = try await waitUntil { provider.processSampleCount >= 1 }
        XCTAssertTrue(started, "L1: expanding the disclosure must scan processes (R3)")
        XCTAssertTrue(monitor.isSamplingProcesses, "L1: start marks the loop running")
        XCTAssertEqual(monitor.activeProcessCategory, .cpu, "L1: the active category records .cpu")

        // Memory ranks on the first pass (R6): the published list
        // serves as the seed for the stop assertions below.
        let published = try await waitUntil(timeout: 5) {
            !monitor.topMemoryProcesses.isEmpty
        }
        XCTAssertTrue(published, "L1: the first scan publishes the memory ranking (R6)")
        XCTAssertEqual(monitor.topMemoryProcesses.first?.name, "FixtureProcess")

        monitor.stopProcessSampling()
        monitor.stop()
    }

    // MARK: - L2: starting process sampling keeps the standard loop

    func testStartProcessSamplingDoesNotRestartStandardLoop() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        monitor.apply(preferences)
        XCTAssertTrue(monitor.isSampling)

        let firstPass = try await waitUntil { provider.cpuSampleCount >= 1 }
        XCTAssertTrue(firstPass, "the standard loop takes its tick-zero pass")

        let generation = monitor.standardLoopGeneration
        let cpuReadsAtStart = provider.cpuSampleCount

        monitor.startProcessSampling(category: .cpu)
        let started = try await waitUntil { provider.processSampleCount >= 1 }
        XCTAssertTrue(started, "L2: start must scan processes before the isolation check")

        XCTAssertEqual(
            monitor.standardLoopGeneration,
            generation,
            "L2: starting process sampling must not restart the standard loop (T4)"
        )

        // A restarted standard loop takes an immediate tick-zero CPU
        // read; the untouched loop keeps its 5 s cadence.
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(
            provider.cpuSampleCount,
            cpuReadsAtStart,
            "L2: the standard loop keeps its cadence across process-sampling start (T4)"
        )

        // Same for stop: teardown must not bump the generation.
        monitor.stopProcessSampling()
        XCTAssertEqual(
            monitor.standardLoopGeneration,
            generation,
            "L2: stopping process sampling must not restart the standard loop (T4)"
        )
        XCTAssertFalse(monitor.isSamplingProcesses)

        // Vacuity guard: a standard property change must bump the
        // generation, so the equalities above prove something.
        preferences.historyDuration = 120
        monitor.apply(preferences)
        XCTAssertEqual(
            monitor.standardLoopGeneration,
            generation + 1,
            "a standard property change restarts the standard loop"
        )
        preferences.historyDuration = 60
        monitor.stop()
    }

    // MARK: - L3: collapse-while-open stops, clears, and reads zero (FT-2)

    func testCollapseWhileOpenStopsSamplerClearsListsAndReadsZero() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        monitor.apply(preferences)

        monitor.startProcessSampling(category: .cpu)
        let published = try await waitUntil(timeout: 5) {
            !monitor.topMemoryProcesses.isEmpty
        }
        XCTAssertTrue(published, "seed: the sampler published a list while expanded")

        // Collapse to nil: everything stops and clears at once (R3, T5).
        monitor.stopProcessSampling()
        XCTAssertFalse(
            monitor.isSamplingProcesses,
            "FT-2: collapse-while-open stops the sampler"
        )
        XCTAssertNil(monitor.activeProcessCategory, "FT-2: collapse clears the active category")
        XCTAssertTrue(monitor.topCPUProcesses.isEmpty, "FT-2: stop clears the CPU list")
        XCTAssertTrue(monitor.topMemoryProcesses.isEmpty, "FT-2: stop clears the memory list")

        // Zero process reads while collapsed, while the standard loop
        // keeps running untouched.
        let readsAtCollapse = provider.processSampleCount
        let standardReadsAtCollapse = provider.cpuSampleCount
        XCTAssertTrue(monitor.isSampling, "the standard loop runs through a collapse")
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(
            provider.processSampleCount, readsAtCollapse,
            "FT-2: zero process-sampling reads while collapsed"
        )
        XCTAssertEqual(
            provider.cpuSampleCount, standardReadsAtCollapse,
            "the standard loop keeps its 5 s cadence while collapsed"
        )

        monitor.stop()
    }

    // MARK: - L4: stop clears the base, a restart anchors from scratch

    func testStopClearsBaseSoRestartDoesNotRateTheGap() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        monitor.apply(preferences)

        monitor.startProcessSampling(category: .cpu)
        let seeded = try await waitUntil(timeout: 5) {
            !monitor.topCPUProcesses.isEmpty
        }
        XCTAssertTrue(seeded, "seed: CPU published with a delta (two scans)")

        monitor.stopProcessSampling()
        XCTAssertTrue(monitor.topCPUProcesses.isEmpty, "seed: stop cleared the list")

        // Jumped tick counter across the stop window. A surviving base
        // would rate the gap on the first pass after restart.
        provider.processSamples = [
            RawProcessSample(
                pid: 42,
                cpuTicks: 9_000_000,
                startAbstime: 1_000,
                exitAbstime: 0,
                physFootprint: 536_870_912,
                residentSize: 536_870_912
            ),
        ]
        monitor.startProcessCategoryRestartForTest()

        let republished = try await waitUntil(timeout: 5) {
            !monitor.topMemoryProcesses.isEmpty
        }
        XCTAssertTrue(republished, "the restarted sampler publishes memory on its first pass (R6)")
        XCTAssertTrue(
            monitor.topCPUProcesses.isEmpty,
            "FT-2: the first pass after restart anchors; no off-gap CPU delta (T5)"
        )

        monitor.stopProcessSampling()
        monitor.stop()
    }

    // MARK: - L6: popoverDidClose stops the sampler (FT-2 close path)

    func testPopoverCloseStopsProcessSampling() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        let controller = StatusItemController(
            monitor: monitor,
            preferences: preferences
        )
        controller.popover.animates = false

        // Warm-up: let the test host connect the status bar scene.
        let warm = expectation(description: "warm-up")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { warm.fulfill() }
        await fulfillment(of: [warm], timeout: 3)

        controller.perform(Selector(("togglePopover:")), with: nil)
        let shown = expectation(
            for: NSPredicate(format: "isShown == true"),
            evaluatedWith: controller.popover
        )
        await fulfillment(of: [shown], timeout: 5)
        XCTAssertTrue(controller.popover.isShown)

        monitor.startProcessSampling(category: .cpu)
        let started = try await waitUntil { provider.processSampleCount >= 1 }
        XCTAssertTrue(started, "seed: sampling runs while the popover is open")

        // Close through the normal path (covers outside-click and
        // Escape too: both end in popoverDidClose, T5).
        controller.perform(Selector(("togglePopover:")), with: nil)
        let released = expectation(
            for: NSPredicate(format: "contentViewController == nil"),
            evaluatedWith: controller.popover
        )
        await fulfillment(of: [released], timeout: 3)

        let stopped = try await waitUntil { !monitor.isSamplingProcesses }
        XCTAssertTrue(stopped, "FT-2: popoverDidClose stops the sampler (T5)")
        XCTAssertTrue(monitor.topCPUProcesses.isEmpty, "FT-2: the close path clears the CPU list")
        XCTAssertTrue(monitor.topMemoryProcesses.isEmpty, "FT-2: the close path clears the memory list")

        let readsAtClose = provider.processSampleCount
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(
            provider.processSampleCount, readsAtClose,
            "FT-2: zero process reads after the popover closes"
        )
        monitor.stop()
    }

    // MARK: - FT-4: loading window closes when the held sample resolves

    /// The real FT-4 loading-state test (plan §5 G1, VAC-13). The T-A
    /// `testLoadingLineWinsOverRowCountWhileBootstrapHolds` case checks
    /// only the static placeholder label; this one drives the monitor.
    ///
    /// The fake gates the second scan: the first scan only anchors and
    /// publishes memory (R6), so the gated scan is the first scan that
    /// can carry a CPU ranking (R5). While the gate holds it,
    /// `isSamplingProcesses` must read true — that is the loading
    /// window the disclosure renders as `Sampling top processes…`.
    /// Releasing the gate drives the transition to false, so no
    /// assertion races the live 250 ms warm-up.
    func testFT4LoadingWindowHoldsWhileFirstCPUSampleIsHeldAndClosesWhenItResolves() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        monitor.apply(preferences)

        provider.holdProcessSample(call: 2)
        monitor.startProcessSampling(category: .cpu)

        let held = try await waitUntil(timeout: 5) { provider.isProcessSampleHeld }
        XCTAssertTrue(held, "fixture: the first CPU-producing scan is held inside the fake")
        XCTAssertTrue(
            monitor.isSamplingProcesses,
            "FT-4: the loading window reads true while the first CPU sample is held (VAC-13)"
        )
        XCTAssertTrue(
            monitor.topCPUProcesses.isEmpty,
            "FT-4: no CPU ranking can exist while its sample is held"
        )

        provider.releaseHeldProcessSample()

        let closed = try await waitUntil(timeout: 5) { !monitor.isSamplingProcesses }
        XCTAssertTrue(
            closed,
            "FT-4: the held sample resolving closes the loading window"
        )
        XCTAssertFalse(
            monitor.topCPUProcesses.isEmpty,
            "FT-4: the resolved sample publishes the first CPU ranking"
        )
        XCTAssertEqual(monitor.topCPUProcesses.first?.name, "FixtureProcess")

        monitor.stopProcessSampling()
        XCTAssertFalse(monitor.isSamplingProcesses, "FT-4: stop keeps the window closed")
        monitor.stop()
    }

    // MARK: - VAC-B2: all-name-fail reaches the empty state, never a stuck loading line
    //
    // §10 ISC (fix cycle): the loading line must not persist beyond
    // the first pass that can publish rows for the active category —
    // memory at tick 0, CPU at the +250 ms warm-up pass. When every
    // name lookup fails, the D1 fix drops all candidates, so the
    // section must show `No process data available`, never a stuck
    // `Sampling top processes…`. The placeholder expression below is
    // the card's view-model expression (pinned by
    // ProcessDisclosureTests source tokens).

    /// Five candidates, none named: every lookup fails.
    private func installAllNameFailFixtures(_ provider: FakeSystemMetricsProvider) {
        provider.processNames = [:]
        provider.processSamples = (1...5).map { index in
            RawProcessSample(
                pid: Int32(100 + index),
                cpuTicks: 10_000,
                startAbstime: 1_000,
                exitAbstime: 0,
                physFootprint: UInt64(index) * 536_870_912,
                residentSize: UInt64(index) * 536_870_912
            )
        }
    }

    private func placeholder(
        for monitor: SystemMonitor,
        list: [ProcessMetricItem]
    ) -> String? {
        TopProcessesSectionView.placeholderText(
            processCount: list.count,
            isLoading: monitor.isSamplingProcesses && list.isEmpty
        )
    }

    func testVACB2MemoryAllNameFailShowsEmptyStateAfterTickZero() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        installAllNameFailFixtures(provider)
        monitor.apply(preferences)

        monitor.startProcessSampling(category: .memory)
        let windowClosed = try await waitUntil(timeout: 5) {
            !monitor.isSamplingProcesses
        }
        XCTAssertTrue(
            windowClosed,
            "VAC-B2: tick 0 is memory's first publish-capable pass; the loading window must close there, not hang"
        )
        XCTAssertTrue(
            monitor.topMemoryProcesses.isEmpty,
            "all candidates failed name resolution, so the pass ships no rows"
        )
        let shown = placeholder(for: monitor, list: monitor.topMemoryProcesses)
        XCTAssertEqual(
            shown, "No process data available",
            "VAC-B2: the memory section shows the empty state, never a stuck Sampling top processes…"
        )

        monitor.stopProcessSampling()
        monitor.stop()
    }

    func testVACB2CPUAllNameFailShowsEmptyStateAfterWarmUpPass() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        installAllNameFailFixtures(provider)
        monitor.apply(preferences)

        monitor.startProcessSampling(category: .cpu)
        // The t=0 anchoring pass does not count (VAC-13/R5 keeps its
        // 250 ms bootstrap window): the window closes on the warm-up
        // pass, the first CPU-publish-capable pass.
        let windowClosed = try await waitUntil(timeout: 5) {
            !monitor.isSamplingProcesses
        }
        XCTAssertTrue(
            windowClosed,
            "VAC-B2: the +250 ms warm-up pass is CPU's first publish-capable pass; the loading window must close there"
        )
        XCTAssertTrue(
            monitor.topCPUProcesses.isEmpty,
            "all candidates failed name resolution, so the warm-up pass ships no CPU rows"
        )
        let shown = placeholder(for: monitor, list: monitor.topCPUProcesses)
        XCTAssertEqual(
            shown, "No process data available",
            "VAC-B2: the CPU section shows the empty state, never a stuck Sampling top processes…"
        )

        monitor.stopProcessSampling()
        monitor.stop()
    }

    // MARK: - L7: view disappearance stops the sampler (FT-2 close path)

    func testPopoverContentDisappearStopsProcessSampling() async throws {
        let (monitor, provider, preferences) = makeMonitor()
        monitor.apply(preferences)

        monitor.startProcessSampling(category: .cpu)
        let started = try await waitUntil { provider.processSampleCount >= 1 }
        XCTAssertTrue(started, "seed: sampling runs while the content view is mounted")

        // Mount the real content view behind a detach switch, then
        // flip the switch the way a popover close tears the
        // hierarchy down. Measured evidence (T-C review fix):
        // `contentViewController = nil` never fires the root view's
        // onDisappear (cleared-wait timed out at 3 s with the hook
        // present), so that detach could not prove the T5 hook.
        // Flipping the branch removes the subtree through SwiftUI
        // itself, which does deliver onDisappear.
        let trigger = PopoverDetachTrigger()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        let controller = NSHostingController(
            rootView: PopoverDetachHost(
                trigger: trigger,
                monitor: monitor,
                preferences: preferences
            )
        )
        window.contentViewController = controller
        window.orderFront(nil)

        let appeared = try await waitUntil { trigger.contentDidAppear }
        XCTAssertTrue(appeared, "seed: the content view mounted before the detach")

        trigger.attached = false

        let stopped = try await waitUntil(timeout: 3) { !monitor.isSamplingProcesses }
        XCTAssertTrue(stopped, "FT-2: onDisappear stops the sampler (T5)")
        // The flag is not the FT-2 proof: the bootstrap window closes
        // it at +250 ms even with the stop hook deleted, and
        // onDisappear delivery is asynchronous to the detach. Wait
        // event-driven for the stop to land on the published lists;
        // with the hook deleted neither list ever clears (the tick-0
        // memory publish survives), so this assert has teeth (mirror
        // of L6).
        let cleared = try await waitUntil(timeout: 3) {
            monitor.topCPUProcesses.isEmpty && monitor.topMemoryProcesses.isEmpty
        }
        XCTAssertTrue(cleared, "FT-2: the detach path clears both published lists")
        let readsAtDetach = provider.processSampleCount
        // 300 ms covers the warm-up tick at +250 ms: a live loop
        // takes one more read inside this window (5 s cadence after).
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(
            provider.processSampleCount, readsAtDetach,
            "FT-2: zero process reads after the view disappeared"
        )
        window.close()
        monitor.stop()
    }
}

/// FT-2 harness (T-C review fix): drives a real SwiftUI hierarchy
/// disappearance for L7. See the evidence comment at the detach site.
@MainActor
final class PopoverDetachTrigger: ObservableObject {
    /// Flipping this to false removes the content subtree through
    /// SwiftUI, which fires `PopoverContentView.onDisappear`.
    @Published var attached = true
    /// Set by the content's onAppear: proves the subtree mounted
    /// before the test flips the switch.
    @Published var contentDidAppear = false
}

/// Conditional wrapper around the real content view.
private struct PopoverDetachHost: View {
    @ObservedObject var trigger: PopoverDetachTrigger
    let monitor: SystemMonitor
    let preferences: PreferencesStore

    var body: some View {
        if trigger.attached {
            PopoverContentView(monitor: monitor, preferences: preferences)
                .onAppear { trigger.contentDidAppear = true }
        }
    }
}

private extension SystemMonitor {
    /// RED-phase helper: restarts process sampling through the public
    /// API so L4 can re-enter the `.cpu` state after a stop. T-C keeps
    /// the same entry point; nothing extra is implemented here.
    func startProcessCategoryRestartForTest() {
        startProcessSampling(category: .cpu)
    }
}
