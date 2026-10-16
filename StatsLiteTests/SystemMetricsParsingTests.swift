//
//  SystemMetricsParsingTests.swift
//  StatsLiteTests
//
//  Pure mapping rules: raw sysctl values to pressure metrics, raw
//  PerformanceStatistics dictionaries to GPU metrics. No kernel calls,
//  so every case is a fixed input.
//

import XCTest
@testable import StatsLite

final class SystemMetricsParsingTests: XCTestCase {

    // MARK: - Memory pressure

    func testPressureUsesKernelAvailabilityWhenBothReadsSucceed() {
        let normal = SystemMetricsParsing.pressureMetrics(rawLevel: 1, availabilityLevel: 40)
        XCTAssertEqual(normal.state, .normal)
        XCTAssertEqual(normal.pressurePercentage, 0.6, accuracy: 1e-9)

        let warning = SystemMetricsParsing.pressureMetrics(rawLevel: 2, availabilityLevel: 10)
        XCTAssertEqual(warning.state, .warning)
        XCTAssertEqual(warning.pressurePercentage, 0.9, accuracy: 1e-9)

        let critical = SystemMetricsParsing.pressureMetrics(rawLevel: 4, availabilityLevel: 0)
        XCTAssertEqual(critical.state, .critical)
        XCTAssertEqual(critical.pressurePercentage, 1.0, accuracy: 1e-9)
    }

    func testPressureUnknownRawLevelMapsToUnknownState() {
        // 3 is not a kernel pressure level. The state is unknown, and the
        // percentage is 0 for an unknown state.
        let metrics = SystemMetricsParsing.pressureMetrics(rawLevel: 3, availabilityLevel: 50)
        XCTAssertEqual(metrics.state, .unknown)
        XCTAssertEqual(metrics.pressurePercentage, 0.0, accuracy: 1e-9)
    }

    func testPressureMissingLevelReadMapsToUnknownState() {
        let metrics = SystemMetricsParsing.pressureMetrics(rawLevel: nil, availabilityLevel: 50)
        XCTAssertEqual(metrics.state, .unknown)
        XCTAssertEqual(metrics.pressurePercentage, 0.0, accuracy: 1e-9)
    }

    func testPressureFallsBackToFixedValueWhenAvailabilityReadFails() {
        let normal = SystemMetricsParsing.pressureMetrics(rawLevel: 1, availabilityLevel: nil)
        XCTAssertEqual(normal.state, .normal)
        XCTAssertEqual(normal.pressurePercentage, 0.15, accuracy: 1e-9)

        let warning = SystemMetricsParsing.pressureMetrics(rawLevel: 2, availabilityLevel: nil)
        XCTAssertEqual(warning.state, .warning)
        XCTAssertEqual(warning.pressurePercentage, 0.65, accuracy: 1e-9)

        let critical = SystemMetricsParsing.pressureMetrics(rawLevel: 4, availabilityLevel: nil)
        XCTAssertEqual(critical.state, .critical)
        XCTAssertEqual(critical.pressurePercentage, 0.90, accuracy: 1e-9)
    }

    func testPressureBothReadsFail() {
        let metrics = SystemMetricsParsing.pressureMetrics(rawLevel: nil, availabilityLevel: nil)
        XCTAssertEqual(metrics.state, .unknown)
        XCTAssertEqual(metrics.pressurePercentage, 0.0, accuracy: 1e-9)
    }

    func testPressureClampsOutOfRangeAvailability() {
        // 150 % free gives negative pressure, clamped to 0.
        let tooFree = SystemMetricsParsing.pressureMetrics(rawLevel: 1, availabilityLevel: 150)
        XCTAssertEqual(tooFree.pressurePercentage, 0.0, accuracy: 1e-9)

        // -20 % free gives pressure above 1, clamped to 1.
        let tooLow = SystemMetricsParsing.pressureMetrics(rawLevel: 4, availabilityLevel: -20)
        XCTAssertEqual(tooLow.pressurePercentage, 1.0, accuracy: 1e-9)
    }

