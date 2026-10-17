//
//  SparklineTimeAxisView.swift
//  StatsLite
//
//  Shared time axis row for all sparklines and metric graphs.
//  Renders the start duration on the leading edge and "Now" on the
//  trailing edge. 9 pt system font, monospaced digits, tertiary
//  foreground, hidden from the accessibility tree. No .animation or
//  .contentTransition.
//

import SwiftUI

/// Shared time axis row for all sparklines and metric graphs.
/// Renders the start duration on the leading edge and "Now" on the trailing edge.
struct SparklineTimeAxisView: View, Equatable {
    let duration: TimeInterval

    var body: some View {
        HStack {
            Text(MetricFormatters.historyDurationAxis(duration))
            Spacer()
            Text("Now")
        }
        .font(.system(size: 9, weight: .regular).monospacedDigit())
        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
        .accessibilityHidden(true)
    }
}
