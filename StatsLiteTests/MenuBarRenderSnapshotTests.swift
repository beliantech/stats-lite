//
//  MenuBarRenderSnapshotTests.swift
//  StatsLiteTests
//
//  Offscreen pixel VACs for the menu bar blocks (plan
//  2026-10-24-menu-bar-offscreen-render-tests). The suite renders
//  the real views through MenuBarRenderHarness and measures ink in
//  the bitmap: no live screen capture, so the pixel VACs verify
//  with the screen locked and the display asleep. Live screen
//  captures stay end-to-end spot checks only (AGENTS.md).
//
//  Failure modes, one guard each: FM1 blank render (ISC-1 ink floor
//  plus the negative-path test), FM2 scale drift (pinned 2x harness
//  and production-constant render dimensions), FM3 forced
//  appearance ignored (ISC-5 luminance probe), FM4 re-declared
//  geometry (every width, height, and gap reads MenuBarLayout).
//  The numbers below are the fixed ISC values — do not weaken them
//  in green. The suite forces both system appearances through
//  MenuBarRenderHarness.
//

import AppKit
import SwiftUI
import XCTest
@testable import StatsLite

@MainActor
final class MenuBarRenderSnapshotTests: XCTestCase {

    // MARK: - Thresholds (the only literals: measurement values)

    /// Ink weight floor: a pixel counts as ink when its luminance
    /// distance from the fixed 50 % gray background reaches this.
    /// The background itself sits at 0.5, so it never counts. The
    /// floor stays low enough to keep glyph antialiasing tails —
    /// the live VAC measurement counted them (plan Addendum B).
    private let inkThreshold: Double = 2

    /// ISC-1 (FM1): minimum ink pixels per block render.
    private let minimumInkPixels = 100

    /// ISC-2: label-to-dot centroid tolerance in bitmap pixels.
    private let centroidTolerance: Double = 0.30

    /// ISC-3/ISC-5: shared inter-block ink gap target and tolerance
    /// in bitmap pixels at 2x, used by both the MEM→TEMP and the
    /// TEMP→NET legs. Addendum B measured 21.0 px nominal under the
    /// 4 pt gap token (22 px rendered); the 5 pt token (plan
    /// 2026-10-26-menubar-block-gap-5pt) ripples the frame gap
    /// 8 px → 10 px, so both legs re-measure 24 px. The trailing-dot
    /// split constant `tempNetInkGap` is gone: with the dots leading
    /// again (plan 2026-10-26-network-dots-leading-rate-cap), the
    /// leftmost NET ink is the dot edge and the TEMP→NET leg rejoins
    /// the shared value (ISC-5, VAC-R16).
    private let interBlockGap: Double = 24
    private let interBlockGapTolerance: Double = 1

    /// ISC-4: top ink edge tolerance in bitmap pixels.
    private let topEdgeTolerance: Double = 0.4

    /// ISC-5: value-text luminance difference floor between the two
    /// forced appearances. Shared with the Layer-3 label probe
    /// (plan 2026-10-25-menubar-label-contrast, VAC-10): one 40
    /// floor, one harness, one appearance pair.
    private let appearanceLuminanceDelta: Double = 40

    /// ISC-7 (plan 2026-10-25-menubar-label-contrast, H0
    /// falsification): floor for the forced-.darkAqua CPU label
    /// peak pixel luminance (0-255 sRGB over the fixed 50 % gray
    /// harness background, line-1 label region). Calibration (T1.2,
    /// red run in this harness): V_red = 198.0 on the
    /// .foregroundStyle(.secondary) code (printed by the probe on
    /// failure). T = floor((V_red + (213 - 8)) / 2) = floor(201.5)
    /// = 201: strictly above V_red by 3, and 12 below the expected
    /// green render (prior ≈ 213), so the required ≥ 8 margin
    /// holds. The live-teal 124 baseline (D1) is never a threshold
    /// — only harness numbers count.
    private let darkAquaLabelPeakLuminanceFloor: Double = 201

    /// VAC-A (plan 2026-10-25-menubar-item-gap-uniform-minimum,
    /// correction 3): standard-block ink-gap bounds in bitmap pixels
    /// at 2x. Floor = MenuBarLayout.gap design token at 2x (10 px
    /// under the 5 pt token, plan 2026-10-26-menubar-block-gap-5pt;
    /// never lowered). Ceiling = token + glyph side bearings
    /// (2 px per edge), so a regression to the pre-fix 38–45 px
    /// fixed-frame gaps fails.
    private let minimalGapFloor: Double = 10
    private let minimalGapCeiling: Double = 14

    /// VAC-A: maximum pixel delta between the CPU→GPU and GPU→MEM
    /// gap minima (uniformity at 2x). Raised to 2 only with
    /// recorded bearing evidence, never above (correction 3).
    private let gapUniformityTolerance: Double = 1

    /// VAC-B (T2) → VAC-C105 (T3): collision floor at extreme
    /// values (`99%`, `--%`) — the closest-approach gap must not
    /// merge below 9 px at 2x (7 px under the 4 pt token plus the
    /// +2 px mechanical ripple of the 5 pt token, plan
    /// 2026-10-26-menubar-block-gap-5pt). VAC-C105 is a floor-only
    /// rule (Appendix C §5).
    private let extremeGapFloor: Double = 9

    /// VAC-C105: regression ceiling at extreme values, raised from
    /// the T2 value 13 px to the largest designed standard-block
    /// gap in the T3 contract (Appendix C §3: `--%` on CPU→GPU
    /// measures 18–19 px under the 4 pt token; the single-digit
    /// band topped out at 27 px). The 5 pt token (plan
    /// 2026-10-26-menubar-block-gap-5pt) ripples both +2 px. A
    /// regression to the pre-fix 38–45 px fixed-frame gaps still
    /// fails.
    private let extremeGapCeiling: Double = 29

    /// VAC-C104 (Appendix C §5): GPU single-digit (`0%`…`9%`)
    /// CPU→GPU closest-approach gap band at 2x. The Appendix C §3
    /// table measures 25–26 px (frame gap 8 px + 16.68 px leading
    /// slack of an 18.66 pt value in the 27 pt frame + bearings)
    /// under the 4 pt token; the 5 pt token (plan
    /// 2026-10-26-menubar-block-gap-5pt) ripples the frame gap to
    /// 10 px and the band to 25–29 px (±2 px slack around the
    /// table). On the T2 34 pt frame the same block renders ~39 px
    /// and fails.
    private let singleDigitGapFloor: Double = 25
    private let singleDigitGapCeiling: Double = 29

    /// VAC-C107 (Appendix C §5): slot-fill. Each frame void at the
    /// slot edge must not exceed 1 px at 2x — the T2 ~15 px side
    /// voids are eliminated edge-to-edge.
    private let slotVoidCeiling: Double = 1

    /// VAC-C107 composition gap bands for the cold (nil → `--%`)
    /// fixture, from the Appendix C §3 bitmap ink-gap table:
    /// CPU→GPU 18–19 px, GPU→MEM 12–13 px under the 4 pt token.
    /// The 5 pt token (plan 2026-10-26-menubar-block-gap-5pt)
    /// ripples both +2 px. Each band carries ±1 px slack around the
    /// table values (the `--%` hyphen bearings).
    private let coldGpuMemGapFloor: Double = 13
    private let coldGpuMemGapCeiling: Double = 16
    private let coldCpuGpuGapFloor: Double = 19
    private let coldCpuGpuGapCeiling: Double = 22

    /// VAC-D: per-block trailing flush — right ink of line 1 and
    /// line 2 within 1 px at 2x (the 2026-10-24 right-alignment
    /// directive).
    private let trailingFlushTolerance: Double = 1

    /// VAC-C: left/right void split of the centered block group,
    /// in bitmap pixels at 2x. T3 measures the voids as frame
    /// voids (production-derived frame edges vs the slot inner
    /// edges): under trailing alignment the leftmost ink includes
    /// the CPU block's leading slack, which is frame geometry,
    /// not slot void. The |leftVoid − rightVoid| symmetry rule
    /// (T2 VAC-C106) survives on the frame-void basis.
    private let voidDeltaTolerance: Double = 2

    private let appearances: [NSAppearance.Name] = [.darkAqua, .aqua]

    // MARK: - Production fixtures (MenuBarBlockBuilder, ISC-6)

