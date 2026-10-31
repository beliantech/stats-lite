//
//  FiveMetricLockTests.swift
//  StatsLiteTests
//
//  Red-phase tests for the five-metric visible-metrics lock
//  (plan 2026-10-31-settings-visible-metrics-lock-all-toggles).
//  One test per failure mode FM1 to FM5, plus unit coverage for
//  VAC-4, VAC-5, VAC-6, VAC-7, VAC-8, VAC-9, VAC-10, VAC-11, and
//  VAC-13. The store still counts only CPU, RAM, and GPU, so these
//  tests fail until Option A lands.
//
//  Do not weaken them in green.
//

import XCTest
@testable import StatsLite

/// UserDefaults keys owned by these tests, plus the reset helper.
/// The names stay file-private so the suites cannot collide.
private let fiveMetricLockKeys = [
    "showCPU",
    "showRAM",
    "showGPU",
    "showTemperature",
    "showNetwork",
    "refreshInterval",
    "historyDuration",
]

private func clearFiveMetricLockKeys() {
    for key in fiveMetricLockKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@MainActor
final class FiveMetricLockTests: XCTestCase {

    /// The five visible metrics in Settings row order.
    private enum VisibleMetric: CaseIterable {
        case cpu, gpu, ram, temperature, network

        var label: String {
            switch self {
            case .cpu: return "CPU"
            case .gpu: return "GPU"
            case .ram: return "RAM"
            case .temperature: return "Temperature"
            case .network: return "Network"
            }
        }
    }

    override func setUp() {
        super.setUp()
        clearFiveMetricLockKeys()
    }

    override func tearDown() {
        clearFiveMetricLockKeys()
        super.tearDown()
    }

    // MARK: - Helpers

    private func isOn(
        _ metric: VisibleMetric,
        in store: PreferencesStore
    ) -> Bool {
        switch metric {
        case .cpu: return store.showCPU
        case .gpu: return store.showGPU
        case .ram: return store.showRAM
        case .temperature: return store.showTemperature
        case .network: return store.showNetwork
        }
    }

    private func set(
        _ metric: VisibleMetric,
        _ value: Bool,
        in store: PreferencesStore
    ) {
        switch metric {
        case .cpu: store.showCPU = value
        case .gpu: store.showGPU = value
        case .ram: store.showRAM = value
        case .temperature: store.showTemperature = value
        case .network: store.showNetwork = value
        }
    }

    /// A fresh store with every metric except `sole` switched off.
    private func makeSoleEnabled(_ sole: VisibleMetric) -> PreferencesStore {
        let store = PreferencesStore()
        for metric in VisibleMetric.allCases where metric != sole {
            set(metric, false, in: store)
        }
        return store
    }

    /// Checks the sole-ON contract for one metric: the four others
    /// are off, the count is 1, the sole toggle locks, and the four
    /// off toggles stay unlocked. Returns the store so the caller can
    /// drive the release transition.
    @discardableResult
    private func assertSoleEnabledState(
        _ sole: VisibleMetric,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> PreferencesStore {
        let store = makeSoleEnabled(sole)

        // Setup sanity: without it the checks below pass on a store
        // that never reached the sole-ON state.
        for other in VisibleMetric.allCases where other != sole {
            XCTAssertFalse(
                isOn(other, in: store),
                "setup: \(other.label) turns off for \(sole.label) sole-ON",
                file: file,
                line: line
            )
        }
        XCTAssertEqual(
            store.activeMetricCount,
            1,
            "\(sole.label) sole-ON counts as one enabled metric",
            file: file,
            line: line
        )
        XCTAssertTrue(
            store.isToggleLocked(isOn(sole, in: store)),
            "FM1/VAC: the sole \(sole.label) toggle locks",
            file: file,
            line: line
        )
        for other in VisibleMetric.allCases where other != sole {
            XCTAssertFalse(
                store.isToggleLocked(isOn(other, in: store)),
                "\(other.label) stays unlocked while off",
                file: file,
                line: line
            )
        }
        return store
    }

    /// Checks that no toggle locks in the state the caller just
    /// built, and that the count matches the expected total.
    private func assertNothingLocked(
        _ store: PreferencesStore,
        count: Int,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            store.activeMetricCount,
            count,
            "\(context): the five-metric count is \(count)",
            file: file,
            line: line
        )
        for metric in VisibleMetric.allCases {
            XCTAssertFalse(
                store.isToggleLocked(isOn(metric, in: store)),
                "\(context): no toggle locks (\(metric.label))",
                file: file,
                line: line
            )
        }
    }

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

    // MARK: - FM1 (the last-one lock covers all five metrics)

    /// FM1: each of the five metrics locks its own toggle when it is
    /// the only enabled metric. This carries the VAC-7 to VAC-11
    /// sole-ON lock assertions at unit level.
    func testFM1SoleEnabledMetricLocksForEachOfFiveMetrics() {
        for sole in VisibleMetric.allCases {
            clearFiveMetricLockKeys()
            assertSoleEnabledState(sole)
        }
    }

    // MARK: - VAC-4, VAC-5, VAC-6 (multi-metric states lock nothing)

    /// VAC-4: CPU and GPU off with RAM, Temperature, and Network on.
    /// The Memory toggle must not lock while three metrics are on.
    func testVAC4CPUGPUOffWithRAMTemperatureNetworkOnLocksNothing() {
        let store = PreferencesStore()
        store.showCPU = false
        store.showGPU = false

        assertNothingLocked(
            store,
            count: 3,
            context: "VAC-4: RAM, Temperature, and Network on"
        )
    }

    /// VAC-5: CPU and RAM off with GPU, Temperature, and Network on.
    /// The GPU toggle must not lock while three metrics are on.
    func testVAC5CPURAMOffGPUTemperatureNetworkOnLocksNothing() {
        let store = PreferencesStore()
        store.showCPU = false
        store.showRAM = false

        assertNothingLocked(
            store,
            count: 3,
            context: "VAC-5: GPU, Temperature, and Network on"
        )
    }

    /// VAC-6: exactly two metrics on lock nothing. Pair one is the
    /// blueprint example (Temperature + Network). Pair two mixes one
    /// core metric with Temperature (CPU + Temperature).
    func testVAC6ExactlyTwoMetricsOnLocksNothing() {
        let first = PreferencesStore()
        first.showCPU = false
        first.showGPU = false
        first.showRAM = false
        XCTAssertFalse(first.showRAM, "setup: the three core metrics turn off")
        assertNothingLocked(
            first,
            count: 2,
            context: "VAC-6: Temperature and Network on"
        )

        clearFiveMetricLockKeys()
        let second = PreferencesStore()
        second.showGPU = false
        second.showRAM = false
        second.showNetwork = false
        XCTAssertFalse(second.showRAM, "setup: GPU, RAM, and Network turn off")
        assertNothingLocked(
            second,
            count: 2,
            context: "VAC-6: CPU and Temperature on"
        )
    }

    // MARK: - VAC-7 to VAC-11 (sole-ON lock and its release)

    /// VAC-7: CPU sole ON locks. The lock releases when Temperature
    /// joins, so the count must include Temperature.
    func testVAC7SoleEnabledCPULocksUntilTemperatureJoins() {
        let store = assertSoleEnabledState(.cpu)

        store.showTemperature = true
        XCTAssertEqual(
            store.activeMetricCount,
            2,
            "VAC-7: Temperature joins the five-metric count"
        )
        XCTAssertFalse(
            store.isToggleLocked(store.showCPU),
            "VAC-7: the CPU lock releases at two metrics"
        )
        XCTAssertFalse(
            store.isToggleLocked(store.showTemperature),
            "VAC-7: the joining toggle stays unlocked"
        )
    }

    /// VAC-8: GPU sole ON locks. The lock releases when Network
    /// joins, so the count must include Network.
    func testVAC8SoleEnabledGPULocksUntilNetworkJoins() {
        let store = assertSoleEnabledState(.gpu)

        store.showNetwork = true
        XCTAssertEqual(
            store.activeMetricCount,
            2,
            "VAC-8: Network joins the five-metric count"
        )
        XCTAssertFalse(
            store.isToggleLocked(store.showGPU),
            "VAC-8: the GPU lock releases at two metrics"
        )
        XCTAssertFalse(
            store.isToggleLocked(store.showNetwork),
            "VAC-8: the joining toggle stays unlocked"
        )
    }

    /// VAC-9: RAM sole ON locks. The lock releases when Temperature
    /// joins, so the count must include Temperature.
    func testVAC9SoleEnabledRAMLocksUntilTemperatureJoins() {
        let store = assertSoleEnabledState(.ram)

        store.showTemperature = true
        XCTAssertEqual(
            store.activeMetricCount,
            2,
            "VAC-9: Temperature joins the five-metric count"
        )
        XCTAssertFalse(
            store.isToggleLocked(store.showRAM),
            "VAC-9: the RAM lock releases at two metrics"
        )
        XCTAssertFalse(
            store.isToggleLocked(store.showTemperature),
            "VAC-9: the joining toggle stays unlocked"
        )
    }

    /// VAC-10: Temperature sole ON locks. The lock releases when CPU
    /// joins, so the count must include Temperature at one and two.
    func testVAC10SoleEnabledTemperatureLocks() {
        let store = assertSoleEnabledState(.temperature)

        store.showCPU = true
        XCTAssertEqual(
            store.activeMetricCount,
            2,
            "VAC-10: CPU joins the five-metric count"
        )
        XCTAssertFalse(
            store.isToggleLocked(store.showTemperature),
            "VAC-10: the Temperature lock releases at two metrics"
        )
        XCTAssertFalse(
            store.isToggleLocked(store.showCPU),
            "VAC-10: the joining toggle stays unlocked"
        )
    }

    /// VAC-11: Network sole ON locks. The lock releases when CPU
    /// joins, so the count must include Network at one and two.
    func testVAC11SoleEnabledNetworkLocks() {
        let store = assertSoleEnabledState(.network)

        store.showCPU = true
        XCTAssertEqual(
            store.activeMetricCount,
            2,
            "VAC-11: CPU joins the five-metric count"
        )
        XCTAssertFalse(
            store.isToggleLocked(store.showNetwork),
            "VAC-11: the Network lock releases at two metrics"
        )
        XCTAssertFalse(
            store.isToggleLocked(store.showCPU),
            "VAC-11: the joining toggle stays unlocked"
        )
    }

    // MARK: - FM2 (the count never reaches zero)

    /// Walks the store from all-five-on down to one metric, then
    /// across three different sole metrics (GPU, Network, and
    /// Temperature). The didSet guard must refuse every turn-off that
    /// would leave zero metrics on and accept every other turn-off,
    /// so activeMetricCount never reads 0.
    func testFM2ActiveMetricCountNeverReachesZero() {
        let store = PreferencesStore()

        // Down to GPU sole.
        store.showCPU = false
        store.showRAM = false
        store.showTemperature = false
        store.showNetwork = false
        XCTAssertEqual(store.activeMetricCount, 1, "FM2: one metric remains")

        // The last metric refuses to switch off.
        store.showGPU = false
        XCTAssertTrue(store.showGPU, "FM2: didSet reverts the last enabled metric")
        XCTAssertEqual(
            store.activeMetricCount,
            1,
            "FM2: the count stays at 1 after the refusal"
        )

        // Network joins the count, so GPU may switch off now.
        store.showNetwork = true
        XCTAssertEqual(
            store.activeMetricCount,
            2,
            "FM2: Network joins the five-metric count"
        )

        store.showGPU = false
        XCTAssertFalse(store.showGPU, "FM2: a non-last metric switches off")
        XCTAssertEqual(store.activeMetricCount, 1, "FM2: the count returns to 1")

        // Network is now the last metric: refuse.
        store.showNetwork = false
        XCTAssertTrue(store.showNetwork, "FM2: didSet reverts the last enabled metric")
        XCTAssertEqual(
            store.activeMetricCount,
            1,
            "FM2: the count stays at 1 after the refusal"
        )

        // Temperature joins, the Network switches off, and
        // Temperature becomes the last metric.
        store.showTemperature = true
        XCTAssertEqual(
            store.activeMetricCount,
            2,
            "FM2: Temperature joins the five-metric count"
        )
        store.showNetwork = false
        XCTAssertFalse(store.showNetwork, "FM2: a non-last metric switches off")
        XCTAssertEqual(store.activeMetricCount, 1, "FM2: the count returns to 1")

        store.showTemperature = false
        XCTAssertTrue(
            store.showTemperature,
            "FM2: didSet reverts the last enabled metric"
        )
        XCTAssertEqual(
            store.activeMetricCount,
            1,
            "FM2: the count stays at 1 after the refusal"
        )
        XCTAssertNotEqual(
            store.activeMetricCount,
            0,
            "FM2: no reachable state reports zero metrics"
        )
    }

    // MARK: - FM3 (Network-only state survives init)

    /// Seeds a Network-only state through UserDefaults. The init
    /// repair must fire only when all five keys are false, so the
    /// store keeps the Network-only state instead of force-enabling
    /// a core metric.
    func testFM3NetworkOnlyStateSurvivesInit() {
        UserDefaults.standard.set(false, forKey: "showCPU")
        UserDefaults.standard.set(false, forKey: "showRAM")
        UserDefaults.standard.set(false, forKey: "showGPU")
        UserDefaults.standard.set(false, forKey: "showTemperature")
        UserDefaults.standard.set(true, forKey: "showNetwork")

        let store = PreferencesStore()

        XCTAssertFalse(
            store.showCPU,
            "FM3: the init repair must not fire when the Network is on"
        )
        XCTAssertFalse(store.showRAM, "FM3: no core metric is force-enabled")
        XCTAssertFalse(store.showGPU, "FM3: no core metric is force-enabled")
        XCTAssertFalse(store.showTemperature, "FM3: Temperature stays off")
        XCTAssertTrue(store.showNetwork, "FM3: the Network-only state survives init")
        XCTAssertEqual(
            store.activeMetricCount,
            1,
            "FM3: the Network is the sole enabled metric"
        )
        XCTAssertTrue(
            store.isToggleLocked(store.showNetwork),
            "FM3: the sole Network toggle locks"
        )
        XCTAssertTrue(
            store.enabledMetrics.isEmpty,
            "FM3: the Network samples outside enabledMetrics"
        )
    }

    // MARK: - FM4 (sampling keeps flowing with core metrics off)

    /// Network-only: enabledMetrics is empty, so MonitorGuard stops
    /// the standard loop, but the independent 1 s network loop still
    /// runs and publishes rates.
    func testFM4NetworkOnlyKeepsIndependentNetworkSamplingFlowing() async throws {
        UserDefaults.standard.set(false, forKey: "showCPU")
        UserDefaults.standard.set(false, forKey: "showRAM")
        UserDefaults.standard.set(false, forKey: "showGPU")
        UserDefaults.standard.set(false, forKey: "showTemperature")
        UserDefaults.standard.set(true, forKey: "showNetwork")

        let store = PreferencesStore()
        XCTAssertFalse(
            store.showCPU,
            "FM4 setup: no core metric is force-enabled"
        )
        XCTAssertEqual(
            store.activeMetricCount,
            1,
            "FM4 setup: the Network is the sole enabled metric"
        )
        XCTAssertTrue(
            store.enabledMetrics.isEmpty,
            "FM4: the Network samples outside enabledMetrics"
        )

        let provider = FakeSystemMetricsProvider(
            networkBytes: NetworkBytes(bytesIn: 1_000_000, bytesOut: 500_000)
        )
        let monitor = SystemMonitor(provider: provider)
        monitor.apply(store)

        XCTAssertFalse(
            monitor.isSampling,
            "FM4: MonitorGuard stops the standard loop on the empty set"
        )
        XCTAssertTrue(
            monitor.isNetworkSampling,
            "FM4: the network loop runs independently of restartSampling"
        )

        let published = try await waitUntil(timeout: 8) {
            monitor.latestNetwork != nil
        }
        XCTAssertTrue(
            published,
            "FM4: Network data keeps flowing with all core metrics off"
        )
        XCTAssertGreaterThan(
            provider.networkSampleCount,
            0,
            "FM4: the network loop reads the provider"
        )

        monitor.stop()
    }

    /// Temperature-only: Temperature rides enabledMetrics, so the
    /// standard loop runs and keeps sampling with every core metric
    /// off. The network loop stays off.
    func testFM4TemperatureOnlyKeepsStandardSamplingFlowing() async throws {
        UserDefaults.standard.set(false, forKey: "showCPU")
        UserDefaults.standard.set(false, forKey: "showRAM")
        UserDefaults.standard.set(false, forKey: "showGPU")
        UserDefaults.standard.set(false, forKey: "showNetwork")
        UserDefaults.standard.set(true, forKey: "showTemperature")

        let store = PreferencesStore()
        XCTAssertFalse(
            store.showCPU,
            "FM4 setup: no core metric is force-enabled"
        )
        XCTAssertEqual(
            store.activeMetricCount,
            1,
            "FM4 setup: Temperature is the sole enabled metric"
        )
        XCTAssertEqual(
            store.enabledMetrics,
            [.temperature],
            "FM4: Temperature rides enabledMetrics"
        )

        let provider = FakeSystemMetricsProvider(
            temperature: TemperatureMetrics(cpuCelsius: 61, gpuCelsius: 44)
        )
        let monitor = SystemMonitor(provider: provider)
        monitor.apply(store)

        XCTAssertTrue(
            monitor.isSampling,
            "FM4: the standard loop samples the Temperature-only set"
        )
        XCTAssertFalse(
            monitor.isNetworkSampling,
            "FM4: no network loop without showNetwork"
        )

        let sampled = try await waitUntil(timeout: 5) {
            provider.temperatureSampleCount >= 1
        }
        XCTAssertTrue(
            sampled,
            "FM4: Temperature data keeps flowing with all core metrics off"
        )

        monitor.stop()
    }

    // MARK: - FM5 (a legacy seeded state stays valid)

    /// Seeds a legacy subset: CPU, RAM, and Temperature on, GPU and
    /// Network off. No migration exists, so every seeded flag must
    /// survive init unchanged and the state must report a valid
    /// count with no locked toggle.
    func testFM5LegacySeededStateStaysValidUnderFiveMetricCount() {
        UserDefaults.standard.set(true, forKey: "showCPU")
        UserDefaults.standard.set(true, forKey: "showRAM")
        UserDefaults.standard.set(false, forKey: "showGPU")
        UserDefaults.standard.set(false, forKey: "showNetwork")
        UserDefaults.standard.set(true, forKey: "showTemperature")

        let store = PreferencesStore()

        XCTAssertTrue(store.showCPU, "FM5: no forced flip on upgrade")
        XCTAssertTrue(store.showRAM, "FM5: no forced flip on upgrade")
        XCTAssertFalse(store.showGPU, "FM5: a seeded opt-out survives")
        XCTAssertFalse(store.showNetwork, "FM5: a seeded opt-out survives")
        XCTAssertTrue(store.showTemperature, "FM5: no forced flip on upgrade")
        XCTAssertEqual(
            store.activeMetricCount,
            3,
            "FM5: the legacy subset counts under the five-metric total"
        )
        XCTAssertFalse(store.isToggleLocked(store.showCPU))
        XCTAssertFalse(store.isToggleLocked(store.showRAM))
        XCTAssertFalse(store.isToggleLocked(store.showTemperature))
    }

    // MARK: - VAC-13 (all-five-false storage repair)

    /// UserDefaults with all five metric keys false: init restores
    /// showCPU as the safe fallback and persists the repair. The
    /// other four keys stay false.
    func testVAC13AllFiveFalseKeysRestoreShowCPUOnInit() {
        UserDefaults.standard.set(false, forKey: "showCPU")
        UserDefaults.standard.set(false, forKey: "showRAM")
        UserDefaults.standard.set(false, forKey: "showGPU")
        UserDefaults.standard.set(false, forKey: "showTemperature")
        UserDefaults.standard.set(false, forKey: "showNetwork")

        let store = PreferencesStore()

        XCTAssertTrue(
            store.showCPU,
            "VAC-13: init restores showCPU when all five keys are false"
        )
        XCTAssertFalse(store.showRAM, "VAC-13: the repair touches showCPU only")
        XCTAssertFalse(store.showGPU, "VAC-13: the repair touches showCPU only")
        XCTAssertFalse(
            store.showTemperature,
            "VAC-13: the repair touches showCPU only"
        )
        XCTAssertFalse(store.showNetwork, "VAC-13: the repair touches showCPU only")
        XCTAssertEqual(
            store.activeMetricCount,
            1,
            "VAC-13: one metric remains after the repair"
        )
        XCTAssertEqual(
            UserDefaults.standard.bool(forKey: "showCPU"),
            true,
            "VAC-13: the repair persists to storage"
        )
    }
}