    // MARK: - GPU

    func testGPUReturnsNilWhenNoDeviceReportExists() {
        XCTAssertNil(SystemMetricsParsing.gpuMetrics(fromStatistics: []))
    }

    func testGPUReturnsNilWhenDeviceKeyMissing() {
        XCTAssertNil(
            SystemMetricsParsing.gpuMetrics(fromStatistics: [["Renderer Utilization %": 50]])
        )
        XCTAssertNil(
            SystemMetricsParsing.gpuMetrics(fromStatistics: [["Unrelated Key": 50]])
        )
        // Present but not an Int counts as missing.
        XCTAssertNil(
            SystemMetricsParsing.gpuMetrics(fromStatistics: [["Device Utilization %": "50"]])
        )
    }

    func testGPUSingleDeviceMapsPercentToFraction() throws {
        let metrics = try XCTUnwrap(
            SystemMetricsParsing.gpuMetrics(fromStatistics: [["Device Utilization %": 50]])
        )
        XCTAssertEqual(metrics.deviceUtilization, 0.5, accuracy: 1e-9)
        XCTAssertNil(metrics.rendererUtilization)
        XCTAssertNil(metrics.tilerUtilization)
    }

    func testGPUAveragesDeviceUtilizationAcrossDevices() throws {
        let twoDevices = try XCTUnwrap(SystemMetricsParsing.gpuMetrics(fromStatistics: [
            ["Device Utilization %": 0],
            ["Device Utilization %": 100],
        ]))
        XCTAssertEqual(twoDevices.deviceUtilization, 0.5, accuracy: 1e-9)

        let threeDevices = try XCTUnwrap(SystemMetricsParsing.gpuMetrics(fromStatistics: [
            ["Device Utilization %": 30],
            ["Device Utilization %": 60],
            ["Device Utilization %": 90],
        ]))
        XCTAssertEqual(threeDevices.deviceUtilization, 0.6, accuracy: 1e-9)
    }

    func testGPUClampsOutOfRangeDeviceValues() throws {
        let over = try XCTUnwrap(
            SystemMetricsParsing.gpuMetrics(fromStatistics: [["Device Utilization %": 150]])
        )
        XCTAssertEqual(over.deviceUtilization, 1.0)

        let under = try XCTUnwrap(
            SystemMetricsParsing.gpuMetrics(fromStatistics: [["Device Utilization %": -20]])
        )
        XCTAssertEqual(under.deviceUtilization, 0.0)
    }

    func testGPUAveragesOnlyOverDevicesWithDeviceKey() throws {
        // A report without the device key does not join the average.
        let metrics = try XCTUnwrap(SystemMetricsParsing.gpuMetrics(fromStatistics: [
            ["Device Utilization %": 100],
            ["Renderer Utilization %": 90],
        ]))
        XCTAssertEqual(metrics.deviceUtilization, 1.0, accuracy: 1e-9)
    }

