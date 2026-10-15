import CoreGraphics
import Foundation

enum WindowSelectionEngine {
    struct Match {
        let ownerName: String
        let windowNumber: Int
        let bounds: CGRect
        let rank: Int

        var centerPoint: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
    }

    static func fuzzyMatch(query: String, in windows: [[String: Any]]) -> [Match] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        var matches: [Match] = []
        for window in windows {
            guard let owner = window[kCGWindowOwnerName as String] as? String, !owner.isEmpty,
                  let bounds = boundsRect(for: window) else { continue }
            let name = owner.lowercased()
            let rank: Int
            if name.hasPrefix(needle) {
                rank = 0
            } else if name.contains(needle) {
                rank = 1
            } else {
                continue
            }
            matches.append(Match(ownerName: owner, windowNumber: windowNumber(window), bounds: bounds, rank: rank))
        }
        matches.sort { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            let order = a.ownerName.localizedStandardCompare(b.ownerName)
            if order != .orderedSame { return order == .orderedAscending }
            return a.windowNumber < b.windowNumber
        }
        return matches
    }

    static func rowMajorSorted(in windows: [[String: Any]]) -> [Match] {
        var matches = windows.compactMap { window -> Match? in
            guard let owner = window[kCGWindowOwnerName as String] as? String, !owner.isEmpty,
                  let bounds = boundsRect(for: window) else { return nil }
            return Match(ownerName: owner, windowNumber: windowNumber(window), bounds: bounds, rank: 0)
        }
        // Retain the 40-point row tolerance used for slightly misaligned thumbnails.
        matches.sort { a, b in
            if abs(a.bounds.minY - b.bounds.minY) > 40 { return a.bounds.minY < b.bounds.minY }
            if a.bounds.minX != b.bounds.minX { return a.bounds.minX < b.bounds.minX }
            return a.windowNumber < b.windowNumber
        }
        return matches
    }

    static func boundsRect(for window: [String: Any]) -> CGRect? {
        guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let x = bounds["X"] as? NSNumber, let y = bounds["Y"] as? NSNumber,
              let width = bounds["Width"] as? NSNumber, let height = bounds["Height"] as? NSNumber else { return nil }
        return CGRect(x: x.doubleValue, y: y.doubleValue, width: width.doubleValue, height: height.doubleValue)
    }

    static func windowNumber(_ window: [String: Any]) -> Int {
        (window[kCGWindowNumber as String] as? NSNumber)?.intValue ?? 0
    }
}
