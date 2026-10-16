//
//  MenuBarValueTypographyTests.swift
//  StatsLiteTests
//
//  Plan 2026-10-16-menu-bar-label-network-regular, Phase 2 (red):
//  pin the menu bar block typography tokens to the blueprint
//  targets. The red run fails on both production tokens: the label
//  font at MenuBarStackedItemView.swift:112 carries .bold and the
//  network rate fonts at :153 and :167 carry .medium. Mechanism: a
//  source-token check anchored on the view source through
//  #filePath. The check compares the literal font token in the
//  source file that the compiler builds against the expected
//  literal, so it cannot pass while those lines carry .bold or
//  .medium. The value, monospaced-digit, and clearance tests (IC-1,
//  IC-2, IC-3, IC-11, IC-12) are regression guards and pass at
//  HEAD.
//

import AppKit
import XCTest
@testable import StatsLite

final class MenuBarValueTypographyTests: XCTestCase {

    // MARK: - Expected source tokens (normalized: whitespace removed)

    /// `.font(.system(size: 10.5, weight: .regular).monospacedDigit())`
    private let expectedValueFont = ".font(.system(size:10.5,weight:.regular).monospacedDigit())"
    /// `.font(.system(size: 8, weight: .regular))`
    private let expectedLabelFont = ".font(.system(size:8,weight:.regular))"
    /// `.foregroundStyle(.secondary)`
    private let expectedLabelStyle = ".foregroundStyle(.secondary)"
    /// `.font(.system(size: 9, weight: .regular).monospacedDigit())`
    private let expectedNetworkFont = ".font(.system(size:9,weight:.regular).monospacedDigit())"

    // MARK: - Source loading helpers

