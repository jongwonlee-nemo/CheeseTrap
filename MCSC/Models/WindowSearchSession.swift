import CoreGraphics
import Foundation

struct WindowSearchSession {
    var query = ""
    var selectedIndex = -1

    enum Effect: Equatable {
        case ignore
        case updated
        case activate
        case clear
        case moveScreen(forward: Bool)
    }

    private enum KeyCode {
        static let `return`: Int64 = 36
        static let keypadEnter: Int64 = 76
        static let escape: Int64 = 53
        static let delete: Int64 = 51
        static let forwardDelete: Int64 = 117
        static let tab: Int64 = 48
        static let downArrow: Int64 = 125
        static let upArrow: Int64 = 126
    }

    private static let blockedModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]

    mutating func clear() {
        query = ""
        selectedIndex = -1
    }

    func matches(in windows: [[String: Any]]) -> [WindowSelectionEngine.Match] {
        WindowSelectionEngine.fuzzyMatch(query: query, in: windows)
    }

    mutating func handleKey(
        keyCode: Int64,
        characters: String?,
        flags: CGEventFlags,
        windows: [[String: Any]]
    ) -> Effect {
        let shortcutModifiers = flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift, .maskSecondaryFn])
        if keyCode == KeyCode.tab, shortcutModifiers == .maskAlternate || shortcutModifiers == [.maskAlternate, .maskShift] {
            return .moveScreen(forward: !flags.contains(.maskShift))
        }
        guard flags.rawValue & Self.blockedModifiers.rawValue == 0 else { return .ignore }
        switch keyCode {
        case KeyCode.return, KeyCode.keypadEnter:
            return selectedIndex >= 0 ? .activate : .ignore
        case KeyCode.escape:
            guard !query.isEmpty else { return .ignore }
            clear()
            return .clear
        case KeyCode.delete, KeyCode.forwardDelete:
            guard !query.isEmpty else { return .ignore }
            query.removeLast()
            if query.isEmpty {
                selectedIndex = -1
                return .clear
            }
            syncSelection(with: matches(in: windows))
            return .updated
        case KeyCode.tab:
            return cycle(forward: !flags.contains(.maskShift), in: windows, allowEmptyQuery: true)
        case KeyCode.downArrow:
            return cycle(forward: true, in: windows)
        case KeyCode.upArrow:
            return cycle(forward: false, in: windows)
        default:
            guard let characters, !characters.isEmpty else { return .ignore }
            let filtered = characters.filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            guard !filtered.isEmpty else { return .ignore }
            if query.isEmpty, filtered.trimmingCharacters(in: .whitespaces).isEmpty { return .ignore }
            query.append(contentsOf: filtered)
            syncSelection(with: matches(in: windows))
            return .updated
        }
    }

    private mutating func cycle(forward: Bool, in windows: [[String: Any]], allowEmptyQuery: Bool = false) -> Effect {
        let hits: [WindowSelectionEngine.Match]
        if query.isEmpty {
            guard allowEmptyQuery else { return .ignore }
            hits = WindowSelectionEngine.rowMajorSorted(in: windows)
            guard !hits.isEmpty else { return .ignore }
        } else {
            hits = matches(in: windows)
            guard !hits.isEmpty else { return .updated }
        }
        if selectedIndex < 0 {
            selectedIndex = 0
        } else if forward {
            selectedIndex = (selectedIndex + 1) % hits.count
        } else {
            selectedIndex = selectedIndex <= 0 ? hits.count - 1 : selectedIndex - 1
        }
        return .updated
    }

    private mutating func syncSelection(with hits: [WindowSelectionEngine.Match]) {
        if hits.isEmpty {
            selectedIndex = -1
        } else if selectedIndex < 0 || selectedIndex >= hits.count {
            selectedIndex = 0
        }
    }
}
