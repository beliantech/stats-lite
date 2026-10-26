//
//  MenuBarTempBlockTests.swift
//  StatsLiteTests
//
//  T4 red phase (plan 2026-10-23-temp-menu-bar-metric, Phase 4):
//  the two-row TEMP menu-bar block. One test per failure mode:
//  FM-T4-1 .. FM-T4-9.
//
//  Contract the green implementation must match (every new argument
//  keeps a default, so the existing suites stay source-compatible):
//  - MenuBarBlockKind gains `.temp`.
//  - MenuBarBlockBuilder.blocks gains `showTemperature: Bool = false`
//    directly after `showNetwork:` and
//    `temperature: TemperatureMetrics? = nil` directly after
//    `gpuPercent:`. The temp block carries discrete subsystem
//    labels (parity with the standard metric labels): `label`
//    holds "C" and `secondaryLabel` holds "G" at 8 pt regular
//    secondary, while `valueText` holds the CPU degrees ("84°")
//    and `secondaryValueText` the GPU degrees ("61°") at 9 pt
//    regular monospacedDigit. `width` pins to
//    MenuBarLayout.tempBlockWidth.
//  - MenuBarLayout gains `tempBlockWidth` and
//    `length(... showTemperature:)` with `showTemperature:` directly
//    after `showNetwork:`.
//  - MenuBarAccessibility.compositeLabel gains the same two
//    arguments in the same positions as the builder.
//  - `struct MenuBarTempBlockView` renders the block, in
//    MenuBarStackedItemView.swift or in its own file. FM-T4-8 finds
//    it either way.
//
//  These tests fail until T4 lands. Do not weaken them in green.
//

import AppKit
import SwiftUI
import XCTest
@testable import StatsLite

@MainActor
final class MenuBarTempBlockTests: XCTestCase {

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

    /// The TEMP block the builder produces for one snapshot reading,
    /// built through the SystemSnapshot seam the stacked view uses,
    /// so the matrix below matches the production data path.
    private func tempBlock(
        cpuCelsius: Double?,
        gpuCelsius: Double?
    ) throws -> MenuBarBlock {
        let snapshot = SystemSnapshot(
            enabled: [.cpu, .memory, .gpu, .temperature],
            temperature: TemperatureMetrics(cpuCelsius: cpuCelsius, gpuCelsius: gpuCelsius)
        )
        let result = blocks(
            showCPU: false,
            showRAM: false,
            showGPU: false,
            showTemperature: true,
            temperature: snapshot.temperature
        )
        XCTAssertEqual(
            result.count,
            1,
            "FM-T4-5: a temperature-only build must produce exactly one block"
        )
        return try XCTUnwrap(
            result.first { $0.kind == .temp },
            "FM-T4-5: no .temp block — MenuBarBlockBuilder must append kind .temp when showTemperature is on"
        )
    }

    /// StatsLite/ relative to this test file. #filePath bakes this
    /// file's path at compile time, so the scan reads the same
    /// sources the compiler builds.
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

