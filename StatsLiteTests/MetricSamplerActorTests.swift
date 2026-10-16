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

    // MARK: - Network rate sampling (FM1-FM6)

    /// Sampler plus fake pre-loaded with one network byte sample.
    private func makeNetworkPair(
        bytesIn: UInt64,
        bytesOut: UInt64
    ) -> (MetricSamplerActor, FakeSystemMetricsProvider) {
        let provider = FakeSystemMetricsProvider(
            networkBytes: NetworkBytes(bytesIn: bytesIn, bytesOut: bytesOut)
        )
        return (MetricSamplerActor(provider: provider), provider)
    }

    /// FM2: the first sample must never divide a cumulative uptime
    /// counter by one second of elapsed time. Sample two publishes.
    func testFirstNetworkSampleReturnsNilThenSecondPublishesRate() async throws {
        let (sampler, provider) = makeNetworkPair(
            bytesIn: 98_765_432_109,
            bytesOut: 12_345_678_901
        )
        let t0 = ContinuousClock().now

        let first = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(first, "FM2: the first sample returns nil")
        XCTAssertEqual(provider.networkSampleCount, 1)

        provider.networkBytes = NetworkBytes(
            bytesIn: 98_765_433_109,
            bytesOut: 12_345_679_901
        )
        let second = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(1))
        )
        let metrics = try XCTUnwrap(second, "FM2: sample two publishes a rate")
        XCTAssertEqual(metrics.downloadBytesPerSecond, 1_000, accuracy: 0.001)
        XCTAssertEqual(metrics.uploadBytesPerSecond, 1_000, accuracy: 0.001)
    }

    /// FM1: a counter rollback (interface reset, USB-Ethernet
    /// reconnect) must not trap in unsigned subtraction and must not
    /// emit a bogus rate. The base re-anchors on the rollback sample.
    func testNetworkCounterRollbackReturnsNilAndReanchors() async throws {
        let (sampler, provider) = makeNetworkPair(bytesIn: 5_000_000, bytesOut: 4_000_000)
        let t0 = ContinuousClock().now

        let anchor = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(anchor)

        // Both counters fall below the anchor. A raw UInt64
        // subtraction would trap here, so the guard must catch it.
        provider.networkBytes = NetworkBytes(bytesIn: 1_000_000, bytesOut: 500_000)
        let rollback = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(1))
        )
        XCTAssertNil(rollback, "FM1: rollback returns nil, never a wrapped rate")

        // The rollback sample re-anchored the base: only the delta
        // after it counts toward the next rate.
        provider.networkBytes = NetworkBytes(bytesIn: 1_500_000, bytesOut: 700_000)
        let recovered = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(2))
        )
        let metrics = try XCTUnwrap(
            recovered,
            "FM1: the sample after a rollback publishes from the new anchor"
        )
        XCTAssertEqual(metrics.downloadBytesPerSecond, 500_000, accuracy: 0.001)
        XCTAssertEqual(metrics.uploadBytesPerSecond, 200_000, accuracy: 0.001)
    }

    /// FM3: a gap over 2.5 s (system sleep/wake) re-anchors and
    /// returns nil instead of a diluted rate.
    func testNetworkSampleGapOverTwoAndAHalfSecondsReturnsNil() async throws {
        let (sampler, provider) = makeNetworkPair(bytesIn: 1_000_000, bytesOut: 0)
        let t0 = ContinuousClock().now

        let anchor = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(anchor)

        provider.networkBytes = NetworkBytes(bytesIn: 900_000_000, bytesOut: 900_000_000)
        let slept = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(7200))
        )
        XCTAssertNil(slept, "FM3: a 7200 s gap returns nil, never a diluted rate")

        // Re-anchored on the sleep-wake sample: the next pass rates
        // against it, not against the pre-sleep base.
        provider.networkBytes = NetworkBytes(bytesIn: 900_500_000, bytesOut: 900_500_000)
        let afterWake = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(7201))
        )
        let metrics = try XCTUnwrap(afterWake, "FM3: the sample after the gap re-anchors")
        XCTAssertEqual(metrics.downloadBytesPerSecond, 500_000, accuracy: 0.001)
        XCTAssertEqual(metrics.uploadBytesPerSecond, 500_000, accuracy: 0.001)
    }

    /// FM4: two samples 0.0005 s apart return nil instead of an
    /// infinity or NaN rate from a tiny denominator.
    func testNetworkSamplesHalfAMillisecondApartReturnNil() async {
        let (sampler, provider) = makeNetworkPair(bytesIn: 1_000_000, bytesOut: 1_000_000)
        let t0 = ContinuousClock().now

        let anchor = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(anchor)

        provider.networkBytes = NetworkBytes(bytesIn: 900_000_000, bytesOut: 900_000_000)
        let tiny = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .microseconds(500))
        )
        XCTAssertNil(tiny, "FM4: 0.0005 s apart returns nil, never infinity or NaN")
    }

    /// Zero and negative elapsed time hit the same guard: a zero
    /// denominator would produce infinity.
    func testNetworkZeroOrNegativeElapsedTimeReturnsNil() async {
        let (sampler, provider) = makeNetworkPair(bytesIn: 1_000_000, bytesOut: 1_000_000)
        let t0 = ContinuousClock().now

        let anchor = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(anchor)

        provider.networkBytes = NetworkBytes(bytesIn: 2_000_000, bytesOut: 2_000_000)
        let sameInstant = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(sameInstant, "elapsed 0 s returns nil, never infinity")

        provider.networkBytes = NetworkBytes(bytesIn: 3_000_000, bytesOut: 3_000_000)
        let earlier = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(-1))
        )
        XCTAssertNil(earlier, "negative elapsed time returns nil")
    }

    /// FM5: a failed kernel read returns nil and keeps the base, so
    /// only one pass is lost and the next good read still has its
    /// predecessor (delta over t0 → t0+2 s, divided by 2 s).
    func testFailedNetworkReadKeepsBaseAnchor() async throws {
        let (sampler, provider) = makeNetworkPair(bytesIn: 1_000_000, bytesOut: 0)
        let t0 = ContinuousClock().now

        let anchor = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(anchor)

        provider.networkBytes = nil
        let failed = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(1))
        )
        XCTAssertNil(failed, "FM5: a failed read returns nil")
        XCTAssertEqual(provider.networkSampleCount, 2)

        // The base still holds the bytes from t0, so the delta spans
        // two seconds. Losing the base would make this a first sample.
        provider.networkBytes = NetworkBytes(bytesIn: 3_000_000, bytesOut: 200_000)
        let recovered = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(2))
        )
        let metrics = try XCTUnwrap(recovered, "FM5: the base survives one failed pass")
        XCTAssertEqual(metrics.downloadBytesPerSecond, 1_000_000, accuracy: 0.001)
        XCTAssertEqual(metrics.uploadBytesPerSecond, 100_000, accuracy: 0.001)
    }

    /// FM6: clearNetworkBase drops the anchor, so the next sample is
    /// a fresh first sample (nil) and sample two of the new session
    /// publishes again.
    func testClearNetworkBaseMakesNextSampleReturnNil() async throws {
        let (sampler, provider) = makeNetworkPair(bytesIn: 0, bytesOut: 0)
        let t0 = ContinuousClock().now

        let anchor = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(anchor)

        provider.networkBytes = NetworkBytes(bytesIn: 1_000_000, bytesOut: 1_000_000)
        let rate = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(1))
        )
        XCTAssertNotNil(rate, "a steady pair publishes a rate before the clear")

        await sampler.clearNetworkBase()

        provider.networkBytes = NetworkBytes(bytesIn: 9_000_000, bytesOut: 9_000_000)
        let afterClear = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(2))
        )
        XCTAssertNil(afterClear, "FM6: after clearNetworkBase the next sample anchors again")

        provider.networkBytes = NetworkBytes(bytesIn: 10_000_000, bytesOut: 10_000_000)
        let secondOfNewSession = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(3))
        )
        let metrics = try XCTUnwrap(
            secondOfNewSession,
            "FM6: sample two of the new session publishes"
        )
        XCTAssertEqual(metrics.downloadBytesPerSecond, 1_000_000, accuracy: 0.001)
        XCTAssertEqual(metrics.uploadBytesPerSecond, 1_000_000, accuracy: 0.001)
    }

    /// Disabled routing (MetricSamplerActorTests style): nil result,
    /// no provider read, no base stored.
    func testDisabledNetworkSampleReturnsNilWithoutReadingProvider() async {
        let provider = FakeSystemMetricsProvider(
            networkBytes: NetworkBytes(bytesIn: 1_000_000, bytesOut: 1_000_000)
        )
        let sampler = MetricSamplerActor(provider: provider)

        let result = await sampler.sampleNetwork(enabled: false, now: ContinuousClock().now)

        XCTAssertNil(result, "a disabled network sample returns nil")
        XCTAssertEqual(
            provider.networkSampleCount,
            0,
            "routing: a disabled network never hits the provider"
        )
    }

    /// FM6 (disable path): turning the network off clears the base,
    /// so re-enabling starts from a fresh first sample and no
    /// ten-minute-gap spike can appear.
    func testDisablingNetworkClearsBaseSoReenableNeedsFirstSample() async throws {
        let (sampler, provider) = makeNetworkPair(bytesIn: 1_000_000, bytesOut: 1_000_000)
        let t0 = ContinuousClock().now

        let first = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(first)

        provider.networkBytes = NetworkBytes(bytesIn: 2_000_000, bytesOut: 2_000_000)
        let rate = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(1))
        )
        let beforeDisable = try XCTUnwrap(rate)
        XCTAssertEqual(beforeDisable.downloadBytesPerSecond, 1_000_000, accuracy: 0.001)

        let disabled = await sampler.sampleNetwork(
            enabled: false,
            now: t0.advanced(by: .seconds(2))
        )
        XCTAssertNil(disabled, "a disabled sample returns nil")
        XCTAssertEqual(provider.networkSampleCount, 2, "the disabled pass does not read the provider")

        provider.networkBytes = NetworkBytes(bytesIn: 50_000_000, bytesOut: 50_000_000)
        let afterReenable = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(3))
        )
        XCTAssertNil(
            afterReenable,
            "FM6: the base was cleared on disable, so this is a first sample again"
        )

        provider.networkBytes = NetworkBytes(bytesIn: 51_000_000, bytesOut: 51_000_000)
        let secondOfNewSession = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(4))
        )
        let metrics = try XCTUnwrap(
            secondOfNewSession,
            "FM6: sample two after re-enable publishes"
        )
        XCTAssertEqual(metrics.downloadBytesPerSecond, 1_000_000, accuracy: 0.001)
        XCTAssertEqual(metrics.uploadBytesPerSecond, 1_000_000, accuracy: 0.001)
    }

    /// F3-equivalent rate math (D5): the divisor is the measured
    /// elapsed time between clock instants, never a hard-coded 1.0 s.
    func testNetworkRateDividesByMeasuredElapsedTime() async throws {
        let (sampler, provider) = makeNetworkPair(bytesIn: 0, bytesOut: 0)
        let t0 = ContinuousClock().now

        let anchor = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(anchor)

        provider.networkBytes = NetworkBytes(bytesIn: 8_388_608, bytesOut: 1_048_576)
        let measured = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(2))
        )
        let metrics = try XCTUnwrap(measured)
        // Delta over 2 s. A hard-coded 1.0 s divisor would report
        // 8_388_608 and 1_048_576 here and fail both equalities.
        XCTAssertEqual(metrics.downloadBytesPerSecond, 4_194_304, accuracy: 0.001)
        XCTAssertEqual(metrics.uploadBytesPerSecond, 524_288, accuracy: 0.001)
    }

    /// FM3 boundary: 3.0 s sits just above the ratified 2.5 s cap,
    /// so the gap sample re-anchors and returns nil instead of a
    /// diluted rate. The next pass rates against the new anchor.
    func testNetworkGapOfThreeSecondsReanchorsThenPublishesRate() async throws {
        let (sampler, provider) = makeNetworkPair(bytesIn: 1_000_000, bytesOut: 0)
        let t0 = ContinuousClock().now

        let anchor = await sampler.sampleNetwork(enabled: true, now: t0)
        XCTAssertNil(anchor)

        provider.networkBytes = NetworkBytes(bytesIn: 400_000_000, bytesOut: 400_000_000)
        let gapped = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(3))
        )
        XCTAssertNil(gapped, "FM3: a 3.0 s gap returns nil, never a diluted rate")

        // The gap sample re-anchored the base: the next pass divides
        // by its own 1 s window, not by the pre-gap anchor.
        provider.networkBytes = NetworkBytes(bytesIn: 400_750_000, bytesOut: 400_250_000)
        let reanchored = await sampler.sampleNetwork(
            enabled: true,
            now: t0.advanced(by: .seconds(4))
        )
        let metrics = try XCTUnwrap(
            reanchored,
            "FM3: the sample after a 3.0 s gap re-anchors"
        )
        XCTAssertEqual(metrics.downloadBytesPerSecond, 750_000, accuracy: 0.001)
        XCTAssertEqual(metrics.uploadBytesPerSecond, 250_000, accuracy: 0.001)
    }
}
