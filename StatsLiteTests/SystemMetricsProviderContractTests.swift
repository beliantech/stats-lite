//
//  SystemMetricsProviderContractTests.swift
//  StatsLiteTests
//
//  Contract every SystemMetricsProvider must satisfy: value ranges,
//  aggregate consistency, and memory formula consistency. The contract
//  runs against the fake (protocol conformance) and the live provider
//  (real Mach, IOKit, and sysctl reads on this machine).
//

import Foundation
import XCTest
@testable import StatsLite

final class SystemMetricsProviderContractTests: XCTestCase {

    // MARK: - Fake round trip

    func testFakeReturnsConfiguredValues() {
        let cpu = CPUTicks(perCore: [
            CoreTickSample(user: 1, system: 2, idle: 3, nice: 4),
        ])
        let memory = MemoryMetrics(
            usedBytes: 6,
            totalBytes: 10,
            appMemoryBytes: 3,
            wiredBytes: 2,
            compressedBytes: 1
        )
        let gpu = GPUMetrics(deviceUtilization: 0.25, rendererUtilization: 0.5)
        let pressure = MemoryPressureMetrics(state: .critical, pressurePercentage: 0.9)
        let provider = FakeSystemMetricsProvider(
            cpuTicks: cpu,
            memory: memory,
            gpu: gpu,
            pressure: pressure
        )

        XCTAssertEqual(provider.sampleCPUTicks(), cpu)
        XCTAssertEqual(provider.sampleMemory(), memory)
        XCTAssertEqual(provider.sampleGPU(), gpu)
        XCTAssertEqual(provider.sampleMemoryPressure(), pressure)
    }

    func testFakeDefaultsWithoutConfigurationReturnUnavailable() {
        let provider = FakeSystemMetricsProvider()
        XCTAssertNil(provider.sampleCPUTicks())
        XCTAssertNil(provider.sampleMemory())
        XCTAssertNil(provider.sampleGPU())
    }

    // MARK: - Network byte counters

    func testFakeReturnsConfiguredNetworkBytes() {
        let network = NetworkBytes(bytesIn: 1_234, bytesOut: 5_678)
        let provider = FakeSystemMetricsProvider(networkBytes: network)

        XCTAssertEqual(provider.sampleNetworkBytes(), network)
        XCTAssertEqual(provider.sampleNetworkBytes(), network)
        XCTAssertEqual(provider.networkSampleCount, 2)
    }

    func testFakeDefaultNetworkBytesAreUnavailable() {
        let provider = FakeSystemMetricsProvider()

        XCTAssertNil(provider.sampleNetworkBytes())
        XCTAssertEqual(provider.networkSampleCount, 1)
    }

    // MARK: - Temperature (FM-T2-4, FM-T2-5)

    func testFakeReturnsConfiguredTemperature() {
        let temperature = TemperatureMetrics(cpuCelsius: 84, gpuCelsius: 61)
        let provider = FakeSystemMetricsProvider(temperature: temperature)

        XCTAssertEqual(provider.sampleTemperature(), temperature)
        XCTAssertEqual(provider.sampleTemperature(), temperature)
        XCTAssertEqual(
            provider.temperatureSampleCount,
            2,
            "every sampleTemperature() call increments the counter (FM-T2-5)"
        )
    }

    func testFakeDefaultTemperatureIsUnreadable() {
        let provider = FakeSystemMetricsProvider()

        XCTAssertNil(
            provider.sampleTemperature(),
            "nil means unreadable: no throw and no crash (FM-T2-4)"
        )
        XCTAssertEqual(
            provider.temperatureSampleCount,
            1,
            "an unreadable call still counts (FM-T2-5)"
        )
    }

    func testLiveProviderReadsTemperatureOnThisMachine() throws {
        let provider = LiveSystemMetricsProvider()

        // Phase 0 H1 measured 24 readable CPU keys on this machine
        // (artifacts/2026-10-23-temp-menu-bar-metric/phase0-report.md),
        // so a nil here means the SMC route broke (FM-T2-4: returns
        // values when readable). The GPU subsystem stays optional: no
        // key classified GPU-side in Phase 0.
        let temperature = try XCTUnwrap(
            provider.sampleTemperature(),
            "AppleSMC must expose at least the CPU die sensors"
        )
        let cpu = try XCTUnwrap(
            temperature.cpuCelsius,
            "the CPU row must read on this machine (Phase 0 H1)"
        )
        XCTAssertTrue(cpu.isFinite)
        XCTAssertTrue((-20...130).contains(cpu), "stored values clamp to -20...130 °C")
        if let gpu = temperature.gpuCelsius {
            XCTAssertTrue(gpu.isFinite)
            XCTAssertTrue((-20...130).contains(gpu))
        }
    }

    // MARK: - Shared contract

    func testFakeProviderHonorsContract() throws {
        try assertProviderContract(
            FakeSystemMetricsProvider(
                cpuTicks: CPUTicks(perCore: [
                    CoreTickSample(user: 40, system: 20, idle: 300, nice: 0),
                ]),
                memory: MemoryMetrics(
                    usedBytes: 8,
                    totalBytes: 16,
                    appMemoryBytes: 4,
                    wiredBytes: 2,
                    compressedBytes: 2
                ),
                gpu: GPUMetrics(deviceUtilization: 0.5),
                pressure: MemoryPressureMetrics(state: .warning, pressurePercentage: 0.65)
            )
        )
    }

    func testLiveProviderHonorsContract() throws {
        try assertProviderContract(LiveSystemMetricsProvider())
    }

