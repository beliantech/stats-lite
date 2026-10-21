//
//  UpdateBannerCardView.swift
//  StatsLite
//
//  Tier 1 in-app update notification card. Displays update title,
//  new version label, release link button, and dismiss button.
//

import AppKit
import SwiftUI

struct UpdateBannerCardView: View {
    let updateVersion: String
    let releaseURL: URL
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
                NSWorkspace.shared.open(releaseURL)
                onDismiss()
            } label: {
                Text("View Release")
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
            .help("Open release page in default browser")
            .accessibilityLabel("View release page for Stats Lite \(updateVersion) in browser")

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}