    /// CPU 45 %, MEM 50 % normal, GPU 32 %, TEMP C 45° / G 32° —
    /// every block built through the production builder, so the
    /// suite measures production output, not hand-written blocks.
    private func builtBlocks() throws -> (
        cpu: MenuBarBlock,
        mem: MenuBarBlock,
        gpu: MenuBarBlock,
        temp: MenuBarBlock
    ) {
        let blocks = MenuBarBlockBuilder.blocks(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            showNetwork: false,
            showTemperature: true,
            cpuPercent: 0.45,
            pressurePercent: 0.50,
            pressureState: .normal,
            gpuPercent: 0.32,
            temperature: TemperatureMetrics(cpuCelsius: 45, gpuCelsius: 32)
        )
        func block(_ kind: MenuBarBlockKind) throws -> MenuBarBlock {
            try XCTUnwrap(
                blocks.first { $0.kind == kind },
                "fixture missing block \(kind) for an enabled metric"
            )
        }
        return try (block(.cpu), block(.ram), block(.gpu), block(.temp))
    }

    /// NET block with rates, so both indicator dots render.
    private func networkBlock() throws -> MenuBarBlock {
        let blocks = MenuBarBlockBuilder.blocks(
            showCPU: false,
            showRAM: false,
            showGPU: false,
            showNetwork: true,
            showTemperature: false,
            cpuPercent: nil,
            pressurePercent: nil,
            pressureState: nil,
            gpuPercent: nil,
            downloadRate: 720 * 1024,
            uploadRate: 10 * 1024
        )
        return try XCTUnwrap(
            blocks.first { $0.kind == .network },
            "fixture missing block network for showNetwork"
        )
    }

    /// The production adjacency of two neighboring blocks: the same
    /// spacing MenuBarStackedItemView uses between neighbors.
    private func adjacent<A: View, B: View>(_ first: A, _ second: B) -> some View {
        HStack(alignment: .center, spacing: MenuBarLayout.gap) {
            first
            second
        }
    }

    // MARK: - Row bands (production rowHeight, ISC-6)

    private var scale: CGFloat { MenuBarRenderHarness.scale }

    /// Line-1 band in bitmap pixels: the first 11 pt row.
    private var line1: Range<Int> { 0..<Int(MenuBarLayout.rowHeight * scale) }

    /// Line-2 band in bitmap pixels: the second 11 pt row.
    private var line2: Range<Int> {
        Int(MenuBarLayout.rowHeight * scale)..<(2 * Int(MenuBarLayout.rowHeight * scale))
    }

    // MARK: - ISC-1 + FM2/FM4 (ink floor and production geometry)

    /// ISC-1 (FM1): every block render must contain real ink before
    /// any measurement runs. A blank or near-blank bitmap means the
    /// harness lost its host environment, scale factor, or fixed
    /// size — fail loudly here, never measure a blank.
    func testEveryBlockRenderProducesInk() throws {
        let blocks = try builtBlocks()
        let network = try networkBlock()
        for appearance in appearances {
            let renders: [(String, MenuBarRenderHarness.Render)] = [
                (
                    "MenuBarTempBlockView",
                    MenuBarRenderHarness.render(
                        MenuBarTempBlockView(block: blocks.temp),
                        appearance: appearance
                    )
                ),
                (
                    "MenuBarNetworkBlockView",
                    MenuBarRenderHarness.render(
                        MenuBarNetworkBlockView(block: network),
                        appearance: appearance
                    )
                ),
                (
                    "MenuBarBlockView CPU",
                    MenuBarRenderHarness.render(
                        MenuBarBlockView(block: blocks.cpu),
                        appearance: appearance
                    )
                ),
                (
                    "MenuBarBlockView MEM",
                    MenuBarRenderHarness.render(
                        MenuBarBlockView(block: blocks.mem),
                        appearance: appearance
                    )
                ),
                (
                    "MenuBarBlockView GPU",
                    MenuBarRenderHarness.render(
                        MenuBarBlockView(block: blocks.gpu),
                        appearance: appearance
                    )
                ),
            ]
            for (name, bitmap) in renders {
                let ink = bitmap.inkPixelCount(threshold: inkThreshold)
                XCTAssertGreaterThanOrEqual(
                    ink,
                    minimumInkPixels,
                    """
                    ISC-1 (FM1): \(name) under \(appearance.rawValue) rendered \
                    \(ink) ink pixels, under the \(minimumInkPixels) floor — the \
                    render is blank or near-blank and no measurement may run on it.
                    """
                )
            }
        }
    }

    /// ISC-6 + FM2/FM4: every render box measures the production
    /// geometry at the pinned 2x scale — height 2 x rowHeight, widths
    /// from MenuBarLayout. TEMP and NET keep exact pinned widths.
    /// Standard blocks render at intrinsic content width, bounded by
    /// the blockWidth length budget (plan 2026-10-25, correction 1),
    /// so their width asserts as a ceiling, not equality. The
    /// measurements in this suite verify production layout, not
    /// re-declared numbers.
    func testRenderDimensionsMatchProductionGeometry() throws {
        let blocks = try builtBlocks()
        let network = try networkBlock()
        let expectedHeight = Int(MenuBarLayout.rowHeight * scale * 2)
        /// (name, render, width in pt, width is pinned exactly)
        let cases: [(String, MenuBarRenderHarness.Render, CGFloat, Bool)] = [
            (
                "temp",
                MenuBarRenderHarness.render(
                    MenuBarTempBlockView(block: blocks.temp),
                    appearance: .darkAqua
                ),
                MenuBarLayout.tempBlockWidth,
                true
            ),
            (
                "network",
                MenuBarRenderHarness.render(
                    MenuBarNetworkBlockView(block: network),
                    appearance: .darkAqua
                ),
                MenuBarLayout.networkBlockWidth,
                true
            ),
            (
                "cpu",
                MenuBarRenderHarness.render(
                    MenuBarBlockView(block: blocks.cpu),
                    appearance: .darkAqua
                ),
                MenuBarLayout.blockWidth,
                false
            ),
            (
                "mem",
                MenuBarRenderHarness.render(
                    MenuBarBlockView(block: blocks.mem),
                    appearance: .darkAqua
                ),
                MenuBarLayout.blockWidth,
                false
            ),
            (
                "gpu",
                MenuBarRenderHarness.render(
                    MenuBarBlockView(block: blocks.gpu),
                    appearance: .darkAqua
                ),
                MenuBarLayout.blockWidth,
                false
            ),
        ]
        for (name, bitmap, width, isWidthPinned) in cases {
            if isWidthPinned {
                XCTAssertEqual(
                    bitmap.pixelsWide,
                    Int(width * scale),
                    "ISC-6 (FM2/FM4): \(name) render width must be the MenuBarLayout width at 2x"
                )
            } else {
                // The production geometry of a standard block is its
                // content width, bounded by the blockWidth length
                // budget that MenuBarLayout.length sums.
                XCTAssertLessThanOrEqual(
                    bitmap.pixelsWide,
                    Int(width * scale),
                    "ISC-6 (FM2/FM4): \(name) render width must fit the MenuBarLayout.blockWidth length budget at 2x"
                )
            }
            XCTAssertEqual(
                bitmap.pixelsHigh,
                expectedHeight,
                "ISC-6 (FM2/FM4): \(name) render height must be 2 x MenuBarLayout.rowHeight at 2x"
            )
        }
    }

    /// FM1 negative path: the ink floor must catch a render that
    /// carries no ink at all, so a broken harness fails loudly
    /// before any measurement runs.
    func testInkFloorFiresOnBackgroundOnlyRender() {
        let blank = MenuBarRenderHarness.render(
            Color.clear.frame(
                width: MenuBarLayout.blockWidth,
                height: 2 * MenuBarLayout.rowHeight
            ),
            appearance: .darkAqua
        )
        let ink = blank.inkPixelCount(threshold: inkThreshold)
        XCTAssertLessThan(
            ink,
            minimumInkPixels,
            """
            FM1: a background-only render carries \(ink) ink pixels and must \
            stay under the \(minimumInkPixels) floor, or the ISC-1 guard can \
            never fire on a blank render.
            """
        )
    }

    // MARK: - ISC-2 (VAC-16/17): label and dot centroids

