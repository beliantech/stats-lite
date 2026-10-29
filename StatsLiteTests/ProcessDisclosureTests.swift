//
//  ProcessDisclosureTests.swift
//  StatsLiteTests
//
//  RED suite (plan 2026-10-23-top-processes-breakdown, T-A / G1):
//  accordion state (FT-1, R4), the GPU-unavailable branch copy
//  (VAC-9, R7), and the section placeholder lines for the loading
//  state (VAC-13/R5) and the empty state (R2b). The rules live as
//  pure statics so the tests verify them without rendering, the same
//  pattern as NetworkSparklineViewTests.
//
//  T-D review carry-over additions: the wired @State accordion
//  (FT-1 — the cards write through the shared binding, not just the
//  pure rule), the wired card accessibility tree (FT-3 / AMD-3, via
//  source tokens and view-value string walks — the SwiftUI
//  accessibility tree does not materialize in a headless
//  NSHostingView), the T-C loading contract passed by each card, and
//  the no-duplicate-PID row rule.
//
//  Red history: the T-A originals went red against the RED stubs —
//  the toggle stub returned `current` (never expanded, never
//  collapsed), the placeholder stub returned "" (never nil, never a
//  plan string), and the GPU copy was "". The seven T-D carry-over
//  tests were authored after the seams landed, so they were green on
//  arrival and never ran red against those stubs.
//
//  Red history (plan 2026-10-29-remove-daemons-caption, T1): the
//  VAC-R8 source guard went red while the helper-gap caption code
//  still lived in StatsLite/TopProcessesView.swift and
//  StatsLite/CPUCardView.swift. The VAC-R4 three-state render test
//  was green on arrival: the caption flag defaults to false, so the
//  parameter-free init never rendered the caption.
//

import SwiftUI
import XCTest
@testable import StatsLite

@MainActor
final class ProcessDisclosureTests: XCTestCase {

    // MARK: - Source helpers (same pattern as SparklineTimeAxisGuardTests)

    /// URL of a production source file relative to this test file.
    private func sourceURL(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
            .standardizedFileURL
    }

    private func loadSource(
        _ relativePath: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let data = try Data(contentsOf: sourceURL(relativePath))
        return try XCTUnwrap(
            String(data: data, encoding: .utf8),
            "\(relativePath) is not valid UTF-8",
            file: file,
            line: line
        )
    }

