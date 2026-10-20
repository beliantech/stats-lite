//
//  GitHubReleaseSource.swift
//  StatsLite
//
//  Production release source: one GET to the GitHub latest-release
//  endpoint with a 15 s timeout. Any transport error or non-200
//  status returns nil; nil means silent no-op, no retry.
//

import Foundation

struct GitHubReleaseSource: UpdateReleaseSource {

    static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/beliantech/stats-lite-macos/releases/latest"
    )!

    func latestRelease() async -> ReleaseInfo? {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.timeoutInterval = 15
        request.setValue(
            "application/vnd.github.v3+json",
            forHTTPHeaderField: "Accept"
        )
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else { return nil }
            return try ReleaseInfo.decodeLatest(data: data)
        } catch {
            return nil
        }
    }
}
