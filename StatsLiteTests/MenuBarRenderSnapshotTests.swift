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

    /// ISC-3: inter-block ink gap target and tolerance in bitmap
    /// pixels at 2x (re-issued VAC-22/23, Addendum B: 21.0 px).
    private let interBlockGap: Double = 21
    private let interBlockGapTolerance: Double = 1

    /// ISC-4: top ink edge tolerance in bitmap pixels.
    private let topEdgeTolerance: Double = 0.4

    /// ISC-5: value-text luminance difference floor between the two
    /// forced appearances.
    private let appearanceLuminanceDelta: Double = 40

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

    /// ISC-6 + FM2/FM4: every render box measures exactly the
    /// production geometry at the pinned 2x scale — widths from
    /// MenuBarLayout, height 2 x rowHeight. The measurements in
    /// this suite verify production layout, not re-declared
    /// numbers.
    func testRenderDimensionsMatchProductionGeometry() throws {
        let blocks = try builtBlocks()
        let network = try networkBlock()
        let expectedHeight = Int(MenuBarLayout.rowHeight * scale * 2)
        let cases: [(String, MenuBarRenderHarness.Render, CGFloat)] = [
            (
                "temp",
                MenuBarRenderHarness.render(
                    MenuBarTempBlockView(block: blocks.temp),
                    appearance: .darkAqua
                ),
                MenuBarLayout.tempBlockWidth
            ),
            (
                "network",
                MenuBarRenderHarness.render(
                    MenuBarNetworkBlockView(block: network),
                    appearance: .darkAqua
                ),
                MenuBarLayout.networkBlockWidth
            ),
            (
                "cpu",
                MenuBarRenderHarness.render(
                    MenuBarBlockView(block: blocks.cpu),
                    appearance: .darkAqua
                ),
                MenuBarLayout.blockWidth
            ),
            (
                "mem",
                MenuBarRenderHarness.render(
                    MenuBarBlockView(block: blocks.mem),
                    appearance: .darkAqua
                ),
                MenuBarLayout.blockWidth
            ),
            (
                "gpu",
                MenuBarRenderHarness.render(
                    MenuBarBlockView(block: blocks.gpu),
                    appearance: .darkAqua
                ),
                MenuBarLayout.blockWidth
            ),
        ]
        for (name, bitmap, width) in cases {
            XCTAssertEqual(
                bitmap.pixelsWide,
                Int(width * scale),
                "ISC-6 (FM2/FM4): \(name) render width must be the MenuBarLayout width at 2x"
            )
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
            let networkColumns = networkStart..<bitmap.pixelsWide

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
                    xRange: networkColumns,
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
                    xRange: networkColumns,
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

    // MARK: - ISC-3 (VAC-22/23): inter-block ink gaps

    /// ISC-3 (re-issued VAC-22/23, Addendum B): the ink gaps
    /// between blocks measure 21 ±1 px at 2x. TEMP value right ink
    /// → red dot left ink crosses the TEMP↔NET boundary; GPU value
    /// right ink → C label left ink crosses the GPU↔TEMP boundary.
    /// Both pairs render in their production adjacency with the
    /// production gap, so the gap itself comes from production.
    /// Convention: the gap is the empty span between the two inks,
    /// from the first background column after one ink to the first
    /// inked column of the other (the sub-pixel edge-to-edge read
    /// of plan Addendum B).
    func testInterBlockInkGapsMeasureTwentyOnePixels() throws {
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
                "ISC-3 (FM1): no red-dot ink on line 1 of the \(appearance.rawValue) render"
            )
            let valueRightEdge = tempValueRight + 1
            XCTAssertEqual(
                Double(redDotLeft - valueRightEdge),
                interBlockGap,
                accuracy: interBlockGapTolerance,
                """
                ISC-3 (VAC-22): TEMP value right ink → red dot left ink = \
                \(redDotLeft - valueRightEdge) px under \(appearance.rawValue); \
                the re-issued gap is 21 ±1 px at 2x.
                """
            )

            let gpuTemp = MenuBarRenderHarness.render(
                adjacent(
                    MenuBarBlockView(block: blocks.gpu),
                    MenuBarTempBlockView(block: blocks.temp)
                ),
                appearance: appearance
            )
            let gpuEnd = Int(MenuBarLayout.blockWidth * scale)
            let gpuValueRight = try XCTUnwrap(
                gpuTemp.rightmostInkX(
                    yRange: line2,
                    xRange: 0..<gpuEnd,
                    threshold: inkThreshold
                ),
                "ISC-3 (FM1): no GPU value ink on line 2 of the \(appearance.rawValue) render"
            )
            let cLeft = try XCTUnwrap(
                gpuTemp.leftmostInkX(
                    yRange: line1,
                    xRange: gpuEnd..<gpuTemp.pixelsWide,
                    threshold: inkThreshold
                ),
                "ISC-3 (FM1): no C-label ink on line 1 of the \(appearance.rawValue) render"
            )
            let gpuValueRightEdge = gpuValueRight + 1
            XCTAssertEqual(
                Double(cLeft - gpuValueRightEdge),
                interBlockGap,
                accuracy: interBlockGapTolerance,
                """
                ISC-3 (VAC-23): GPU value right ink → C label left ink = \
                \(cLeft - gpuValueRightEdge) px under \(appearance.rawValue); \
                the re-issued gap is 21 ±1 px at 2x.
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
                let edge = try XCTUnwrap(
                    bitmap.subpixelTopInkY(
                        columns: 0..<bitmap.pixelsWide,
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
                    xRange: 0..<tempBitmap.pixelsWide,
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
}
