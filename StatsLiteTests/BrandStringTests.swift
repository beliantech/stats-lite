//
//  BrandStringTests.swift
//  StatsLiteTests
//
//  Plan 2026-10-22-visible-ui-copy-stats-lite-spacing (red): pin
//  every user-visible brand string to "Stats Lite" (with space).
//  The popover header title, the quit tooltip, the update banner
//  strings, and the status item VoiceOver title are pinned through
//  the mechanisms the suite already uses: Mirror reflection over
//  the view body (SettingsWindowTests pattern) and a runtime read
//  of the status button's accessibility title. This red commit
//  fails on all four surfaces while production still writes
//  "StatsLite" (no space). IC1, IC2, IC4, IC6; VAC-1, VAC-3,
//  VAC-6, VAC-8, VAC-9.
//

import AppKit
import SwiftUI
import XCTest
@testable import StatsLite

@MainActor
final class BrandStringTests: XCTestCase {

    /// Every String stored anywhere in a SwiftUI view value tree,
    /// found via Mirror. Same walk as
    /// SettingsWindowTests.collectViewStrings; private to this
    /// file, so the names do not collide.
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

    /// The reflected strings that mention the product name, so a
    /// failure message quotes the exact values production produced.
    private func brandStrings(in view: some View) -> [String] {
        collectViewStrings(view.body)
            .filter { $0.contains("Stats") }
    }

    // MARK: - Popover header title (IC1, VAC-1)

    func testPopoverHeaderBrandTextReadsStatsLite() {
        let strings = brandStrings(
            in: PopoverContentView(
                monitor: SystemMonitor(),
                preferences: PreferencesStore()
            )
        )
        XCTAssertTrue(
            strings.contains("Stats Lite"),
            """
            IC1: the popover header title must read 'Stats Lite' \
            (with space); found brand strings \(strings).
            """
        )
    }

    // MARK: - Quit tooltip (IC2, VAC-3)

    func testQuitTooltipReadsQuitStatsLite() {
        let strings = brandStrings(
            in: PopoverContentView(
                monitor: SystemMonitor(),
                preferences: PreferencesStore()
            )
        )
        XCTAssertTrue(
            strings.contains("Quit Stats Lite"),
            """
            IC2: the power-button tooltip must read 'Quit Stats Lite'; \
            found brand strings \(strings).
            """
        )
    }

    // MARK: - Status item VoiceOver title (IC4, VAC-6)

    func testStatusItemAccessibilityTitleReadsStatsLite() {
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        let title = controller.button?.accessibilityTitle()
        XCTAssertEqual(
            title,
            "Stats Lite",
            """
            IC4: the status item VoiceOver title must read 'Stats Lite'; \
            got \(title.map { "'\($0)'" } ?? "nil").
            """
        )
    }

    // MARK: - Update banner (IC6, VAC-8, VAC-9)
    //
    // Inside the test-host app the LocalizedStringKey strings are
    // stored as format keys with %@ where the version interpolates
    // (a bare script process flattens instead; the test host is the
    // ground truth). The pins below match the format form, so the
    // red shows 'StatsLite %@' and green needs 'Stats Lite %@'.

    /// The banner with a fixture version, same v1.4.0 the update
    /// source tests use.
    private var banner: UpdateBannerCardView {
        UpdateBannerCardView(
            updateVersion: "v1.4.0",
            isHandingOff: false,
            onInstall: {},
            onDismiss: {}
        )
    }

    func testUpdateBannerA11yLabelReadsStatsLite() {
        let strings = brandStrings(in: banner)
        XCTAssertTrue(
            strings.contains("Update available. Stats Lite %@ is available."),
            """
            IC6: the banner accessibility label format must read \
            'Update available. Stats Lite %@ is available.'; \
            found brand strings \(strings).
            """
        )
    }

    func testUpdateBannerBodyTextReadsStatsLite() {
        let strings = brandStrings(in: banner)
        XCTAssertTrue(
            strings.contains("Stats Lite %@ is available."),
            """
            IC6: the banner body text format must read \
            'Stats Lite %@ is available.'; \
            found brand strings \(strings).
            """
        )
    }

    func testUpdateBannerInstallButtonLabelReadsStatsLite() {
        let strings = brandStrings(in: banner)
        XCTAssertTrue(
            strings.contains("Install Stats Lite %@"),
            """
            IC6: the install-button accessibility label format must read \
            'Install Stats Lite %@'; found brand strings \(strings).
            """
        )
    }
}
