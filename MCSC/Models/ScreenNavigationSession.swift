import Cocoa

struct ScreenNavigationSession {
    struct Screen {
        let id: CGDirectDisplayID
        let frame: CGRect
    }

    static var connectedScreens: [Screen] {
        let connected = NSScreen.screens
        let primaryHeight = connected.first?.frame.height ?? 0
        return connected.compactMap { screen -> Screen? in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            // Convert Cocoa's bottom-left origin to the Quartz coordinates used by windows and the pointer.
            let frame = CGRect(x: screen.frame.minX, y: primaryHeight - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height)
            return Screen(id: id.uint32Value, frame: frame)
        }.sorted { a, b in
            if a.frame.minX != b.frame.minX { return a.frame.minX < b.frame.minX }
            if a.frame.minY != b.frame.minY { return a.frame.minY < b.frame.minY }
            return a.id < b.id
        }
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
