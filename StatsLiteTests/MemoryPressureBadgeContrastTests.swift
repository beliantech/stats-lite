//
//  MemoryPressureBadgeContrastTests.swift
//  StatsLiteTests
//
//  RED suite (plan 2026-10-27-memory-pressure-badge-contrast, T1):
//  WCAG 2.2 contrast of the Memory Pressure status pill badge. VAC-1
//  through VAC-7 require every state/appearance pair to reach at
//  least 4.5:1 between the badge text and the badge fill composited
//  over the card surface.
//
//  The test resolves `badgeTextColor`, `badgeBackgroundColor`, and
//  `badgeBorderColor` from DesignTokens.swift under each forced
//  appearance. It fails to compile until those tokens exist.
//
//  Color model: Core Graphics composites source-over on
//  gamma-encoded sRGB values, so the translucent fill composites
//  over the card surface in gamma space. WCAG relative luminance
//  then linearizes the composited channels. The card surface is
//  `NSColor.controlBackgroundColor` resolved under the same
//  appearance; the material backdrop behind the 0.65-opacity card
//  fill is not modeled, so the test fixes the surface determinis-
//  tically. Measured with the plan's nominal token values, every
//  pair clears 4.5:1 under both this surface and a 0.65-over-
//  windowBackgroundColor proxy surface (red-phase probe).
//

import XCTest
import SwiftUI
@testable import StatsLite

@MainActor
final class MemoryPressureBadgeContrastTests: XCTestCase {

    // MARK: - Color plumbing

    /// Gamma-encoded sRGB components of a color, resolved under a
    /// forced appearance. Fails the test when resolution fails.
    private func srgbComponents(
        of color: Color,
        appearance: NSAppearance.Name,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> (r: Double, g: Double, b: Double, a: Double) {
        var components: (r: Double, g: Double, b: Double, a: Double)?
        NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
            guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
            components = (Double(r), Double(g), Double(b), Double(a))
        }
        return try XCTUnwrap(
            components,
            "color did not resolve to sRGB under \(appearance.rawValue)",
            file: file,
            line: line
        )
    }

    /// sRGB channel to linear-light value (WCAG 2.2).
    private func linearize(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }

    /// Source-over composite of a translucent source over an
    /// opaque destination on gamma-encoded sRGB values, returned
    /// as linear-light channels.
    private func compositeGamma(
        src: (r: Double, g: Double, b: Double, a: Double),
        over dst: (r: Double, g: Double, b: Double, a: Double)
    ) -> (r: Double, g: Double, b: Double) {
        let a = src.a
        return (
            linearize(src.r * a + dst.r * (1 - a)),
            linearize(src.g * a + dst.g * (1 - a)),
            linearize(src.b * a + dst.b * (1 - a))
        )
    }

    /// WCAG 2.2 relative luminance of linear-light channels.
    private func relativeLuminance(
        _ rgb: (r: Double, g: Double, b: Double)
    ) -> Double {
        0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
    }