    /// URL of MenuBarStackedItemView.swift relative to this test
    /// file. #filePath bakes this test file's path at compile time,
    /// so the check reads the same source the compiler builds.
    private var stackedItemViewURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("StatsLite/MenuBarStackedItemView.swift")
            .standardizedFileURL
    }

    private func loadSource(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let data = try Data(contentsOf: stackedItemViewURL)
        return try XCTUnwrap(
            String(data: data, encoding: .utf8),
            "MenuBarStackedItemView.swift is not valid UTF-8",
            file: file,
            line: line
        )
    }

    /// Source range of one top-level struct: from its declaration
    /// to the next top-level struct or the end of the file. Fails
    /// the test when the declaration is missing, so an extraction
    /// miss can never pass vacuously.
    private func declarationScope(
        of typeName: String,
        in source: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Substring {
        let start = try XCTUnwrap(
            source.range(of: "struct \(typeName)"),
            "\(typeName) declaration not found in MenuBarStackedItemView.swift",
            file: file,
            line: line
        )
        let rest = source[start.upperBound...]
        let end = rest.range(of: "\nstruct ")?.lowerBound ?? source.endIndex
        return source[start.lowerBound..<end]
    }

    /// Full source line that contains `needle` in `text`, searched
    /// after `text.startIndex`.
    private func sourceLine(
        containing needle: String,
        in text: Substring
    ) -> Substring? {
        guard let needleRange = text.range(of: needle) else { return nil }
        let before = text[text.startIndex..<needleRange.lowerBound]
        let lineStart = before
            .lastIndex(of: "\n")
            .map { text.index(after: $0) } ?? text.startIndex
        let after = text[needleRange.upperBound...]
        let lineEnd = after.firstIndex(of: "\n") ?? text.endIndex
        return text[lineStart..<lineEnd]
    }

    /// Normalizes one source fragment for token comparison: cuts a
    /// trailing `//` comment, then removes every whitespace run.
    private func squashed(_ fragment: some StringProtocol) -> String {
        var text = Substring(fragment)
        if let comment = text.range(of: "//") {
            text = text[text.startIndex..<comment.lowerBound]
        }
        return text
            .split(whereSeparator: { $0.isWhitespace })
            .joined()
    }

    /// The `.font(...)` token on the first `.font(` line after
    /// `anchor`, normalized. Fails the test when the anchor or the
    /// font line is missing.
    private func fontToken(
        after anchor: String,
        in scope: Substring,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let anchorRange = try XCTUnwrap(
            scope.range(of: anchor),
            "anchor \(anchor) not found in scope",
            file: file,
            line: line
        )
        let afterAnchor = scope[anchorRange.upperBound...]
        let fontLine = try XCTUnwrap(
            sourceLine(containing: ".font(", in: afterAnchor),
            "no .font( line after anchor \(anchor)",
            file: file,
            line: line
        )
        guard let tokenStart = fontLine.range(of: ".font("),
              let closeParen = fontLine.lastIndex(of: ")"),
              closeParen >= tokenStart.lowerBound else {
            XCTFail(
                "line after anchor \(anchor) has no complete .font( token: \(fontLine)",
                file: file,
                line: line
            )
            return ""
        }
        return squashed(fontLine[tokenStart.lowerBound...closeParen])
    }

    // MARK: - FM1: value font is 10.5 pt regular monospacedDigit

    func testValueFontIsTenAndAHalfPointRegularMonospacedDigit() throws {
        let source = try loadSource()
        let scope = try declarationScope(of: "MenuBarBlockView", in: source)
        let token = try fontToken(
            after: "Text(block.valueText)",
            in: scope
        )
        XCTAssertEqual(
            token,
            expectedValueFont,
            """
            FM1: the MenuBarBlockView value font at \
            MenuBarStackedItemView.swift:115-116 must be \
            Font.system(size: 10.5, weight: .regular).monospacedDigit(). \
            Found \(token).
            """
        )
    }

    // MARK: - IC-2: monospaced digits on the value font

    func testValueFontKeepsMonospacedDigit() throws {
        let source = try loadSource()
        let scope = try declarationScope(of: "MenuBarBlockView", in: source)
        let token = try fontToken(
            after: "Text(block.valueText)",
            in: scope
        )
        XCTAssertTrue(
            token.contains(".monospacedDigit()"),
            """
            IC-2: the value font must keep .monospacedDigit() so digits \
            never shift the pinned block; found \(token).
            """
        )
    }

    // MARK: - IC-4: label flips to 8 pt regular secondary

    func testLabelFontIsEightPointRegularSecondary() throws {
        let source = try loadSource()
        let scope = try declarationScope(of: "MenuBarBlockView", in: source)
        let labelStart = try XCTUnwrap(
            scope.range(of: "Text(block.label)"),
            "label anchor not found in MenuBarBlockView"
        )
        let valueStart = try XCTUnwrap(
            scope.range(of: "Text(block.valueText)"),
            "value anchor not found in MenuBarBlockView"
        )
        XCTAssertTrue(
            labelStart.upperBound < valueStart.lowerBound,
            "the label line must precede the value line"
        )
        let region = squashed(scope[labelStart.upperBound..<valueStart.lowerBound])
        XCTAssertTrue(
            region.contains(expectedLabelFont),
            """
            IC-4: the category labels (CPU, MEM, GPU) must be 8 pt \
            .regular with .foregroundStyle(.secondary) and no .bold \
            weight; found label region \(region).
            """
        )
        XCTAssertTrue(
            region.contains(expectedLabelStyle),
            """
            IC-4: the category label must be \
            .foregroundStyle(.secondary); found label region \(region).
            """
        )
    }

    // MARK: - IC-10: network flips to 9 pt regular, value size stays 10.5

    func testNetworkFontsAreNinePointRegularAndValueStaysSizeTenAndAHalf() throws {
        let source = try loadSource()

        let blockScope = try declarationScope(of: "MenuBarBlockView", in: source)
        let blockValueToken = try fontToken(
            after: "Text(block.valueText)",
            in: blockScope
        )
        XCTAssertTrue(
            blockValueToken.contains("size:10.5"),
            """
            IC-10: the MenuBarBlockView value line must keep size 10.5; \
            found \(blockValueToken).
            """
        )

        let networkScope = try declarationScope(
            of: "MenuBarNetworkBlockView",
            in: source
        )
        let uploadToken = try fontToken(
            after: "Text(block.valueText)",
            in: networkScope
        )
        let downloadToken = try fontToken(
            after: "Text(block.secondaryValueText",
            in: networkScope
        )
        // One compound assertion records one failure for the guard while
        // still covering both lines: it fails unless :153 AND :167 both
        // carry the flipped token, and the message quotes both found
        // tokens, so the red output shows both production lines.
        XCTAssertEqual(
            [uploadToken, downloadToken],
            [expectedNetworkFont, expectedNetworkFont],
            """
            IC-10: the upload rate line at MenuBarStackedItemView.swift:153 \
            and the download rate line at MenuBarStackedItemView.swift:167 \
            must each be \
            .font(.system(size: 9, weight: .regular).monospacedDigit()), \
            no .medium; found upload \(uploadToken), \
            download \(downloadToken).
            """
        )
    }

    // MARK: - IC-3: clearance for "100%" at 10.5 pt regular

    func testClearanceForWidestValueAtRegularMeetsThreeAndAHalfPoints() {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        let width = ("100%" as NSString)
            .size(withAttributes: [.font: font])
            .width
        let clearance = MenuBarLayout.blockWidth - width

        XCTAssertEqual(
            MenuBarLayout.blockWidth,
            34.0,
            accuracy: 0.0001,
            "IC-3: the block width must stay 34.0 pt"
        )
        XCTAssertGreaterThanOrEqual(
            clearance,
            3.5,
            """
            IC-3: total clearance for "100%" at 10.5 pt regular \
            monospacedDigit must be at least 3.5 pt; got \(clearance) pt.
            """
        )
        XCTAssertEqual(
            width,
            29.93,
            accuracy: 0.05,
            "expected 29.93 pt text width at the target font"
        )
        XCTAssertEqual(
            clearance,
            4.07,
            accuracy: 0.05,
            "expected 4.07 pt total clearance at the target font"
        )
    }

    // MARK: - IC-11: label-row clearance at 8 pt regular

    func testLabelRowClearanceForMemRowMeetsThreeAndAHalfPoints() {
        let font = NSFont.systemFont(ofSize: 8, weight: .regular)
        func width(of text: String) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: font]).width
        }

        XCTAssertEqual(
            MenuBarLayout.blockWidth,
            34.0,
            accuracy: 0.0001,
            "IC-11: the block width must stay 34.0 pt"
        )

        let memClearance = MenuBarLayout.blockWidth - (4.0 + 2.0 + width(of: "MEM"))
        XCTAssertGreaterThanOrEqual(
            memClearance,
            3.5,
            """
            IC-11: total clearance for the MEM label row (4.0 pt dot + \
            2.0 pt gap + "MEM" at 8 pt regular) must be at least 3.5 pt; \
            got \(memClearance) pt.
            """
        )
        XCTAssertEqual(
            memClearance,
            8.6406,
            accuracy: 0.05,
            "expected 8.6406 pt total clearance for the MEM label row"
        )

        let cpuClearance = MenuBarLayout.blockWidth - width(of: "CPU")
        XCTAssertGreaterThanOrEqual(
            cpuClearance,
            16.0,
            """
            IC-11: total clearance for the CPU label must be at least \
            16.0 pt; got \(cpuClearance) pt.
            """
        )
        XCTAssertEqual(
            cpuClearance,
            16.6836,
            accuracy: 0.05,
            "expected 16.6836 pt total clearance for the CPU label"
        )

        let gpuClearance = MenuBarLayout.blockWidth - width(of: "GPU")
        XCTAssertGreaterThanOrEqual(
            gpuClearance,
            16.0,
            """
            IC-11: total clearance for the GPU label must be at least \
            16.0 pt; got \(gpuClearance) pt.
            """
        )
        XCTAssertEqual(
            gpuClearance,
            16.4375,
            accuracy: 0.05,
            "expected 16.4375 pt total clearance for the GPU label"
        )
    }

    // MARK: - IC-12: network-block clearance at 9 pt regular mono

    func testNetworkBlockClearanceForWidestRateStringMeetsSpacerMinimum() {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        let width = ("999 MB/s" as NSString)
            .size(withAttributes: [.font: font])
            .width

        XCTAssertEqual(
            MenuBarLayout.networkBlockWidth,
            50.0,
            accuracy: 0.0001,
            "IC-12: the network block width must stay 50.0 pt"
        )
        XCTAssertEqual(
            width,
            42.1084,
            accuracy: 0.05,
            "expected 42.1084 pt text width at the target font"
        )

        let clearance = MenuBarLayout.networkBlockWidth - 6.0 - width
        XCTAssertGreaterThanOrEqual(
            clearance,
            1.8,
            """
            IC-12: total clearance for "999 MB/s" at 9 pt regular \
            monospacedDigit plus the 6.0 pt dot must be at least 1.8 pt \
            for Spacer(minLength: 1); got \(clearance) pt.
            """
        )
        XCTAssertEqual(
            clearance,
            1.8916,
            accuracy: 0.05,
            "expected 1.8916 pt total clearance at the target font"
        )
    }
}
