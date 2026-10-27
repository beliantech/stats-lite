//
//  StatusItemControllerPopoverTests.swift
//  StatsLiteTests
//
//  Popover lifecycle (plan Phase 1): init must not build the
//  hosting controller, the first open mounts it, a close releases
//  it, and a later open mounts a fresh one. The re-entrancy guard
//  must survive a rapid open/close pair without a crash.
//
//  Outside-click dismissal (plan 2026-10-21, Phase 2): the global
//  and local click monitors exist only while the popover is shown,
//  and handleLocalClickEvent(_:) passes clicks on the popover
//  window and the status-button window and closes on any other
//  window.
//

import AppKit
import XCTest
@testable import StatsLite

@MainActor
private final class InstallHandoffSparkleFake: SparkleUpdaterControlling {
    private(set) var isUpdaterRunning = false
    private(set) var checkForUpdatesCount = 0
    private(set) var checkForUpdatesInteractivelyCount = 0

    func checkForUpdates() {
        checkForUpdatesCount += 1
    }

    func checkForUpdatesInteractively() {
        checkForUpdatesInteractivelyCount += 1
    }
}

@MainActor
final class StatusItemControllerPopoverTests: XCTestCase {

    /// Drives the status button's private @objc action the same way
    /// AppKit does when the button is clicked.
    private func toggle(_ controller: StatusItemController) {
        controller.perform(Selector(("togglePopover:")), with: nil)
    }

    /// Runs the run loop for a fixed interval.
    private func spinRunLoop(for seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    /// Polls until the popover is onscreen.
    private func waitUntilShown(
        _ popover: NSPopover,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let shown = expectation(
            for: NSPredicate(format: "isShown == true"),
            evaluatedWith: popover
        )
        wait(for: [shown], timeout: 5)
        XCTAssertTrue(popover.isShown, file: file, line: line)
    }

    /// Polls until the popover drops its content controller, which
    /// only happens from popoverDidClose(_:).
    private func waitUntilContentReleased(
        _ popover: NSPopover,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let released = expectation(
            for: NSPredicate(format: "contentViewController == nil"),
            evaluatedWith: popover
        )
        wait(for: [released], timeout: 5)
        XCTAssertNil(popover.contentViewController, file: file, line: line)
    }

    /// Clicks once and confirms the popover is onscreen. The first
    /// show in the test host can race the status bar scene
    /// connection, so one retry click is allowed.
    private func open(
        _ controller: StatusItemController,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let popover = controller.popover
        toggle(controller)
        spinRunLoop(for: 0.2)
        if !popover.isShown {
            toggle(controller)
        }
        waitUntilShown(popover, file: file, line: line)
    }

    func testInitDoesNotMountPopoverContent() {
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        XCTAssertNil(
            controller.popover.contentViewController,
            "init must not create the hosting controller"
        )
    }

    /// AppKit dims the item on an unfocused display by drawing the
    /// replicant snapshot at alpha 0.5, but only when
    /// button.image != nil and the image is not template. A nil
    /// image makes the gate read "already styled" and the dim is
    /// skipped (docs/research/2026-10-21-status-item-inactive-dim.md).
    func test_statusItem_imageSetForInactiveDisplayDimEligibility() {
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        XCTAssertNotNil(
            controller.button?.image,
            "button.image must be non-nil so AppKit applies its inactive-display dim"
        )
        XCTAssertEqual(
            controller.button?.image?.isTemplate,
            false,
            "button.image must be non-template so AppKit's gate takes the dim path"
        )
    }

    func testTogglePopoverCyclesMountAndRelease() {
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        let popover = controller.popover
        // Close teardown must not depend on the display link: with the
        // display asleep, animated teardown never completes.
        popover.animates = false
        XCTAssertNil(popover.contentViewController)

        // Warm-up: let the test host connect the status bar scene
        // before the first show.
        let warm = expectation(description: "warm-up")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { warm.fulfill() }
        wait(for: [warm], timeout: 3)

        // First open mounts the hosting controller lazily.
        open(controller)
        let first = popover.contentViewController
        XCTAssertNotNil(first, "first open must mount the hosting controller")

        // Second click right after the open requests a close.
        toggle(controller)
        waitUntilContentReleased(popover)

        // Past the 0.25 s guard a reopen mounts a fresh controller.
        Thread.sleep(forTimeInterval: 0.35)
        open(controller)
        let second = popover.contentViewController
        XCTAssertNotNil(second, "reopen must remount the hosting controller")
        XCTAssertFalse(
            second === first,
            "each open cycle gets a fresh hosting controller"
        )

        toggle(controller)
        waitUntilContentReleased(popover)
    }

    /// T3b: an install handoff from the banner closes the popover
    /// through the normal close path (StatusItemController wires
    /// closePopover to performClose), so popoverDidClose runs its
    /// lifecycle: content released, highlight cleared. animates =
    /// false keeps the close deterministic while the display sleeps
    /// (same rule as testTogglePopoverCyclesMountAndRelease).
    func testInstallHandoffClosesPopoverThroughPopoverDidClose() {
        let updater = InstallHandoffSparkleFake()
        // activateApp stays a no-op: the test host must never steal
        // focus. closePopover starts as the default no-op so the
        // assertions prove the controller's own wiring.
        let service = UpdateCheckService(
            environment: [:],
            updater: updater,
            activateApp: {}
        )
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore(),
            updateChecker: service
        )
        let popover = controller.popover
        popover.animates = false

        warmUpStatusBar()
        open(controller)
        XCTAssertTrue(popover.isShown)

        service.installUpdate()

        waitUntilContentReleased(popover)
        XCTAssertFalse(
            popover.isShown,
            "T3b: the install handoff must close the popover"
        )
        XCTAssertEqual(
            controller.button?.isHighlighted,
            false,
            "the completed close must clear the button highlight"
        )
        XCTAssertEqual(
            updater.checkForUpdatesCount,
            1,
            "the handoff must still reach the Sparkle seam after closing"
        )
        XCTAssertTrue(
            service.isHandingOff,
            "the coordinator, not the view, owns the in-flight state"
        )
    }

