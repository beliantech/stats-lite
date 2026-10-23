//
//  MenuBarTempVerificationTests.swift
//  StatsLiteTests
//
//  T5 red phase (plan 2026-10-23-temp-menu-bar-metric, Phase 5):
//  the code-level verification net for the TEMP menu-bar metric.
//  One test per failure mode: FM-T5-1 .. FM-T5-6. The visual VAC
//  (dark + light screenshots against baseline `a458ed1`) is
//  verified in a separate task.
//
//  The net pins production that T2-T4 already merged: block order
//  and length across every metric permutation, the temperature
//  term in snapshot equality, the pinned width at the clamp-max
//  row, the row tint convention, sampler gating end to end, and
//  the snapshot-change signal. Do not weaken these tests in green.
//

import AppKit
import XCTest
@testable import StatsLite

@MainActor
final class MenuBarTempVerificationTests: XCTestCase {

    // MARK: - Helpers

    private func blocks(
        showCPU: Bool = true,
        showRAM: Bool = true,
        showGPU: Bool = true,
        showNetwork: Bool = false,
        showTemperature: Bool = false,
        cpuPercent: Double? = 0.20,
        pressurePercent: Double? = 0.50,
        pressureState: MemoryPressureState? = .normal,
        gpuPercent: Double? = 0.30,
        temperature: TemperatureMetrics? = nil,
        downloadRate: Double? = nil,
        uploadRate: Double? = nil
    ) -> [MenuBarBlock] {
        MenuBarBlockBuilder.blocks(
            showCPU: showCPU,
            showRAM: showRAM,
            showGPU: showGPU,
            showNetwork: showNetwork,
            showTemperature: showTemperature,
            cpuPercent: cpuPercent,
            pressurePercent: pressurePercent,
            pressureState: pressureState,
            gpuPercent: gpuPercent,
            temperature: temperature,
            downloadRate: downloadRate,
            uploadRate: uploadRate
        )
    }

    /// Snapshot with every metric member populated, including
    /// `temperature`. The enabled set must carry `.temperature` or
    /// the init gate nils the member before equality can see it.
    private func fullSnapshot(
        timestamp: Date,
        temperature: TemperatureMetrics? = TemperatureMetrics(
            cpuCelsius: 84,
            gpuCelsius: 61
        )
    ) -> SystemSnapshot {
        SystemSnapshot(
            timestamp: timestamp,
            enabled: [.cpu, .memory, .gpu, .temperature],
            cpu: CPUMetrics(totalUsage: 0.25, perCore: [0.25]),
            memory: MemoryMetrics(
                usedBytes: 1,
                totalBytes: 2,
                appMemoryBytes: 1,
                wiredBytes: 0,
                compressedBytes: 0
            ),
            memoryPressure: MemoryPressureMetrics(
                state: .normal,
                pressurePercentage: 0.15
            ),
            gpu: GPUMetrics(
                deviceUtilization: 0.5,
                rendererUtilization: 0.4,
                tilerUtilization: nil
            ),
            temperature: temperature
        )
    }

