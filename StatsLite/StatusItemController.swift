//
//  StatusItemController.swift
//  StatsLite
//
//  Custom NSStatusItem replaces MenuBarExtra, which flattens its
//  label into the status button title and cannot render the stacked
//  block layout. The button hosts a hitTest-nil NSHostingView with
//  MenuBarStackedItemView. The hosting view pins with frame-based
//  layout, not constraints: sizingOptions = [] and an autoresizing
//  mask of [.width, .height] track button.bounds, so a
//  statusItem.length change on a metric toggle resizes the view
//  with no clipping and no per-tick constraint churn. Clicks toggle a transient
//  NSPopover with the unchanged PopoverContentView. A 0.25 s
//  debounce on popoverDidClose stops the transient-reopen race: the
//  popover closes on the button's own click before the action fires,
//  so isShown alone would read false and reopen instantly. Outside
//  clicks need lifecycle-scoped NSEvent monitors, because `.transient`
//  never sees them in this non-activating agent.
//

import AppKit
import SwiftUI

/// Hosting view that lets clicks fall through to the status button.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {

    private let monitor: SystemMonitor
    private let preferences: PreferencesStore
    private let updateChecker: UpdateCheckService?
    private let statusItem: NSStatusItem

    /// Internal so popover lifecycle tests can inspect the mount.
    let popover: NSPopover

    /// systemUptime of the last popover close. togglePopover()
    /// ignores clicks inside the debounce window.
    private var lastCloseTimestamp: TimeInterval = 0

    /// Internal so popover lifecycle tests can assert install/remove.
    /// `nonisolated(unsafe)`: MainActor code writes the tokens, and
    /// only the nonisolated deinit reads them at final release.
    nonisolated(unsafe) var globalClickMonitor: Any?

    /// Internal so popover lifecycle tests can assert install/remove.
    /// `nonisolated(unsafe)` for the same reason as globalClickMonitor.
    nonisolated(unsafe) var localClickMonitor: Any?

    /// Internal so layout tests can inspect the hosting view.
    var button: NSStatusBarButton? { statusItem.button }

    /// Shared empty image that makes the item eligible for AppKit's
    /// inactive-display dim (see the call site in init).
    private static let emptyStatusImage = NSImage()

    init(
        monitor: SystemMonitor,
        preferences: PreferencesStore,
        updateChecker: UpdateCheckService? = nil
    ) {
        self.monitor = monitor
        self.preferences = preferences
        self.updateChecker = updateChecker
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: MenuBarLayout.length(
                showCPU: preferences.showCPU,
                showRAM: preferences.showRAM,
                showGPU: preferences.showGPU,
                showNetwork: preferences.showNetwork,
                showTemperature: preferences.showTemperature
            )
        )

        let popover = NSPopover()
        popover.behavior = .transient
        self.popover = popover

        super.init()

        popover.delegate = self

        guard let button else { return }
        let rootView = MenuBarStackedItemView(
            monitor: monitor,
            preferences: preferences,
            onPreferencesChange: { [weak self] in
                self?.updateItemLength()
                self?.updateAccessibility()
            },
            onSnapshotChange: { [weak self] in
                self?.updateAccessibility()
            }
        )
        let hostingView = PassthroughHostingView(rootView: rootView)
        // Frame-based layout only. sizingOptions = [] keeps the
        // hosting view from resizing to its intrinsic content; the
        // autoresizing mask follows button.bounds, so a
        // statusItem.length change resizes the view with no clipping
        // and no per-tick constraint churn (AC-11).
        hostingView.sizingOptions = []
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = button.bounds
        button.addSubview(hostingView)
        // AppKit's inactive-display dim pass draws the replicant
        // snapshot at 0.5 alpha only when button.image != nil and is
        // not template; a nil image makes the gate read "already
        // styled" and the dim is skipped. One shared empty
        // non-template image (zero pixels, no layout impact) makes
        // the item eligible. See
        // docs/research/2026-10-21-status-item-inactive-dim.md.
        button.image = Self.emptyStatusImage

        button.target = self
        button.action = #selector(togglePopover(_:))

        updateAccessibility()
    }

    // Removes the monitors at final release, so no monitor
    // outlives the controller (IC5).
    deinit {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }
    }

    // MARK: - Popover toggle

    @objc private func togglePopover(_ sender: Any?) {
        if ProcessInfo.processInfo.systemUptime - lastCloseTimestamp < 0.25 {
            return
        }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        openPopover()
    }

    private func openPopover() {
        guard let button else { return }
        button.isHighlighted = true
        // Mount only when about to show and no controller is held.
        // Keeps the hosting controller out of init so no popover
        // view evaluates while the popover stays closed.
        if popover.contentViewController == nil {
            popover.contentViewController = NSHostingController(
                rootView: PopoverContentView(
                    monitor: monitor,
                    preferences: preferences,
                    updateChecker: updateChecker
                )
            )
        }
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
        installOutsideClickMonitors()
    }

    // MARK: - Outside-click dismissal monitors

    /// Installs the global and local mouse-down monitors that close
    /// the shown popover. Any previous install is removed first, so
    /// one show cycle owns exactly one monitor pair.
    func installOutsideClickMonitors() {
        removeOutsideClickMonitors()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.popover.isShown else { return }
                self.removeOutsideClickMonitors()
                self.popover.performClose(nil)
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            self?.handleLocalClickEvent(event) ?? event
        }
    }

    /// Removes both click monitors. Called before every install and
    /// from popoverDidClose and deinit so no monitor outlives a shown
    /// popover or the controller.
    func removeOutsideClickMonitors() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
    }

    /// Local-monitor hook. Clicks on the popover window and on the
    /// status-button window pass through unchanged, so the transient
    /// behavior and togglePopover keep their own close/reopen
    /// sequence. Clicks on any other window remove the monitors and
    /// close the popover once. Always returns the event.
    func handleLocalClickEvent(_ event: NSEvent) -> NSEvent? {
        guard popover.isShown else { return event }
        if event.window === popover.contentViewController?.view.window
            || event.window === button?.window {
            return event
        }
        removeOutsideClickMonitors()
        guard popover.isShown else { return event }
        popover.performClose(nil)
        return event
    }

    // MARK: - Measurement support

    // Verification hook (T-E, plan 2026-10-23 screenshot evidence):
    // forces the popover itself into one appearance. NSApp.appearance
    // does not reach NSPopover windows (they attach to the system
    // status-bar window). Called only when the `--capture-appearance`
    // launch flag is present; nil restores inheritance. Test hook,
    // not a product feature.
    func applyCaptureAppearance(_ appearance: NSAppearance?) {
        popover.appearance = appearance
    }

    // measurement support: automated open/hold/close cycle for the
    // footprint harness (scripts/measure_popover_footprint.sh). Opens
    // ~1 s after launch, holds `holdSeconds`, closes through the normal
    // close path so popoverDidClose releases the content controller,
    // waits 2 s, repeats `cycles` times. Each event prints an epoch
    // timestamp the harness matches against its footprint samples.
    func startMeasurementCycle(cycles: Int, holdSeconds: Double) {
        guard cycles > 0 else { return }
        Task { @MainActor [weak self] in
            for cycle in 1...cycles {
                // First open 1 s after launch, later opens 2 s after
                // the previous close.
                let delay: UInt64 = cycle == 1 ? 1_000_000_000 : 2_000_000_000
                try? await Task.sleep(nanoseconds: delay)
                guard let self else { return }
                Self.log("cycle \(cycle)/\(cycles) open")
                self.openPopover()
                try? await Task.sleep(
                    nanoseconds: UInt64(max(holdSeconds, 0) * 1_000_000_000)
                )
                Self.log("cycle \(cycle)/\(cycles) close")
                self.popover.performClose(nil)
            }
            Self.log("cycles complete")
        }
    }

    // Each event writes an epoch-stamped line to stderr (unbuffered)
    // so the harness can match hook events against its samples.
    private static func log(_ message: String) {
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        let line = "[measurement] \(stamp) \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }

    func popoverDidClose(_ notification: Notification) {
        removeOutsideClickMonitors()
        // T5: every close path stops the lazy process sampler. This
        // delegate fires for outside-click and Escape dismissals too:
        // both call performClose and bypass togglePopover.
        monitor.stopProcessSampling()
        lastCloseTimestamp = ProcessInfo.processInfo.systemUptime
        button?.isHighlighted = false
        // Release the controller so no popover view evaluates while
        // closed. @State in PopoverContentView (coresExpanded) resets
        // on close by design.
        popover.contentViewController = nil
    }

    // MARK: - Observation targets (plan Task 6)

    /// Resizes the status item to the enabled-metrics permutation.
    /// The stacked view calls this when preferences change.
    func updateItemLength() {
        statusItem.length = MenuBarLayout.length(
            showCPU: preferences.showCPU,
            showRAM: preferences.showRAM,
            showGPU: preferences.showGPU,
            showNetwork: preferences.showNetwork,
            showTemperature: preferences.showTemperature
        )
    }

    /// Re-arms the VoiceOver label on the button. The hosting view
    /// is hitTest-nil, so the SwiftUI side is hidden from VoiceOver.
    /// The stacked view calls this when preferences or the snapshot
    /// change. Same value paths and pressure derivation the old
    /// MenuBarItemView used.
    func updateAccessibility() {
        button?.setAccessibilityElement(true)
        button?.setAccessibilityTitle("Stats Lite")
        button?.setAccessibilityLabel(compositeLabel)
    }

    /// "Stats Lite: CPU 14 percent, Memory Pressure Normal at 25
    /// percent, GPU 28 percent, Network Upload 10 KB/s, Download 720
    /// KB/s" from the latest snapshot and network pass.
    private var compositeLabel: String {
        let snapshot = monitor.latestSnapshot
        let pressure = snapshot?.memoryPressure
        let pressureState = (pressure?.state ?? .unknown)
            .displayState(pressure: pressure?.pressurePercentage ?? 0)
        return MenuBarAccessibility.compositeLabel(
            showCPU: preferences.showCPU,
            showRAM: preferences.showRAM,
            showGPU: preferences.showGPU,
            showNetwork: preferences.showNetwork,
            cpuPercent: snapshot?.cpu?.totalUsage,
            pressurePercent: pressure?.pressurePercentage,
            pressure: pressureState,
            gpuPercent: snapshot?.gpu?.deviceUtilization,
            downloadRate: monitor.latestNetwork?.downloadBytesPerSecond,
            uploadRate: monitor.latestNetwork?.uploadBytesPerSecond
        )
    }
}
