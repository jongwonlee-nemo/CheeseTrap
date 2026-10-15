import CoreGraphics

struct ScreenNavigationSession {
    struct Screen {
        let id: CGDirectDisplayID
        let frame: CGRect
    }

    private(set) var screenID: CGDirectDisplayID?

    func current(in screens: [Screen]) -> Screen? {
        screens.first { $0.id == screenID }
    }

    mutating func begin(at point: CGPoint, in screens: [Screen]) {
        screenID = (screens.first { $0.frame.contains(point) } ?? screens.first)?.id
    }

    @discardableResult
    mutating func move(forward: Bool, in screens: [Screen]) -> Screen? {
        guard screens.count > 1, let index = screens.firstIndex(where: { $0.id == screenID }) else { return nil }
        let next = (index + (forward ? 1 : screens.count - 1)) % screens.count
        screenID = screens[next].id
        return screens[next]
    }
}
