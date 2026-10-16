// Resolves the CGWindowID of the open StatsLite popover window.
//
// Usage: swift scripts/windowid.swift
//
// Prints the window id of the frontmost on-screen StatsLite window
// with non-zero bounds. The popover window sits at layer 101 and has
// real bounds; the status bar item window can report zero-size
// bounds, so the bounds filter picks the popover. Exits 1 and prints
// nothing when no StatsLite window matches.

import CoreGraphics
import Foundation

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    FileHandle.standardError.write("CGWindowListCopyWindowInfo failed\n".data(using: .utf8)!)
    exit(1)
}

// The list is ordered front-to-back.
for window in list {
    guard let owner = window[kCGWindowOwnerName as String] as? String,
          owner == "StatsLite" else { continue }
    guard let number = window[kCGWindowNumber as String] as? NSNumber else { continue }
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = (bounds["Width"] as? NSNumber)?.doubleValue ?? 0
    let height = (bounds["Height"] as? NSNumber)?.doubleValue ?? 0
    if width > 0 && height > 0 {
        print(number.intValue)
        exit(0)
    }
}

exit(1)
