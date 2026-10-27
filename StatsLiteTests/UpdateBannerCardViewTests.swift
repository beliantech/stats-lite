//
//  UpdateBannerCardViewTests.swift
//  StatsLiteTests
//
//  Banner copy and container contract (blueprint 2026-10-26 Parts 2
//  and 3, VAC-1/3/5/6/9): the primary action is "Install Update",
//  the old browser CTA is gone, and the accessibility/help labels
//  match the blueprint table. VAC-2: the popover shows the banner
//  only while an update is published. Strings come from a Mirror
//  walk of the view body. In the test host the LocalizedStringKey
//  interpolations store as "%@" format keys (same ground truth as
//  BrandStringTests), so interpolated pins accept either form. No
//  network, no Sparkle window.
//

import XCTest
@testable import StatsLite

/// Reflects every String (and LocalizedStringKey storage) reachable
/// from a view value tree.
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

/// Reflects every nested type name reachable from a view value
/// tree, so a container modifier (MetricCardStyle) is assertable.
private func collectTypeNames(_ root: Any) -> [String] {
    var result: [String] = []

    func walk(_ value: Any, depth: Int) {
        guard depth < 40 else { return }
        result.append(String(describing: type(of: value)))
        for child in Mirror(reflecting: value).children {
            walk(child.value, depth: depth + 1)
        }
    }

    walk(root, depth: 0)
    return result
}

/// UserDefaults dismissal key used by the popover-wiring test.
private let bannerDismissalKey = "updateCheckDismissedVersion"

@MainActor
final class UpdateBannerCardViewTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: bannerDismissalKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: bannerDismissalKey)
        super.tearDown()
    }

    private func makeBanner(
        version: String = "v2.0.0",
        handingOff: Bool = false
    ) -> UpdateBannerCardView {
        UpdateBannerCardView(
            updateVersion: version,
            isHandingOff: handingOff,
            onInstall: {},
            onDismiss: {}
        )
    }

    /// True when the strings hold every variant: the raw form and
    /// the "%@" format-key form the test host stores for
    /// interpolations.
    private func contains(
        _ strings: [String],
        anyOf variants: [String]
    ) -> Bool {
        variants.contains { strings.contains($0) }
    }

    // MARK: - Primary action (VAC-6, blueprint Part 1 decision 1)

    func testPrimaryActionCopyIsInstallUpdateWithNoBrowserCTA() {
        let strings = collectViewStrings(makeBanner().body)

        XCTAssertTrue(
            strings.contains("Install Update"),
            "the primary action must read 'Install Update'; found \(strings)"
        )
        XCTAssertFalse(
            strings.contains("View Release"),
            "the retired browser CTA must be gone; found \(strings)"
        )
        XCTAssertFalse(
            strings.contains { $0.contains("browser") },
            "no banner string may mention a browser; found \(strings)"
        )
        XCTAssertFalse(
            strings.contains { $0.contains("release page") },
            "no banner string may point at a release page; found \(strings)"
        )
    }

    // MARK: - Accessibility contract (VAC-9)

    func testAccessibilityLabelsMatchBlueprintPart2() {
        let strings = collectViewStrings(makeBanner().body)

        XCTAssertTrue(
            contains(
                strings,
                anyOf: [
                    "Update available. Stats Lite %@ is available.",
                    "Update available. Stats Lite v2.0.0 is available.",
                ]
            ),
            "VAC-9: the card container label must match; found \(strings)"
        )
        XCTAssertTrue(
            strings.contains("Dismiss update notification"),
            "VAC-9: the dismiss button label must match; found \(strings)"
        )
        XCTAssertTrue(
            contains(
                strings,
                anyOf: [
                    "Install Stats Lite %@",
                    "Install Stats Lite v2.0.0",
                ]
            ),
            "VAC-9: the install button label must match; found \(strings)"
        )
    }

    // MARK: - Help tooltips (VAC-4, blueprint Part 2)

    func testHelpTooltipsMatchBlueprintPart2() {
        let strings = collectViewStrings(makeBanner().body)

        XCTAssertTrue(
            strings.contains("Dismiss"),
            "VAC-4: the dismiss tooltip must read 'Dismiss'; found \(strings)"
        )
        XCTAssertTrue(
            contains(
                strings,
                anyOf: [
                    "Install Stats Lite %@",
                    "Install Stats Lite v2.0.0",
                ]
            ),
            "the install tooltip must carry the install label; found \(strings)"
        )
    }

    // MARK: - Header and body copy (VAC-3, VAC-5)

    func testHeaderAndBodyCopyMatchBlueprintPart2() {
        let strings = collectViewStrings(makeBanner().body)

        XCTAssertTrue(
            strings.contains("Update Available"),
            "VAC-3: the header title must read 'Update Available'; found \(strings)"
        )
        XCTAssertTrue(
            contains(
                strings,
                anyOf: [
                    "Stats Lite %@ is available.",
                    "Stats Lite v2.0.0 is available.",
                ]
            ),
            "VAC-5: the body text must match; found \(strings)"
        )
    }

    /// VAC-5 with a 16-character version tag: the same copy pattern
    /// renders the longer version without any alternate string.
    func testBodyCopyPatternHoldsForLongVersionTag() {
        let strings = collectViewStrings(
            makeBanner(version: "v10.12.34").body
        )

        XCTAssertTrue(
            contains(
                strings,
                anyOf: [
                    "Stats Lite %@ is available.",
                    "Stats Lite v10.12.34 is available.",
                ]
            ),
            "VAC-5: the body copy pattern must hold for a long tag; found \(strings)"
        )
    }

    // MARK: - Container (VAC-1)

    func testBannerUsesSharedMetricCardStyleContainer() {
        let types = collectTypeNames(makeBanner().body)

        XCTAssertTrue(
            types.contains { $0.contains("MetricCardStyle") },
            "VAC-1: the banner must sit in the shared MetricCardStyle container; "
                + "found types \(types)"
        )
    }

    // MARK: - Popover wiring (VAC-2)

    /// The popover shows the banner while the coordinator publishes
    /// an update, and the banner disappears once the version is
    /// dismissed. The walk reads stored view values (it never
    /// evaluates the nested banner's body), so banner presence is
    /// the banner's own stored updateVersion string.
    func testPopoverShowsBannerUntilVersionIsDismissed() {
        let service = UpdateCheckService(environment: [:])
        service.publishAvailableUpdate(
            displayVersion: "2.0.0",
            releaseNotesURL: URL(string: "https://example.com/releases/2.0.0")
        )

        func storedStrings() -> [String] {
            collectViewStrings(
                PopoverContentView(
                    monitor: SystemMonitor(),
                    preferences: PreferencesStore(),
                    updateChecker: service
                ).body
            )
        }

        XCTAssertTrue(
            storedStrings().contains("v2.0.0"),
            "VAC-2: a published update must mount the banner in the popover"
        )

        service.dismiss(version: "2.0.0")

        XCTAssertFalse(
            storedStrings().contains("v2.0.0"),
            "VAC-2: a dismissed version must remove the banner from the popover"
        )
    }
}