    func testGPUReadsRendererAndTilerKeys() throws {
        let metrics = try XCTUnwrap(SystemMetricsParsing.gpuMetrics(fromStatistics: [
            [
                "Device Utilization %": 40,
                "Renderer Utilization %": 70,
                "Tiler Utilization %": 10,
            ],
        ]))
        XCTAssertEqual(metrics.deviceUtilization, 0.4, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics.rendererUtilization), 0.7, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics.tilerUtilization), 0.1, accuracy: 1e-9)
    }

    func testGPUAveragesRendererOnlyOverDevicesThatReportIt() throws {
        let metrics = try XCTUnwrap(SystemMetricsParsing.gpuMetrics(fromStatistics: [
            ["Device Utilization %": 50, "Renderer Utilization %": 100],
            ["Device Utilization %": 50],
        ]))
        XCTAssertEqual(metrics.deviceUtilization, 0.5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(metrics.rendererUtilization), 1.0, accuracy: 1e-9)
        XCTAssertNil(metrics.tilerUtilization)
    }

    // MARK: - Network interface rows (loopback exclusion, F4)

    private func netRow(
        isLoopback: Bool,
        bytesIn: Int64?,
        bytesOut: Int64?
    ) -> NetworkInterfaceRow {
        NetworkInterfaceRow(isLoopback: isLoopback, bytesIn: bytesIn, bytesOut: bytesOut)
    }

    func testNetworkBytesSumsAllNonLoopbackInterfaces() {
        // F4: Wi-Fi and VPN traffic both count. Loopback counters
        // never join the sum, even when they dominate the list.
        let rows = [
            netRow(isLoopback: true, bytesIn: 10_000_000_000, bytesOut: 10_000_000_000),
            netRow(isLoopback: false, bytesIn: 1_000, bytesOut: 500),
            netRow(isLoopback: false, bytesIn: 100, bytesOut: 200),
            netRow(isLoopback: false, bytesIn: 0, bytesOut: 0),
        ]

        let bytes = SystemMetricsParsing.networkBytes(from: rows)

        XCTAssertEqual(
            bytes,
            NetworkBytes(bytesIn: 1_100, bytesOut: 700),
            "every non-loopback counter sums, loopback stays out"
        )
    }

    func testNetworkBytesReturnsNilForEmptyInterfaceList() {
        XCTAssertNil(
            SystemMetricsParsing.networkBytes(from: []),
            "no interface rows means the read produced no sample"
        )
    }

    func testNetworkBytesReturnsNilWhenEveryInterfaceIsLoopback() {
        let rows = [netRow(isLoopback: true, bytesIn: 5_000, bytesOut: 5_000)]
        XCTAssertNil(
            SystemMetricsParsing.networkBytes(from: rows),
            "only loopback traffic means no measurable sample"
        )
    }

    func testNetworkBytesReturnsNilWhenIfDataIsAbsent() {
        XCTAssertNil(
            SystemMetricsParsing.networkBytes(from: [
                netRow(isLoopback: false, bytesIn: 1_000, bytesOut: 500),
                netRow(isLoopback: false, bytesIn: nil, bytesOut: 200),
            ]),
            "an absent if_data byte count fails the whole read"
        )
        XCTAssertNil(
            SystemMetricsParsing.networkBytes(from: [
                netRow(isLoopback: false, bytesIn: 1_000, bytesOut: 500),
                netRow(isLoopback: false, bytesIn: 100, bytesOut: nil),
            ]),
            "an absent if_data out-count fails the whole read"
        )
    }

    func testNetworkBytesReturnsNilWhenCountersAreNegative() {
        XCTAssertNil(
            SystemMetricsParsing.networkBytes(from: [
                netRow(isLoopback: false, bytesIn: -1, bytesOut: 200),
            ]),
            "a negative in-counter means a corrupt read"
        )
        XCTAssertNil(
            SystemMetricsParsing.networkBytes(from: [
                netRow(isLoopback: false, bytesIn: 1_000, bytesOut: -1),
            ]),
            "a negative out-counter means a corrupt read"
        )
    }

    func testNetworkBytesSumsWithoutSignedOverflowTrap() {
        // Int64.max + Int64.max fits in UInt64. An Int64 accumulator
        // would trap here, so the sum must run in unsigned 64-bit.
        let rows = [
            netRow(isLoopback: false, bytesIn: Int64.max, bytesOut: Int64.max),
            netRow(isLoopback: false, bytesIn: Int64.max, bytesOut: Int64.max),
        ]

        let bytes = SystemMetricsParsing.networkBytes(from: rows)

        XCTAssertEqual(
            bytes,
            NetworkBytes(
                bytesIn: 18_446_744_073_709_551_614,
                bytesOut: 18_446_744_073_709_551_614
            )
        )
    }
}
