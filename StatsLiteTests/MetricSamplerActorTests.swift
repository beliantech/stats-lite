//
//  MetricSamplerActorTests.swift
//  StatsLiteTests
//
//  Toggle-aware sampling: only enabled metrics hit the provider, the
//  CPU previous-tick state clears when CPU turns off, a rapid restart
//  with identical ticks reports zero, and failed reads stay nil.
//

import XCTest
@testable import StatsLite

final class MetricSamplerActorTests: XCTestCase {

    // MARK: - Helpers

    private func makeTicks(
        user: UInt64,
        system: UInt64,
        idle: UInt64,
        nice: UInt64 = 0
    ) -> CPUTicks {
        CPUTicks(perCore: [
            CoreTickSample(user: user, system: system, idle: idle, nice: nice),
        ])
    }

    /// Ticks A: total 1150, busy 150.
    private func makeTicksA() -> CPUTicks {
        makeTicks(user: 100, system: 50, idle: 1000)
    }

    /// Ticks B: total 1400, busy 300. Delta against A: 150 / 250 = 0.6.
    private func makeTicksB() -> CPUTicks {
        makeTicks(user: 200, system: 100, idle: 1100)
    }

    private func makeProvider() -> FakeSystemMetricsProvider {
        FakeSystemMetricsProvider(
            cpuTicks: makeTicksA(),
            memory: MemoryMetrics(
                usedBytes: 8,
                totalBytes: 10,
                appMemoryBytes: 4,
                wiredBytes: 2,
                compressedBytes: 1
            ),
            gpu: GPUMetrics(deviceUtilization: 0.3),
            pressure: MemoryPressureMetrics(state: .warning, pressurePercentage: 0.65)
        )
    }

    // MARK: - Enabled-set routing

    func testEnabledSetRoutesEveryMetric() async throws {
        let provider = makeProvider()
        let sampler = MetricSamplerActor(provider: provider)

        let snapshot = await sampler.collectSnapshot(enabled: .all)

        XCTAssertEqual(provider.cpuSampleCount, 1)
        XCTAssertEqual(provider.memorySampleCount, 1)
        XCTAssertEqual(provider.pressureSampleCount, 1)
        XCTAssertEqual(provider.gpuSampleCount, 1)
        XCTAssertEqual(snapshot.enabled, .all)
        XCTAssertNotNil(try XCTUnwrap(snapshot.cpu))
        XCTAssertNotNil(try XCTUnwrap(snapshot.memory))
        XCTAssertNotNil(try XCTUnwrap(snapshot.memoryPressure))
        XCTAssertNotNil(try XCTUnwrap(snapshot.gpu))
    }

    func testCPUIsNotSampledWhenDisabled() async {
        let provider = makeProvider()
        let sampler = MetricSamplerActor(provider: provider)

        let snapshot = await sampler.collectSnapshot(enabled: [.memory, .gpu])

        XCTAssertEqual(provider.cpuSampleCount, 0)
        XCTAssertEqual(provider.memorySampleCount, 1)
        XCTAssertEqual(provider.pressureSampleCount, 1)
        XCTAssertEqual(provider.gpuSampleCount, 1)
        XCTAssertNil(snapshot.cpu)
        XCTAssertNotNil(snapshot.memory)
        XCTAssertNotNil(snapshot.memoryPressure)
        XCTAssertNotNil(snapshot.gpu)
    }

    func testMemoryAndGPUIsNotSampledWhenDisabled() async {
        let provider = makeProvider()
        let sampler = MetricSamplerActor(provider: provider)

        let snapshot = await sampler.collectSnapshot(enabled: [.cpu])

        XCTAssertEqual(provider.cpuSampleCount, 1)
        XCTAssertEqual(provider.memorySampleCount, 0)
        XCTAssertEqual(provider.pressureSampleCount, 0)
        XCTAssertEqual(provider.gpuSampleCount, 0)
        XCTAssertNotNil(snapshot.cpu)
        XCTAssertNil(snapshot.memory)
        XCTAssertNil(snapshot.memoryPressure)
        XCTAssertNil(snapshot.gpu)
    }

    func testEmptyEnabledSetSamplesNothing() async {
        let provider = makeProvider()
        let sampler = MetricSamplerActor(provider: provider)

        let snapshot = await sampler.collectSnapshot(enabled: [])

        XCTAssertEqual(provider.cpuSampleCount, 0)
        XCTAssertEqual(provider.memorySampleCount, 0)
        XCTAssertEqual(provider.pressureSampleCount, 0)
        XCTAssertEqual(provider.gpuSampleCount, 0)
        XCTAssertEqual(snapshot.enabled, [])
        XCTAssertNil(snapshot.cpu)
        XCTAssertNil(snapshot.memory)
        XCTAssertNil(snapshot.memoryPressure)
        XCTAssertNil(snapshot.gpu)
    }

    // MARK: - CPU previous-tick state

    func testFirstCPUSampleReportsZeroUsage() async throws {
        let sampler = MetricSamplerActor(provider: makeProvider())

        let snapshot = await sampler.collectSnapshot(enabled: [.cpu])

        let cpu = try XCTUnwrap(snapshot.cpu)
        XCTAssertEqual(cpu.totalUsage, 0.0, accuracy: 0.0001)
    }

