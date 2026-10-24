//
//  AMParityTests.swift
//  StatsLiteTests
//
//  RED suite (plan 2026-10-24-activity-monitor-parity-top-processes,
//  §4 U1/U1b/U2): the Activity Monitor parity seams. U1:
//  `cpuDisplayFraction` is percent-of-one-core with no core-count
//  divisor. U1b: the formatter contracts side by side —
//  `percentTenth` keeps the 0...1 whole-machine clamp while
//  `processPercentTenth` allows ≥100% rows up to 999.9%. U2: the
//  R2 title chain (KERN_PROCARGS2 argv[0] basename first, then
//  proc_pidpath basename, then proc_name) and the argv[0] byte
//  layout (int32 argc, exec_path NUL, ALL padding NULs skipped,
//  then argv[0] NUL-terminated). Row-drop on all-fail (D1) and the
//  ≤10 lookup budget stay covered by the fake-provider tests in
//  MetricProcessSamplerTests (P11).
//

import Foundation
import XCTest
@testable import StatsLite

final class AMParityTests: XCTestCase {

    // MARK: - U1: cpuDisplayFraction, percent-of-one-core

    func testOneCoreSecondOfTicksOverOneSecondIsOneHundredPercent() {
        // 1 core-second of ticks is 1e9 ns of work at a 1 ns/tick
        // timebase. The fraction is 1.0 regardless of core count:
        // the R1 basis has no core-count divisor.
        let fraction = ProcessMetricItem.cpuDisplayFraction(
            deltaTicks: 1_000_000_000,
            elapsedSeconds: 1,
            nanosecondsPerTick: 1
        )
        XCTAssertEqual(
            fraction, 1.0, accuracy: 1e-12,
            "U1: one core-second over one second is 100% of one core"
        )
    }

    func testTimebaseScalesTicksBeforeTheDivision() {
        // A 2.5 ns/tick timebase: 400 M ticks are 1e9 ns of work.
        let fraction = ProcessMetricItem.cpuDisplayFraction(
            deltaTicks: 400_000_000,
            elapsedSeconds: 1,
            nanosecondsPerTick: 2.5
        )
        XCTAssertEqual(
            fraction, 1.0, accuracy: 1e-12,
            "U1: the explicit timebase scales ticks, no global query"
        )
    }

    func testZeroTicksIsZero() {
        let fraction = ProcessMetricItem.cpuDisplayFraction(
            deltaTicks: 0,
            elapsedSeconds: 1,
            nanosecondsPerTick: 1
        )
        XCTAssertEqual(fraction, 0.0, accuracy: 1e-12, "U1: zero ticks is 0")
    }

    func testFourCoreSecondsOverOneSecondReportsFourPointZero() {
        // R1: a busy multi-core process exceeds 1.0 — Activity
        // Monitor shows 191.8%, so 4 core-seconds must report 4.0
        // ("400.0%") instead of clamping to the old full-capacity 1.0.
        let fraction = ProcessMetricItem.cpuDisplayFraction(
            deltaTicks: 4_000_000_000,
            elapsedSeconds: 1,
            nanosecondsPerTick: 1
        )
        XCTAssertEqual(
            fraction, 4.0, accuracy: 1e-9,
            "U1: four core-seconds over one second is 4.0, no full-capacity clamp"
        )
    }

    func testFifteenCoreSecondsClampsAtNinePointNineNineNine() {
        let fraction = ProcessMetricItem.cpuDisplayFraction(
            deltaTicks: 15_000_000_000,
            elapsedSeconds: 1,
            nanosecondsPerTick: 1
        )
        XCTAssertEqual(
            fraction, 9.999, accuracy: 1e-9,
            "U1: the display fraction clamps at 9.999 → \"999.9%\" (R1)"
        )
    }

    // MARK: - U1b: formatter contracts side by side

    func testProcessPercentTenthAllowsValuesAboveOneHundredPercent() {
        XCTAssertEqual(
            MetricFormatters.processPercentTenth(1.918), "191.8%",
            "U1b: process rows show percent-of-one-core, AM style"
        )
        XCTAssertEqual(
            MetricFormatters.processPercentTenth(15.0), "999.9%",
            "U1b: the 9.999 clamp labels as 999.9%"
        )
        XCTAssertEqual(
            MetricFormatters.processPercentTenth(0.094), "9.4%",
            "U1b: values below 100% keep one decimal"
        )
        XCTAssertEqual(MetricFormatters.processPercentTenth(nil), "--%")
        XCTAssertEqual(MetricFormatters.processPercentTenth(.nan), "--%")
        XCTAssertEqual(MetricFormatters.processPercentTenth(-0.5), "0.0%")
    }

    func testPercentTenthKeepsTheWholeMachineClampBesideTheProcessFormatter() {
        // percentTenth stays the 0...1 formatter for CPU Total and
        // GPU; processPercentTenth is the only ≥100% path (R1).
        XCTAssertEqual(MetricFormatters.percentTenth(1.5), "100.0%")
        XCTAssertEqual(MetricFormatters.percentTenth(0.24), "24.0%")
        XCTAssertEqual(MetricFormatters.processPercentTenth(1.5), "150.0%")
    }

    // MARK: - U2: KERN_PROCARGS2 argv[0] byte layout