    /// ISC-2: the TEMP subsystem labels sit on the same optical line
    /// as the network indicator dots. Intensity-weighted sub-pixel
    /// centroids: |cy(C) − cy(red dot)| and |cy(G) − cy(cyan dot)|
    /// each within 0.30 px at 2x, under both forced appearances.
    /// The two blocks render in their production adjacency with the
    /// production gap, so both bitmaps share one coordinate system.
    func testTempLabelCentroidsAlignWithNetworkDotCentroids() throws {
        let blocks = try builtBlocks()
        let network = try networkBlock()
        let networkStart = Int(
            (MenuBarLayout.tempBlockWidth + MenuBarLayout.gap) * scale
        )
        for appearance in appearances {
            let bitmap = MenuBarRenderHarness.render(
                adjacent(
                    MenuBarTempBlockView(block: blocks.temp),
                    MenuBarNetworkBlockView(block: network)
                ),
                appearance: appearance
            )
            let tempColumns = 0..<networkStart
            // plan 2026-10-26-network-dots-leading-rate-cap: the
            // dots lead the NET frame (0..5 pt = networkStart ..
            // networkStart + 10 px at 2x), so the dot queries read
            // the leading dot band. A trailing-dot render carries
            // no ink in this band and the unwrap below fails loudly.
            let dotBand = networkStart..<(networkStart + 10)

            let cyC = try XCTUnwrap(
                bitmap.leftmostClusterCentroidY(
                    yRange: line1,
                    xRange: tempColumns,
                    threshold: inkThreshold
                ),
                "ISC-2 (FM1): no C-label ink in the TEMP region of the \(appearance.rawValue) render"
            )
            let cyRedDot = try XCTUnwrap(
                bitmap.leftmostClusterCentroidY(
                    yRange: line1,
                    xRange: dotBand,
                    threshold: inkThreshold
                ),
                "ISC-2 (FM1): no red-upload-dot ink in the NET region of the \(appearance.rawValue) render"
            )
            XCTAssertLessThanOrEqual(
                abs(cyC - cyRedDot),
                centroidTolerance,
                """
                ISC-2 (VAC-16): |cy(C) − cy(red dot)| = \
                \(abs(cyC - cyRedDot)) px under \(appearance.rawValue); the C \
                label and the red dot must share an optical line within 0.30 px.
                """
            )

            let cyG = try XCTUnwrap(
                bitmap.leftmostClusterCentroidY(
                    yRange: line2,
                    xRange: tempColumns,
                    threshold: inkThreshold
                ),
                "ISC-2 (FM1): no G-label ink in the TEMP region of the \(appearance.rawValue) render"
            )
            let cyCyanDot = try XCTUnwrap(
                bitmap.leftmostClusterCentroidY(
                    yRange: line2,
                    xRange: dotBand,
                    threshold: inkThreshold
                ),
                "ISC-2 (FM1): no cyan-download-dot ink in the NET region of the \(appearance.rawValue) render"
            )
            XCTAssertLessThanOrEqual(
                abs(cyG - cyCyanDot),
                centroidTolerance,
                """
                ISC-2 (VAC-17): |cy(G) − cy(cyan dot)| = \
                \(abs(cyG - cyCyanDot)) px under \(appearance.rawValue); the G \
                label and the cyan dot must share an optical line within 0.30 px.
                """
            )
        }
    }

    // MARK: - plan 2026-10-26-network-dots-leading-rate-cap,
    // ISC-4 (VAC-R12..R15): dots lead, rate text flush right, 47 pt frame

    /// ISC-4 (VAC-R12..R15): each network row leads with its
    /// indicator dot and pins its rate text flush right inside the
    /// 47 pt frame (94 px at 2x), both dots sharing one x column.
    /// Per row × both fixtures × both appearances: (a) the pinned
    /// width is 47 pt and the render measures exactly
    /// MenuBarLayout.networkBlockWidth × 2 px (VAC-R12); (b) dot
    /// ink starts at x ≤ 1 px and ends at x ≤ 10 px, both dots
    /// within one column (VAC-R13); (c) rate-text right ink
    /// reaches within 3 px of the trailing frame edge (VAC-R14);
    /// (d) the widest-string fixture keeps a ≥ 5 px dot-to-text
    /// gutter (VAC-R15). The dot band is 0..<12 px; a trailing-dot
    /// render carries no ink there and the unwrap fails loudly.
    func testNetworkDotsLeadAndTextFlushRight() throws {
        let production = try networkBlock()
        let widest = MenuBarBlock(
            kind: .network,
            label: "",
            dotState: nil,
            valueText: "9.9 MB/s",
            valueTint: .primary,
            width: MenuBarLayout.networkBlockWidth,
            secondaryValueText: "9.9 MB/s",
            secondaryValueTint: .primary
        )
        let fixtures: [(String, MenuBarBlock)] = [
            ("production rates", production),
            ("widest rates", widest),
        ]
        let dotBand = 0..<12
        for appearance in appearances {
            for (fixtureName, block) in fixtures {
                let bitmap = MenuBarRenderHarness.render(
                    MenuBarNetworkBlockView(block: block),
                    appearance: appearance
                )
                XCTAssertEqual(
                    MenuBarLayout.networkBlockWidth,
                    47.0,
                    accuracy: 0.0001,
                    """
                    ISC-4 (VAC-R12): the pinned network block width must \
                    shrink 50 pt → 47 pt; found \
                    \(MenuBarLayout.networkBlockWidth) pt.
                    """
                )
                XCTAssertEqual(
                    bitmap.pixelsWide,
                    Int(MenuBarLayout.networkBlockWidth * scale),
                    """
                    ISC-4 (VAC-R12): the network block must render exactly \
                    MenuBarLayout.networkBlockWidth × 2 = 94 px wide at 2x; \
                    \(fixtureName) under \(appearance.rawValue) rendered \
                    \(bitmap.pixelsWide) px.
                    """
                )
                var dotLeftByRow: [Int] = []
                for (rowName, row) in [("line 1", line1), ("line 2", line2)] {
                    let dotLeft = try XCTUnwrap(
                        bitmap.leftmostInkX(
                            yRange: row,
                            xRange: dotBand,
                            threshold: inkThreshold
                        ),
                        """
                        ISC-4 (VAC-R13): no leading indicator-dot ink on \
                        \(rowName) of the \(fixtureName) fixture under \
                        \(appearance.rawValue); the dot must lead the row from \
                        the block's leading edge.
                        """
                    )
                    XCTAssertLessThanOrEqual(
                        dotLeft,
                        1,
                        """
                        ISC-4 (VAC-R13): \(fixtureName) \(rowName) dot left \
                        ink = \(dotLeft) px under \(appearance.rawValue); the \
                        leading dot must start at x ≤ 1 px at 2x.
                        """
                    )
                    let dotRight = try XCTUnwrap(
                        bitmap.rightmostInkX(
                            yRange: row,
                            xRange: dotBand,
                            threshold: inkThreshold
                        ),
                        """
                        ISC-4 (VAC-R13): no leading indicator-dot ink on \
                        \(rowName) of the \(fixtureName) fixture under \
                        \(appearance.rawValue).
                        """
                    )
                    XCTAssertLessThanOrEqual(
                        dotRight,
                        10,
                        """
                        ISC-4 (VAC-R13): \(fixtureName) \(rowName) dot right \
                        ink = \(dotRight) px under \(appearance.rawValue); the \
                        leading dot must end at x ≤ 10 px at 2x.
                        """
                    )
                    let textRight = try XCTUnwrap(
                        bitmap.rightmostInkX(
                            yRange: row,
                            xRange: dotBand.upperBound..<bitmap.pixelsWide,
                            threshold: inkThreshold
                        ),
                        """
                        ISC-4 (VAC-R14): no rate-text ink on \(rowName) of the \
                        \(fixtureName) fixture under \(appearance.rawValue).
                        """
                    )
                    XCTAssertGreaterThanOrEqual(
                        textRight,
                        bitmap.pixelsWide - 3,
                        """
                        ISC-4 (VAC-R14): \(fixtureName) \(rowName) rate-text \
                        right ink = \(textRight) px under \(appearance.rawValue); \
                        the flush-right text must reach within 3 px of the \
                        \(bitmap.pixelsWide) px trailing edge.
                        """
                    )
                    if fixtureName == "widest rates" {
                        let textLeft = try XCTUnwrap(
                            bitmap.leftmostInkX(
                                yRange: row,
                                xRange: dotBand.upperBound..<bitmap.pixelsWide,
                                threshold: inkThreshold
                            ),
                            """
                            ISC-4 (VAC-R15): no rate-text ink on \(rowName) of \
                            the \(fixtureName) fixture under \
                            \(appearance.rawValue).
                            """
                        )
                        XCTAssertGreaterThanOrEqual(
                            textLeft - dotRight,
                            5,
                            """
                            ISC-4 (VAC-R15): \(fixtureName) \(rowName) \
                            dot-to-text gutter = \(textLeft - dotRight) px \
                            under \(appearance.rawValue); the widest rate \
                            string must keep ≥ 5 px between dot right ink and \
                            rate-text left ink at 2x.
                            """
                        )
                    }
                    dotLeftByRow.append(dotLeft)
                }
                XCTAssertEqual(
                    abs(dotLeftByRow[0] - dotLeftByRow[1]),
                    0,
                    accuracy: 1,
                    """
                    ISC-4 (VAC-R13): \(fixtureName) dot left ink differs by \
                    \(abs(dotLeftByRow[0] - dotLeftByRow[1])) px between line \
                    1 (\(dotLeftByRow[0]) px) and line 2 \
                    (\(dotLeftByRow[1]) px) under \(appearance.rawValue); \
                    both dots must share one x column within 1 px.
                    """
                )
            }
        }
    }

