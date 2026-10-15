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

    init(
        cpuTicks: CPUTicks? = nil,
        memory: MemoryMetrics? = nil,
        gpu: GPUMetrics? = nil,
        pressure: MemoryPressureMetrics = MemoryPressureMetrics(
            state: .normal,
            pressurePercentage: 0.15
        )
    ) {
        self.cpuTicks = cpuTicks
        self.memory = memory
        self.gpu = gpu
        self.pressure = pressure
    }

    func sampleCPUTicks() -> CPUTicks? { cpuTicks }
    func sampleMemory() -> MemoryMetrics? { memory }
    func sampleGPU() -> GPUMetrics? { gpu }
    func sampleMemoryPressure() -> MemoryPressureMetrics { pressure }
}
