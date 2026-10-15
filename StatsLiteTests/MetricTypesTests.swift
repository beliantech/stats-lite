//
//  MetricTypesTests.swift
//  StatsLiteTests
//
//  Value-type contracts: pressure level naming, range clamping,
//  snapshot membership per enabled set, Sendable conformance.
//

import Foundation
import XCTest
@testable import StatsLite

final class MetricTypesTests: XCTestCase {

    // MARK: CoreTickSample

    func testCoreTickSampleTotals() {
        let sample = CoreTickSample(user: 10, system: 5, idle: 80, nice: 5)
        XCTAssertEqual(sample.total, 100)
        XCTAssertEqual(sample.busy, 20)
    }

    // MARK: MemoryPressureState

    func testPressureStateRawValuesMatchKernelLevels() {
        XCTAssertEqual(MemoryPressureState.unknown.rawValue, 0)
        XCTAssertEqual(MemoryPressureState.normal.rawValue, 1)
        XCTAssertEqual(MemoryPressureState.warning.rawValue, 2)
        XCTAssertEqual(MemoryPressureState.critical.rawValue, 4)
    }

    func testPressureStateDisplayNames() {
        XCTAssertEqual(MemoryPressureState.normal.displayName, "Normal")
        XCTAssertEqual(MemoryPressureState.warning.displayName, "Warning")
        XCTAssertEqual(MemoryPressureState.critical.displayName, "Critical")
        XCTAssertEqual(MemoryPressureState.unknown.displayName, "Unknown")
    }

    func testPressureStateMapsUnmappedKernelValuesToUnknown() {
        XCTAssertEqual(MemoryPressureState(rawLevel: 1), .normal)
        XCTAssertEqual(MemoryPressureState(rawLevel: 2), .warning)
        XCTAssertEqual(MemoryPressureState(rawLevel: 4), .critical)
        XCTAssertEqual(MemoryPressureState(rawLevel: 3), .unknown)
        XCTAssertEqual(MemoryPressureState(rawLevel: -7), .unknown)
        XCTAssertNil(MemoryPressureState(rawValue: 3))
    }

    // MARK: CPUMetrics

    func testCPUMetricsClampsToUnitRange() {
        let metrics = CPUMetrics(totalUsage: 1.5, perCore: [-0.2, 0.5, 2.0])
        XCTAssertEqual(metrics.totalUsage, 1.0)
        XCTAssertEqual(metrics.perCore, [0.0, 0.5, 1.0])
    }

    // MARK: MemoryMetrics

    func testMemoryMetricsUsedPercentageIsOccupancy() {
        let gib: UInt64 = 1_073_741_824
        let metrics = MemoryMetrics(
            usedBytes: 8 * gib,
            totalBytes: 16 * gib,
            appMemoryBytes: 4 * gib,
            wiredBytes: 2 * gib,
            compressedBytes: 2 * gib
        )
        XCTAssertEqual(metrics.usedPercentage, 0.5, accuracy: 1e-9)
    }

    func testMemoryMetricsUsedPercentageWithZeroTotalIsZero() {
        let metrics = MemoryMetrics(
            usedBytes: 100,
            totalBytes: 0,
            appMemoryBytes: 0,
            wiredBytes: 0,
            compressedBytes: 0
        )
        XCTAssertEqual(metrics.usedPercentage, 0.0)
    }

    // MARK: MemoryPressureMetrics

    func testPressureMetricsComposesStateAndFallbackPercentage() {
        let metrics = MemoryPressureMetrics(state: .warning, availabilityPercent: nil)
        XCTAssertEqual(metrics.state, .warning)
        XCTAssertEqual(metrics.pressurePercentage, 0.65, accuracy: 1e-9)
    }

    func testPressureMetricsClampsStoredPercentage() {
        let high = MemoryPressureMetrics(state: .critical, pressurePercentage: 1.4)
        XCTAssertEqual(high.pressurePercentage, 1.0)
        let low = MemoryPressureMetrics(state: .normal, pressurePercentage: -0.3)
        XCTAssertEqual(low.pressurePercentage, 0.0)
    }

    // MARK: GPUMetrics

    func testGPUMetricsClampsUtilizationAndKeepsMissingFieldsNil() {
        let metrics = GPUMetrics(
            deviceUtilization: 1.4,
            rendererUtilization: nil,
            tilerUtilization: 0.3
        )
        XCTAssertEqual(metrics.deviceUtilization, 1.0)
        XCTAssertNil(metrics.rendererUtilization)
        XCTAssertEqual(metrics.tilerUtilization, 0.3)
    }

    // MARK: SystemSnapshot

    func testSnapshotKeepsOnlyEnabledMembers() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let cpu = CPUMetrics(totalUsage: 0.25, perCore: [0.25])
        let memory = MemoryMetrics(
            usedBytes: 1, totalBytes: 2, appMemoryBytes: 1, wiredBytes: 0, compressedBytes: 0
        )
        let pressure = MemoryPressureMetrics(state: .normal, pressurePercentage: 0.15)
        let gpu = GPUMetrics(deviceUtilization: 0.5, rendererUtilization: nil, tilerUtilization: nil)