    // MARK: - ISC-3 (VAC-22/23): inter-block ink gaps

    /// ISC-3/ISC-5 (re-issued VAC-22/23, Addendum B): the ink gaps
    /// between blocks measure 24 ±1 px at 2x under the 5 pt gap
    /// token (MEM→TEMP measured 24 px under both appearances in
    /// the green run of plan 2026-10-26-menubar-block-gap-5pt;
    /// 22 px rendered under the 4 pt token, +2 px mechanical
    /// ripple). TEMP value right ink
    /// → NET leading-dot left ink crosses the TEMP↔NET boundary
    /// and rejoins the shared interBlockGap 24 ±1 px (plan
    /// 2026-10-26-network-dots-leading-rate-cap, ISC-5/VAC-R16:
    /// with the dots leading again the leftmost NET ink is the dot
    /// edge, so the trailing-dot split leg is gone);
    /// MEM value
    /// right ink → C label left ink crosses the MEM↔TEMP boundary
    /// and keeps interBlockGap 24 ±1 px.
    /// Both pairs render in their production adjacency with the
    /// production gap, so the gap itself comes from production.
    /// Convention: the gap is the empty span between the two inks,
    /// from the first background column after one ink to the first
    /// inked column of the other (the sub-pixel edge-to-edge read
    /// of plan Addendum B).
    func testInterBlockInkGapsMeasureTwentyFourPixels() throws {
        let blocks = try builtBlocks()
        let network = try networkBlock()
        for appearance in appearances {
            let tempNet = MenuBarRenderHarness.render(
                adjacent(
                    MenuBarTempBlockView(block: blocks.temp),
                    MenuBarNetworkBlockView(block: network)
                ),
                appearance: appearance
            )
            let networkStart = Int(
                (MenuBarLayout.tempBlockWidth + MenuBarLayout.gap) * scale
            )
            let tempValueRight = try XCTUnwrap(
                tempNet.rightmostInkX(
                    yRange: line1,
                    xRange: 0..<networkStart,
                    threshold: inkThreshold
                ),
                "ISC-3 (FM1): no TEMP value ink on line 1 of the \(appearance.rawValue) render"
            )
            let redDotLeft = try XCTUnwrap(
                tempNet.leftmostInkX(
                    yRange: line1,
                    xRange: networkStart..<tempNet.pixelsWide,
                    threshold: inkThreshold
                ),
                "ISC-5 (FM1): no NET leading-dot ink on line 1 of the \(appearance.rawValue) render"
            )
            let valueRightEdge = tempValueRight + 1
            XCTAssertEqual(
                Double(redDotLeft - valueRightEdge),
                interBlockGap,
                accuracy: interBlockGapTolerance,
                """
                ISC-5 (VAC-R16): TEMP value right ink → leading-dot left ink \
                = \(redDotLeft - valueRightEdge) px under \(appearance.rawValue); \
                the TEMP↔NET gap rejoins the shared 24 ±1 px at 2x (leading \
                dots restore the pre-move leg, plan \
                2026-10-26-network-dots-leading-rate-cap).
                """
            )

            let memTemp = MenuBarRenderHarness.render(
                adjacent(
                    MenuBarBlockView(block: blocks.mem),
                    MenuBarTempBlockView(block: blocks.temp)
                ),
                appearance: appearance
            )
            // The MEM block renders at intrinsic content width, so
            // the boundary comes from a single-block render instead
            // of blockWidth (plan 2026-10-25, correction 2). The
            // expected 24 ±1 px does not change: the MEM ink edge
            // and the TEMP frame shift left by the same amount.
            let memWidth = MenuBarRenderHarness.render(
                MenuBarBlockView(block: blocks.mem),
                appearance: appearance
            ).pixelsWide
            let memEnd = memWidth + Int(MenuBarLayout.gap * scale)
            let memValueRight = try XCTUnwrap(
                memTemp.rightmostInkX(
                    yRange: line2,
                    xRange: 0..<memWidth,
                    threshold: inkThreshold
                ),
                "ISC-3 (FM1): no MEM value ink on line 2 of the \(appearance.rawValue) render"
            )
            let cLeft = try XCTUnwrap(
                memTemp.leftmostInkX(
                    yRange: line1,
                    xRange: memEnd..<memTemp.pixelsWide,
                    threshold: inkThreshold
                ),
                "ISC-3 (FM1): no C-label ink on line 1 of the \(appearance.rawValue) render"
            )
            let memValueRightEdge = memValueRight + 1
            XCTAssertEqual(
                Double(cLeft - memValueRightEdge),
                interBlockGap,
                accuracy: interBlockGapTolerance,
                """
                ISC-3 (VAC-23): MEM value right ink → C label left ink = \
                \(cLeft - memValueRightEdge) px under \(appearance.rawValue); \
                the gap is 24 ±1 px at 2x (plan \
                2026-10-26-menubar-block-gap-5pt, measured 24 px in the \
                green run).
                """
            )
        }
    }

    // MARK: - VAC-A/B/C (plan 2026-10-25): uniform minimal gaps

    /// Per-band ink gaps at one block boundary inside an adjacency
    /// render. The boundary is the left block's single-block render
    /// width in bitmap pixels (production-derived). Gap convention
    /// matches ISC-3: the empty span between the two inks, from the
    /// first background column after one ink to the first inked
    /// column of the other.
    private func bandGaps(
        _ bitmap: MenuBarRenderHarness.Render,
        boundary: Int
    ) throws -> (line1: Int, line2: Int) {
        func bandGap(_ band: Range<Int>) throws -> Int {
            let leftBlockRightInk = try XCTUnwrap(
                bitmap.rightmostInkX(
                    yRange: band,
                    xRange: 0..<boundary,
                    threshold: inkThreshold
                ),
                "VAC (FM1): no left-block ink on band \(band) before boundary \(boundary)"
            )
            let rightBlockLeftInk = try XCTUnwrap(
                bitmap.leftmostInkX(
                    yRange: band,
                    xRange: boundary..<bitmap.pixelsWide,
                    threshold: inkThreshold
                ),
                "VAC (FM1): no right-block ink on band \(band) after boundary \(boundary)"
            )
            return rightBlockLeftInk - (leftBlockRightInk + 1)
        }
        let g1 = try bandGap(line1)
        let g2 = try bandGap(line2)
        return (g1, g2)
    }

    /// The three standard blocks from explicit percents: nil builds
    /// `−−−%` with a tertiary tint, exactly what a fresh monitor
    /// renders before its first snapshot (VAC-B extremes, VAC-C).
    private func standardTriple(
        cpuPercent: Double?,
        pressurePercent: Double?,
        gpuPercent: Double?
    ) throws -> (cpu: MenuBarBlock, mem: MenuBarBlock, gpu: MenuBarBlock) {
        let blocks = MenuBarBlockBuilder.blocks(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            cpuPercent: cpuPercent,
            pressurePercent: pressurePercent,
            pressureState: .normal,
            gpuPercent: gpuPercent
        )
        func block(_ kind: MenuBarBlockKind) throws -> MenuBarBlock {
            try XCTUnwrap(
                blocks.first { $0.kind == kind },
                "fixture missing block \(kind) for an enabled metric"
            )
        }
        return try (block(.cpu), block(.ram), block(.gpu))
    }

    // MARK: - VAC-101 (plan 2026-10-25 T2): frozen block positions

    /// VAC-101: one position measure across the value sweep must
    /// never move — max minus min stays 0.0 px at 2x. The failure
    /// message carries the extreme sweep points and every sample,
    /// so a red run reports the measured shift directly.
    private func assertFrozenAcrossSweep(
        _ samples: [(point: String, pixels: Double)],
        block: String,
        measure: String,
        appearance: NSAppearance.Name,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard
            let minimum = samples.min(by: { $0.pixels < $1.pixels }),
            let maximum = samples.max(by: { $0.pixels < $1.pixels })
        else {
            XCTFail(
                "VAC-C101: no \(measure) samples for \(block) under \(appearance.rawValue)",
                file: file,
                line: line
            )
            return
        }
        let spread = maximum.pixels - minimum.pixels
        XCTAssertLessThanOrEqual(
            spread,
            0.0,
            """
            VAC-C101: \(block) \(measure) spread = \(spread) px at 2x under \
            \(appearance.rawValue) (min \(minimum.pixels) px at \
            "\(minimum.point)", max \(maximum.pixels) px at \
            "\(maximum.point)", samples: \
            \(samples.map { "\($0.point):\($0.pixels)" }.joined(separator: ", "))); \
            the position must freeze within 0.0 px across the sweep.
            """,
            file: file,
            line: line
        )
    }

