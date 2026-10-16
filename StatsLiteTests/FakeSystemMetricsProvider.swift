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

    // Sampling counters: the sampler tests assert which metrics were read.
    private(set) var cpuSampleCount = 0
    private(set) var memorySampleCount = 0
    private(set) var gpuSampleCount = 0
    private(set) var pressureSampleCount = 0
    private(set) var networkSampleCount = 0

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
}