        let snapshot = SystemSnapshot(
            timestamp: timestamp,
            enabled: [.memory],
            cpu: cpu,
            memory: memory,
            memoryPressure: pressure,
            gpu: gpu
        )

        XCTAssertNil(snapshot.cpu)
        XCTAssertNil(snapshot.gpu)
        XCTAssertEqual(snapshot.memory, memory)
        XCTAssertEqual(snapshot.memoryPressure, pressure)
        XCTAssertEqual(snapshot.timestamp, timestamp)
        XCTAssertEqual(snapshot.enabled, [.memory])
    }

    func testSnapshotKeepsAllMembersWhenAllMetricsEnabled() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_001)
        let cpu = CPUMetrics(totalUsage: 0.25, perCore: [0.25])
        let memory = MemoryMetrics(
            usedBytes: 1, totalBytes: 2, appMemoryBytes: 1, wiredBytes: 0, compressedBytes: 0
        )
        let pressure = MemoryPressureMetrics(state: .normal, pressurePercentage: 0.15)
        let gpu = GPUMetrics(deviceUtilization: 0.5, rendererUtilization: 0.4, tilerUtilization: nil)

        let snapshot = SystemSnapshot(
            timestamp: timestamp,
            enabled: [.cpu, .memory, .gpu],
            cpu: cpu,
            memory: memory,
            memoryPressure: pressure,
            gpu: gpu
        )

        XCTAssertEqual(snapshot.cpu, cpu)
        XCTAssertEqual(snapshot.memory, memory)
        XCTAssertEqual(snapshot.memoryPressure, pressure)
        XCTAssertEqual(snapshot.gpu, gpu)
        XCTAssertEqual(snapshot.enabled, [.cpu, .memory, .gpu])
    }

    func testSnapshotStartsWithoutMembersWhenNoneAreSupplied() {
        let snapshot = SystemSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_002),
            enabled: .cpu
        )
        XCTAssertNil(snapshot.cpu)
        XCTAssertNil(snapshot.memory)
        XCTAssertNil(snapshot.memoryPressure)
        XCTAssertNil(snapshot.gpu)
    }

    // MARK: AC-7 snapshot equality (timestamp excluded)

    func testSnapshotEqualityIgnoresTimestamp() {
        let baseline = Self.makeFullSnapshot(timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        var later = baseline
        later.timestamp = Date(timeIntervalSince1970: 1_700_000_002)

        XCTAssertNotEqual(baseline.timestamp, later.timestamp)
        XCTAssertEqual(baseline, later)
    }

    func testSnapshotInequalityWhenEnabledChanges() {
        let baseline = Self.makeFullSnapshot(timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        var changed = baseline
        changed.enabled = [.cpu]

        XCTAssertNotEqual(changed, baseline)
    }

    func testSnapshotInequalityWhenCPUChanges() {
        let baseline = Self.makeFullSnapshot(timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        var changed = baseline
        changed.cpu = CPUMetrics(totalUsage: 0.9, perCore: [0.9])

        XCTAssertNotEqual(changed, baseline)
    }

    func testSnapshotInequalityWhenMemoryChanges() {
        let baseline = Self.makeFullSnapshot(timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        var changed = baseline
        changed.memory = MemoryMetrics(
            usedBytes: 9, totalBytes: 10, appMemoryBytes: 5, wiredBytes: 2, compressedBytes: 2
        )

        XCTAssertNotEqual(changed, baseline)
    }

    func testSnapshotInequalityWhenMemoryPressureChanges() {
        let baseline = Self.makeFullSnapshot(timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        var changed = baseline
        changed.memoryPressure = MemoryPressureMetrics(state: .critical, pressurePercentage: 0.95)

        XCTAssertNotEqual(changed, baseline)
    }

    func testSnapshotInequalityWhenGPUChanges() {
        let baseline = Self.makeFullSnapshot(timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        var changed = baseline
        changed.gpu = GPUMetrics(deviceUtilization: 0.95, rendererUtilization: 0.9, tilerUtilization: nil)

        XCTAssertNotEqual(changed, baseline)
    }

    /// Snapshot with every metric enabled and every member populated.
    private static func makeFullSnapshot(timestamp: Date) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: timestamp,
            enabled: .all,
            cpu: CPUMetrics(totalUsage: 0.25, perCore: [0.25]),
            memory: MemoryMetrics(
                usedBytes: 1, totalBytes: 2, appMemoryBytes: 1, wiredBytes: 0, compressedBytes: 0
            ),
            memoryPressure: MemoryPressureMetrics(state: .normal, pressurePercentage: 0.15),
            gpu: GPUMetrics(deviceUtilization: 0.5, rendererUtilization: 0.4, tilerUtilization: nil)
        )
    }

    // MARK: Sendable (Swift 6 strict concurrency)

    func testDomainTypesConformToSendable() {
        assertSendable(CoreTickSample.self)
        assertSendable(CPUMetrics.self)
        assertSendable(MemoryMetrics.self)
        assertSendable(MemoryPressureState.self)
        assertSendable(MemoryPressureMetrics.self)
        assertSendable(GPUMetrics.self)
        assertSendable(EnabledMetrics.self)
        assertSendable(SystemSnapshot.self)
    }

    private func assertSendable<T: Sendable>(_: T.Type) {}
}
