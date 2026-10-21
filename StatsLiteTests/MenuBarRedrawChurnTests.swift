//
//  MenuBarRedrawChurnTests.swift
//  StatsLiteTests
//
//  Plan Phase 5 (AC-11 support): the status item view path must not
//  carry .contentTransition or .animation modifiers. Those modifiers
//  keep RenderBox re-rasterizing glyphs at AppKit's UpdateCycle
//  quantum (~205 redraws/s) even when the digits do not change. The
//  checks walk the SwiftUI value tree with Mirror and reject any
//  modifier type name that mentions Animation or ContentTransition.
//  The hosting-view checks pin frame-based layout: empty
//  sizingOptions, autoresizing mask, no constraints, frame that
//  follows the status button across statusItem.length changes.
//

import AppKit
import SwiftUI
import XCTest
@testable import StatsLite

@MainActor
final class MenuBarRedrawChurnTests: XCTestCase {

    // MARK: - Mirror walk helpers

    /// Runtime type names of every value in a view body tree.
    /// Function-typed children (action closures, ForEach content
    /// closures) are skipped: they hold no modifier metadata.
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
            appendTypeNames(
                childMirror,
                into: &names,
                depth: depth + 1
            )
        }
    }

    /// Guards the walk against vacuous passes: the tree must contain
    /// a minimum number of nodes and the expected stack container.
    private func assertTreeIsPopulated(
        _ names: [String],
        containing container: String,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThan(
            names.count,
            8,
            "\(context): only \(names.count) nodes; the walk found nothing to check",
            file: file,
            line: line
        )
        XCTAssertTrue(
            names.contains { $0.contains(container) },
            "\(context): expected a \(container) node in the tree; got \(names.joined(separator: ", "))",
            file: file,
            line: line
        )
    }

    private func assertNoAnimatedModifiers(
        in names: [String],
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let banned = names.filter { name in
            name.localizedCaseInsensitiveContains("animation")
                || name.localizedCaseInsensitiveContains("contenttransition")
        }
        XCTAssertTrue(
            banned.isEmpty,
            "\(context): status item views must not use .animation or .contentTransition; found \(banned.joined(separator: ", "))",
            file: file,
            line: line
        )
    }

    // MARK: - View tree: no animation, no contentTransition

    func testStackedItemBodyHasNoAnimationOrContentTransition() {
        let view = MenuBarStackedItemView(
            monitor: SystemMonitor(provider: FakeSystemMetricsProvider()),
            preferences: PreferencesStore()
        )

        let names = typeTreeNames(of: view.body)
        assertTreeIsPopulated(
            names,
            containing: "HStack",
            context: "MenuBarStackedItemView.body"
        )
        assertNoAnimatedModifiers(
            in: names,
            context: "MenuBarStackedItemView.body"
        )
    }

    func testMenuBarBlockViewBodyHasNoAnimation() {
        let blocks = MenuBarBlockBuilder.blocks(
            showCPU: true,
            showRAM: true,
            showGPU: true,
            cpuPercent: 0.14,
            pressurePercent: 0.25,
            pressureState: .normal,
            gpuPercent: 0.28
        )
        XCTAssertEqual(blocks.count, 3, "the walk needs a dot block and two plain blocks")

        for block in blocks {
            let names = typeTreeNames(of: MenuBarBlockView(block: block).body)
            assertTreeIsPopulated(
                names,
                containing: "VStack",
                context: "MenuBarBlockView(\(block.label)).body"
            )
            assertNoAnimatedModifiers(
                in: names,
                context: "MenuBarBlockView(\(block.label)).body"
            )
        }
    }

    // MARK: - Frame-based hosting view

    private func hostingView(
        of controller: StatusItemController
    ) -> PassthroughHostingView<MenuBarStackedItemView>? {
        controller.button?.subviews
            .compactMap { $0 as? PassthroughHostingView<MenuBarStackedItemView> }
            .first
    }

    func testHostingViewUsesFrameBasedLayoutWithoutSizingOptions() {
        let controller = StatusItemController(
            monitor: SystemMonitor(provider: FakeSystemMetricsProvider()),
            preferences: PreferencesStore()
        )
        guard let button = controller.button,
              let hosting = hostingView(of: controller) else {
            XCTFail("the status button must host a PassthroughHostingView<MenuBarStackedItemView>")
            return
        }

        XCTAssertEqual(
            hosting.sizingOptions,
            [],
            "sizingOptions = [] stops the hosting view from driving its own size"
        )
        XCTAssertTrue(
            hosting.translatesAutoresizingMaskIntoConstraints,
            "frame-based layout must not translate the autoresizing mask into constraints"
        )
        XCTAssertEqual(
            hosting.autoresizingMask,
            [.width, .height],
            "the view must stretch with the button"
        )
        // AppKit/SwiftUI internals hold single-item centering
        // constraints for their private drawing views (CGDrawingView,
        // _NSGraphicsView) once a layout pass runs; setting
        // button.image for the inactive-display dim triggers that
        // pass. The invariant is that no constraint pins the
        // hosting view itself: our pin stays frame math.
        let ours = hosting.constraints.filter {
            $0.firstItem === hosting || $0.secondItem === hosting
        }
        XCTAssertTrue(
            ours.isEmpty,
            "the hosting view must pin with frame math, not constraints"
        )
        XCTAssertEqual(
            hosting.frame,
            button.bounds,
            "the hosting view fills the button at init"
        )
    }

    func testHostingViewTracksButtonBoundsAcrossLengthChanges() {
        let preferences = PreferencesStore()
        let controller = StatusItemController(
            monitor: SystemMonitor(provider: FakeSystemMetricsProvider()),
            preferences: preferences
        )
        guard let button = controller.button,
              let hosting = hostingView(of: controller) else {
            XCTFail("the status button must host a PassthroughHostingView<MenuBarStackedItemView>")
            return
        }
        defer {
            preferences.showGPU = true
            controller.updateItemLength()
        }

        preferences.showGPU = false
        controller.updateItemLength()
        assertFrameMatchesButton(hosting, button, context: "GPU off")

        preferences.showGPU = true
        controller.updateItemLength()
        assertFrameMatchesButton(hosting, button, context: "GPU back on")
    }

    private func assertFrameMatchesButton(
        _ hosting: NSView,
        _ button: NSView,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            hosting.frame.origin.x,
            button.bounds.origin.x,
            accuracy: 0.5,
            "\(context): hosting x",
            file: file,
            line: line
        )
        XCTAssertEqual(
            hosting.frame.origin.y,
            button.bounds.origin.y,
            accuracy: 0.5,
            "\(context): hosting y",
            file: file,
            line: line
        )
        XCTAssertEqual(
            hosting.frame.width,
            button.bounds.width,
            accuracy: 0.5,
            "\(context): hosting width (no clipping)",
            file: file,
            line: line
        )
        XCTAssertEqual(
            hosting.frame.height,
            button.bounds.height,
            accuracy: 0.5,
            "\(context): hosting height (no clipping)",
            file: file,
            line: line
        )
    }
}
