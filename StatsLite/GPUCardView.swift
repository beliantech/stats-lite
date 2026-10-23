//
//  GPUCardView.swift
//  StatsLite
//
//  GPU card per extension blueprint §2. Available state: header value,
//  38 pt teal sparkline. Unavailable state: --% value, dashed
//  container with warning icon, caveat footnote.
//

import SwiftUI

struct GPUCardView: View {
    let monitor: SystemMonitor

    private var gpu: GPUMetrics? { monitor.latestSnapshot?.gpu }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("GPU Usage")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                value
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary)

            if gpu != nil {
                SparklineView(
                    values: monitor.gpuHistory.values,
                    tintColor: .teal,
                    capacity: monitor.sparklineCapacity
                )
                .equatable()

                SparklineTimeAxisView(duration: monitor.historyDuration).equatable()
            } else {
                Text("Unavailable")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                dashedContainer
                Text("Sampling requires Apple Silicon or supported Metal driver.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .metricCardStyle()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header value

    private var value: some View {
        Text(MetricFormatters.percentTenth(gpu?.deviceUtilization))
            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(gpu == nil ? Color(nsColor: .tertiaryLabelColor) : Color.primary)
    }

    // MARK: - Unavailable state (VAC-19): 38 pt dashed container

    private var dashedContainer: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("GPU metrics unavailable on this hardware")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(
                    Color(nsColor: .separatorColor).opacity(0.6),
                    style: StrokeStyle(lineWidth: 0.6, dash: [4, 4])
                )
        )
    }

    // MARK: - Derived state

    private var summary: String {
        guard let gpu else {
            return "GPU metrics unavailable on this hardware. Sampling requires Apple Silicon or supported Metal driver."
        }
        let percent = Int((gpu.deviceUtilization * 100).rounded())
        return "GPU usage is \(percent) percent."
    }
}
