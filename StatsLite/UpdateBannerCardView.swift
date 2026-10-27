//
//  UpdateBannerCardView.swift
//  StatsLite
//
//  Update notification card (blueprint 2026-10-26 Parts 2 and 3).
//  Three rows inside the shared .metricCardStyle() container: a
//  header (icon, "Update Available", dismiss), a single-line body,
//  and one primary "Install Update" action. The button disables at
//  0.6 opacity while the coordinator handoff (isHandingOff) is in
//  flight, so a second click cannot start a second handoff. No
//  browser path: Sparkle owns release notes. No .animation or
//  .contentTransition (status-item view rule).
//

import SwiftUI

struct UpdateBannerCardView: View {
    let updateVersion: String
    let isHandingOff: Bool
    let onInstall: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow
            bodyRow
            actionRow
        }
        .metricCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Update available. Stats Lite \(updateVersion) is available.")
    }

    // MARK: - Header Row (~18 pt)

    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.blue)

            Text("Update Available")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 4)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
            .accessibilityLabel("Dismiss update notification")
        }
    }

    // MARK: - Body Row (~14 pt)

    private var bodyRow: some View {
        Text("Stats Lite \(updateVersion) is available.")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    // MARK: - Action Row (~20 pt)

    private var actionRow: some View {
        HStack {
            Button {
                onInstall()
            } label: {
                Text("Install Update")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isHandingOff)
            .opacity(isHandingOff ? 0.6 : 1)
            .help("Install Stats Lite \(updateVersion)")
            .accessibilityLabel("Install Stats Lite \(updateVersion)")

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}