    // MARK: - Live reads on this machine

    func testLiveProviderReadsRealSystemValues() throws {
        let provider = LiveSystemMetricsProvider()

        // Mach reads must succeed on macOS, so these are not allowed to
        // return nil here.
        let cpu = try XCTUnwrap(
            provider.sampleCPUTicks(),
            "host_processor_info must return CPU ticks"
        )
        XCTAssertFalse(cpu.perCore.isEmpty)
        XCTAssertEqual(cpu.perCore.count, ProcessInfo.processInfo.activeProcessorCount)
        XCTAssertGreaterThan(cpu.aggregate.total, 0, "tick counters accumulate since boot")

        let memory = try XCTUnwrap(
            provider.sampleMemory(),
            "host_statistics64 must return VM statistics"
        )
        XCTAssertEqual(memory.totalBytes, ProcessInfo.processInfo.physicalMemory)
        XCTAssertGreaterThan(memory.wiredBytes, 0, "wired memory is never zero")
        XCTAssertGreaterThan(memory.appMemoryBytes, 0, "app memory is never zero")

        let pressure = provider.sampleMemoryPressure()
        XCTAssertNotEqual(
            pressure.state,
            .unknown,
            "both memorystatus sysctl reads must succeed on macOS"
        )
        XCTAssertTrue((0...1).contains(pressure.pressurePercentage))

        // GPU is allowed to be nil (VMs, unsupported hardware). When a GPU
        // reports, the value must be a fraction in 0...1.
        if let gpu = provider.sampleGPU() {
            XCTAssertTrue((0...1).contains(gpu.deviceUtilization))
            if let renderer = gpu.rendererUtilization {
                XCTAssertTrue((0...1).contains(renderer))
            }
            if let tiler = gpu.tilerUtilization {
                XCTAssertTrue((0...1).contains(tiler))
            }
        }

        // A second pass must behave the same. Repeated calls also prove
        // the per-call cleanup paths do not trap. Tick counters move, so
        // only the structure is compared.
        let cpuAgain = try XCTUnwrap(provider.sampleCPUTicks())
        XCTAssertEqual(cpuAgain.perCore.count, cpu.perCore.count)
        let memoryAgain = try XCTUnwrap(provider.sampleMemory())
        XCTAssertEqual(memoryAgain.totalBytes, memory.totalBytes)
        XCTAssertGreaterThan(memoryAgain.usedBytes, 0)
    }

    // MARK: - Contract helper

    /// Invariants that hold for every provider, configured or live.
    private func assertProviderContract(
        _ provider: any SystemMetricsProvider,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        if let cpu = provider.sampleCPUTicks() {
            XCTAssertFalse(cpu.perCore.isEmpty, "a CPU sample needs at least one core", file: file, line: line)
            XCTAssertEqual(
                cpu.aggregate,
                CPUTicks(perCore: cpu.perCore).aggregate,
                "aggregate must equal the sum of the per-core entries",
                file: file,
                line: line
            )
            XCTAssertLessThanOrEqual(
                cpu.perCore.count,
                ProcessInfo.processInfo.activeProcessorCount,
                "no more entries than active cores",
                file: file,
                line: line
            )
        }

        if let memory = provider.sampleMemory() {
            XCTAssertGreaterThan(memory.totalBytes, 0, file: file, line: line)
            XCTAssertEqual(
                memory.usedBytes,
                memory.appMemoryBytes + memory.wiredBytes + memory.compressedBytes,
                "used = app + wired + compressed",
                file: file,
                line: line
            )
            XCTAssertLessThanOrEqual(memory.usedBytes, memory.totalBytes, file: file, line: line)
        }

        if let gpu = provider.sampleGPU() {
            XCTAssertTrue((0...1).contains(gpu.deviceUtilization), file: file, line: line)
            if let renderer = gpu.rendererUtilization {
                XCTAssertTrue((0...1).contains(renderer), file: file, line: line)
            }
            if let tiler = gpu.tilerUtilization {
                XCTAssertTrue((0...1).contains(tiler), file: file, line: line)
            }
        }

        // Network: a nil read means the interface walk failed or no
        // usable interface exists. A present sample exposes both
        // counters, and a repeat read must not trap.
        if let network = provider.sampleNetworkBytes() {
            _ = network.bytesIn
            _ = network.bytesOut
        }
        _ = provider.sampleNetworkBytes()

        // Temperature: nil means both subsystems are unreadable (the
        // nil-contract, no throw and no trap). A present sample carries
        // finite values inside the -20...130 °C range, and a repeat
        // read must not trap.
        if let temperature = provider.sampleTemperature() {
            if let cpu = temperature.cpuCelsius {
                XCTAssertTrue(
                    cpu.isFinite && (-20...130).contains(cpu),
                    "cpu \(cpu) °C must be finite and inside -20...130",
                    file: file,
                    line: line
                )
            }
            if let gpu = temperature.gpuCelsius {
                XCTAssertTrue(
                    gpu.isFinite && (-20...130).contains(gpu),
                    "gpu \(gpu) °C must be finite and inside -20...130",
                    file: file,
                    line: line
                )
            }
        }
        _ = provider.sampleTemperature()

        let pressure = provider.sampleMemoryPressure()
        XCTAssertTrue(
            [MemoryPressureState.unknown, .normal, .warning, .critical]
                .contains(pressure.state),
            file: file,
            line: line
        )
        XCTAssertTrue((0...1).contains(pressure.pressurePercentage), file: file, line: line)
    }
}