    /// One KERN_PROCARGS2 buffer: int32 argc, exec_path NUL, `padding`
    /// NUL bytes, argv[0] NUL, then a possibly truncated argv[1].
    private func procArgsBuffer(
        argc: Int32 = 1,
        execPath: String = "/Applications/StatsLite.app/Contents/MacOS/StatsLite",
        padding: Int = 3,
        argv0: String = "/usr/local/bin/node",
        argv1Prefix: String? = "extra"
    ) -> [UInt8] {
        var bytes: [UInt8] = []
        withUnsafeBytes(of: argc.littleEndian) { bytes.append(contentsOf: $0) }
        bytes.append(contentsOf: Array(execPath.utf8))
        bytes.append(0)
        bytes.append(contentsOf: Array(repeating: 0, count: padding))
        bytes.append(contentsOf: Array(argv0.utf8))
        bytes.append(0)
        if let argv1Prefix {
            // A trailing string still terminates with NUL, as every
            // KERN_PROCARGS2 string does. argv[1] may be truncated
            // in a real buffer, but the terminator is always present.
            bytes.append(contentsOf: Array(argv1Prefix.utf8.prefix(4)))
            bytes.append(0)
        }
        return bytes
    }

    func testArgvZeroParserSkipsEveryPaddingNULAndReadsArgvZero() {
        let parsed = LiveSystemMetricsProvider.argv0(fromProcArgs: procArgsBuffer())
        XCTAssertEqual(
            parsed, "/usr/local/bin/node",
            "U2: exec_path NUL, then EVERY padding NUL skipped, then argv[0]"
        )
    }

    func testArgvZeroParserHandlesABareNameAndNoPadding() {
        let parsed = LiveSystemMetricsProvider.argv0(
            fromProcArgs: procArgsBuffer(execPath: "short", padding: 0, argv0: "pi")
        )
        XCTAssertEqual(parsed, "pi", "U2: argv[0] can be a bare executable name")
    }

    func testArgvZeroParserFailsOnTruncatedOrEmptyBuffers() {
        XCTAssertNil(
            LiveSystemMetricsProvider.argv0(fromProcArgs: []),
            "U2: an empty buffer yields nil"
        )
        XCTAssertNil(
            LiveSystemMetricsProvider.argv0(fromProcArgs: [1, 0, 0]),
            "U2: a buffer shorter than the int32 argc prefix yields nil"
        )
        // A padding run that reaches the end of the buffer carries no
        // argv[0] bytes at all: nil, never an empty name. (Note: a
        // non-empty argv[0] is the only layout a real process emits;
        // an "empty argv[0] followed by argv[1]" buffer is
        // indistinguishable from padding by the plan's byte layout
        // and is not asserted.)
        XCTAssertNil(
            LiveSystemMetricsProvider.argv0(
                fromProcArgs: procArgsBuffer(argc: 1, argv0: "", argv1Prefix: nil)
            ),
            "U2: padding with no argv[0] bytes after it yields nil"
        )
    }

    func testArgvZeroParserReadsArgvZeroWhenLaterStringsAreTruncated() {
        // R2: "Read only argv[0]; later strings may be truncated."
        // The buffer cuts argv[1] mid-word; argv[0] still parses whole.
        let parsed = LiveSystemMetricsProvider.argv0(
            fromProcArgs: procArgsBuffer(argv0: "/usr/local/bin/pi", argv1Prefix: "extr")
        )
        XCTAssertEqual(
            parsed, "/usr/local/bin/pi",
            "U2: a truncated argv[1] never disturbs argv[0]"
        )
    }

    // MARK: - U2: the title chain (R2)

    func testTitleChainPrefersArgvZeroBasename() {
        let resolved = LiveSystemMetricsProvider.resolvedProcessName(
            argv0: { "/usr/local/bin/node" },
            path: { "/usr/bin/node" },
            procName: { "node" }
        )
        XCTAssertEqual(
            resolved, "node",
            "U2: the argv[0] basename wins — this machine's `pi` must not read `node` (V2)"
        )
    }

    func testTitleChainFallsBackToPathBasenameWhenArgvZeroFails() {
        // EINVAL (other-user pid) arrives as nil from argv[0]; the
        // chain continues silently to proc_pidpath.
        let resolved = LiveSystemMetricsProvider.resolvedProcessName(
            argv0: { nil },
            path: { "/usr/bin/WindowServer" },
            procName: { "SomeShortName" }
        )
        XCTAssertEqual(resolved, "WindowServer", "U2: argv[0] EINVAL continues to the path basename")
    }

    func testTitleChainFallsBackToProcNameWhenBothReadsFail() {
        let resolved = LiveSystemMetricsProvider.resolvedProcessName(
            argv0: { nil },
            path: { nil },
            procName: { "pi" }
        )
        XCTAssertEqual(resolved, "pi", "U2: proc_name is the last resort")
    }

    func testTitleChainAllFailYieldsNilSoTheRowDrops() {
        XCTAssertNil(
            LiveSystemMetricsProvider.resolvedProcessName(
                argv0: { nil },
                path: { nil },
                procName: { nil }
            ),
            "U2: all three failing yields nil — the sampler drops the row, no placeholder (D1)"
        )
        XCTAssertNil(
            LiveSystemMetricsProvider.resolvedProcessName(
                argv0: { "" },
                path: { "" },
                procName: { "" }
            ),
            "U2: empty names never publish either"
        )
    }
}