    /// VAC-C101 (position freezing invariant, plan 2026-10-25 T3,
    /// Appendix C §5): sweep the standard blocks through every
    /// digit boundary plus the clip and placeholder points (`0%`,
    /// `5%`, `10%`, `50%`, `99%`, `1.0` → `99%`, nil → `--%`) and
    /// prove that no block moves. A string-integrity guard runs
    /// first at every sweep point: the position measurement must
    /// run on the natural clip-99 strings the T3 contract
    /// renders, never on padded text (`045%`, T2) or the old
    /// `−−−%` placeholder. Each block
    /// contributes three measures, each frozen within 0.0 px at
    /// 2x: the single-block frame width (the next block's origin
    /// starts after it), the composition x-origin (cumulative
    /// production widths plus MenuBarLayout.gap, the VAC-A
    /// boundary convention), and the composition trailing ink edge
    /// (under trailing alignment the ink edge follows the frame).
    /// One pixel of movement fails: a frozen position moves by
    /// exactly zero.
    func testStandardBlockPositionsFreezeAcrossValueSweep() throws {
        let sweep: [(point: String, text: String, cpu: Double?, pressure: Double?, gpu: Double?)] = [
            ("0%", "0%", 0.0, 0.0, 0.0),
            ("5%", "5%", 0.05, 0.05, 0.05),
            ("10%", "10%", 0.10, 0.10, 0.10),
            ("50%", "50%", 0.50, 0.50, 0.50),
            ("99%", "99%", 0.99, 0.99, 0.99),
            ("1.0", "99%", 1.0, 1.0, 1.0),
            ("nil", "--%", nil, nil, nil),
        ]
        let gapPixels = MenuBarLayout.gap * scale
        for appearance in appearances {
            var frameWidths: [String: [(point: String, pixels: Double)]] = [:]
            var xOrigins: [String: [(point: String, pixels: Double)]] = [:]
            var trailingEdges: [String: [(point: String, pixels: Double)]] = [:]
            for point in sweep {
                let blocks = try standardTriple(
                    cpuPercent: point.cpu,
                    pressurePercent: point.pressure,
                    gpuPercent: point.gpu
                )
                let ordered: [(String, MenuBarBlock)] = [
                    ("CPU", blocks.cpu),
                    ("GPU", blocks.gpu),
                    ("MEM", blocks.mem),
                ]
                // VAC-C101 string integrity: every block must carry
                // the natural clip-99 string this sweep point
                // claims to measure. A padded T2 render (`000%`,
                // `100%`, `−−−%`) must never pass as a natural-text
                // position measurement.
                for (name, block) in ordered {
                    XCTAssertEqual(
                        block.valueText,
                        point.text,
                        """
                        VAC-C101 (\(point.point)): the \(name) block must \
                        carry the natural clip-99 string "\(point.text)" the \
                        position measurement claims to measure; found \
                        \(block.valueText)
                        """
                    )
                }
                // Single-block renders: the production frame widths
                // that place every following block's origin.
                var widths: [Double] = []
                for (name, block) in ordered {
                    let single = MenuBarRenderHarness.render(
                        MenuBarBlockView(block: block),
                        appearance: appearance
                    )
                    let width = Double(single.pixelsWide)
                    widths.append(width)
                    frameWidths[name, default: []].append(
                        (point: point.point, pixels: width)
                    )
                }
                // The production adjacency of all three standard
                // blocks: nested adjacent(…) keeps the same
                // MenuBarLayout.gap spacing at every boundary.
                let composition = MenuBarRenderHarness.render(
                    adjacent(
                        MenuBarBlockView(block: blocks.cpu),
                        adjacent(
                            MenuBarBlockView(block: blocks.gpu),
                            MenuBarBlockView(block: blocks.mem)
                        )
                    ),
                    appearance: appearance
                )
                var origin = 0.0
                for (index, (name, _)) in ordered.enumerated() {
                    xOrigins[name, default: []].append(
                        (point: point.point, pixels: origin)
                    )
                    // The trailing ink edge sits at a constant
                    // offset from the frame origin (same final
                    // glyph "%" in every sweep string), so it
                    // tracks the origin at pixel precision.
                    let regionStart = Int(origin)
                    let regionEnd = index == ordered.count - 1
                        ? composition.pixelsWide
                        : Int(origin + widths[index])
                    let trailing = try XCTUnwrap(
                        composition.rightmostInkX(
                            yRange: 0..<composition.pixelsHigh,
                            xRange: regionStart..<regionEnd,
                            threshold: inkThreshold
                        ),
                        """
                        VAC-101 (FM1): no ink for the \(name) block in region \
                        \(regionStart)..<\(regionEnd) under \
                        \(appearance.rawValue) at sweep \(point.point)
                        """
                    )
                    trailingEdges[name, default: []].append(
                        (point: point.point, pixels: Double(trailing))
                    )
                    origin += widths[index] + gapPixels
                }
            }
            for name in ["CPU", "MEM", "GPU"] {
                assertFrozenAcrossSweep(
                    frameWidths[name] ?? [],
                    block: name,
                    measure: "single-block frame width",
                    appearance: appearance
                )
                assertFrozenAcrossSweep(
                    xOrigins[name] ?? [],
                    block: name,
                    measure: "x-origin",
                    appearance: appearance
                )
                assertFrozenAcrossSweep(
                    trailingEdges[name] ?? [],
                    block: name,
                    measure: "trailing ink edge",
                    appearance: appearance
                )
            }
        }
    }

    /// VAC-C102/C103/C106 (plan 2026-10-25 T3, Appendix C §5;
    /// formerly VAC-A/VAC-D): both standard-block boundaries hold
    /// a minimal, uniform ink gap. Per band the gap measures, then
    /// the band minimum (closest approach) must sit in [10, 14] px at
    /// 2x, and the two boundaries' minima must differ by at most
    /// 1 px, under both forced appearances. VAC-C106 rides along:
    /// each
    /// block's line-1 and line-2 right ink stay within 1 px, so both
    /// rows remain flush to the trailing edge (2026-10-24 directive).
    func testStandardBlockGapsAreUniformAndMinimal() throws {
        let blocks = try builtBlocks()
        let boundaries: [(String, MenuBarBlock, MenuBarBlock)] = [
            ("CPU→GPU", blocks.cpu, blocks.gpu),
            ("GPU→MEM", blocks.gpu, blocks.mem),
        ]
        for appearance in appearances {
            var gapMinima: [Int] = []
            for (name, leftBlock, rightBlock) in boundaries {
                let boundary = MenuBarRenderHarness.render(
                    MenuBarBlockView(block: leftBlock),
                    appearance: appearance
                ).pixelsWide
                let bitmap = MenuBarRenderHarness.render(
                    adjacent(
                        MenuBarBlockView(block: leftBlock),
                        MenuBarBlockView(block: rightBlock)
                    ),
                    appearance: appearance
                )
                let gaps = try bandGaps(bitmap, boundary: boundary)
                let minimum = min(gaps.line1, gaps.line2)
                gapMinima.append(minimum)
                XCTAssertGreaterThanOrEqual(
                    Double(minimum),
                    minimalGapFloor,
                    """
                    VAC-A: \(name) closest-approach gap = \(minimum) px under \
                    \(appearance.rawValue) (line1 \(gaps.line1) px, line2 \
                    \(gaps.line2) px); the floor is MenuBarLayout.gap at 2x \
                    (10 px), never lowered.
                    """
                )
                XCTAssertLessThanOrEqual(
                    Double(minimum),
                    minimalGapCeiling,
                    """
                    VAC-A: \(name) closest-approach gap = \(minimum) px under \
                    \(appearance.rawValue) (line1 \(gaps.line1) px, line2 \
                    \(gaps.line2) px); the ceiling is 14 px (10 px token + \
                    glyph bearings), so a fixed 39 pt frame cannot come back.
                    """
                )
            }
            let uniformity = abs(gapMinima[0] - gapMinima[1])
            XCTAssertLessThanOrEqual(
                Double(uniformity),
                gapUniformityTolerance,
                """
                VAC-A: |gap(CPU→GPU) − gap(GPU→MEM)| = \(uniformity) px under \
                \(appearance.rawValue) (minima \(gapMinima)); both gaps must \
                be equal within 1 px at 2x.
                """
            )
        }

        // VAC-D = VAC-105 (trailing edge flushness): both rows of
        // each standard block stay flush to the trailing edge —
        // line-1 and line-2 right ink within 1 px.
        let standard: [(String, MenuBarBlock)] = [
            ("CPU", blocks.cpu),
            ("MEM", blocks.mem),
            ("GPU", blocks.gpu),
        ]
        for appearance in appearances {
            for (name, block) in standard {
                let bitmap = MenuBarRenderHarness.render(
                    MenuBarBlockView(block: block),
                    appearance: appearance
                )
                let line1Right = try XCTUnwrap(
                    bitmap.rightmostInkX(
                        yRange: line1,
                        xRange: 0..<bitmap.pixelsWide,
                        threshold: inkThreshold
                    ),
                    "VAC-D (FM1): no line-1 ink for \(name) under \(appearance.rawValue)"
                )
                let line2Right = try XCTUnwrap(
                    bitmap.rightmostInkX(
                        yRange: line2,
                        xRange: 0..<bitmap.pixelsWide,
                        threshold: inkThreshold
                    ),
                    "VAC-D (FM1): no line-2 ink for \(name) under \(appearance.rawValue)"
                )
                let delta = abs(line1Right - line2Right)
                XCTAssertLessThanOrEqual(
                    Double(delta),
                    trailingFlushTolerance,
                    """
                    VAC-D: \(name) line-1 vs line-2 right ink delta = \
                    \(delta) px under \(appearance.rawValue) (line1 \
                    \(line1Right) px, line2 \(line2Right) px); both rows must \
                    stay flush to the trailing edge within 1 px.
                    """
                )
            }
        }
    }

