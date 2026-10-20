//
//  MenuBarValueTypographyTests.swift
//  StatsLiteTests
//
//  Plan 2026-10-17-menu-bar-typography-and-block-width (red):
//  pin the menu bar block typography and row-alignment tokens to
//  the blueprint targets. Green target state: category labels at
//  7 pt regular secondary (MenuBarStackedItemView.swift:112),
//  values at 12 pt regular monospacedDigit (:117), network rates
//  at 9 pt regular monospacedDigit (:155 and :170), standard
//  block width 39 pt (MenuBarBlockModel.swift:56), and every row
//  container pinned with .frame(height: MenuBarLayout.rowHeight)
//  (11 pt), so both blocks fit exactly 22.0 pt against
//  NSStatusBar.system.thickness (VAC-11 and VAC-12). Mechanism: a
//  source-token check anchored on the view source through
//  #filePath, plus font-metric clearance measurements. This red
//  commit re-expects the label token (size: 7), the value token
//  (size: 12), and both clearance guards at 12 pt / 7 pt inside
//  the 39 pt block, so the red run fails on the label token, the
//  value token, the network value-size check, and both clearance
//  guards while production still pins 8 pt / 11 pt / 34 pt. The
//  spacing, network-clearance, fitting-height, and row-frame
//  guards pass unchanged.
//

import AppKit
import SwiftUI
import XCTest
@testable import StatsLite

final class MenuBarValueTypographyTests: XCTestCase {

    // MARK: - Expected source tokens (normalized: whitespace removed)

    /// `.font(.system(size: 12, weight: .regular).monospacedDigit())`
    private let expectedValueFont = ".font(.system(size:12,weight:.regular).monospacedDigit())"
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

