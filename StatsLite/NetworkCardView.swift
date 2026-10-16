//
//  NetworkCardView.swift
//  StatsLite
//
//  Network Usage card: header row (network symbol + title + combined
//  rate), legend row (red Up / blue Down / Peak), 56 pt mirrored
//  chart, time axis row. Colors follow the menu-bar convention:
//  upload systemRed, download systemBlue. Loading state shows
//  -- KB/s, "Waiting for first sample", and a 38 pt placeholder.
//  Sampling off shows the dashed 38 pt container with a warning icon
//  and footnote (mirrors GPUCardView). No .animation or
//  .contentTransition anywhere in this view.
//

import SwiftUI

struct NetworkCardView: View {
    let monitor: SystemMonitor

    private var metrics: NetworkMetrics? { monitor.latestNetwork }

    private var uploadRate: Double? { metrics?.uploadBytesPerSecond }
    private var downloadRate: Double? { metrics?.downloadBytesPerSecond }

    private var totalRate: Double? {
        guard let metrics else { return nil }
        return metrics.uploadBytesPerSecond + metrics.downloadBytesPerSecond
    }

    /// Peak of both histories, in bytes per second. The 10 KB/s floor
    /// applies to the chart domain only, not to this display value.
    private var peakRate: Double {
        let uploadPeak = monitor.networkUploadHistory.values.max() ?? 0
        let downloadPeak = monitor.networkDownloadHistory.values.max() ?? 0
        return Swift.max(uploadPeak, downloadPeak)
    }

    /// Shared chart domain: peak with a 10 KB/s floor, so an idle
    /// link still renders a stable flat baseline.
    private var domainMax: Double { Swift.max(peakRate, 10 * 1024) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow

            if !monitor.isNetworkSampling {
                Text("Unavailable")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                dashedContainer
                Text("Sampling runs while Network Usage is on in Settings.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let metrics {
                legendRow(metrics: metrics)

                NetworkSparklineView(
                    downloadValues: monitor.networkDownloadHistory.values,
                    uploadValues: monitor.networkUploadHistory.values,
                    domainMax: domainMax,
                    capacity: monitor.networkSparklineCapacity
                )
                .equatable()

                axisRow
            } else {
                Text("Waiting for first sample")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                placeholderRect
            }
        }
        .metricCardStyle()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    // MARK: - Header row (~16 pt)

    private var headerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "network")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Network Usage")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(MetricFormatters.networkRate(totalRate))
                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(metrics == nil ? Color(nsColor: .tertiaryLabelColor) : Color.primary)
        }
    }

    // MARK: - Legend row (~14 pt): Up / Down / Peak on one line

    private func legendRow(metrics: NetworkMetrics) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(nsColor: .systemRed))
                    .frame(width: 6, height: 6)
                Text("Up: \(MetricFormatters.networkRate(metrics.uploadBytesPerSecond))")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(nsColor: .systemBlue))
                    .frame(width: 6, height: 6)
                Text("Down: \(MetricFormatters.networkRate(metrics.downloadBytesPerSecond))")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text("Peak: \(MetricFormatters.networkRate(peakRate))")
                .font(.system(size: 9.5).monospacedDigit())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Time axis row (~12 pt)

    private var axisRow: some View {
        HStack {
            Text("-\(Int(monitor.historyDuration))s")
            Spacer()
            Text("Now")
        }
        .font(.system(size: 9))
        .foregroundStyle(.tertiary)
    }

    // MARK: - Loading state (VAC-11): 38 pt placeholder rect

    private var placeholderRect: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(
                Color(nsColor: .separatorColor).opacity(0.6),
                lineWidth: 0.6
            )
            .frame(maxWidth: .infinity, minHeight: 38)
    }

    // MARK: - Unavailable state (VAC-12): 38 pt dashed container

    private var dashedContainer: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Network sampling is off")
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

    // MARK: - Accessibility (VAC-13)

    private var summary: String {
        guard let metrics else { return "Network usage unavailable" }
        return "Network usage: Upload \(MetricFormatters.networkRate(metrics.uploadBytesPerSecond)), "
            + "Download \(MetricFormatters.networkRate(metrics.downloadBytesPerSecond)), "
            + "Combined \(MetricFormatters.networkRate(totalRate)), "
            + "Peak \(MetricFormatters.networkRate(peakRate))"
    }
}