    /// Normalizes source text for token comparison: cuts `//`
    /// comments line by line, then removes every whitespace run.
    /// A missing token therefore never hides behind formatting.
    private func squashed(_ source: String) -> String {
        let withoutComments = source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let comment = line.range(of: "//") else { return line }
                return line[line.startIndex..<comment.lowerBound]
            }
            .joined()
        return withoutComments
            .split(whereSeparator: { $0.isWhitespace })
            .joined()
    }

    /// Number of non-overlapping occurrences of `token` in `source`.
    private func occurrences(of token: String, in source: String) -> Int {
        var count = 0
        var searchRange = source.startIndex..<source.endIndex
        while let found = source.range(of: token, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<source.endIndex
        }
        return count
    }

    /// Every String stored anywhere in a SwiftUI view value tree
    /// (same walk as SparklineTimeAxisGuardTests).
    private func collectViewStrings(_ root: Any) -> [String] {
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

    // MARK: - FT-1 / R4: accordion toggle rule

    func testExpandingFromCollapsedSetsTheCategory() {
        let next = PopoverContentView.toggledProcessCategory(nil, to: .cpu)
        XCTAssertEqual(
            next, .cpu,
            "FT-1: tapping a collapsed disclosure expands that card"
        )
    }

    func testExpandingAnotherCardCollapsesTheOpenList() {
        let next = PopoverContentView.toggledProcessCategory(.cpu, to: .memory)
        XCTAssertEqual(
            next, .memory,
            "FT-1: expanding card B's list collapses card A's in the same step (R4)"
        )
    }

    func testRetappingTheOpenCardCollapsesToNil() {
        let next = PopoverContentView.toggledProcessCategory(.cpu, to: .cpu)
        XCTAssertNil(
            next,
            "R3: retapping the open card collapses to nil, which drives stopProcessSampling"
        )
    }

    // MARK: - VAC-13 / R5 and R2b: section placeholder lines

    func testLoadingStateShowsStaticSamplingLine() {
        XCTAssertEqual(
            TopProcessesSectionView.placeholderText(processCount: 0, isLoading: true),
            "Sampling top processes…",
            "VAC-13: the CPU first-sample window shows the static line, never a spinner"
        )
    }

    func testEmptyStateShowsNoProcessDataLine() {
        XCTAssertEqual(
            TopProcessesSectionView.placeholderText(processCount: 0, isLoading: false),
            "No process data available",
            "R2b: a scan with zero processes shows the static empty line"
        )
    }

    func testRealRowsShowNoPlaceholder() {
        XCTAssertNil(
            TopProcessesSectionView.placeholderText(processCount: 3, isLoading: false),
            "R2b: once rows exist the placeholder disappears"
        )
    }

    func testLoadingLineWinsOverRowCountWhileBootstrapHolds() {
        // FT-4: the mock provider can hold the first CPU sample; the
        // section then shows the loading line, not the empty line.
        XCTAssertEqual(
            TopProcessesSectionView.placeholderText(processCount: 0, isLoading: true),
            "Sampling top processes…",
            "FT-4: holding the first sample keeps the loading line (VAC-13), not R2b"
        )
    }

    // MARK: - FT-1 carry-over: the wired @State accordion (review note)

    func testWiredToggleThroughBindingCollapsesTheOpenCard() {
        // The disclosure action the cards invoke writes the shared
        // rule through the PopoverContentView binding, so a tap on
        // card B stores B and collapses card A in the same step —
        // real wiring, not just the pure rule above.
        var store: ProcessCategory? = .cpu
        let binding = Binding(
            get: { store },
            set: { store = $0 }
        )

        PopoverContentView.toggleProcessCategory(binding, to: .memory)
        XCTAssertEqual(
            store, .memory,
            "FT-1 wiring: tapping card B's disclosure writes .memory through the binding, collapsing card A (R4)"
        )

        PopoverContentView.toggleProcessCategory(binding, to: .memory)
        XCTAssertNil(
            store,
            "FT-1 wiring: retapping card B collapses to nil, which drives stopProcessSampling (R3)"
        )
    }

    func testPopoverThreadsTheAccordionBindingIntoEveryCardAndTheSamplingHooks() throws {
        let flat = squashed(try loadSource("StatsLite/PopoverContentView.swift"))

        let threading = "expandedProcessCategory:$expandedProcessCategory"
        XCTAssertEqual(
            occurrences(of: threading, in: flat), 2,
            "T-G: after the D2 removal only the CPU and Memory cards receive the shared @State binding"
        )
        XCTAssertTrue(
            flat.contains(".onChange(of:expandedProcessCategory)"),
            "R3: PopoverContentView must observe the accordion state"
        )
        XCTAssertTrue(
            flat.contains("monitor.startProcessSampling(category:category)"),
            "R3: expanding must call startProcessSampling with the active category"
        )
        XCTAssertTrue(
            flat.contains("monitor.stopProcessSampling()"),
            "R3: collapse-to-nil must call stopProcessSampling"
        )
        XCTAssertTrue(
            flat.contains(".animation(.easeInOut(duration:0.2),value:expandedProcessCategory)"),
            "T8: the popover root animation wires to expandedProcessCategory, never to the status item"
        )
    }

    func testCardsRouteDisclosureTapsThroughTheSharedRuleWithTheLoadingContract() throws {
        let cpu = squashed(try loadSource("StatsLite/CPUCardView.swift"))
        XCTAssertTrue(
            cpu.contains("PopoverContentView.toggleProcessCategory($expandedProcessCategory,to:.cpu)"),
            "FT-1 wiring: the CPU disclosure taps the shared rule with .cpu"
        )
        XCTAssertTrue(
            cpu.contains("expandedProcessCategory==.cpu"),
            "FT-1 wiring: the CPU list renders while the shared state says .cpu"
        )
        XCTAssertTrue(
            cpu.contains("isLoading:monitor.isSamplingProcesses&&monitor.topCPUProcesses.isEmpty"),
            "FT-4/T-C contract: the CPU loading line follows isSamplingProcesses && list empty"
        )

        let memory = squashed(try loadSource("StatsLite/MemoryPressureCardView.swift"))
        XCTAssertTrue(
            memory.contains("PopoverContentView.toggleProcessCategory($expandedProcessCategory,to:.memory)"),
            "FT-1 wiring: the Memory disclosure taps the shared rule with .memory"
        )
        XCTAssertTrue(
            memory.contains("expandedProcessCategory==.memory"),
            "FT-1 wiring: the memory list renders while the shared state says .memory"
        )
        XCTAssertTrue(
            memory.contains("isLoading:monitor.isSamplingProcesses&&monitor.topMemoryProcesses.isEmpty"),
            "T-C contract: the memory loading line follows isSamplingProcesses && list empty"
        )

        // T-G / D2 negative contract: the GPU card carries no Top
        // Processes wiring. These asserts fail against the pre-removal
        // source and pass once the R1-R3 removal lands.
        let gpu = squashed(try loadSource("StatsLite/GPUCardView.swift"))
        XCTAssertFalse(
            gpu.contains("TopProcessesDisclosureButton"),
            "T-G: the GPU card carries no Top Processes disclosure (D2 removal R2)"
        )
        XCTAssertFalse(
            gpu.contains("GPUUnavailableProcessesView"),
            "T-G: the GPU card never renders the unavailable container (D2 removal R3)"
        )
        XCTAssertFalse(
            gpu.contains("expandedProcessCategory"),
            "T-G: the GPU card carries no accordion binding (D2 removal R1)"
        )
    }

    // MARK: - FT-3 carry-over: the wired card accessibility tree (AMD-3, §4.5)

    func testCardRootsContainChildrenWhileTheHeaderIgnoresThem() throws {
        for file in ["CPUCardView.swift", "MemoryPressureCardView.swift", "GPUCardView.swift"] {
            let flat = squashed(try loadSource("StatsLite/\(file)"))
            XCTAssertTrue(
                flat.contains(".metricCardStyle().accessibilityElement(children:.contain)"),
                "\(file): the outer card must use .children .contain so the disclosure and rows stay reachable (AMD-3)"
            )
            XCTAssertFalse(
                flat.contains(".metricCardStyle().accessibilityElement(children:.ignore)"),
                "\(file): the root .ignore blackout is exactly what AMD-3 removes"
            )
            XCTAssertTrue(
                flat.contains(".accessibilityElement(children:.ignore).accessibilityLabel("),
                "\(file): the header sub-container keeps .ignore with the summary label (AMD-3)"
            )
        }
    }

    func testDisclosureAndRowLabelsFollowTheSectionAccessibilityContract() throws {
        let flat = squashed(try loadSource("StatsLite/TopProcessesView.swift"))
        XCTAssertTrue(
            flat.contains(".accessibilityLabel(disclosureLabel)"),
            "§4.5: the disclosure attaches its label to the accessibility tree"
        )
        XCTAssertTrue(
            flat.contains("\"Topprocessesfor\\(metricTitle)\""),
            "§4.5: the disclosure label reads Top processes for <metric>"
        )
        XCTAssertTrue(
            flat.contains(".accessibilityValue(isExpanded?\"Expanded\":\"Collapsed\")"),
            "§4.5: the disclosure value reports Expanded or Collapsed"
        )
        XCTAssertTrue(
            flat.contains("\"Double-clicktoexpandorcollapsethetopfiveactiveprocesses.\""),
            "§4.5: the disclosure hint text is exact"
        )
        XCTAssertTrue(
            flat.contains(".accessibilityHidden(true)"),
            "§4.5: the gauge stays hidden from VoiceOver — the value text is authoritative"
        )

        // Runtime: the button body carries the plan strings.
        let button = TopProcessesDisclosureButton(
            isExpanded: false,
            usageState: .warning,
            metricTitle: "CPU Total",
            action: {}
        )
        let buttonStrings = collectViewStrings(button.body)
        XCTAssertTrue(
            buttonStrings.contains("Top Processes"),
            "the disclosure renders the Top Processes label (got: \(buttonStrings))"
        )
        XCTAssertTrue(
            buttonStrings.contains("Top processes for CPU Total"),
            "the disclosure body carries its §4.5 accessibility label (got: \(buttonStrings))"
        )
        XCTAssertTrue(
            buttonStrings.contains("Collapsed"),
            "the collapsed state string reaches the accessibility value (got: \(buttonStrings))"
        )

        // Runtime: a row body carries the plan label. Rows sit
        // behind a ForEach content closure, which Mirror cannot
        // enter, so the walk targets the row value directly.
        let item = ProcessMetricItem(
            pid: 4821,
            name: "Xcode",
            fraction: 0.842,
            valueLabel: "84.2%"
        )
        let section = TopProcessesSectionView(
            processes: [item],
            tintColor: .blue,
            isLoading: false,
            gaugeBasis: .maxNormalized
        )
        let rowStrings = collectViewStrings(section.row(for: item))
        XCTAssertTrue(
            rowStrings.contains("Xcode, Process ID 4821, 84.2%"),
            "§4.5: a row's accessibility label reaches the row body (got: \(rowStrings))"
        )
    }

    // MARK: - U3 / R3: gauge basis (plan 2026-10-24 §3)

    func testMaxNormalizedGaugeFractionsScaleToTheRowMax() {
        let fractions = [4.0, 2.0, 0.1].map {
            TopProcessesSectionView.gaugeFraction(
                basis: .maxNormalized, rowValue: $0, maxValue: 4.0
            )
        }
        XCTAssertEqual(fractions[0]!, 1.0, accuracy: 1e-12, "U3: the top row fills edge-to-edge")
        XCTAssertEqual(fractions[1]!, 0.5, accuracy: 1e-12, "U3: half the max fills half the track")
        XCTAssertEqual(fractions[2]!, 0.025, accuracy: 1e-12, "U3: small rows scale proportionally")
    }

    func testMaxNormalizedAllZeroPassRendersTrackOnlyWithoutNaN() {
        // The sampler can publish an all-zero pass; maxValue 0 must
        // never divide 0/0. nil means track-only, no fill capsule.
        for rowValue in [0.0, 0.0, 0.0] {
            let fraction = TopProcessesSectionView.gaugeFraction(
                basis: .maxNormalized, rowValue: rowValue, maxValue: 0
            )
            XCTAssertNil(
                fraction,
                "U3: an all-zero pass renders track-only gauges, no NaN path"
            )
        }
    }

    func testMaxNormalizedNegativeOrNaNMaxNeverProducesAFill() {
        XCTAssertNil(
            TopProcessesSectionView.gaugeFraction(
                basis: .maxNormalized, rowValue: 0.5, maxValue: -1
            ),
            "U3: a non-positive max renders track-only"
        )
        XCTAssertNil(
            TopProcessesSectionView.gaugeFraction(
                basis: .maxNormalized, rowValue: 0.5, maxValue: .nan
            ),
            "U3: a NaN max renders track-only, never a NaN width"
        )
    }

    func testMaxNormalizedZeroRowBesidePositiveRowsKeepsTheTwoPointMinimum() {
        let fraction = TopProcessesSectionView.gaugeFraction(
            basis: .maxNormalized, rowValue: 0, maxValue: 4.0
        )
        XCTAssertEqual(fraction!, 0.0, accuracy: 1e-12)
        let width = Swift.max(44 * fraction!, 2)
        XCTAssertEqual(width, 2, "U3: a zero row beside positive rows keeps the 2 pt minimum fill")
        XCTAssertFalse(width.isNaN, "U3: produced widths are never NaN")
    }

    func testRamFractionGaugeKeepsTheBytesOverTotalRAMClamp() {
        // Regression: .ramFraction behaves exactly like the old
        // clamp for every value the memory rows can carry.
        let regular = TopProcessesSectionView.gaugeFraction(
            basis: .ramFraction, rowValue: 0.42, maxValue: 0
        )
        XCTAssertEqual(regular!, 0.42, accuracy: 1e-12, "U3: memory gauges stay bytes / total RAM")
        XCTAssertEqual(
            Swift.max(44 * regular!, 2), Swift.max(44 * 0.42, 2), accuracy: 1e-12,
            "U3: memory gauge widths are byte-identical to the old formula"
        )
        XCTAssertEqual(
            TopProcessesSectionView.gaugeFraction(basis: .ramFraction, rowValue: 1.5, maxValue: 0)!,
            1.0, accuracy: 1e-12, "U3: over-total footprints clamp at the full track"
        )
        XCTAssertEqual(
            TopProcessesSectionView.gaugeFraction(basis: .ramFraction, rowValue: -0.2, maxValue: 0)!,
            0.0, accuracy: 1e-12, "U3: negative values clamp at 0"
        )
    }

    // MARK: - R3 gauge basis: CPU max-normalized, Memory RAM-fraction (plan 2026-10-24 §3)

    /// The helper-gap caption is removed (plan 2026-10-29). What
    /// stays of the U4/R3 token test is the gauge-basis contract
    /// plus the Memory-card negatives. Caption absence itself is
    /// the VAC-R8 source guard below.
    func testGaugeBasisTokensPlaceCPUAndMemorySectionsCorrectly() throws {
        let cpu = squashed(try loadSource("StatsLite/CPUCardView.swift"))
        XCTAssertTrue(
            cpu.contains("gaugeBasis:.maxNormalized"),
            "U4: the CPU card passes the max-normalized gauge basis"
        )

        let memory = squashed(try loadSource("StatsLite/MemoryPressureCardView.swift"))
        XCTAssertFalse(
            memory.contains("Systemdaemons"),
            "U4: the Memory section carries no caption"
        )
        XCTAssertFalse(
            memory.contains("showsHelperGapCaption:true"),
            "U4: the Memory card never enables the caption"
        )
        XCTAssertTrue(
            memory.contains("gaugeBasis:.ramFraction"),
            "U4: the Memory card passes the RAM-fraction gauge basis"
        )
    }

    // MARK: - VAC-R8 / VAC-R4 (plan 2026-10-29): the helper-gap caption is removed

    /// VAC-R8 source guard: no `System daemons not included` string,
    /// no `helperGapCaption` identifier, and no
    /// `showsHelperGapCaption` identifier in any Swift source under
    /// `StatsLite/`. Fails while the caption code still exists —
    /// that failure is the expected red of plan 2026-10-29 T1.
    func testSourceGuardFindsNoHelperGapCaptionArtifactsInStatsLiteSources() throws {
        let root = sourceURL("StatsLite")
        let swiftFiles = try XCTUnwrap(
            FileManager.default
                .enumerator(at: root, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" },
            "VAC-R8: enumerate Swift sources under StatsLite/"
        )
        XCTAssertFalse(
            swiftFiles.isEmpty,
            "VAC-R8: the StatsLite/ tree contains Swift sources"
        )

        let forbidden = [
            "System daemons not included",
            "helperGapCaption",
            "showsHelperGapCaption",
        ]
        var violations: [String] = []
        for file in swiftFiles {
            let source = try String(contentsOf: file, encoding: .utf8)
            for token in forbidden where source.contains(token) {
                violations.append("\(file.lastPathComponent): \(token)")
            }
        }
        XCTAssertTrue(
            violations.isEmpty,
            "VAC-R8: remove every helper-gap caption artifact from StatsLite/:\n"
                + violations.sorted().joined(separator: "\n")
        )
    }

    /// VAC-R4 render test: the expanded section renders no caption
    /// in the populated, loading, and empty states, and the
    /// loading / empty placeholder lines still render. Uses the
    /// parameter-free initializer — the caption flag disappears in
    /// the same change that removes the caption, so this test must
    /// never mention it.
    func testExpandedSectionRendersNoCaptionInAnyState() {
        let caption = "System daemons not included"

        let populated = TopProcessesSectionView(
            processes: [
                ProcessMetricItem(pid: 1918, name: "fixture-burn", fraction: 1.918, valueLabel: "191.8%")
            ],
            tintColor: .blue,
            isLoading: false,
            gaugeBasis: .maxNormalized
        )
        let populatedStrings = collectViewStrings(populated.body)
        XCTAssertTrue(
            populatedStrings.contains("fixture-burn"),
            "VAC-R4: the populated state still renders the process rows"
        )
        XCTAssertFalse(
            populatedStrings.contains(caption),
            "VAC-R4: the populated state renders no caption"
        )

        let loading = TopProcessesSectionView(
            processes: [],
            tintColor: .blue,
            isLoading: true,
            gaugeBasis: .maxNormalized
        )
        let loadingStrings = collectViewStrings(loading.body)
        XCTAssertTrue(
            loadingStrings.contains("Sampling top processes…"),
            "VAC-R4: the loading placeholder line still renders"
        )
        XCTAssertFalse(
            loadingStrings.contains(caption),
            "VAC-R4: the loading state renders no caption"
        )

        let empty = TopProcessesSectionView(
            processes: [],
            tintColor: .blue,
            isLoading: false,
            gaugeBasis: .maxNormalized
        )
        let emptyStrings = collectViewStrings(empty.body)
        XCTAssertTrue(
            emptyStrings.contains("No process data available"),
            "VAC-R4: the empty placeholder line still renders"
        )
        XCTAssertFalse(
            emptyStrings.contains(caption),
            "VAC-R4: the empty state renders no caption"
        )
    }

    // MARK: - §4.3 row helpers: PID suffix on every row (D1, Appendix D item 3)

    func testPIDSuffixRendersOnEveryRow() {
        let named = ProcessMetricItem(
            pid: 4821,
            name: "Xcode",
            fraction: 0.5,
            valueLabel: "84.2%"
        )
        XCTAssertEqual(
            TopProcessesSectionView.pidText(for: named),
            "(4821)",
            "a resolved name keeps the parenthesized PID"
        )

        // pidText has no fallback-dedupe branch anymore: even a name
        // that looks like the removed `Process NNNNN` string still
        // renders the suffix, so every row reads `name (pid)`.
        let anyName = ProcessMetricItem(
            pid: 4821,
            name: "Process 4821",
            fraction: 0.5,
            valueLabel: "84.2%"
        )
        XCTAssertEqual(
            TopProcessesSectionView.pidText(for: anyName),
            "(4821)",
            "the PID suffix renders on every row (Appendix D item 3)"
        )
    }

    func testRowAccessibilityLabelFormatMatchesThePlan() {
        let item = ProcessMetricItem(
            pid: 4821,
            name: "Xcode",
            fraction: 0.842,
            valueLabel: "84.2%"
        )
        XCTAssertEqual(
            TopProcessesSectionView.rowLabel(for: item),
            "Xcode, Process ID 4821, 84.2%",
            "§4.5: rows read name, Process ID, value"
        )
    }
}