    // MARK: - Outside-click dismissal monitors (plan Phase 2)

    /// Lets the test host connect the status bar scene before the
    /// first show. Same warm-up as
    /// testTogglePopoverCyclesMountAndRelease.
    private func warmUpStatusBar() {
        let warm = expectation(description: "warm-up")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { warm.fulfill() }
        wait(for: [warm], timeout: 3)
    }

    /// Builds a synthetic left mouse-down for a window number. The
    /// event resolves `window` through this process's window list,
    /// so a shown popover window or the status-bar window resolves
    /// to the live window object, and window number 0 resolves to a
    /// nil window.
    private func mouseDown(windowNumber: Int) -> NSEvent {
        NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }

    /// IC5: the monitors exist only while the popover is shown.
    /// init installs nothing, openPopover installs both tokens, and
    /// popoverDidClose removes both.
    func testClickMonitorsInstalledOnOpenAndRemovedOnClose() {
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        let popover = controller.popover
        popover.animates = false

        XCTAssertNil(
            controller.globalClickMonitor,
            "init must not install the global click monitor"
        )
        XCTAssertNil(
            controller.localClickMonitor,
            "init must not install the local click monitor"
        )

        warmUpStatusBar()
        open(controller)
        XCTAssertNotNil(
            controller.globalClickMonitor,
            "showing the popover must install the global click monitor"
        )
        XCTAssertNotNil(
            controller.localClickMonitor,
            "showing the popover must install the local click monitor"
        )

        toggle(controller)
        waitUntilContentReleased(popover)
        XCTAssertFalse(popover.isShown, "close must complete before the monitor check")
        XCTAssertNil(
            controller.globalClickMonitor,
            "popoverDidClose must remove the global click monitor"
        )
        XCTAssertNil(
            controller.localClickMonitor,
            "popoverDidClose must remove the local click monitor"
        )
    }

    /// FM3: a mouse-down inside the popover window passes through
    /// the local handler unchanged and never starts a close.
    func testLocalClickOnPopoverWindowPassesThroughWithoutClosing() {
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        let popover = controller.popover

        warmUpStatusBar()
        open(controller)

        guard
            let popoverWindow = popover.contentViewController?.view.window
        else {
            XCTFail("a shown popover must expose its content view window")
            return
        }
        let event = mouseDown(windowNumber: popoverWindow.windowNumber)
        XCTAssertTrue(
            event.window === popoverWindow,
            "probe: the synthetic event must resolve to the popover window"
        )

        let returned = controller.handleLocalClickEvent(event)
        XCTAssertTrue(
            returned === event,
            "FM3: an in-popover click must return the event unchanged"
        )
        XCTAssertTrue(
            popover.isShown,
            "FM3: an in-popover click must not close the popover"
        )
        XCTAssertNotNil(popover.contentViewController)
    }

