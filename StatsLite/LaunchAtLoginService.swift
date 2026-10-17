//
//  LaunchAtLoginService.swift
//  StatsLite
//
//  Launch-at-login via SMAppService.mainApp. Every call performs one
//  status check or one register/unregister action. `.requiresApproval`
//  maps to its own state: the app shows a hint and never retries.
//

import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginService {

    /// Login-item state. `approvalNeeded` means macOS waits for the
    /// user in System Settings; the app must not call register again.
    enum State: Equatable {
        case enabled
        case disabled
        case approvalNeeded
        case notRegistered
        case unavailable(String)
    }

    /// Current state. Call `refresh()` after the app returns from
    /// System Settings, because the user can change the state there.
    private(set) var state: State = .notRegistered

    /// Message from the last failed register or unregister call.
    /// Nil after a successful call.
    private(set) var errorMessage: String?

    init() {
        refresh()
    }

    /// Reads `SMAppService.mainApp.status` once and maps it.
    func refresh() {
        state = Self.map(SMAppService.mainApp.status)
    }

    /// Registers the app as a login item. A thrown error becomes
    /// `errorMessage`; the state changes only on the next `refresh()`.
    func register() {
        do {
            try SMAppService.mainApp.register()
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    /// Removes the app from login items.
    func unregister() {
        do {
            try SMAppService.mainApp.unregister()
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    /// Opens System Settings > General > Login Items. This is a user
    /// action. The app polls nothing after this call.
    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func map(_ status: SMAppService.Status) -> State {
        switch status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .approvalNeeded
        case .notRegistered:
            return .notRegistered
        case .notFound:
            // Measured 2026-10-17 (macOS 26/27): a fresh app reports
            // `.notFound` before its first registration, and a probe-measured
            // `register()` succeeds from that state. Treat it as registerable.
            return .notRegistered
        @unknown default:
            return .unavailable("Unknown login item status")
        }
    }
}