    /// StatsLite/ relative to this test file. #filePath bakes this
    /// file's path at compile time, so the scan reads the same
    /// sources the compiler builds (MenuBarTempBlockTests pattern).
    private var statsLiteDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("StatsLite")
    }

    private func sourceFile(named name: String) throws -> String {
        let data = try Data(contentsOf: statsLiteDirectory.appendingPathComponent(name))
        return try XCTUnwrap(
            String(data: data, encoding: .utf8),
            "\(name) is not valid UTF-8"
        )
    }

    /// Removes `//` line comments, so token scans cannot trip over
    /// prose that documents the rule.
    private func commentStripped(_ source: String) -> String {
        source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                guard let cut = line.range(of: "//") else { return String(line) }
                return String(line[line.startIndex..<cut.lowerBound])
            }
            .joined(separator: "\n")
    }

    /// Source range of one top-level declaration: from `start` to
    /// the next column-0 declaration or the end of the file
    /// (MenuBarTempBlockTests pattern).
    private func topLevelScope(
        of start: Range<String.Index>,
        in source: String
    ) -> Substring {
        let rest = source[start.upperBound...]
        var end = source.endIndex
        let markers = [
            "\nstruct ", "\nfinal ", "\nclass ", "\nextension ",
            "\nenum ", "\nprotocol ", "\nprivate ", "\ninternal ",
            "\npublic ",
        ]
        for marker in markers {
            if let range = rest.range(of: marker), range.lowerBound < end {
                end = range.lowerBound
            }
        }
        return source[start.lowerBound..<end]
    }

    /// The `valueColor` switch of one block view, with all
    /// whitespace removed, so two view implementations compare as
    /// one token string. The range ends at the column-4 closing
    /// brace of the getter, one indentation level outside the
    /// switch body.
    private func valueColorMapping(
        structNamed: String,
        in commentStrippedSource: String
    ) throws -> String {
        let structRange = try XCTUnwrap(
            commentStrippedSource.range(of: "struct \(structNamed)"),
            "view introspection failed: struct \(structNamed) not found"
        )
        let scope = topLevelScope(of: structRange, in: commentStrippedSource)
        let valueStart = try XCTUnwrap(
            scope.range(of: "private var valueColor: Color {"),
            "view introspection failed: valueColor not found in \(structNamed)"
        )
        let fromGetter = scope[valueStart.lowerBound...]
        let getterEnd = try XCTUnwrap(
            fromGetter.range(of: "\n    }"),
            "view introspection failed: end of valueColor not found in \(structNamed)"
        )
        return fromGetter[..<getterEnd.upperBound]
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    // MARK: - FM-T5-1 (32-permutation order/length guard)

    /// The centerpiece guard. The existing 8-combo test
    /// (MenuBarBlockBuilderTests
    /// .testEveryEnabledCombinationProducesCorrectCountAndOrder)
    /// toggles CPU/RAM/GPU freely, so no combo space is pinned
    /// always-on: the full 32 on/off permutations of {cpu, ram, gpu,
    /// temperature, network} apply. For every permutation:
    /// `MenuBarLayout.length` must equal the sum of the enabled
    /// block widths plus gaps plus padding, and `blocks` must build
    /// the canonical CPU → MEM → GPU → TEMP → NET subsequence. VAC-1.
    func testEveryMetricPermutationKeepsLengthIdentityAndCanonicalOrder() {
        var permutationsChecked = 0

        for mask in 0..<32 {
            let cpu = mask & 1 != 0
            let ram = mask & 2 != 0
            let gpu = mask & 4 != 0
            let temperature = mask & 8 != 0
            let network = mask & 16 != 0
            permutationsChecked += 1

            let built = blocks(
                showCPU: cpu,
                showRAM: ram,
                showGPU: gpu,
                showNetwork: network,
                showTemperature: temperature
            )

            let widthSum = built.reduce(CGFloat(0)) { $0 + $1.width }
            let gaps = CGFloat(max(built.count - 1, 0)) * MenuBarLayout.gap
            let length = MenuBarLayout.length(
                showCPU: cpu,
                showRAM: ram,
                showGPU: gpu,
                showNetwork: network,
                showTemperature: temperature
            )
            XCTAssertEqual(
                length,
                widthSum + gaps + 2 * MenuBarLayout.padding,
                accuracy: 0.0001,
                """
                FM-T5-1: length must equal sum(block widths) + gaps + \
                padding for CPU:\(cpu) RAM:\(ram) GPU:\(gpu) TEMP:\(temperature) \
                NET:\(network).
                """
            )

            var canonical: [MenuBarBlockKind] = []
            if cpu { canonical.append(.cpu) }
            if ram { canonical.append(.ram) }
            if gpu { canonical.append(.gpu) }
            if temperature { canonical.append(.temp) }
            if network { canonical.append(.network) }

            XCTAssertEqual(
                built.map(\.kind),
                canonical,
                """
                FM-T5-1 (VAC-1): CPU:\(cpu) RAM:\(ram) GPU:\(gpu) \
                TEMP:\(temperature) NET:\(network) must build the canonical \
                CPU → MEM → GPU → TEMP → NET subsequence with no reordering.
                """
            )
        }

        XCTAssertEqual(
            permutationsChecked,
            32,
            "the guard must walk all 32 on/off combinations, not a sample"
        )
    }

    // MARK: - FM-T5-2 (snapshot equality: temperature membership)

    /// The `temperature` term inside `SystemSnapshot.==`. The
    /// timestamp exclusion half already exists at MetricTypesTests
    /// .testSnapshotEqualityIgnoresTimestamp and is not duplicated
    /// here. A missing temperature term compares equal across a
    /// sensor tick, `.onChange(of: monitor.latestSnapshot)` never
    /// fires, and the menu bar freezes on temperature-only changes.
    func testSnapshotInequalityWhenTemperatureChangesAlone() {
        let baseline = fullSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_100)
        )
        XCTAssertNotNil(
            baseline.temperature,
            "the enabled set carries .temperature, so init keeps the reading"
        )

        var changed = baseline
        changed.temperature = TemperatureMetrics(cpuCelsius: 85, gpuCelsius: 61)

        XCTAssertEqual(
            changed.timestamp,
            baseline.timestamp,
            "sanity: the two snapshots differ only in temperature"
        )
        XCTAssertNotEqual(
            changed,
            baseline,
            """
            FM-T5-2: two snapshots differing only in temperature must \
            compare unequal — the == term keeps the menu bar from \
            freezing on a temperature-only tick.
            """
        )
    }

    // MARK: - FM-T5-3 (pinned width fits the clamp-max row)

    /// The T4 review flagged the measurement gap: FM-T4-4 pins
    /// "CPU 100°" (43.91 pt) but the widest row the view can render
    /// is "GPU 130°" (44.19 pt at the 9 pt row font), because init
    /// clamps readings at 130 °C. The row text below comes from the
    /// builder fed a clamp-max TemperatureMetrics, so the
    /// measurement never bypasses the clamp (T2 note: the degrees()
    /// Int conversion must not see unclamped input).
    func testTempBlockWidthFitsClampMaxGPUDegreesRow() throws {
        let block = try XCTUnwrap(
            blocks(
                showCPU: false,
                showRAM: false,
                showGPU: false,
                showTemperature: true,
                temperature: TemperatureMetrics(cpuCelsius: 999, gpuCelsius: 999)
            ).first { $0.kind == .temp },
            "FM-T5-3: no .temp block for an enabled temperature"
        )

        XCTAssertEqual(
            block.valueText,
            "CPU 130°",
            "init clamps 999 °C to the 130 °C band before the formatter"
        )
        XCTAssertEqual(
            block.secondaryValueText,
            "GPU 130°",
            "the clamp max reaches the bottom row — the true widest row"
        )
        XCTAssertEqual(
            block.width,
            MenuBarLayout.tempBlockWidth,
            "the block pins its width regardless of the reading"
        )

        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        let cpuWidth = try XCTUnwrap(block.valueText)
            .size(withAttributes: [.font: font]).width
        let gpuWidth = try XCTUnwrap(block.secondaryValueText)
            .size(withAttributes: [.font: font]).width
        let widest = max(cpuWidth, gpuWidth)

        XCTAssertGreaterThanOrEqual(
            MenuBarLayout.tempBlockWidth,
            widest,
            """
            FM-T5-3 (VAC-9): tempBlockWidth must fit the true widest row \
            "GPU 130°" at 9 pt regular monospacedDigit (\(widest) pt), so \
            a clamp-max reading never clips, wraps, or shifts neighbors.
            """
        )
    }

    // MARK: - FM-T5-4 (row tint mapping matches Network)

    /// T4 review open item, decided here.
    ///
    /// Choice: TEMP is primary-by-design, and the decision matches
    /// the Network block — no production fix is needed, this test
    /// documents the choice.
    ///
    /// Reasoning, read from production: the network builder assigns
    /// only .primary (readable rate) and .tertiary (missing rate) —
    /// rates have no heat threshold. MenuBarNetworkBlockView folds
    /// .warning/.critical to Color.primary anyway, so even an
    /// unexpected threshold tint renders menu-bar text color.
    /// MenuBarTempBlockView copies that view mapping exactly, and
    /// the temp builder follows the same two-state rule. The fold
    /// flagged in the T4 review therefore diverges from
    /// MenuBarBlockView (CPU/GPU: warning → orange, critical → red),
    /// not from Network; the divergence is intended. Temperature has
    /// no warning/critical threshold in this repo, and the design
    /// blueprint pins TEMP rows to the Network style.
    func testTempRowTintsFollowNetworkPrimaryByDesign() throws {
        // Reachable builder convention: every readable value in the
        // clamp band renders .primary, a missing row renders
        // .tertiary — the same two-state rule the network builder
        // uses. Neither block ever assigns warning or critical.
        for celsius in stride(from: -20.0, through: 130.0, by: 1.0) {
            let temp = try XCTUnwrap(
                blocks(
                    showCPU: false,
                    showRAM: false,
                    showGPU: false,
                    showTemperature: true,
                    temperature: TemperatureMetrics(
                        cpuCelsius: celsius,
                        gpuCelsius: celsius
                    )
                ).first { $0.kind == .temp },
                "FM-T5-4: no .temp block at \(celsius) °C"
            )
            XCTAssertEqual(
                temp.valueTint,
                .primary,
                "FM-T5-4: a readable CPU row renders primary at \(celsius) °C"
            )
            XCTAssertEqual(
                temp.secondaryValueTint,
                .primary,
                "FM-T5-4: a readable GPU row renders primary at \(celsius) °C"
            )
        }

        let unreadable = try XCTUnwrap(
            blocks(
                showCPU: false,
                showRAM: false,
                showGPU: false,
                showTemperature: true,
                temperature: nil
            ).first { $0.kind == .temp },
            "FM-T5-4: no .temp block for an unreadable temperature"
        )
        XCTAssertEqual(
            unreadable.valueTint,
            .tertiary,
            "FM-T5-4: an unreadable CPU row tints tertiary (nil rule)"
        )
        XCTAssertEqual(
            unreadable.secondaryValueTint,
            .tertiary,
            "FM-T5-4: an unreadable GPU row tints tertiary (nil rule)"
        )

        // The Network convention this test measures against, from
        // the same builder: readable → .primary, missing → .tertiary.
        let networkReadable = try XCTUnwrap(
            blocks(
                showCPU: false,
                showRAM: false,
                showGPU: false,
                showNetwork: true,
                downloadRate: 720 * 1024,
                uploadRate: 10 * 1024
            ).first { $0.kind == .network },
            "FM-T5-4: no .network block with rates present"
        )
        XCTAssertEqual(
            networkReadable.valueTint,
            .primary,
            "sanity: the network convention this test pins is readable → primary"
        )
        let networkMissing = try XCTUnwrap(
            blocks(
                showCPU: false,
                showRAM: false,
                showGPU: false,
                showNetwork: true,
                downloadRate: nil,
                uploadRate: nil
            ).first { $0.kind == .network },
            "FM-T5-4: no .network block with rates missing"
        )
        XCTAssertEqual(
            networkMissing.valueTint,
            .tertiary,
            "sanity: the network convention this test pins is missing → tertiary"
        )

        // View-level mapping: MenuBarTempBlockView's valueColor
        // switch must match MenuBarNetworkBlockView's token for
        // token. If Network ever learns warning/critical handling,
        // TEMP must change in the same commit — and the fold stays
        // explicit for both.
        let source = commentStripped(
            try sourceFile(named: "MenuBarStackedItemView.swift")
        )
        let networkMapping = try valueColorMapping(
            structNamed: "MenuBarNetworkBlockView",
            in: source
        )
        let tempMapping = try valueColorMapping(
            structNamed: "MenuBarTempBlockView",
            in: source
        )
        XCTAssertFalse(
            networkMapping.isEmpty,
            "sanity: the Network valueColor scope must not be empty"
        )
        XCTAssertFalse(
            tempMapping.isEmpty,
            "sanity: the TEMP valueColor scope must not be empty"
        )
        XCTAssertEqual(
            tempMapping,
            networkMapping,
            """
            FM-T5-4: MenuBarTempBlockView's value-tint mapping must match \
            the Network block's convention — a hot-but-readable row renders \
            the color Network renders for the same tint.
            """
        )
        XCTAssertTrue(
            tempMapping.contains("case.primary,.warning,.critical:Color.primary"),
            """
            FM-T5-4: an unexpected warning/critical tint must fold to \
            primary (the Network convention this test documents); got \
            \(tempMapping).
            """
        )
    }

    // MARK: - FM-T5-5 (gating end to end with the real fake)

    /// Store seam (reviewer F1) → sampler → snapshot → builder, one
    /// pass each way. TemperatureSamplerGatingTests pins the explicit
    /// set and PreferencesShowTemperatureWiringTests pins the store
    /// edge with a readable fixture; this test pins the end-to-end
    /// chain for both gate states and closes it at the block the
    /// menu bar renders: disabled → zero provider reads and a nil
    /// member; enabled but unreadable → one read, a nil member, and
    /// both rows still rendering placeholders (never hidden, never a
    /// fake 0° — VAC-4).
    func testTemperatureGatingEndToEndAcrossSamplerAndSnapshot() async throws {
        let fixture = TemperatureMetrics(cpuCelsius: 84, gpuCelsius: 61)
        let store = PreferencesStore()
        defer { store.showTemperature = true }

        // Disabled: the store drops .temperature, so the provider
        // never sees a read across the full pass.
        store.showTemperature = false
        let disabledProvider = FakeSystemMetricsProvider(temperature: fixture)
        let disabledSnapshot = await MetricSamplerActor(
            provider: disabledProvider
        ).collectSnapshot(enabled: store.enabledMetrics)
        XCTAssertEqual(
            disabledProvider.temperatureSampleCount,
            0,
            "FM-T5-5: a disabled temperature must never reach the provider"
        )
        XCTAssertNil(
            disabledSnapshot.temperature,
            "FM-T5-5: a disabled temperature leaves the snapshot member nil"
        )

        // Enabled but unreadable: the pass counts one read, the
        // nil-contract keeps the member nil, and both rows render
        // the placeholder through the snapshot → builder path.
        store.showTemperature = true
        let unreadableProvider = FakeSystemMetricsProvider()
        let snapshot = await MetricSamplerActor(
            provider: unreadableProvider
        ).collectSnapshot(enabled: store.enabledMetrics)
        XCTAssertGreaterThan(
            unreadableProvider.temperatureSampleCount,
            0,
            "FM-T5-5: an enabled temperature counts at least one read per pass"
        )
        XCTAssertNil(
            snapshot.temperature,
            "FM-T5-5: an unreadable read stays nil in the snapshot (no throw)"
        )

        let built = blocks(
            showCPU: false,
            showRAM: false,
            showGPU: false,
            showTemperature: true,
            temperature: snapshot.temperature
        )
        XCTAssertEqual(
            built.count,
            1,
            "FM-T5-5 (VAC-4): the TEMP block never disappears while enabled"
        )
        XCTAssertEqual(
            built.first?.valueText,
            "CPU --°",
            "FM-T5-5 (VAC-4): an unreadable CPU row renders the placeholder, never 0°"
        )
        XCTAssertEqual(
            built.first?.secondaryValueText,
            "GPU --°",
            "FM-T5-5 (VAC-4): an unreadable GPU row renders the placeholder, never 0°"
        )
    }

    // MARK: - FM-T5-6 (temperature-only change drives the signal)

    /// The redraw/onChange signal chain for temperature ticks:
    /// `.onChange(of: monitor.latestSnapshot)` in
    /// MenuBarStackedItemView fires only when `SystemSnapshot.==`
    /// reports a change, then invokes `onSnapshotChange`, which
    /// StatusItemController wires to `updateAccessibility()`. Pin
    /// both halves: a temperature-only tick must fire (or the menu
    /// bar freezes on temperature changes), a timestamp-only tick
    /// must not (or every pass churns the label — AC-7; foundation
    /// at MetricTypesTests .testSnapshotEqualityIgnoresTimestamp).
    ///
    /// Mechanism note: MenuBarRedrawChurnTests carries no
    /// snapshot-signal mechanism — its walks cover animation
    /// modifiers and hosting frames — so this test pins the signal
    /// at its two testable seams: the equality that gates firing
    /// and the source wiring that carries the fire. SwiftUI
    /// `.onChange` itself needs a live host and cannot fire
    /// deterministically in unit tests.
    func testTemperatureOnlyChangeDrivesSignalWhileTimestampOnlyDoesNot() throws {
        let baseline = fullSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_200)
        )

        var temperatureTick = baseline
        temperatureTick.temperature = TemperatureMetrics(
            cpuCelsius: 85,
            gpuCelsius: 61
        )
        XCTAssertNotEqual(
            temperatureTick,
            baseline,
            """
            FM-T5-6: a temperature-only change must report a snapshot \
            change, or .onChange(of: monitor.latestSnapshot) never fires \
            and the label never refreshes.
            """
        )

        var timestampTick = baseline
        timestampTick.timestamp = baseline.timestamp.addingTimeInterval(1)
        XCTAssertEqual(
            timestampTick.timestamp,
            baseline.timestamp.addingTimeInterval(1),
            "sanity: only the timestamp differs"
        )
        XCTAssertEqual(
            timestampTick,
            baseline,
            """
            FM-T5-6: a timestamp-only change must not report a snapshot \
            change — otherwise every pass fires the redraw signal (AC-7).
            """
        )

        // Wiring seam 1: the view forwards latestSnapshot changes to
        // the onSnapshotChange hook.
        let stacked = commentStripped(
            try sourceFile(named: "MenuBarStackedItemView.swift")
        )
        let viewPattern =
            #"\.onChange\(of: monitor\.latestSnapshot\) \{\s*onSnapshotChange\?\(\)\s*\}"#
        XCTAssertNotNil(
            stacked.range(of: viewPattern, options: .regularExpression),
            """
            FM-T5-6: MenuBarStackedItemView must forward \
            .onChange(of: monitor.latestSnapshot) to onSnapshotChange?().
            """
        )

        // Wiring seam 2: the controller turns the hook into the
        // accessibility redraw.
        let controller = commentStripped(
            try sourceFile(named: "StatusItemController.swift")
        )
        let controllerPattern =
            #"onSnapshotChange: \{ \[weak self\] in\s*self\?\.updateAccessibility\(\)\s*\}"#
        XCTAssertNotNil(
            controller.range(of: controllerPattern, options: .regularExpression),
            """
            FM-T5-6: StatusItemController must wire onSnapshotChange to \
            updateAccessibility(), or a temperature-only tick refreshes \
            nothing.
            """
        )
    }
}
