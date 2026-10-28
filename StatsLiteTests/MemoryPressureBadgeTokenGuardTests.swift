//
//  MemoryPressureBadgeTokenGuardTests.swift
//  StatsLiteTests
//
//  RED suite (plan 2026-10-27-memory-pressure-badge-contrast, T1):
//  source-token guards for the Memory Pressure status pill badge.
//  ISC wiring: DesignTokens.swift defines `badgeTextColor`,
//  `badgeBackgroundColor`, and `badgeBorderColor`, and the badge
//  reads all three. VAC-8 pins the badge geometry: 10 pt semibold
//  text, 6 pt horizontal / 2 pt vertical padding, `Capsule()` fill,
//  0.5 pt stroke. VAC-9: no animated transitions in the badge.
//  VAC-10: the gauge fill and the sparkline tint keep reading
//  `state.levelColor`.
//
//  The guards read production source the same way
//  MetricBarTokenGuardTests does: comments are cut, whitespace runs
//  are removed, and each check matches a squashed token, so no
//  target state can hide behind formatting.
//

import XCTest
@testable import StatsLite

final class MemoryPressureBadgeTokenGuardTests: XCTestCase {

    // MARK: - Source helpers (same pattern as MetricBarTokenGuardTests)

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

    /// Extracts one computed-property scope from squashed source:
    /// the text after `start` up to `end`. Both tokens must exist,
    /// so a renamed scope fails loudly instead of silently matching
    /// the wrong region.
    private func scope(
        _ flat: String,
        after start: String,
        until end: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let startRange = try XCTUnwrap(
            flat.range(of: start),
            "scope start token missing from source: \(start)",
            file: file,
            line: line
        )
        let tail = flat[startRange.upperBound...]
        let endRange = try XCTUnwrap(
            tail.range(of: end),
            "scope end token missing from source: \(end)",
            file: file,
            line: line
        )
        return String(tail[tail.startIndex..<endRange.lowerBound])
    }

    /// The badge scope of the memory card.
    private func badgeScope(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let flat = squashed(try loadSource("StatsLite/MemoryPressureCardView.swift", file: file, line: line))
        return try scope(
            flat,
            after: "privatevarbadge:someView{",
            until: "privatevargaugeBar",
            file: file,
            line: line
        )
    }

    // MARK: - ISC wiring: the three badge tokens exist

    func testDesignTokensDefineTheBadgeTextColorBackgroundAndBorder() throws {
        let flat = squashed(try loadSource("StatsLite/DesignTokens.swift"))

        XCTAssertTrue(
            flat.contains("varbadgeTextColor:Color{"),
            "ISC: DesignTokens.swift must define `var badgeTextColor: Color` on MemoryPressureState"
        )
        XCTAssertTrue(
            flat.contains("varbadgeBackgroundColor:Color{"),
            "ISC: DesignTokens.swift must define `var badgeBackgroundColor: Color` on MemoryPressureState"
        )
        XCTAssertTrue(
            flat.contains("varbadgeBorderColor:Color{"),
            "ISC: DesignTokens.swift must define `var badgeBorderColor: Color` on MemoryPressureState"
        )
        XCTAssertTrue(
            flat.contains("varlevelColor:Color{"),
            "VAC-10: the shared levelColor token must stay in place for the dot, gauge, and sparkline"
        )
    }

    // MARK: - ISC wiring: the badge reads the three tokens

    func testBadgeReadsTheThreeBadgeTokens() throws {
        let badge = try badgeScope()

        XCTAssertTrue(
            badge.contains(".foregroundStyle(state.badgeTextColor)"),
            "ISC: the badge text must use state.badgeTextColor, not the raw level color"
        )
        XCTAssertTrue(
            badge.contains(".background(Capsule().fill(state.badgeBackgroundColor))"),
            "ISC: the badge capsule fill must use state.badgeBackgroundColor"
        )
        XCTAssertTrue(
            badge.contains(".overlay(Capsule().stroke(state.badgeBorderColor,lineWidth:0.5))"),
            "ISC: the badge capsule stroke must use state.badgeBorderColor at 0.5 pt"
        )
        XCTAssertFalse(
            badge.contains("levelColor"),
            "ISC: the badge must not read state.levelColor anymore; VAC-1..VAC-7 own the badge colors"
        )
    }

    // MARK: - VAC-8: badge geometry stays unchanged

    func testBadgeKeepsTheBlueprintGeometry() throws {
        let badge = try badgeScope()

        XCTAssertTrue(
            badge.contains(".font(.system(size:10,weight:.semibold))"),
            "VAC-8: the badge text stays 10 pt semibold"
        )
        XCTAssertTrue(
            badge.contains(".padding(.horizontal,6)"),
            "VAC-8: the badge keeps 6 pt horizontal padding"
        )
        XCTAssertTrue(
            badge.contains(".padding(.vertical,2)"),
            "VAC-8: the badge keeps 2 pt vertical padding"
        )
        XCTAssertTrue(
            badge.contains("Capsule().fill("),
            "VAC-8: the badge background stays a Capsule fill"
        )
        XCTAssertTrue(
            badge.contains("lineWidth:0.5"),
            "VAC-8: the badge stroke stays 0.5 pt"
        )
    }

    // MARK: - VAC-9: no animated transitions in the badge

    func testBadgeHasNoAnimatedTransitions() throws {
        let badge = try badgeScope()

        XCTAssertFalse(
            badge.contains(".animation"),
            "VAC-9: the badge must not use .animation"
        )
        XCTAssertFalse(
            badge.contains(".contentTransition"),
            "VAC-9: the badge must not use .contentTransition"
        )
    }

    // MARK: - VAC-10: levelColor still drives gauge, sparkline, and process tint

    func testGaugeAndSparklineKeepTheLevelColorTint() throws {
        let flat = squashed(try loadSource("StatsLite/MemoryPressureCardView.swift"))

        XCTAssertTrue(
            flat.contains("fill(state.levelColor)"),
            "VAC-10: the gauge bar fill must keep state.levelColor"
        )
        XCTAssertTrue(
            flat.contains("tintColor:state.levelColor"),
            "VAC-10: the sparkline tint must keep state.levelColor"
        )
        XCTAssertTrue(
            flat.contains("case.normal:state.levelColor"),
            "VAC-10: the normal process gauge tint must keep state.levelColor"
        )
        XCTAssertEqual(
            occurrences(of: "state.levelColor", in: flat), 3,
            "VAC-10: after the badge switch, exactly the gauge fill, the sparkline tint, and the normal process tint read state.levelColor"
        )
    }
}
