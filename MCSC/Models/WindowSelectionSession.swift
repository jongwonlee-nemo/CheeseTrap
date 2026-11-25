import CoreGraphics

struct WindowSelectionSession {
    var selectedIndex = -1

    enum Effect: Equatable {
        case ignore
        case updated
        case activate
        case moveScreen(forward: Bool)
        case closeWindow
        case forceQuitApp
    }

    private enum KeyCode {
        static let `return`: Int64 = 36
        static let keypadEnter: Int64 = 76
        static let tab: Int64 = 48
        static let w: Int64 = 13
        static let q: Int64 = 12
    }

    // Top-row and keypad key codes for labels 1–9, 0.
    private static let labelKeyCodes: [Int64] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]
    private static let keypadLabelKeyCodes: [Int64] = [83, 84, 85, 86, 87, 88, 89, 91, 92, 82]

    private static let blockedModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]

    mutating func clear() {
        selectedIndex = -1
    }

    mutating func handleKey(keyCode: Int64, flags: CGEventFlags, matchCount: Int) -> Effect {
        let shortcutModifiers = flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift, .maskSecondaryFn])
        if keyCode == KeyCode.tab, shortcutModifiers == .maskAlternate || shortcutModifiers == [.maskAlternate, .maskShift] {
            return .moveScreen(forward: !flags.contains(.maskShift))
        }
        if shortcutModifiers == .maskCommand {
            if keyCode == KeyCode.w { return .closeWindow }
            if keyCode == KeyCode.q { return .forceQuitApp }
        }
        guard flags.rawValue & Self.blockedModifiers.rawValue == 0 else { return .ignore }
        switch keyCode {
        case KeyCode.return, KeyCode.keypadEnter:
            return selectedIndex >= 0 ? .activate : .ignore
        case KeyCode.tab:
            guard matchCount > 0 else { return .ignore }
            if selectedIndex < 0 {
                selectedIndex = 0
            } else if !flags.contains(.maskShift) {
                selectedIndex = (selectedIndex + 1) % matchCount
            } else {
                selectedIndex = selectedIndex <= 0 ? matchCount - 1 : selectedIndex - 1
            }
            return .updated
        default:
            guard !flags.contains(.maskShift),
                  let index = Self.labelKeyCodes.firstIndex(of: keyCode) ?? Self.keypadLabelKeyCodes.firstIndex(of: keyCode),
                  index < matchCount else { return .ignore }
            selectedIndex = index
            return .activate
        }
    }
}