    /// URL of MenuBarBlockModel.swift relative to this test file,
    /// same #filePath pattern as stackedItemViewURL. A read error
    /// throws and fails the test, never a vacuous pass.
    private var blockModelURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("StatsLite/MenuBarBlockModel.swift")
            .standardizedFileURL
    }

    private func loadLayoutSource(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let data = try Data(contentsOf: blockModelURL)
        return try XCTUnwrap(
            String(data: data, encoding: .utf8),
            "MenuBarBlockModel.swift is not valid UTF-8",
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

    // MARK: - FM1: value font is 12 pt regular monospacedDigit

    func testValueFontIsTwelvePointRegularMonospacedDigit() throws {
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
            MenuBarStackedItemView.swift:116-117 must be \
            Font.system(size: 12, weight: .regular).monospacedDigit(). \
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

    // MARK: - IC-4: label flips to 7 pt regular secondary

    func testLabelFontIsSevenPointRegularSecondary() throws {
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

    // MARK: - IC-10: network flips to 9 pt regular, value size stays 12

    func testNetworkFontsAreNinePointRegularAndValueStaysSizeTwelve() throws {
        let source = try loadSource()

        let blockScope = try declarationScope(of: "MenuBarBlockView", in: source)
        let blockValueToken = try fontToken(
            after: "Text(block.valueText)",
            in: blockScope
        )
        XCTAssertTrue(
            blockValueToken.contains("size:12"),
            """
            IC-10: the MenuBarBlockView value line must keep size 12; \
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
        // still covering both lines: it fails unless :155 AND :170 both
        // carry the flipped token, and the message quotes both found
        // tokens, so the red output shows both production lines.
        XCTAssertEqual(
            [uploadToken, downloadToken],
            [expectedNetworkFont, expectedNetworkFont],
            """
            IC-10: the upload rate line at MenuBarStackedItemView.swift:155 \
            and the download rate line at MenuBarStackedItemView.swift:170 \
            must each be \
            .font(.system(size: 9, weight: .regular).monospacedDigit()), \
            no .medium; found upload \(uploadToken), \
            download \(downloadToken).
            """
        )
    }

    // MARK: - IC-3: clearance for "100%" at 12 pt regular

    func testClearanceForWidestValueAtTwelvePointRegularMeetsTwoAndAHalfPointPerSideRule() {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12.0, weight: .regular)
        let width = ("100%" as NSString)
            .size(withAttributes: [.font: font])
            .width
        let clearance = MenuBarLayout.blockWidth - width

        XCTAssertEqual(
            MenuBarLayout.blockWidth,
            39.0,
            accuracy: 0.0001,
            "IC-3: the block width must be 39.0 pt"
        )
        XCTAssertGreaterThanOrEqual(
            clearance,
            5.0,
            """
            IC-3: total clearance for "100%" at 12 pt regular \
            monospacedDigit must be at least 5.0 pt; got \(clearance) pt.
            """
        )
        XCTAssertGreaterThanOrEqual(
            clearance / 2.0,
            2.5,
            """
            IC-3: per-side clearance for "100%" at 12 pt regular \
            monospacedDigit must be at least 2.5 pt; \
            got \(clearance / 2.0) pt.
            """
        )
        XCTAssertEqual(
            width,
            33.78,
            accuracy: 0.05,
            "expected 33.78 pt text width at the target font"
        )
        XCTAssertEqual(
            clearance,
            5.22,
            accuracy: 0.05,
            "expected 5.22 pt total clearance at the target font"
        )
    }

    // MARK: - IC-11: label-row clearance at 7 pt regular

    func testLabelRowClearanceForMemRowAtSevenPointRegularMeetsThreeAndAHalfPoints() {
        let font = NSFont.systemFont(ofSize: 7.0, weight: .regular)
        func width(of text: String) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: font]).width
        }

        XCTAssertEqual(
            MenuBarLayout.blockWidth,
            39.0,
            accuracy: 0.0001,
            "IC-11: the block width must be 39.0 pt"
        )

        let memClearance = MenuBarLayout.blockWidth - (4.0 + 2.0 + width(of: "MEM"))
        XCTAssertGreaterThanOrEqual(
            memClearance,
            3.5,
            """
            IC-11: total clearance for the MEM label row (4.0 pt dot + \
            2.0 pt gap + "MEM" at 7 pt regular) must be at least 3.5 pt; \
            got \(memClearance) pt.
            """
        )
        XCTAssertEqual(
            memClearance,
            15.9067,
            accuracy: 0.05,
            "expected 15.9067 pt total clearance for the MEM label row"
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
            23.6943,
            accuracy: 0.05,
            "expected 23.6943 pt total clearance for the CPU label"
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
            23.4790,
            accuracy: 0.05,
            "expected 23.4790 pt total clearance for the GPU label"
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

        let clearance = MenuBarLayout.networkBlockWidth - 5.0 - width
        XCTAssertGreaterThanOrEqual(
            clearance,
            1.8,
            """
            IC-12: total clearance for "999 MB/s" at 9 pt regular \
            monospacedDigit plus the 5.0 pt dot must be at least 1.8 pt \
            for Spacer(minLength: 1); got \(clearance) pt.
            """
        )
        XCTAssertEqual(
            clearance,
            2.8916,
            accuracy: 0.05,
            "expected 2.8916 pt total clearance at the target font"
        )
    }

    // MARK: - plan IC-3 (VAC-3): metric block stack spacing is 0

    func testMetricBlockStackUsesZeroVerticalSpacing() throws {
        let source = try loadSource()
        let scope = try declarationScope(of: "MenuBarBlockView", in: source)
        let line = try XCTUnwrap(
            sourceLine(containing: "VStack(", in: scope),
            "no VStack( line found in MenuBarBlockView"
        )
        XCTAssertEqual(
            squashed(line),
            "VStack(alignment:.center,spacing:0){",
            """
            plan IC-3: the MenuBarBlockView stack at \
            MenuBarStackedItemView.swift:103 must be \
            VStack(alignment: .center, spacing: 0); found \(line).
            """
        )
    }

    // MARK: - plan IC-4 (VAC-4): network block stack row spacing is 0

    func testNetworkBlockStackUsesZeroRowSpacing() throws {
        let source = try loadSource()
        let scope = try declarationScope(
            of: "MenuBarNetworkBlockView",
            in: source
        )
        let line = try XCTUnwrap(
            sourceLine(containing: "VStack(", in: scope),
            "no VStack( line found in MenuBarNetworkBlockView"
        )
        XCTAssertEqual(
            squashed(line),
            "VStack(alignment:.leading,spacing:0){",
            """
            plan IC-4: the MenuBarNetworkBlockView stack at \
            MenuBarStackedItemView.swift:145 must be \
            VStack(alignment: .leading, spacing: 0); found \(line).
            """
        )
    }

    // MARK: - VAC-11/VAC-12: row height constant and block alignment invariants

    // @MainActor: NSHostingView(rootView:) is MainActor-isolated and
    // the target compiles in Swift 6 mode, so the fitting-height
    // probe must run on the main actor (same pattern as
    // MenuBarRedrawChurnTests).
    @MainActor
    func testBlockFittingHeightsAreEqualAndMatchStatusBarThickness() {
        let standardBlock = MenuBarBlockView(
            block: MenuBarBlock(
                kind: .cpu,
                label: "CPU",
                dotState: nil,
                valueText: "100%",
                valueTint: .primary,
                width: MenuBarLayout.blockWidth
            )
        )
        let networkBlock = MenuBarNetworkBlockView(
            block: MenuBarBlock(
                kind: .network,
                label: "",
                dotState: nil,
                valueText: "999 MB/s",
                valueTint: .primary,
                width: MenuBarLayout.networkBlockWidth,
                secondaryValueText: "999 MB/s",
                secondaryValueTint: .primary
            )
        )

        let stdHeight = NSHostingView(rootView: standardBlock).fittingSize.height
        let netHeight = NSHostingView(rootView: networkBlock).fittingSize.height

        XCTAssertEqual(
            stdHeight,
            22.0,
            accuracy: 0.01,
            "VAC-11: MenuBarBlockView fitting height must be 22.0 pt"
        )
        XCTAssertEqual(
            netHeight,
            22.0,
            accuracy: 0.01,
            "VAC-11: MenuBarNetworkBlockView fitting height must be 22.0 pt"
        )
        XCTAssertEqual(
            stdHeight,
            netHeight,
            accuracy: 0.01,
            "VAC-11: both block types must have equal fitting height within 0.01 pt"
        )
    }

    func testRowFramesUseRowHeightConstantInBothBlocks() throws {
        // Constant check folded from blueprint Appendix B item 5
        // (Approach item 3): a compiled reference to the not-yet
        // existing constant would break the red build, so the 11 pt
        // constant is pinned as an exact source token on
        // MenuBarBlockModel.swift instead.
        let layoutLine = try XCTUnwrap(
            sourceLine(
                containing: "rowHeight",
                in: Substring(try loadLayoutSource())
            ),
            "no rowHeight line found in MenuBarBlockModel.swift"
        )
        XCTAssertEqual(
            squashed(layoutLine),
            "staticletrowHeight:CGFloat=11",
            """
            VAC-12: MenuBarLayout.rowHeight must be declared as \
            static let rowHeight: CGFloat = 11; found \(layoutLine).
            """
        )

        let source = try loadSource()
        let blockScope = try declarationScope(of: "MenuBarBlockView", in: source)
        let netScope = try declarationScope(of: "MenuBarNetworkBlockView", in: source)

        let expectedFrame = ".frame(height:MenuBarLayout.rowHeight)"
        XCTAssertTrue(
            squashed(blockScope).contains(expectedFrame),
            "VAC-12: MenuBarBlockView must use .frame(height: MenuBarLayout.rowHeight)"
        )

        let uploadSection = try XCTUnwrap(
            netScope.range(of: "Upload rate"),
            "Upload rate section not found in MenuBarNetworkBlockView"
        )
        let uploadFrameLine = try XCTUnwrap(
            sourceLine(containing: ".frame(height", in: netScope[uploadSection.upperBound...]),
            "no .frame(height line found in upload rate section"
        )
        XCTAssertEqual(
            squashed(uploadFrameLine),
            expectedFrame,
            "VAC-12: MenuBarNetworkBlockView line 1 must use .frame(height: MenuBarLayout.rowHeight)"
        )

        let downloadSection = try XCTUnwrap(
            netScope.range(of: "Download rate"),
            "Download rate section not found in MenuBarNetworkBlockView"
        )
        let downloadFrameLine = try XCTUnwrap(
            sourceLine(containing: ".frame(height", in: netScope[downloadSection.upperBound...]),
            "no .frame(height line found in download rate section"
        )
        XCTAssertEqual(
            squashed(downloadFrameLine),
            expectedFrame,
            "VAC-12: MenuBarNetworkBlockView line 2 must use .frame(height: MenuBarLayout.rowHeight)"
        )
    }

    // MARK: - plan 2026-10-20-menu-bar-value-vertical-shift: value line vertical shift

    /// VAC-1 / IC-1: the shift token is one layout constant, pinned
    /// at -1 pt in MenuBarLayout. The check reads both the source
    /// declaration and the compiled constant, so a comment-only
    /// change or a stub value fails.
    func testValueYOffsetConstantIsMinusOne() throws {
        let layoutLine = try XCTUnwrap(
            sourceLine(
                containing: "static let valueYOffset",
                in: Substring(try loadLayoutSource())
            ),
            "no valueYOffset declaration found in MenuBarBlockModel.swift"
        )
        XCTAssertEqual(
            squashed(layoutLine),
            "staticletvalueYOffset:CGFloat=-1",
            """
            VAC-1: MenuBarLayout.valueYOffset must be declared as \
            static let valueYOffset: CGFloat = -1; found \(layoutLine).
            """
        )
        XCTAssertEqual(
            MenuBarLayout.valueYOffset,
            -1,
            accuracy: 0.0001,
            """
            VAC-1: the compiled MenuBarLayout.valueYOffset must equal \
            -1 pt; got \(MenuBarLayout.valueYOffset).
            """
        )
    }

    /// VAC-2 / IC-2: MenuBarBlockView applies the shift only to the
    /// value Text. Source-string inspection inside the
    /// MenuBarBlockView body scope, anchored on the value Text, so
    /// an offset on some other view cannot satisfy the check.
    func testMenuBarBlockViewAppliesValueYOffsetModifier() throws {
        let source = try loadSource()
        let scope = try declarationScope(of: "MenuBarBlockView", in: source)
        let valueStart = try XCTUnwrap(
            scope.range(of: "Text(block.valueText)"),
            "value anchor not found in MenuBarBlockView"
        )
        let valueRegion = squashed(scope[valueStart.lowerBound...])
        XCTAssertTrue(
            valueRegion.contains(".offset(y:MenuBarLayout.valueYOffset)"),
            """
            VAC-2: MenuBarBlockView must apply \
            .offset(y: MenuBarLayout.valueYOffset) to Text(block.valueText); \
            found value region \(valueRegion).
            """
        )
    }

    /// IC-3 (VAC-3…VAC-7, VAC-11): font-metric geometry of the
    /// shifted value line. The plan's baseline formula: single-line
    /// text centered in a row of rowHeight puts the baseline at
    /// rowCenter + (ascender + descender) / 2; the shift moves the
    /// baseline by valueYOffset. Tolerance ±0.05 pt.
    func testValueBaselineOffsetAndGeometryInvariants() {
        let thickness: CGFloat = 22.0
        let rowHeight = MenuBarLayout.rowHeight

        let labelFont = NSFont.systemFont(ofSize: 7.0, weight: .regular)
        let valueFont = NSFont.monospacedDigitSystemFont(
            ofSize: 12.0,
            weight: .regular
        )
        let networkFont = NSFont.monospacedDigitSystemFont(
            ofSize: 9.0,
            weight: .regular
        )

        // Row 1 holds the label, row 2 holds the value — same order
        // as the MenuBarBlockView stack.
        let labelBaseline = rowHeight / 2
            + (labelFont.ascender + labelFont.descender) / 2
        let topGap = labelBaseline - labelFont.capHeight

        let valueRowCenter = rowHeight + rowHeight / 2
        let naturalBaseline = valueRowCenter
            + (valueFont.ascender + valueFont.descender) / 2
        let shiftedBaseline = naturalBaseline + MenuBarLayout.valueYOffset
        let valueCapTop = shiftedBaseline - valueFont.capHeight
        let bottomGap = thickness - shiftedBaseline
        let opticalGap = valueCapTop - labelBaseline

        let networkDownloadBaseline = valueRowCenter
            + (networkFont.ascender + networkFont.descender) / 2

        XCTAssertEqual(
            naturalBaseline,
            21.04,
            accuracy: 0.05,
            """
            IC-3: the unshifted 12 pt value baseline must sit at \
            21.04 pt; got \(naturalBaseline).
            """
        )
        XCTAssertEqual(
            shiftedBaseline,
            20.04,
            accuracy: 0.05,
            """
            VAC-3: with valueYOffset the value baseline must move to \
            20.04 pt; got \(shiftedBaseline).
            """
        )
        XCTAssertEqual(
            thickness - naturalBaseline,
            0.96,
            accuracy: 0.05,
            """
            IC-3: the unshifted bottom gap must be 0.96 pt; got \
            \(thickness - naturalBaseline).
            """
        )
        XCTAssertEqual(
            bottomGap,
            1.96,
            accuracy: 0.05,
            """
            VAC-4: the bottom gap must grow from 0.96 pt to 1.96 pt; \
            got \(bottomGap).
            """
        )
        XCTAssertEqual(
            opticalGap,
            3.43,
            accuracy: 0.05,
            """
            VAC-5: the label-to-value optical gap must fall from \
            4.43 pt to 3.43 pt; got \(opticalGap).
            """
        )
        XCTAssertGreaterThan(
            topGap,
            bottomGap,
            """
            VAC-6: the top gap \(topGap) pt must exceed the bottom gap \
            \(bottomGap) pt.
            """
        )
        XCTAssertEqual(
            valueCapTop,
            11.58,
            accuracy: 0.05,
            """
            VAC-7: the shifted value cap top must sit at 11.58 pt; \
            got \(valueCapTop).
            """
        )
        XCTAssertGreaterThanOrEqual(
            valueCapTop,
            rowHeight,
            """
            VAC-7: the value ink top \(valueCapTop) pt must stay at or \
            below the row 2 top \(rowHeight) pt (zero clipping).
            """
        )
        XCTAssertLessThanOrEqual(
            shiftedBaseline,
            thickness,
            """
            VAC-7: the value baseline \(shiftedBaseline) pt must stay at \
            or above the menu bar bottom \(thickness) pt (zero clipping).
            """
        )
        XCTAssertEqual(
            shiftedBaseline - networkDownloadBaseline,
            0.14,
            accuracy: 0.05,
            """
            VAC-11: the standard and network download baselines must \
            align within 0.14 pt; got delta \
            \(shiftedBaseline - networkDownloadBaseline) pt.
            """
        )
    }
}