    /// FM2: a mouse-down on the status-button window passes through
    /// the local handler unchanged, so togglePopover keeps the
    /// close/reopen sequence under its own control.
    func testLocalClickOnStatusButtonWindowPassesThroughWithoutClosing() {
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        let popover = controller.popover

        warmUpStatusBar()
        open(controller)

        guard let buttonWindow = controller.button?.window else {
            XCTFail("the status button must live in a window once shown")
            return
        }
        let event = mouseDown(windowNumber: buttonWindow.windowNumber)
        XCTAssertTrue(
            event.window === buttonWindow,
            "probe: the synthetic event must resolve to the status-button window"
        )

        let returned = controller.handleLocalClickEvent(event)
        XCTAssertTrue(
            returned === event,
            "FM2: a status-button click must return the event unchanged"
        )
        XCTAssertTrue(
            popover.isShown,
            "FM2: a status-button click must not close the popover"
        )
        XCTAssertNotNil(popover.contentViewController)
    }

    /// IC4/FM5: a mouse-down on any other window closes the
    /// popover through the normal close path and still returns the
    /// event. A second call while already closed must not crash and
    /// must not start a second close cycle.
    func testLocalClickOnOtherWindowClosesPopoverAndSecondCallIsSafe() {
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        let popover = controller.popover
        popover.animates = false

        warmUpStatusBar()
        open(controller)

        // A window that is neither the popover window nor the
        // status-button window.
        let otherWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        otherWindow.orderFront(nil)
        // releasedWhenClosed defaults to true: close() then consumes
        // an autorelease-pool reference and the test-scope pool pop
        // SIGSEGVs (reproduced on unmodified baseline app code, T3
        // receipt). Keep the release with ARC's local instead.
        otherWindow.isReleasedWhenClosed = false
        defer { otherWindow.close() }

        let event = mouseDown(windowNumber: otherWindow.windowNumber)
        XCTAssertFalse(
            event.window === popover.contentViewController?.view.window,
            "probe: the event must not resolve to the popover window"
        )
        XCTAssertFalse(
            event.window === controller.button?.window,
            "probe: the event must not resolve to the status-button window"
        )

        let returned = controller.handleLocalClickEvent(event)
        XCTAssertTrue(
            returned === event,
            "FM5: the handler returns the event after it triggers the close"
        )
        waitUntilContentReleased(popover)
        XCTAssertFalse(
            popover.isShown,
            "IC4: an other-window click must close the popover"
        )
        XCTAssertEqual(
            controller.button?.isHighlighted,
            false,
            "the completed close must clear the button highlight"
        )
        XCTAssertNil(popover.contentViewController)

        // Second call while closed: no crash, no double close.
        _ = controller.handleLocalClickEvent(
            mouseDown(windowNumber: otherWindow.windowNumber)
        )
        XCTAssertFalse(
            popover.isShown,
            "FM5: a closed popover must stay closed"
        )
        XCTAssertNil(
            popover.contentViewController,
            "FM5: the second call must not start another close cycle"
        )
        XCTAssertEqual(controller.button?.isHighlighted, false)
    }

    /// IC5: no monitor outlives the controller, in two parts.
    /// popoverDidClose removes both installed tokens, and the monitor
    /// blocks capture the controller weakly, so releasing a controller
    /// with monitors installed runs deinit, which removes them.
    ///
    /// Dealloc after an OPEN popover is not asserted: the same
    /// expectation fails on unmodified baseline app code (A/B receipt
    /// in the T3 report, 2026-10-22), so the open path pins the
    /// controller independently of the monitors.
    func testMonitorsDoNotOutliveController() {
        // Part one: a close through the normal path removes both
        // monitors.
        let controller = StatusItemController(
            monitor: SystemMonitor(),
            preferences: PreferencesStore()
        )
        controller.popover.animates = false
        warmUpStatusBar()
        open(controller)
        XCTAssertNotNil(
            controller.globalClickMonitor,
            "showing the popover must install the global monitor"
        )
        XCTAssertNotNil(
            controller.localClickMonitor,
            "showing the popover must install the local monitor"
        )
        toggle(controller)
        waitUntilContentReleased(controller.popover)
        XCTAssertNil(
            controller.globalClickMonitor,
            "popoverDidClose must remove the global monitor"
        )
        XCTAssertNil(
            controller.localClickMonitor,
            "popoverDidClose must remove the local monitor"
        )

        // Part two: the monitor blocks alone never retain the
        // controller, so deinit runs and removes them.
        weak var weakController: StatusItemController?
        do {
            let fresh = StatusItemController(
                monitor: SystemMonitor(),
                preferences: PreferencesStore()
            )
            warmUpStatusBar()
            fresh.installOutsideClickMonitors()
            XCTAssertNotNil(
                fresh.globalClickMonitor,
                "the install seam must register the global monitor"
            )
            XCTAssertNotNil(
                fresh.localClickMonitor,
                "the install seam must register the local monitor"
            )
            weakController = fresh
        }

        let deadline = Date().addingTimeInterval(5)
        while weakController != nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertNil(
            weakController,
            "monitor blocks must not retain the controller; deinit must run and remove the monitors"
        )
    }
}