    private func swiftSourceFiles() throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: statsLiteDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Removes `//` line comments, so token scans cannot trip over
    /// prose that documents the rule (for example the "No
    /// .animation" header comments in MenuBarStackedItemView.swift).
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
    /// the next column-0 declaration or the end of the file.
    private func topLevelScope(of start: Range<String.Index>, in source: String) -> Substring {
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

    /// Every String stored anywhere in a SwiftUI view value tree,
    /// found via Mirror. Same mechanism as
    /// SettingsWindowTests.collectViewStrings.
    private func viewStrings(_ root: Any) -> [String] {
        var result: [String] = []

        func walk(_ value: Any, depth: Int) {
            guard depth < 40 else { return }
            if let string = value as? String {
                result.append(string)
            }
            for child in Mirror(reflecting: value).children {
                walk(child.value, depth: depth + 1)
            }
        }

        walk(root, depth: 0)
        return result
    }

    // MARK: - FM-T4-1 (order: TEMP between MEM and Network)

    /// With temperature enabled the block order is CPU → GPU → MEM →
    /// TEMP → NET (template: MenuBarBlockBuilderTests network order
    /// assert). VAC-1.
    func testTemperatureEnabledOrdersBlocksWithTempBetweenMEMAndNetwork() {
        let result = blocks(
            showNetwork: true,
            showTemperature: true,
            temperature: TemperatureMetrics(cpuCelsius: 84.4, gpuCelsius: 61.6),
            downloadRate: 720 * 1024,
            uploadRate: 10 * 1024
        )

        XCTAssertEqual(
            result.count,
            5,
            "FM-T4-1: CPU+GPU+MEM+TEMP+NET build five blocks"
        )
        XCTAssertEqual(
            result.map(\.kind),
            [.cpu, .gpu, .ram, .temp, .network],
            """
            FM-T4-1 (VAC-1): with temperature enabled the order must be \
            CPU → GPU → MEM → TEMP → NET.
            """
        )
    }

    // MARK: - FM-T4-2 (order reverts when temperature is disabled)

    func testTemperatureDisabledRevertsToCPUGPUMEMNetworkOrder() {
        let result = blocks(
            showNetwork: true,
            showTemperature: false,
            temperature: TemperatureMetrics(cpuCelsius: 84.4, gpuCelsius: 61.6),
            downloadRate: 720 * 1024,
            uploadRate: 10 * 1024
        )

        XCTAssertEqual(
            result.map(\.kind),
            [.cpu, .gpu, .ram, .network],
            "FM-T4-2: with temperature off the order reverts to CPU → GPU → MEM → NET"
        )
        XCTAssertFalse(
            result.contains { $0.kind == .temp },
            "FM-T4-2: no TEMP block may appear while showTemperature is off"
        )
    }

    // MARK: - FM-T4-3 (layout length: pinned width in and out)

    /// `MenuBarLayout.length` includes the pinned `tempBlockWidth`
    /// when temperature is on and excludes it when off, and the
    /// length identity `length == sum(block widths) + gaps + padding`
    /// holds. Covers temp on/off × network on/off with the three
    /// standard metrics on, plus the temperature-only permutation.
    /// The full 32-permutation space belongs to T5.
    func testLayoutLengthAddsPinnedTempWidthOnlyWhenEnabled() throws {
        let temperature = TemperatureMetrics(cpuCelsius: 84.4, gpuCelsius: 61.6)

        for networkOn in [false, true] {
            let on = MenuBarLayout.length(
                showCPU: true,
                showRAM: true,
                showGPU: true,
                showNetwork: networkOn,
                showTemperature: true
            )
            let off = MenuBarLayout.length(
                showCPU: true,
                showRAM: true,
                showGPU: true,
                showNetwork: networkOn,
                showTemperature: false
            )

            XCTAssertEqual(
                on - off,
                MenuBarLayout.tempBlockWidth + MenuBarLayout.gap,
                accuracy: 0.0001,
                """
                FM-T4-3: enabling TEMP must add exactly its pinned width \
                plus one gap (networkOn: \(networkOn)).
                """
            )

            for (temperatureOn, length) in [(true, on), (false, off)] {
                let built = blocks(
                    showNetwork: networkOn,
                    showTemperature: temperatureOn,
                    temperature: temperature
                )
                let widths = built.reduce(CGFloat(0)) { $0 + $1.width }
                let gaps = CGFloat(built.count - 1) * MenuBarLayout.gap
                XCTAssertEqual(
                    length,
                    widths + gaps + 2 * MenuBarLayout.padding,
                    accuracy: 0.0001,
                    """
                    FM-T4-3: length must equal sum(block widths) + gaps + \
                    padding (networkOn: \(networkOn), temperatureOn: \
                    \(temperatureOn)).
                    """
                )
            }
        }

        let temperatureOnly = MenuBarLayout.length(
            showCPU: false,
            showRAM: false,
            showGPU: false,
            showNetwork: false,
            showTemperature: true
        )
        XCTAssertEqual(
            temperatureOnly,
            2 * MenuBarLayout.padding + MenuBarLayout.tempBlockWidth,
            accuracy: 0.0001,
            "FM-T4-3: temperature alone totals padding plus its pinned width"
        )
    }

    // MARK: - FM-T4-4 (pinned width: VAC-9 3-digit clip guard)

    /// The pinned `tempBlockWidth` fits the worst-case composite
    /// "G" row (8 pt regular "G" label + 2 pt gap + the clamp-max
    /// "130°" at the 9 pt regular monospacedDigit value font), and
    /// the block width never varies with the value. Measurement
    /// harness: MenuBarValueTypographyTests
    /// NSString.size(withAttributes:) pattern.
    func testTempBlockWidthFitsWidestG130DegreesRowAndNeverVariesWithValue() throws {
        let labelFont = NSFont.systemFont(ofSize: 8, weight: .regular)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        let worstCase = ("G" as NSString)
                .size(withAttributes: [.font: labelFont]).width
            + 2.0
            + ("130°" as NSString)
                .size(withAttributes: [.font: valueFont]).width

        XCTAssertGreaterThanOrEqual(
            MenuBarLayout.tempBlockWidth,
            worstCase,
            """
            FM-T4-4 (VAC-9): MenuBarLayout.tempBlockWidth must fit the \
            worst-case composite "G" row ("G" at 8 pt regular + 2 pt gap \
            + "130°" at 9 pt regular monospacedDigit) = \(worstCase) pt, \
            so a clamp-max reading never clips, wraps, or shifts neighbors.
            """
        )

        let hot = try tempBlock(cpuCelsius: 100.0, gpuCelsius: 61.6)
        let missing = try tempBlock(cpuCelsius: nil, gpuCelsius: nil)

        XCTAssertEqual(
            hot.width,
            MenuBarLayout.tempBlockWidth,
            "FM-T4-4: the TEMP block pins to MenuBarLayout.tempBlockWidth"
        )
        XCTAssertEqual(
            missing.width,
            MenuBarLayout.tempBlockWidth,
            "FM-T4-4: the block width never varies with the value (a --° reading keeps the pin)"
        )
        XCTAssertEqual(
            hot.width,
            missing.width,
            "FM-T4-4: a 3-digit reading and a missing reading render at the same width"
        )
    }

    // MARK: - FM-T4-5 (two-row content matrix, VAC-2/3/4)

    /// The temp block carries discrete subsystem labels:
    /// `label` = "C" and `secondaryLabel` = "G" (8 pt regular
    /// secondary), `valueText` = CPU degrees, `secondaryValueText`
    /// = GPU degrees, whole-degree ROUNDING from
    /// MetricFormatters.degrees (61.6 → 62, never truncation). A nil
    /// subsystem renders `--°` on its own row only, never `0°`.
    func testTempRowsRenderPerSubsystemDegreesWithRowPlaceholders() throws {
        // Both sensors present (VAC-2, VAC-3).
        let both = try tempBlock(cpuCelsius: 84.4, gpuCelsius: 61.6)
        XCTAssertEqual(
            both.label,
            "C",
            "FM-T4-5: the top row carries the discrete CPU subsystem label (label parity with the standard metric labels)"
        )
        XCTAssertEqual(
            both.secondaryLabel,
            "G",
            "FM-T4-5: the bottom row carries the discrete GPU subsystem label (label parity with the standard metric labels)"
        )
        XCTAssertEqual(
            both.valueText,
            "84°",
            "FM-T4-5 (VAC-2/3): the top row renders 84° from cpu 84.4 (whole degree), no conjoined prefix"
        )
        XCTAssertEqual(
            both.secondaryValueText,
            "62°",
            "FM-T4-5 (VAC-2/3): the bottom row renders 62° from gpu 61.6 — whole-degree ROUNDING (61.6→62), not truncation [planner red amendment]"
        )
        XCTAssertEqual(both.valueTint, .primary)
        XCTAssertEqual(both.secondaryValueTint, .primary)

        // CPU only: the GPU row shows the placeholder on its row only.
        let cpuOnly = try tempBlock(cpuCelsius: 84.4, gpuCelsius: nil)
        XCTAssertEqual(
            cpuOnly.valueText,
            "84°",
            "FM-T4-5: a missing GPU sensor must not touch the CPU row"
        )
        XCTAssertEqual(
            cpuOnly.secondaryValueText,
            "--°",
            "FM-T4-5 (VAC-4): the GPU row renders \"--°\" when gpu is nil"
        )
        XCTAssertFalse(
            (cpuOnly.secondaryValueText ?? "").contains("0°"),
            "FM-T4-5 (VAC-4): never a fake 0° reading on the GPU row"
        )
        XCTAssertEqual(
            cpuOnly.secondaryValueTint,
            .tertiary,
            "FM-T4-5: the missing GPU row tints tertiary, network pattern"
        )

        // GPU only: the CPU row shows the placeholder.
        let gpuOnly = try tempBlock(cpuCelsius: nil, gpuCelsius: 61.6)
        XCTAssertEqual(
            gpuOnly.valueText,
            "--°",
            "FM-T4-5 (VAC-4): the CPU row renders \"--°\" when cpu is nil"
        )
        XCTAssertFalse(
            gpuOnly.valueText.contains("0°"),
            "FM-T4-5 (VAC-4): never a fake 0° reading on the CPU row"
        )
        XCTAssertEqual(
            gpuOnly.valueTint,
            .tertiary,
            "FM-T4-5: the missing CPU row tints tertiary, network pattern"
        )
        XCTAssertEqual(
            gpuOnly.secondaryValueText,
            "62°",
            "FM-T4-5: a missing CPU sensor must not touch the GPU row (61.6 rounds to 62) [planner red amendment]"
        )

        // Neither: the block stays, both rows read the placeholder
        // and keep their subsystem labels (VAC-4: the block never
        // disappears while enabled).
        let neither = try tempBlock(cpuCelsius: nil, gpuCelsius: nil)
        XCTAssertEqual(neither.valueText, "--°", "FM-T4-5 (VAC-4): neither sensor → top row placeholder")
        XCTAssertEqual(neither.secondaryValueText, "--°", "FM-T4-5 (VAC-4): neither sensor → bottom row placeholder")
        XCTAssertEqual(
            neither.label,
            "C",
            "FM-T4-5: an unreadable reading keeps the CPU subsystem label on the top row"
        )
        XCTAssertEqual(
            neither.secondaryLabel,
            "G",
            "FM-T4-5: an unreadable reading keeps the GPU subsystem label on the bottom row"
        )
    }

    // MARK: - FM-T4-6 (accessibility segment, VAC-10)

    /// The composite VoiceOver label carries "Temperature: CPU 84
    /// degrees, GPU 62 degrees" in the network position (after the
    /// GPU segment, before the Network segment). A missing subsystem
    /// reads "unavailable" on its own row.
    func testCompositeLabelCarriesTemperatureSegmentIncludingUnavailableRows() throws {
        let full = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: false,
            showGPU: true,
            showNetwork: true,
            showTemperature: true,
            cpuPercent: 0.14,
            pressurePercent: nil,
            pressure: .normal,
            gpuPercent: 0.28,
            temperature: TemperatureMetrics(cpuCelsius: 84.4, gpuCelsius: 61.6),
            downloadRate: 720 * 1024,
            uploadRate: 10 * 1024
        )
        XCTAssertTrue(
            full.contains("Temperature: CPU 84 degrees, GPU 62 degrees"),
            """
            FM-T4-6 (VAC-10): the composite label must contain \
            "Temperature: CPU 84 degrees, GPU 62 degrees" (61.6 rounds to 62); got \(full).
            """
        )

        let gpuSegment = try XCTUnwrap(
            full.range(of: "GPU 28 percent"),
            "FM-T4-6: GPU segment missing from \(full)"
        )
        let temperatureSegment = try XCTUnwrap(
            full.range(of: "Temperature:"),
            "FM-T4-6: Temperature segment missing from \(full)"
        )
        let networkSegment = try XCTUnwrap(
            full.range(of: "Network Upload"),
            "FM-T4-6: Network segment missing from \(full)"
        )
        XCTAssertLessThan(
            gpuSegment.upperBound,
            temperatureSegment.lowerBound,
            "FM-T4-6: the Temperature segment sits after the GPU segment"
        )
        XCTAssertLessThan(
            temperatureSegment.lowerBound,
            networkSegment.lowerBound,
            "FM-T4-6: the Temperature segment sits before the Network segment (network position)"
        )

        // Missing GPU sensor: unavailable on that row only.
        let gpuMissing = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: false,
            showGPU: true,
            showNetwork: false,
            showTemperature: true,
            cpuPercent: 0.14,
            pressurePercent: nil,
            pressure: .normal,
            gpuPercent: nil,
            temperature: TemperatureMetrics(cpuCelsius: 84.4, gpuCelsius: nil)
        )
        XCTAssertTrue(
            gpuMissing.contains("Temperature: CPU 84 degrees, GPU unavailable"),
            """
            FM-T4-6 (VAC-10): a nil GPU reading must read \
            "GPU unavailable" inside the Temperature segment; \
            got \(gpuMissing).
            """
        )

