//
//  FakeSystemMetricsProvider.swift
//  StatsLiteTests
//
//  Test double for SystemMetricsProvider. Tests set the stored values
//  before each read. Task 04 sampler tests reuse this fake.
//

import Foundation
@testable import StatsLite

final class FakeSystemMetricsProvider: SystemMetricsProvider, @unchecked Sendable {
    var cpuTicks: CPUTicks?
    var memory: MemoryMetrics?
    var gpu: GPUMetrics?
    var pressure: MemoryPressureMetrics
    var networkBytes: NetworkBytes?

    /// Process fixtures (plan 2026-10-23 T-A): the full-scan result
    /// and the PID display-name table. nil `processSamples` simulates
    /// a failed scan.
    var processSamples: [RawProcessSample]?
    var processNames: [Int32: String] = [:]

    // Sampling counters: the sampler tests assert which metrics were read.
    private(set) var cpuSampleCount = 0
    private(set) var memorySampleCount = 0
    private(set) var gpuSampleCount = 0
    private(set) var pressureSampleCount = 0
    private(set) var networkSampleCount = 0
    private(set) var processSampleCount = 0
    private(set) var processNameLookupCount = 0

    // MARK: - FT-4 gate (plan 2026-10-23 T-C)
    //
    // Holds a chosen `sampleProcesses()` call inside the provider
    // until the test releases it, so the FT-4 loading window can be
    // driven without racing the live 250 ms CPU warm-up. The
    // condition guards the gate state across the sampler actor
    // thread (blocked call) and the MainActor test.
    private let gate = NSCondition()
    private var gateTargetCall: Int?
    private var gateReleased = false
    private var gateHeld = false
    private var gatedCallCount = 0

    /// Arms the gate: the `call`-th `sampleProcesses()` call after
    /// this arm (1-based) blocks until `releaseHeldProcessSample()`.
    /// The first scan only anchors (R6), so call 2 is the first scan
    /// that can carry a CPU ranking (R5).
    func holdProcessSample(call: Int) {
        gate.lock()
        gateTargetCall = call
        gateReleased = false
        gateHeld = false
        gatedCallCount = 0
        gate.unlock()
    }

    /// True while a gated call is blocked inside `sampleProcesses()`.
    var isProcessSampleHeld: Bool {
        gate.lock()
        defer { gate.unlock() }
        return gateHeld
    }

    /// Lets the held call (if any) return its fixture.
    func releaseHeldProcessSample() {
        gate.lock()
        gateReleased = true
        gate.broadcast()
        gate.unlock()
    }

    init(
        cpuTicks: CPUTicks? = nil,
        memory: MemoryMetrics? = nil,
        gpu: GPUMetrics? = nil,
        pressure: MemoryPressureMetrics = MemoryPressureMetrics(
            state: .normal,
            pressurePercentage: 0.15
        ),
        networkBytes: NetworkBytes? = nil
    ) {
        self.cpuTicks = cpuTicks
        self.memory = memory
        self.gpu = gpu
        self.pressure = pressure
        self.networkBytes = networkBytes
    }

    func sampleCPUTicks() -> CPUTicks? {
        cpuSampleCount += 1
        return cpuTicks
    }

    func sampleMemory() -> MemoryMetrics? {
        memorySampleCount += 1
        return memory
    }

    func sampleGPU() -> GPUMetrics? {
        gpuSampleCount += 1
        return gpu
    }

    func sampleMemoryPressure() -> MemoryPressureMetrics {
        pressureSampleCount += 1
        return pressure
    }

    func sampleNetworkBytes() -> NetworkBytes? {
        networkSampleCount += 1
        return networkBytes
    }

    func sampleProcesses() -> [RawProcessSample]? {
        gate.lock()
        gatedCallCount += 1
        let shouldHold = gateTargetCall == gatedCallCount
        if shouldHold { gateHeld = true }
        gate.unlock()

        processSampleCount += 1

        if shouldHold {
            gate.lock()
            // Safety deadline: a test that fails before releasing
            // must not wedge the sampler actor for the suite run.
            let deadline = Date().addingTimeInterval(10)
            while !gateReleased, Date() < deadline {
                _ = gate.wait(until: deadline)
            }
            gateHeld = false
            gate.unlock()
        }
        return processSamples
    }

    func resolveProcessName(pid: Int32) -> String? {
        processNameLookupCount += 1
        return processNames[pid]
    }
}