    /// VAC-C105 (plan 2026-10-25 T3, Appendix C §5; formerly
    /// VAC-B): extreme values never collide.
    /// `99%` everywhere (1.0 clamps) and `--%` everywhere (missing
    /// metrics), both boundaries, both appearances: the
    /// closest-approach floor stays ≥ 9 px at 2x — no ink merge
    /// (7 px under the 4 pt token plus the +2 px ripple of plan
    /// 2026-10-26-menubar-block-gap-5pt).
    /// The fixture string guard runs first: a padded T2 render
    /// must not pass as a natural-text extreme measurement.
    func testExtremeValuesKeepBlockGapsOpen() throws {
        let extremes: [(String, Double?, Double?, Double?)] = [
            ("99%", 1.0, 1.0, 1.0),
            ("--%", nil, nil, nil),
        ]
        for (valueLabel, cpuPercent, pressurePercent, gpuPercent) in extremes {
            let blocks = try standardTriple(
                cpuPercent: cpuPercent,
                pressurePercent: pressurePercent,
                gpuPercent: gpuPercent
            )
            // The fixture must carry the string the gap measurement
            // claims to measure (T3 contract, plan 2026-10-25
            // Appendix C): a render of the old padded (`100%`) or
            // `−−−%` strings must not pass as a natural-text
            // `99%`/`--%` measurement.
            for (name, block) in [
                ("CPU", blocks.cpu),
                ("MEM", blocks.mem),
                ("GPU", blocks.gpu),
            ] {
                XCTAssertEqual(
                    block.valueText,
                    valueLabel,
                    """
                    VAC-C105 (\(valueLabel)): the \(name) block must carry the \
                    \(valueLabel) string the gap measurement claims to measure; \
                    found \(block.valueText)
                    """
                )
            }
            let boundaries: [(String, MenuBarBlock, MenuBarBlock)] = [
                ("CPU→GPU", blocks.cpu, blocks.gpu),
                ("GPU→MEM", blocks.gpu, blocks.mem),
            ]
            for appearance in appearances {
                for (name, leftBlock, rightBlock) in boundaries {
                    let boundary = MenuBarRenderHarness.render(
                        MenuBarBlockView(block: leftBlock),
                        appearance: appearance
                    ).pixelsWide
                    let bitmap = MenuBarRenderHarness.render(
                        adjacent(
                            MenuBarBlockView(block: leftBlock),
                            MenuBarBlockView(block: rightBlock)
                        ),
                        appearance: appearance
                    )
                    let gaps = try bandGaps(bitmap, boundary: boundary)
                    let minimum = min(gaps.line1, gaps.line2)
                    XCTAssertGreaterThanOrEqual(
                        Double(minimum),
                        extremeGapFloor,
                        """
                        VAC-C105 (\(valueLabel)): \(name) closest-approach gap = \
                        \(minimum) px under \(appearance.rawValue) (line1 \
                        \(gaps.line1) px, line2 \(gaps.line2) px); the gaps must \
                        not merge below 9 px at 2x.
                        """
                    )
                    XCTAssertLessThanOrEqual(
                        Double(minimum),
                        extremeGapCeiling,
                        """
                        VAC-C105 (\(valueLabel)): \(name) closest-approach gap = \
                        \(minimum) px under \(appearance.rawValue) (line1 \
                        \(gaps.line1) px, line2 \(gaps.line2) px); the ceiling \
                        is 29 px (Appendix C §3: `--%` on CPU→GPU measures \
                        20–21 px after the 5 pt-token ripple), so a fixed \
                        wide frame cannot come back.
                        """
                    )
                }
            }
        }
    }

    /// VAC-C104 (plan 2026-10-25 T3, Appendix C §5): GPU
    /// single-digit gap floor. A hand-built GPU block carries the
    /// natural "0%" string, so the measurement runs on T3 contract
    /// text on every implementation (the T2 builder pads to
    /// "000%"). The GPU label row is 17.56 pt, narrower than the
    /// 18.66 pt value row, so the value row defines the block
    /// content width: frame gap 5 pt + leading slack 27.0 − 18.66
    /// = 8.34 pt → 13.34 pt = 26.68 px at 2x (the 5 pt token
    /// ripples the Appendix C §3 table's 25–26 px to 27–28 px,
    /// plan 2026-10-26-menubar-block-gap-5pt). VAC-C104 band:
    /// 25–29 px. On the T2 34 pt frame
    /// the same block renders ~39 px and fails the ceiling.
    func testSingleDigitGpuValueKeepsCpuToGpuGapInTwentyFiveToTwentyNinePixels() throws {
        let cpu = try standardTriple(
            cpuPercent: 0.45,
            pressurePercent: 0.50,
            gpuPercent: 0.32
        ).cpu
        let singleDigitGPU = MenuBarBlock(
            kind: .gpu,
            label: "GPU",
            dotState: nil,
            valueText: "0%",
            valueTint: .primary,
            width: MenuBarLayout.blockWidth
        )
        for appearance in appearances {
            let boundary = MenuBarRenderHarness.render(
                MenuBarBlockView(block: cpu),
                appearance: appearance
            ).pixelsWide
            let bitmap = MenuBarRenderHarness.render(
                adjacent(
                    MenuBarBlockView(block: cpu),
                    MenuBarBlockView(block: singleDigitGPU)
                ),
                appearance: appearance
            )
            let gaps = try bandGaps(bitmap, boundary: boundary)
            let minimum = min(gaps.line1, gaps.line2)
            XCTAssertGreaterThanOrEqual(
                Double(minimum),
                singleDigitGapFloor,
                """
                VAC-C104: CPU→GPU closest-approach gap = \(minimum) px under \
                \(appearance.rawValue) (line1 \(gaps.line1) px, line2 \
                \(gaps.line2) px); the single-digit band floor is 25 px at 2x.
                """
            )
            XCTAssertLessThanOrEqual(
                Double(minimum),
                singleDigitGapCeiling,
                """
                VAC-C104: CPU→GPU closest-approach gap = \(minimum) px under \
                \(appearance.rawValue) (line1 \(gaps.line1) px, line2 \
                \(gaps.line2) px); the single-digit band ceiling is 29 px at \
                2x (Appendix C §3: 27–28 px for "0%" in the 27 pt frame after \
                the 5 pt-token ripple).
                """
            )
        }
    }