    /// WCAG 2.2 contrast ratio of two relative luminances.
    private func contrastRatio(_ luminance1: Double, _ luminance2: Double) -> Double {
        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - Shared assertion (VAC-1..VAC-7)

    /// Asserts one state/appearance pair:
    /// - the three badge tokens resolve under the appearance;
    /// - the text color is opaque;
    /// - when `nominalTextHex` is set, the text color matches the
    ///   plan's contrast-matrix hex within rounding;
    /// - the fill alpha matches the plan's opacity token;
    /// - text against fill-over-surface reaches 4.5:1.
    private func assertBadgeMeetsAA(
        state: MemoryPressureState,
        appearance: NSAppearance.Name,
        vac: String,
        nominalTextHex: (r: Int, g: Int, b: Int)? = nil,
        nominalFillAlpha: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let text = try srgbComponents(of: state.badgeTextColor, appearance: appearance, file: file, line: line)
        let fill = try srgbComponents(of: state.badgeBackgroundColor, appearance: appearance, file: file, line: line)
        // Resolving the border proves the token exists and yields a
        // visible stroke; border contrast has no numeric VAC.
        let border = try srgbComponents(of: state.badgeBorderColor, appearance: appearance, file: file, line: line)
        let surface = try srgbComponents(
            of: Color(nsColor: .controlBackgroundColor),
            appearance: appearance,
            file: file,
            line: line
        )

        XCTAssertEqual(
            text.a, 1.0, accuracy: 0.01,
            "\(vac): \(state.displayName) \(appearance.rawValue) badge text must be opaque",
            file: file, line: line
        )
        XCTAssertGreaterThan(
            border.a, 0.0,
            "\(vac): \(state.displayName) \(appearance.rawValue) badge border must be visible",
            file: file, line: line
        )

        if let nominal = nominalTextHex {
            let tolerance = 2.0 / 255.0
            XCTAssertEqual(
                text.r * 255.0, Double(nominal.r), accuracy: 255.0 * tolerance,
                "\(vac): \(state.displayName) \(appearance.rawValue) text red channel must match the plan matrix",
                file: file, line: line
            )
            XCTAssertEqual(
                text.g * 255.0, Double(nominal.g), accuracy: 255.0 * tolerance,
                "\(vac): \(state.displayName) \(appearance.rawValue) text green channel must match the plan matrix",
                file: file, line: line
            )
            XCTAssertEqual(
                text.b * 255.0, Double(nominal.b), accuracy: 255.0 * tolerance,
                "\(vac): \(state.displayName) \(appearance.rawValue) text blue channel must match the plan matrix",
                file: file, line: line
            )
        }

        XCTAssertEqual(
            fill.a, nominalFillAlpha, accuracy: 0.01,
            "\(vac): \(state.displayName) \(appearance.rawValue) badge fill alpha must be the plan token",
            file: file, line: line
        )

        let compositedFill = compositeGamma(src: fill, over: surface)
        let textLuminance = relativeLuminance((r: linearize(text.r), g: linearize(text.g), b: linearize(text.b)))
        let fillLuminance = relativeLuminance(compositedFill)
        let ratio = contrastRatio(textLuminance, fillLuminance)
        XCTAssertGreaterThanOrEqual(
            ratio, 4.5,
            String(
                format: "%@: %@ %@ badge contrast %.2f:1 is below 4.5:1 (text luminance %.3f, composited fill luminance %.3f)",
                vac, state.displayName, appearance.rawValue, ratio, textLuminance, fillLuminance
            ),
            file: file, line: line
        )
    }

    // MARK: - Harness self-check

    /// Proves the forced-appearance resolution is appearance-
    /// sensitive: a dynamic provider color must resolve to
    /// different channels under aqua and darkAqua. Without this
    /// probe, a silently static resolution would let the dark
    /// pairs reuse light values and pass vacuously.
    func testForcedAppearanceResolutionIsAppearanceSensitive() throws {
        let adaptive = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
                : NSColor(srgbRed: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        })
        let underAqua = try srgbComponents(of: adaptive, appearance: .aqua)
        let underDarkAqua = try srgbComponents(of: adaptive, appearance: .darkAqua)
        XCTAssertGreaterThan(
            underAqua.b, 0.5,
            "harness: dynamic color resolved under .aqua must take the light branch (blue)"
        )
        XCTAssertGreaterThan(
            underDarkAqua.r, 0.5,
            "harness: dynamic color resolved under .darkAqua must take the dark branch"
        )
    }

    // MARK: - VAC-1 / VAC-2: Warning (the reported defect)

    func testWarningBadgeMeetsAAInLightAppearance() throws {
        try assertBadgeMeetsAA(
            state: .warning,
            appearance: .aqua,
            vac: "VAC-1",
            nominalTextHex: (r: 132, g: 68, b: 0), // #844400
            nominalFillAlpha: 0.18
        )
    }

    func testWarningBadgeMeetsAAInDarkAppearance() throws {
        try assertBadgeMeetsAA(
            state: .warning,
            appearance: .darkAqua,
            vac: "VAC-2",
            nominalFillAlpha: 0.18
        )
    }

    // MARK: - VAC-3 / VAC-4: Normal

    func testNormalBadgeMeetsAAInLightAppearance() throws {
        try assertBadgeMeetsAA(
            state: .normal,
            appearance: .aqua,
            vac: "VAC-3",
            nominalTextHex: (r: 16, g: 108, b: 42), // #106C2A
            nominalFillAlpha: 0.15
        )
    }

    func testNormalBadgeMeetsAAInDarkAppearance() throws {
        try assertBadgeMeetsAA(
            state: .normal,
            appearance: .darkAqua,
            vac: "VAC-4",
            nominalFillAlpha: 0.15
        )
    }

    // MARK: - VAC-5 / VAC-6: Critical

    func testCriticalBadgeMeetsAAInLightAppearance() throws {
        try assertBadgeMeetsAA(
            state: .critical,
            appearance: .aqua,
            vac: "VAC-5",
            nominalTextHex: (r: 168, g: 23, b: 28), // #A8171C
            nominalFillAlpha: 0.18
        )
    }

    func testCriticalBadgeMeetsAAInDarkAppearance() throws {
        try assertBadgeMeetsAA(
            state: .critical,
            appearance: .darkAqua,
            vac: "VAC-6",
            nominalTextHex: (r: 255, g: 128, b: 128), // #FF8080
            nominalFillAlpha: 0.18
        )
    }

    // MARK: - VAC-7: Unknown

    func testUnknownBadgeMeetsAAInLightAppearance() throws {
        try assertBadgeMeetsAA(
            state: .unknown,
            appearance: .aqua,
            vac: "VAC-7",
            nominalTextHex: (r: 69, g: 69, b: 74), // #45454A
            nominalFillAlpha: 0.15
        )
    }

    func testUnknownBadgeMeetsAAInDarkAppearance() throws {
        try assertBadgeMeetsAA(
            state: .unknown,
            appearance: .darkAqua,
            vac: "VAC-7",
            nominalTextHex: (r: 184, g: 184, b: 189), // #B8B8BD
            nominalFillAlpha: 0.15
        )
    }
}