        // Missing CPU sensor: unavailable on that row only.
        let cpuMissing = MenuBarAccessibility.compositeLabel(
            showCPU: true,
            showRAM: false,
            showGPU: true,
            showNetwork: false,
            showTemperature: true,
            cpuPercent: 0.14,
            pressurePercent: nil,
            pressure: .normal,
            gpuPercent: 0.28,
            temperature: TemperatureMetrics(cpuCelsius: nil, gpuCelsius: 61.6)
        )
        XCTAssertTrue(
            cpuMissing.contains("Temperature: CPU unavailable, GPU 62 degrees"),
            """
            FM-T4-6 (VAC-10): a nil CPU reading must read \
            "CPU unavailable" inside the Temperature segment (61.6 rounds to 62); \
            got \(cpuMissing).
            """
        )
    }

    // MARK: - FM-T4-7 (Settings: Temperature toggle, VAC-8)

    /// The Visible Metrics section contains a "Temperature" toggle,
    /// positioned after the GPU toggle and before the Network
    /// toggle, bound to `$preferences.showTemperature`.
    func testSettingsViewHasTemperatureToggleBetweenGPUAndNetwork() throws {
        let view = SettingsView(
            preferences: PreferencesStore(),
            monitor: SystemMonitor(),
            launchAtLogin: LaunchAtLoginService()
        )
        let strings = viewStrings(view.body)

        // Sanity checks: the reflection must find the neighboring
        // toggles or the checks below pass vacuously.
        XCTAssertTrue(
            strings.contains("GPU Utilization"),
            "View introspection failed: no GPU toggle found."
        )
        XCTAssertTrue(
            strings.contains("Network Throughput"),
            "View introspection failed: no Network toggle found."
        )

        let gpuIndex = try XCTUnwrap(
            strings.firstIndex(of: "GPU Utilization"),
            "sanity"
        )
        let networkIndex = try XCTUnwrap(
            strings.firstIndex(of: "Network Throughput"),
            "sanity"
        )
        let temperatureIndex = try XCTUnwrap(
            strings.firstIndex(of: "Temperature"),
            """
            FM-T4-7 (VAC-8): the Visible Metrics section must contain a \
            Toggle("Temperature", ...) between the GPU and Network toggles.
            """
        )
        XCTAssertLessThan(
            gpuIndex,
            temperatureIndex,
            "FM-T4-7: the Temperature toggle sits after the GPU toggle"
        )
        XCTAssertLessThan(
            temperatureIndex,
            networkIndex,
            "FM-T4-7: the Temperature toggle sits before the Network toggle"
        )

        // Binding: pinned to preferences.showTemperature (plan
        // Phase 4 code, SettingsView Visible Metrics section).
        let settingsSource = commentStripped(try sourceFile(named: "SettingsView.swift"))
        let squashed = settingsSource
            .split(whereSeparator: { $0.isWhitespace })
            .joined()
        XCTAssertTrue(
            squashed.contains(
                "Toggle(\"Temperature\",isOn:$preferences.showTemperature)"
            ),
            """
            FM-T4-7: SettingsView must declare \
            Toggle("Temperature", isOn: $preferences.showTemperature) \
            in the Visible Metrics section.
            """
        )
    }

    // MARK: - FM-T4-8 (no .animation / .contentTransition, VAC-5)

    /// Static-source guard: the TEMP view's declaration scope, the
    /// file that contains it, and MenuBarStackedItemView.swift (the
    /// dispatch and hosting path) contain no `.animation` and no
    /// `.contentTransition`. The scan strips comments first, because
    /// the existing file headers document the rule in prose.
    func testTempViewSourceDeclaresNoAnimatedModifiers() throws {
        var tempViewScope: Substring?
        var tempViewFileName = ""

        for fileURL in try swiftSourceFiles() {
            let code = commentStripped(try sourceFile(named: fileURL.lastPathComponent))
            if let declaration = code.range(of: "struct MenuBarTempBlockView") {
                tempViewFileName = fileURL.lastPathComponent
                tempViewScope = topLevelScope(of: declaration, in: code)
                break
            }
        }

        let scope = try XCTUnwrap(
            tempViewScope,
            """
            FM-T4-8 (VAC-5): struct MenuBarTempBlockView not found in \
            StatsLite/ — the TEMP block view does not exist yet.
            """
        )
        XCTAssertFalse(
            scope.contains(".animation"),
            "FM-T4-8 (VAC-5): MenuBarTempBlockView must not use .animation (transitions stay discrete)"
        )
        XCTAssertFalse(
            scope.contains(".contentTransition"),
            "FM-T4-8 (VAC-5): MenuBarTempBlockView must not use .contentTransition (transitions stay discrete)"
        )

        // Whole containing file: the dispatch branch or any helper
        // in the same file must not add either modifier.
        let container = commentStripped(try sourceFile(named: tempViewFileName))
        XCTAssertFalse(
            container.contains(".animation"),
            "FM-T4-8 (VAC-5): \(tempViewFileName) must not use .animation anywhere"
        )
        XCTAssertFalse(
            container.contains(".contentTransition"),
            "FM-T4-8 (VAC-5): \(tempViewFileName) must not use .contentTransition anywhere"
        )

        // The hosting path in MenuBarStackedItemView.swift stays
        // clean in both layouts (TEMP in its own file or inline).
        let stacked = commentStripped(try sourceFile(named: "MenuBarStackedItemView.swift"))
        XCTAssertFalse(
            stacked.contains(".animation"),
            "FM-T4-8 (VAC-5): MenuBarStackedItemView.swift must not use .animation anywhere"
        )
        XCTAssertFalse(
            stacked.contains(".contentTransition"),
            "FM-T4-8 (VAC-5): MenuBarStackedItemView.swift must not use .contentTransition anywhere"
        )
    }

    // MARK: - FM-T4-9 (menu-bar only: no popover card, VAC-11)

    /// No temperature card exists in the popover composition. Seam:
    /// PopoverContentView gates one card per metric with `if
    /// preferences.show<metric>`, and the popover file is the only
    /// card composition. The card check is a type-name absence scan
    /// across the app target, so a temperature card hides in no
    /// file. This guard passes at red by design (no temperature card
    /// exists yet) and fails the moment one is added; the red run
    /// still fails because the build does not compile.
    func testPopoverCompositionContainsNoTemperatureCard() throws {
        let popover = commentStripped(try sourceFile(named: "PopoverContentView.swift"))

        // Sanity: the known card gates must be present or the
        // absence checks below pass vacuously.
        XCTAssertTrue(
            popover.contains("if preferences.showNetwork {"),
            "View introspection failed: no Network card gate found in PopoverContentView."
        )

        XCTAssertNil(
            popover.range(of: "emperature", options: [.caseInsensitive]),
            """
            FM-T4-9 (VAC-11): PopoverContentView must not mention \
            temperature — the TEMP block is menu-bar only, no card \
            and no tooltip.
            """
        )

        let cardPattern = #"\bstruct\s+\w*Temp\w*Card"#
        for fileURL in try swiftSourceFiles() {
            let code = commentStripped(try sourceFile(named: fileURL.lastPathComponent))
            XCTAssertNil(
                code.range(of: cardPattern, options: .regularExpression),
                """
                FM-T4-9 (VAC-11): a temperature card type exists in \
                \(fileURL.lastPathComponent) — the popover must not gain \
                a temperature card.
                """
            )
        }
    }
}
