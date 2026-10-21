//
//  SparklineTimeAxisGuardTests.swift
//  StatsLiteTests
//
//  FM5 regression guards (already green on day one): the shared
//  SparklineTimeAxisView stays the axis of all four metric cards and
//  keeps the AGENTS.md contract: human duration label
//  (-30s/-1m/-2m/-3m/-5m, never raw -120s) ... Now, 9 pt
//  monospaced-digit tertiary text, .accessibilityHidden(true). The
//  CoreGraphics sparkline swap must not touch this axis row. The
//  checks use formatter output, source tokens through #filePath
//  (same pattern as MenuBarValueTypographyTests), and a Mirror walk
//  of the view body.
//

import SwiftUI
import XCTest
@testable import StatsLite

@MainActor
final class SparklineTimeAxisGuardTests: XCTestCase {

    // MARK: - Source helpers

    /// URL of a production source file relative to this test file.
    /// #filePath bakes this test file's path at compile time, so the
    /// check reads the same source the compiler builds.
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

    // MARK: - View tree helpers (same Mirror walk as MenuBarRedrawChurnTests)

    /// Runtime type names of every value in a view body tree.
    private func typeTreeNames(of body: Any) -> [String] {
        var names: [String] = []
        appendTypeNames(Mirror(reflecting: body), into: &names, depth: 0)
        return names
    }

    private func appendTypeNames(
        _ mirror: Mirror,
        into names: inout [String],
        depth: Int
    ) {
        guard depth < 32 else { return }
        names.append(String(describing: mirror.subjectType))
        for child in mirror.children {
            let childMirror = Mirror(reflecting: child.value)
            let childTypeName = String(reflecting: childMirror.subjectType)
            if childTypeName.hasPrefix("(") { continue }
            appendTypeNames(childMirror, into: &names, depth: depth + 1)
        }
    }

    /// Every String stored anywhere in a SwiftUI view value tree
    /// (same walk as SettingsWindowTests).
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

    // MARK: - FM5: human duration label set, never raw seconds

    func testFM5AxisLabelSetIsHumanDurationsEndingInNow() throws {
        XCTAssertEqual(
            MetricFormatters.historyDurationAxis(30), "-30s",
            "FM5: the 30 s window keeps its seconds label"
        )
        XCTAssertEqual(
            MetricFormatters.historyDurationAxis(60), "-1m",
            "FM5: the 60 s window labels as -1m"
        )
        XCTAssertEqual(
            MetricFormatters.historyDurationAxis(120), "-2m",
            "FM5: AGENTS.md forbids raw -120s on the axis"
        )
        XCTAssertEqual(
            MetricFormatters.historyDurationAxis(180), "-3m",
            "FM5: the 180 s window labels as -3m"
        )
        XCTAssertEqual(
            MetricFormatters.historyDurationAxis(300), "-5m",
            "FM5: the 300 s window labels as -5m"
        )

        // The axis view renders that label on the leading edge and
        // "Now" on the trailing edge.
        let flat = squashed(try loadSource("StatsLite/SparklineTimeAxisView.swift"))
        XCTAssertTrue(
            flat.contains("Text(MetricFormatters.historyDurationAxis(duration))"),
            "FM5: SparklineTimeAxisView must render the formatter label on the leading edge"
        )
        XCTAssertTrue(
            flat.contains("Text(\"Now\")"),
            "FM5: SparklineTimeAxisView must render \"Now\" on the trailing edge"
        )
    }

    // MARK: - FM5: 9 pt monospaced-digit tertiary, accessibility hidden

    func testFM5AxisViewKeepsNinePointMonospacedTertiaryAndA11yHidden() throws {
        let flat = squashed(try loadSource("StatsLite/SparklineTimeAxisView.swift"))

        XCTAssertTrue(
            flat.contains(".font(.system(size:9,weight:.regular).monospacedDigit())"),
            "FM5: the axis label must stay 9 pt regular monospacedDigit"
        )
        XCTAssertTrue(
            flat.contains(".foregroundStyle(Color(nsColor:.tertiaryLabelColor))"),
            "FM5: the axis label must stay tertiary"
        )
        XCTAssertTrue(
            flat.contains(".accessibilityHidden(true)"),
            "FM5: the axis row must stay .accessibilityHidden(true)"
        )

        // Runtime guard: the body keeps the HStack row, carries the
        // "Now" string, and adds no animated modifiers.
        let view = SparklineTimeAxisView(duration: 30)
        let names = typeTreeNames(of: view.body)
        XCTAssertGreaterThan(
            names.count, 8,
            "FM5: only \(names.count) nodes; the Mirror walk found nothing to check"
        )
        XCTAssertTrue(
            names.contains { $0.contains("HStack") },
            "FM5: the axis row must stay an HStack (got: \(names.joined(separator: ", ")))"
        )
        let banned = names.filter { name in
            name.localizedCaseInsensitiveContains("animation")
                || name.localizedCaseInsensitiveContains("contenttransition")
        }
        XCTAssertTrue(
            banned.isEmpty,
            "FM5: the axis row must not use .animation or .contentTransition; found \(banned.joined(separator: ", "))"
        )

        let strings = collectViewStrings(view.body)
        XCTAssertTrue(
            strings.contains("Now"),
            "FM5: the body must carry the \"Now\" string (got: \(strings.joined(separator: ", ")))"
        )

        XCTAssertEqual(
            SparklineTimeAxisView(duration: 30),
            SparklineTimeAxisView(duration: 30),
            "FM5: equal durations compare equal so .equatable() skips redraws"
        )
        XCTAssertNotEqual(
            SparklineTimeAxisView(duration: 30),
            SparklineTimeAxisView(duration: 60),
            "FM5: a changed duration must invalidate"
        )
    }

    // MARK: - FM5: all four metric cards keep the shared axis

    func testFM5AllFourMetricCardsKeepTheSharedAxis() throws {
        let cards = [
            "CPUCardView",
            "GPUCardView",
            "MemoryPressureCardView",
            "NetworkCardView",
        ]

        for card in cards {
            let source = try loadSource("StatsLite/\(card).swift")
            XCTAssertTrue(
                source.contains("SparklineTimeAxisView(duration: monitor.historyDuration)"),
                "FM5: \(card).swift must keep the shared SparklineTimeAxisView axis (AGENTS.md)"
            )
        }
    }
}
