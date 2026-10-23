//
//  TemperatureSamplerGatingTests.swift
//  StatsLiteTests
//
//  Sampler gating contract for temperature (plan
//  2026-10-23-temp-menu-bar-metric, FM-T2-6 and FM-T2-7).
//
//  T3-dependent: these tests reference the Phase 3 API
//  (`EnabledMetrics.temperature` and `SystemSnapshot.temperature`).
//  They stay red until T3 lands. Do not weaken them in T2 green.
//

import XCTest
@testable import StatsLite

final class TemperatureSamplerGatingTests: XCTestCase {

    private func makeEnabledProvider() -> FakeSystemMetricsProvider {
        FakeSystemMetricsProvider(
            temperature: TemperatureMetrics(cpuCelsius: 84, gpuCelsius: 61)
        )
    }

    // MARK: - FM-T2-6 (T3-dependent)

    func testCollectSnapshotSamplesTemperatureWhenEnabled() async {
        let provider = makeEnabledProvider()
        let sampler = MetricSamplerActor(provider: provider)

        let snapshot = await sampler.collectSnapshot(
            enabled: [.cpu, .memory, .gpu, .temperature]
        )

        XCTAssertEqual(
            provider.temperatureSampleCount,
            1,
            "an enabled temperature is sampled exactly once per pass"
        )
        XCTAssertEqual(
            snapshot.temperature,
            TemperatureMetrics(cpuCelsius: 84, gpuCelsius: 61),
            "the sampled reading lands in the snapshot"
        )
    }

    func testCollectSnapshotKeepsTemperatureNilWhenUnreadable() async {
        // Enabled but unreadable: the pass still counts one read, and
        // the snapshot member stays nil (nil-contract, no throw).
        let provider = FakeSystemMetricsProvider()
        let sampler = MetricSamplerActor(provider: provider)

        let snapshot = await sampler.collectSnapshot(
            enabled: [.cpu, .memory, .gpu, .temperature]
        )

        XCTAssertEqual(provider.temperatureSampleCount, 1)
        XCTAssertNil(snapshot.temperature)
    }

    // MARK: - FM-T2-7 (T3-dependent)

    func testDisabledTemperatureIsNeverSampled() async {
        // Explicit set without .temperature: the provider must never
        // see a temperature read, and the snapshot stays nil.
        let provider = makeEnabledProvider()
        let sampler = MetricSamplerActor(provider: provider)

        let snapshot = await sampler.collectSnapshot(
            enabled: [.cpu, .memory, .gpu]
        )

        XCTAssertEqual(
            provider.temperatureSampleCount,
            0,
            "a disabled metric must never reach the provider"
        )
        XCTAssertNil(snapshot.temperature)
    }

    func testAllEnabledSetNeverSamplesTemperature() async {
        // `EnabledMetrics.all` stays [.cpu, .memory, .gpu] (plan Phase 3):
        // temperature rides the separate showTemperature insert, so the
        // default set must not read it.
        let provider = makeEnabledProvider()
        let sampler = MetricSamplerActor(provider: provider)

        let snapshot = await sampler.collectSnapshot(enabled: .all)

        XCTAssertEqual(provider.temperatureSampleCount, 0)
        XCTAssertNil(snapshot.temperature)
    }
}