    /// VAC-C107 (plan 2026-10-25 T3, Appendix C §5; formerly
    /// VAC-C): the production composition at the `length()` slot
    /// (95 pt under the 5 pt gap token, plan
    /// 2026-10-26-menubar-block-gap-5pt). The stacked view renders inside the fixed
    /// item length with a fresh monitor (no snapshot yet, so every
    /// block shows `--%`). The slot-fill geometry holds: the
    /// bitmap measures the full slot width, and each frame void at
    /// the slot edge stays ≤ 1 px — the block group fills the
    /// inner slot edge-to-edge (T2's ~15 px side voids
    /// eliminated). Frame voids come from production-derived frame
    /// widths: under trailing alignment the leftmost ink carries
    /// the CPU block's leading slack, which is frame geometry, not
    /// slot void. The cold-fixture gaps follow the Appendix C §3
    /// bitmap ink-gap table (CPU→GPU 18–19 px, GPU→MEM 12–13 px),
    /// and the group stays centered (≤ 2 px side delta).
    func testStackedItemCompositionFillsSlotEdgeToEdge() throws {
        let preferences = PreferencesStore()
        preferences.showCPU = true
        preferences.showRAM = true
        preferences.showGPU = true
        preferences.showNetwork = false
        preferences.showTemperature = false
        defer {
            // Restore the documented defaults for later tests; the
            // @AppStorage-backed store persists across tests.
            preferences.showCPU = true
            preferences.showRAM = true
            preferences.showGPU = true
            preferences.showNetwork = true
            preferences.showTemperature = true
        }
        let blocks = try standardTriple(
            cpuPercent: nil,
            pressurePercent: nil,
            gpuPercent: nil
        )
        let view = MenuBarStackedItemView(
            monitor: SystemMonitor(provider: FakeSystemMetricsProvider()),
            preferences: preferences
        )
        .frame(
            width: MenuBarLayout.length(
                showCPU: true,
                showRAM: true,
                showGPU: true
            )
        )
        let gapPixels = Int(MenuBarLayout.gap * scale)
        // The composition's root padding shifts every block, so the
        // boundaries include the leading padding term.
        let paddingPixels = Int(MenuBarLayout.padding * scale)
        for appearance in appearances {
            let bitmap = MenuBarRenderHarness.render(
                view,
                appearance: appearance
            )
            // The composition render must fill the fixed item
            // length: bitmap width == MenuBarLayout.length at 2x.
            XCTAssertEqual(
                bitmap.pixelsWide,
                Int(
                    MenuBarLayout.length(
                        showCPU: true,
                        showRAM: true,
                        showGPU: true
                    ) * scale
                ),
                """
                VAC-C107: the production composition render must fill the \
                MenuBarLayout.length slot at 2x under \
                \(appearance.rawValue).
                """
            )
            let cpuWidth = MenuBarRenderHarness.render(
                MenuBarBlockView(block: blocks.cpu),
                appearance: appearance
            ).pixelsWide
            let memWidth = MenuBarRenderHarness.render(
                MenuBarBlockView(block: blocks.mem),
                appearance: appearance
            ).pixelsWide
            // The root frame centers the block group in the slot, so
            // the group starts at padding + (inner slot − content)/2
            // and every boundary shifts with it (the leading padding
            // term alone was not enough — red-phase measurement).
            // Splits sit at the gap midpoints: a ±1 px drift in the
            // analytic group left cannot reach either ink edge (the
            // gap zone is 10 px wide).
            let gpuWidth = MenuBarRenderHarness.render(
                MenuBarBlockView(block: blocks.gpu),
                appearance: appearance
            ).pixelsWide
            let innerSlot = bitmap.pixelsWide - 2 * paddingPixels
            let content = cpuWidth + gapPixels + memWidth + gapPixels + gpuWidth
            let groupLeft = paddingPixels + (innerSlot - content) / 2
            // VAC-C107 frame voids: the padding-stripped space
            // between each slot inner edge and the block group's
            // frame edges, from production-derived frame widths.
            let leftVoid = groupLeft - paddingPixels
            let rightVoid = (bitmap.pixelsWide - paddingPixels)
                - (groupLeft + content)
            for (side, void) in [("left", leftVoid), ("right", rightVoid)] {
                XCTAssertLessThanOrEqual(
                    Double(void),
                    slotVoidCeiling,
                    """
                    VAC-C107: the \(side) slot void = \(void) px under \
                    \(appearance.rawValue) (slot \(bitmap.pixelsWide) px, \
                    content \(content) px); each frame void must not exceed \
                    1 px at 2x — the group fills the inner slot edge-to-edge.
                    """
                )
            }
            let delta = abs(leftVoid - rightVoid)
            XCTAssertLessThanOrEqual(
                Double(delta),
                voidDeltaTolerance,
                """
                VAC-C107: |leftVoid − rightVoid| = \(delta) px under \
                \(appearance.rawValue) (left \(leftVoid) px, right \
                \(rightVoid) px of \(bitmap.pixelsWide) px); the block group \
                must stay centered in the slot within 2 px.
                """
            )
            // Cold-fixture composition gaps per the Appendix C §3
            // bitmap ink-gap table rippled +2 px by the 5 pt token:
            // `--%` opens GPU→MEM to 14–15 px (MEM label-row floor)
            // and CPU→GPU to 20–21 px (the 22.42 pt placeholder in
            // the 27 pt frame), not the 2-digit 12–13 px band.
            let boundaries: [(String, Int, Double, Double)] = [
                (
                    "CPU→GPU",
                    groupLeft + cpuWidth + gapPixels / 2,
                    coldCpuGpuGapFloor,
                    coldCpuGpuGapCeiling
                ),
                (
                    "GPU→MEM",
                    groupLeft + cpuWidth + gapPixels + gpuWidth + gapPixels / 2,
                    coldGpuMemGapFloor,
                    coldGpuMemGapCeiling
                ),
            ]
            for (name, boundary, floor, ceiling) in boundaries {
                let gaps = try bandGaps(bitmap, boundary: boundary)
                let minimum = min(gaps.line1, gaps.line2)
                XCTAssertGreaterThanOrEqual(
                    Double(minimum),
                    floor,
                    """
                    VAC-C107: \(name) closest-approach gap = \(minimum) px \
                    under \(appearance.rawValue) (line1 \(gaps.line1) px, \
                    line2 \(gaps.line2) px); the cold-fixture band floor is \
                    \(floor) px (Appendix C §3).
                    """
                )
                XCTAssertLessThanOrEqual(
                    Double(minimum),
                    ceiling,
                    """
                    VAC-C107: \(name) closest-approach gap = \(minimum) px \
                    under \(appearance.rawValue) (line1 \(gaps.line1) px, \
                    line2 \(gaps.line2) px); the cold-fixture band ceiling is \
                    \(ceiling) px (Appendix C §3).
                    """
                )
            }

            let leftInk = try XCTUnwrap(
                bitmap.leftmostInkX(
                    yRange: 0..<bitmap.pixelsHigh,
                    xRange: 0..<bitmap.pixelsWide,
                    threshold: inkThreshold
                ),
                "VAC-C107 (FM1): no ink at all under \(appearance.rawValue)"
            )
            let rightInk = try XCTUnwrap(
                bitmap.rightmostInkX(
                    yRange: 0..<bitmap.pixelsHigh,
                    xRange: 0..<bitmap.pixelsWide,
                    threshold: inkThreshold
                ),
                "VAC-C107 (FM1): no ink at all under \(appearance.rawValue)"
            )
            // The ink span pins the analytic frame model to the
            // rendered bitmap: the leading ink sits inside the CPU
            // frame and the trailing ink hugs the MEM frame's
            // right edge, so the ≤ 1 px frame voids above cannot
            // come from a misplaced group.
            XCTAssertLessThan(
                Int(leftInk),
                paddingPixels + cpuWidth,
                """
                VAC-C107: leftmost ink at \(leftInk) px must sit inside the \
                CPU frame under \(appearance.rawValue).
                """
            )
            XCTAssertGreaterThan(
                Int(rightInk),
                bitmap.pixelsWide - paddingPixels - memWidth,
                """
                VAC-C107: rightmost ink at \(rightInk) px must sit inside the \
                MEM frame under \(appearance.rawValue).
                """
            )
        }
    }

    // MARK: - ISC-4 (VAC-18): top ink edge alignment

