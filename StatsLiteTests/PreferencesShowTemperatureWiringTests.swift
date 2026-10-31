//
//  PreferencesShowTemperatureWiringTests.swift
//  StatsLiteTests
//
//  T3 red phase (plan 2026-10-23-temp-menu-bar-metric, Phase 3
//  remainder): PreferencesStore.showTemperature, its insert into
//  enabledMetrics (reviewer F1 critical), its place in the
//  five-metric count guard, the @AppStorage key, and the
//  store-to-sampler edge. One test per failure mode: FM-T3-1 ..
//  FM-T3-5.
//
//  These tests fail until T3 lands. Do not weaken them in green.
//

import XCTest
@testable import StatsLite

/// UserDefaults keys owned by these tests, plus the reset helper.
/// Same isolation pattern as PreferencesStoreGuardTests; the names
/// stay file-private so the suites cannot collide.
private let wiringPreferencesKeys = [
    "showCPU",
    "showRAM",
    "showGPU",
    "showNetwork",
    "showTemperature",
    "refreshInterval",
    "historyDuration",
]

private func clearWiringPreferencesKeys() {
    for key in wiringPreferencesKeys {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

@MainActor
final class PreferencesShowTemperatureWiringTests: XCTestCase {

    override func setUp() {
        super.setUp()
        clearWiringPreferencesKeys()
    }

    override func tearDown() {
        clearWiringPreferencesKeys()
        super.tearDown()
    }

    // MARK: - FM-T3-1 (default mirrors showNetwork)

    /// Mirror rule: `showNetwork` ships ON when its key is absent —
    /// the property initializes to `true`, `@AppStorage("showNetwork")`
    /// defaults to `true`, and `init` seeds the property from storage.
    /// `showTemperature` must seed the same way, so a fresh store with
    /// no key written reads `showTemperature == true`.
    func testShowTemperatureDefaultsOnWhenKeyIsAbsent() {
        let store = PreferencesStore()

        XCTAssertTrue(
            store.showTemperature,
            "F2 mirror: TEMP ships ON on fresh and existing installs, like Network"
        )
    }

    // MARK: - FM-T3-2 (F1 critical: insert into enabledMetrics)

    /// Reviewer F1: `showNetwork` lives outside `enabledMetrics`
    /// because its sampling path is separate. Temperature has no
    /// separate path — it rides `collectSnapshot` through
    /// `enabledMetrics`. Copying the "Outside enabledMetrics" carve-out
    /// verbatim leaves both TEMP rows at a permanent `--°`. Pin both
    /// directions: ON inserts `.temperature`, OFF drops it.
    func testEnabledMetricsFollowsShowTemperatureBothDirections() {
        let store = PreferencesStore()

        store.showTemperature = true
        XCTAssertTrue(
            store.enabledMetrics.contains(.temperature),
            "F1: showTemperature ON must insert .temperature or the sampler never reads temperature"
        )

        store.showTemperature = false
        XCTAssertFalse(
            store.enabledMetrics.contains(.temperature),
            "F1: showTemperature OFF must remove .temperature or the sampler keeps reading it"
        )
        XCTAssertTrue(
            store.enabledMetrics.contains(.cpu),
            "the count-guarded members keep their state across a temperature toggle"
        )
    }

    // MARK: - FM-T3-3 (five-metric count and lock participation)

    /// Plan 2026-10-31 Option A: `showTemperature` enters
    /// `activeMetricCount`, its toggle takes the last-one-enabled
    /// lock as the sole enabled metric, and the didSet guard refuses
    /// to turn off that last metric.
    func testShowTemperatureParticipatesInCountGuardAndToggleLock() {
        let store = PreferencesStore()
        XCTAssertEqual(store.activeMetricCount, 5, "all five defaults count")

        // Temperature moves the count in both directions.
        store.showTemperature = false
        XCTAssertEqual(store.activeMetricCount, 4, "temperature enters the five-metric count")
        store.showTemperature = true
        XCTAssertEqual(store.activeMetricCount, 5, "re-enabling restores the full count")

        // Temperature sole metric on: its toggle takes the lock.
        store.showCPU = false
        store.showRAM = false
        store.showGPU = false
        store.showNetwork = false
        XCTAssertFalse(store.showGPU, "setup: the four non-temperature metrics turn off")
        XCTAssertEqual(store.activeMetricCount, 1, "temperature is the sole enabled metric")
        XCTAssertTrue(
            store.isToggleLocked(store.showTemperature),
            "the sole temperature toggle locks"
        )
        XCTAssertFalse(store.isToggleLocked(store.showCPU))

        // The guard refuses to turn off the last metric.
        store.showTemperature = false
        XCTAssertTrue(store.showTemperature, "didSet reverts the sole enabled metric")
        XCTAssertEqual(store.activeMetricCount, 1, "the count stays at 1 after the refusal")
    }

    // MARK: - FM-T3-4 (own @AppStorage key, round-trip)

    func testShowTemperaturePersistsUnderItsOwnKeyAcrossInstances() {
        // The store reads its own key: seed only showTemperature and
        // leave every other metric key absent.
        UserDefaults.standard.set(false, forKey: "showTemperature")

        let seeded = PreferencesStore()
        XCTAssertFalse(seeded.showTemperature, "a persisted opt-out seeds a fresh store")
        XCTAssertTrue(seeded.showNetwork, "the showNetwork key stays untouched")
        XCTAssertTrue(seeded.showGPU, "the other metric keys stay untouched")

        // Write path: with the key cleared, the default is back ON.
        // Toggling writes "showTemperature" only.
        UserDefaults.standard.removeObject(forKey: "showTemperature")
        let first = PreferencesStore()
        XCTAssertTrue(first.showTemperature, "default ON with the key absent")

        first.showTemperature = false
        XCTAssertEqual(
            UserDefaults.standard.object(forKey: "showTemperature") as? Bool,
            false,
            "toggling writes the showTemperature key"
        )
        XCTAssertNil(
            UserDefaults.standard.object(forKey: "showNetwork"),
            "showTemperature must not reuse the showNetwork key"
        )

        let second = PreferencesStore()
        XCTAssertFalse(second.showTemperature, "an opt-out survives a fresh store instance")

        second.showTemperature = true
        let third = PreferencesStore()
        XCTAssertTrue(third.showTemperature, "a re-enable survives a fresh store instance")
    }

    // MARK: - FM-T3-5 (store -> enabledMetrics -> sampler edge)

    /// TemperatureSamplerGatingTests (T2) drives `collectSnapshot`
    /// with an explicit set. This test pins the STORE edge that T2 did
    /// not cover: the store's own `enabledMetrics` must reach the
    /// sampler and gate the provider read.
    func testStoreEnabledMetricsDrivesTemperatureSampling() async {
        let fixture = TemperatureMetrics(cpuCelsius: 84, gpuCelsius: 61)

        // Enabled: store ON -> .temperature present -> one read per pass.
        let store = PreferencesStore()
        store.showTemperature = true
        XCTAssertTrue(
            store.enabledMetrics.contains(.temperature),
            "the store's enabled set carries .temperature to the sampler"
        )

        let enabledProvider = FakeSystemMetricsProvider(temperature: fixture)
        let enabledSampler = MetricSamplerActor(provider: enabledProvider)
        let snapshot = await enabledSampler.collectSnapshot(enabled: store.enabledMetrics)

        XCTAssertEqual(
            enabledProvider.temperatureSampleCount,
            1,
            "a store-enabled temperature is sampled exactly once per pass"
        )
        XCTAssertEqual(snapshot.temperature, fixture, "the reading lands in the snapshot")

        // Disabled: store OFF -> .temperature absent -> zero reads.
        store.showTemperature = false
        XCTAssertFalse(
            store.enabledMetrics.contains(.temperature),
            "the store's enabled set drops .temperature when showTemperature is OFF"
        )

        let disabledProvider = FakeSystemMetricsProvider(temperature: fixture)
        let disabledSampler = MetricSamplerActor(provider: disabledProvider)
        let disabledSnapshot = await disabledSampler.collectSnapshot(
            enabled: store.enabledMetrics
        )

        XCTAssertEqual(
            disabledProvider.temperatureSampleCount,
            0,
            "a store-disabled temperature must never reach the provider"
        )
        XCTAssertNil(disabledSnapshot.temperature)
    }
}