    func testContinuousCPUSampleReportsDeltaUsage() async throws {
        let provider = makeProvider()
        let sampler = MetricSamplerActor(provider: provider)

        _ = await sampler.collectSnapshot(enabled: [.cpu])
        provider.cpuTicks = makeTicksB()
        let snapshot = await sampler.collectSnapshot(enabled: [.cpu])

        let cpu = try XCTUnwrap(snapshot.cpu)
        XCTAssertEqual(cpu.totalUsage, 0.6, accuracy: 0.0001)
    }

    func testCPUDisabledClearsPreviousTicks() async throws {
        let provider = makeProvider()
        let sampler = MetricSamplerActor(provider: provider)

        // Baseline sample with ticks A.
        let first = await sampler.collectSnapshot(enabled: [.cpu])
        XCTAssertEqual(try XCTUnwrap(first.cpu).totalUsage, 0.0, accuracy: 0.0001)

        // CPU off, ticks advance to B. CPU must not be read.
        provider.cpuTicks = makeTicksB()
        let whileDisabled = await sampler.collectSnapshot(enabled: [.memory])
        XCTAssertNil(whileDisabled.cpu)
        XCTAssertEqual(provider.cpuSampleCount, 1)

        // CPU on again. Previous ticks were cleared, so the first sample
        // after re-enable reports 0. A stale base against A would give 0.6.
        let afterReenable = await sampler.collectSnapshot(enabled: [.cpu])
        let cpu = try XCTUnwrap(afterReenable.cpu)
        XCTAssertEqual(cpu.totalUsage, 0.0, accuracy: 0.0001)
        XCTAssertEqual(provider.cpuSampleCount, 2)
    }

    func testRapidRestartWithIdenticalTicksIsZeroDelta() async throws {
        let provider = makeProvider()
        let sampler = MetricSamplerActor(provider: provider)

        _ = await sampler.collectSnapshot(enabled: [.cpu])
        provider.cpuTicks = makeTicksB()
        let moving = await sampler.collectSnapshot(enabled: [.cpu])
        XCTAssertEqual(try XCTUnwrap(moving.cpu).totalUsage, 0.6, accuracy: 0.0001)

        // Rapid restart: the next pass reads identical counters, so the
        // total delta is 0 and the guard reports 0 instead of a spike.
        let restarted = await sampler.collectSnapshot(enabled: [.cpu])
        let cpu = try XCTUnwrap(restarted.cpu)
        XCTAssertEqual(cpu.totalUsage, 0.0, accuracy: 0.0001)
    }

    func testFailedCPUReadYieldsNilAndKeepsPreviousTicks() async throws {
        let provider = makeProvider()
        let sampler = MetricSamplerActor(provider: provider)

        _ = await sampler.collectSnapshot(enabled: [.cpu])

        // Failed read: nil metrics, state preserved.
        provider.cpuTicks = nil
        let failed = await sampler.collectSnapshot(enabled: [.cpu])
        XCTAssertNil(failed.cpu)
        XCTAssertEqual(provider.cpuSampleCount, 2)

        // Next good read still has ticks A as the delta base.
        provider.cpuTicks = makeTicksB()
        let recovered = await sampler.collectSnapshot(enabled: [.cpu])
        XCTAssertEqual(try XCTUnwrap(recovered.cpu).totalUsage, 0.6, accuracy: 0.0001)
    }

    func testPerCoreUsageUsesMatchingPreviousCoreTicks() async throws {
        let coreA = CPUTicks(perCore: [
            CoreTickSample(user: 100, system: 50, idle: 1000, nice: 0),
            CoreTickSample(user: 0, system: 0, idle: 1000, nice: 0),
        ])
        let coreB = CPUTicks(perCore: [
            CoreTickSample(user: 200, system: 100, idle: 1100, nice: 0),
            CoreTickSample(user: 0, system: 0, idle: 1200, nice: 0),
        ])
        let provider = FakeSystemMetricsProvider(cpuTicks: coreA)
        let sampler = MetricSamplerActor(provider: provider)

        _ = await sampler.collectSnapshot(enabled: [.cpu])
        provider.cpuTicks = coreB
        let snapshot = await sampler.collectSnapshot(enabled: [.cpu])

        let cpu = try XCTUnwrap(snapshot.cpu)
        XCTAssertEqual(cpu.perCore.count, 2)
        XCTAssertEqual(cpu.perCore[0], 0.6, accuracy: 0.0001)
        XCTAssertEqual(cpu.perCore[1], 0.0, accuracy: 0.0001)
    }

    func testCoreCountChangeKeepsAggregateAndResetsPerCore() async throws {
        let provider = FakeSystemMetricsProvider(cpuTicks: makeTicksA())
        let sampler = MetricSamplerActor(provider: provider)

        _ = await sampler.collectSnapshot(enabled: [.cpu])

        // Core count changed: per-core history is invalid, each core
        // starts from nil. The aggregate keeps its delta base.
        let twoCores = CPUTicks(perCore: [
            CoreTickSample(user: 200, system: 100, idle: 1100, nice: 0),
            CoreTickSample(user: 0, system: 0, idle: 200, nice: 0),
        ])
        provider.cpuTicks = twoCores
        let snapshot = await sampler.collectSnapshot(enabled: [.cpu])

        let cpu = try XCTUnwrap(snapshot.cpu)
        XCTAssertEqual(cpu.perCore, [0.0, 0.0])
        // Aggregate: previous total 1150 busy 150. Current total 1600
        // busy 300. Delta 150 / 450.
        XCTAssertEqual(cpu.totalUsage, 150.0 / 450.0, accuracy: 0.0001)
    }
}