    /// ISC-4: the top ink edge of the CPU, MEM, and GPU labels and
    /// of the TEMP C label align within 0.4 px at 2x, under both
    /// forced appearances. Each standard block contributes the
    /// minimum edge across its whole line 1: the label tops win
    /// over the MEM pressure dot (which sits lower), and value-ink
    /// that ever reaches the band starts far below the label. The
    /// TEMP block contributes the leftmost line-1 cluster, the C
    /// label, because the 9 pt value digits carry a taller cap and
    /// a whole-line edge would measure the digits, not the label.
    func testTopInkEdgesAlignAcrossLabels() throws {
        let blocks = try builtBlocks()
        let standard: [(String, MenuBarBlock)] = [
            ("CPU", blocks.cpu),
            ("MEM", blocks.mem),
            ("GPU", blocks.gpu),
        ]
        for appearance in appearances {
            var edges: [String: Double] = [:]
            for (name, block) in standard {
                let bitmap = MenuBarRenderHarness.render(
                    MenuBarBlockView(block: block),
                    appearance: appearance
                )
                // Column 0 can carry a full-height black edge
                // column from the harness window (measured:
                // lum(0, *) = 0, lum(1, *) = 128 in fixedSize
                // single renders). It is never glyph ink — glyph
                // ink starts at x >= 16 — so the edge measurement
                // starts at column 1.
                let edge = try XCTUnwrap(
                    bitmap.subpixelTopInkY(
                        columns: 1..<bitmap.pixelsWide,
                        yRange: line1,
                        threshold: inkThreshold
                    ),
                    "ISC-4 (FM1): no sub-pixel top edge for \(name) under \(appearance.rawValue)"
                )
                edges[name] = edge
            }
            let tempBitmap = MenuBarRenderHarness.render(
                MenuBarTempBlockView(block: blocks.temp),
                appearance: appearance
            )
            let cCluster = try XCTUnwrap(
                tempBitmap.leftmostInkCluster(
                    yRange: line1,
                    // Column 1 mirrors the standard-block range above:
                    // the harness edge column at x = 0 is skipped.
                    xRange: 1..<tempBitmap.pixelsWide,
                    threshold: inkThreshold
                ),
                "ISC-4 (FM1): no C-label ink under \(appearance.rawValue)"
            )
            let cEdge = try XCTUnwrap(
                tempBitmap.subpixelTopInkY(
                    columns: cCluster,
                    yRange: line1,
                    threshold: inkThreshold
                ),
                "ISC-4 (FM1): no sub-pixel top edge for C under \(appearance.rawValue)"
            )
            edges["C"] = cEdge

            let maximum = try XCTUnwrap(edges.values.max())
            let minimum = try XCTUnwrap(edges.values.min())
            let spread = maximum - minimum
            XCTAssertLessThanOrEqual(
                spread,
                topEdgeTolerance,
                """
                ISC-4 (VAC-18): top ink edge spread = \(spread) px under \
                \(appearance.rawValue) (edges: \(edges)); CPU, MEM, GPU, and C \
                tops must align within 0.4 px.
                """
            )
        }
    }

    // MARK: - ISC-5 (FM3): both appearances and the luminance probe

    /// ISC-5: the suite runs under forced .darkAqua and .aqua on the
    /// hosting view, and the luminance probe proves the force took
    /// effect: TEMP value-text ink luminance must differ by at least
    /// 40 between the two renders. If the hosting view silently
    /// ignores the forced appearance, both renders carry the same
    /// luminance and this probe fails the suite.
    func testBothForcedAppearancesAndValueTextLuminanceProbe() throws {
        let blocks = try builtBlocks()
        var valueLuminance: [NSAppearance.Name: Double] = [:]
        for appearance in appearances {
            let bitmap = MenuBarRenderHarness.render(
                MenuBarTempBlockView(block: blocks.temp),
                appearance: appearance
            )
            let gCluster = try XCTUnwrap(
                bitmap.leftmostInkCluster(
                    yRange: line2,
                    xRange: 0..<bitmap.pixelsWide,
                    threshold: inkThreshold
                ),
                "ISC-5 (FM1): no G-label ink on line 2 under \(appearance.rawValue)"
            )
            let valueStart = try XCTUnwrap(
                (gCluster.upperBound..<bitmap.pixelsWide).first { x in
                    line2.contains { y in
                        bitmap.ink(x: x, y: y) >= inkThreshold
                    }
                },
                "ISC-5 (FM1): no value-text ink after the G label under \(appearance.rawValue)"
            )
            let mean = try XCTUnwrap(
                bitmap.meanInkLuminance(
                    columns: valueStart..<bitmap.pixelsWide,
                    yRange: line2,
                    threshold: inkThreshold
                ),
                "ISC-5 (FM1): no value-text ink pixels under \(appearance.rawValue)"
            )
            valueLuminance[appearance] = mean
        }

        let dark = try XCTUnwrap(
            valueLuminance[.darkAqua],
            "ISC-5: no luminance measured under forced .darkAqua"
        )
        let light = try XCTUnwrap(
            valueLuminance[.aqua],
            "ISC-5: no luminance measured under forced .aqua"
        )
        let delta = abs(dark - light)
        XCTAssertGreaterThanOrEqual(
            delta,
            appearanceLuminanceDelta,
            """
            ISC-5 (FM3): value-text luminance differed \(delta) between forced \
            .darkAqua (\(dark)) and .aqua (\(light)); the floor is 40, so the \
            forced appearance did not take effect.
            """
        )
        XCTAssertGreaterThan(
            dark,
            light,
            """
            ISC-5 (FM3): forced .darkAqua value text (\(dark)) must be lighter \
            than forced .aqua value text (\(light)); a reversed probe means the \
            appearance mapping is wrong.
            """
        )
    }

    // MARK: - Layer-3 (plan 2026-10-25, VAC-10): label luminance
    // delta under both forced appearances

    /// Layer-3 label probe (plan 2026-10-25-menubar-label-contrast,
    /// VAC-10): CPU label ink mean luminance must differ by at least
    /// the shared 40 floor between forced .darkAqua and .aqua, dark
    /// above light. On red code .secondary already adapts to the
    /// appearance, so the probe can pass — it then stands as the
    /// already-green regression net (D2 records its measured red
    /// delta), and ISC-7 below carries the guaranteed red.
    func testMenuBarLabelLuminanceDeltaUnderBothForcedAppearances() throws {
        let blocks = try builtBlocks()
        var labelLuminance: [NSAppearance.Name: Double] = [:]
        for appearance in appearances {
            let bitmap = MenuBarRenderHarness.render(
                MenuBarBlockView(block: blocks.cpu),
                appearance: appearance
            )
            // Measure CPU label ink luminance across line 1
            let mean = try XCTUnwrap(
                bitmap.meanInkLuminance(
                    columns: 1..<bitmap.pixelsWide,
                    yRange: line1,
                    threshold: inkThreshold
                ),
                "no CPU label ink under \(appearance.rawValue)"
            )
            labelLuminance[appearance] = mean
        }
        let dark = try XCTUnwrap(labelLuminance[.darkAqua])
        let light = try XCTUnwrap(labelLuminance[.aqua])
        let delta = abs(dark - light)
        XCTAssertGreaterThanOrEqual(
            delta,
            appearanceLuminanceDelta,
            """
            VAC-10 (Layer-3): label luminance delta \(delta) must meet or \
            exceed \(appearanceLuminanceDelta) between forced .darkAqua \
            (\(dark)) and .aqua (\(light)) label ink.
            """
        )
        XCTAssertGreaterThan(
            dark,
            light,
            """
            VAC-10 (Layer-3): dark appearance label ink (\(dark)) must be \
            lighter than light appearance ink (\(light)).
            """
        )
    }

    // MARK: - ISC-7 (plan 2026-10-25): dark-appearance label peak
    // pixel luminance floor — the guaranteed red of the plan's H0
    // falsification signature

    /// ISC-7 (plan 2026-10-25-menubar-label-contrast): the
    /// forced-.darkAqua render of MenuBarBlockView(block: cpu)
    /// through MenuBarRenderHarness must show CPU label peak pixel
    /// luminance (0-255 sRGB, line-1 label region over the fixed
    /// gray background) at or above the calibrated floor. The CPU
    /// block carries no dot, so line 1 holds only the label.
    /// Column 0 is the harness black edge column (ISC-4), so the
    /// scan starts at column 1. Red measures V_red (printed below,
    /// recorded in D2); T2 must clear the floor with
    /// Color.menuBarLabel or H0 is dead.
    func testMenuBarLabelPeakLuminanceUnderDarkAquaMeetsFloor() throws {
        let blocks = try builtBlocks()
        let bitmap = MenuBarRenderHarness.render(
            MenuBarBlockView(block: blocks.cpu),
            appearance: .darkAqua
        )
        var peak = 0.0
        for y in line1 {
            for x in 1..<bitmap.pixelsWide {
                let value = bitmap.luminance[y * bitmap.pixelsWide + x]
                if value > peak { peak = value }
            }
        }
        XCTAssertGreaterThanOrEqual(
            peak,
            darkAquaLabelPeakLuminanceFloor,
            """
            ISC-7 (plan 2026-10-25-menubar-label-contrast): CPU label peak \
            pixel luminance = \(peak) (0-255 sRGB) under forced .darkAqua \
            must reach the calibrated floor \
            \(darkAquaLabelPeakLuminanceFloor) (red V_red = \(peak), \
            green render prior ≈ 213, T = floor((V_red + 205) / 2)).
            """
        )
    }
}
