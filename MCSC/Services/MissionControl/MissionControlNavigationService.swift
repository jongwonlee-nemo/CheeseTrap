import Cocoa

@MainActor
final class MissionControlNavigationService {
    private let missionControl = MissionControlService()
    private let accessibility = AccessibilityService()
    private let spaces = SpaceManagementService()
    private let keyboardTap = MCKeyboardTapService()
    private let searchOverlay = SearchBarOverlay()
    private var searchSession = WindowSearchSession()
    private var screenSession = ScreenNavigationSession()
    private var windows: [[String: Any]] = []
    private var spaceObserver: NSObjectProtocol?
    private var isActive = false

    init() {
        missionControl.onActivated = { [weak self] in self?.activate() }
        missionControl.onDeactivated = { [weak self] in self?.deactivate() }
        keyboardTap.onKeyDown = { [weak self] keyCode, characters, flags in
            MainActor.assumeIsolated {
                self?.handleKeyDown(keyCode: keyCode, characters: characters, flags: flags) ?? false
            }
        }
    }

    func start() {
        guard spaceObserver == nil else { return }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clearSearch()
                self?.windows = []
            }
        }
        missionControl.start()
    }

    func stop() {
        missionControl.stop()
        deactivate()
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
    }

    private func activate() {
        guard !isActive else { return }
        clearSearch()
        screenSession.begin(at: CGEvent(source: nil)?.location ?? .zero, in: screens)
        isActive = keyboardTap.start()
    }

    private func deactivate() {
        isActive = false
        keyboardTap.stop()
        clearSearch()
        windows = []
        screenSession = ScreenNavigationSession()
    }

    private var matches: [WindowSelectionEngine.Match] {
        searchSession.query.isEmpty
            ? WindowSelectionEngine.rowMajorSorted(in: windows)
            : searchSession.matches(in: windows)
    }

    private var screens: [ScreenNavigationSession.Screen] {
        let connected = NSScreen.screens
        let primaryHeight = connected.first?.frame.height ?? 0
        return connected.compactMap { screen -> ScreenNavigationSession.Screen? in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            // Convert Cocoa's bottom-left origin to the Quartz coordinates used by thumbnails and the pointer.
            let frame = CGRect(x: screen.frame.minX, y: primaryHeight - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height)
            return ScreenNavigationSession.Screen(id: id.uint32Value, frame: frame)
        }.sorted { a, b in
            if a.frame.minX != b.frame.minX { return a.frame.minX < b.frame.minX }
            if a.frame.minY != b.frame.minY { return a.frame.minY < b.frame.minY }
            return a.id < b.id
        }
    }

    private func handleKeyDown(keyCode: Int64, characters: String?, flags: CGEventFlags) -> Bool {
        guard isActive, missionControl.checkMissionControlActive(force: true) else {
            deactivate()
            return false
        }
        if keyCode == 99 || keyCode == 160 || (keyCode == 126 && flags.contains(.maskControl))
            || (keyCode == 53 && searchSession.query.isEmpty) {
            deactivate()
            return false
        }
        if flags.contains(.maskControl) {
            clearSearch()
            windows = []
            return false
        }
        if flags.contains(.maskCommand), keyCode != 12 && keyCode != 13 { return false }
        if flags.contains(.maskAlternate), keyCode != 48 { return false }

        refreshWindows()
        let effect = searchSession.handleKey(keyCode: keyCode, characters: characters, flags: flags, windows: windows)
        switch effect {
        case .ignore:
            return false
        case .clear:
            clearSearch()
        case .updated:
            updateSearchUI()
        case let .moveScreen(forward):
            guard let screen = screenSession.move(forward: forward, in: screens) else { return false }
            searchSession.selectedIndex = -1
            windows = []
            refreshWindows()
            if !matches.isEmpty { searchSession.selectedIndex = 0 }
            updateSearchUI()
            if selectedMatch() == nil {
                WindowActivationAction.postSyntheticMouseMoved(to: CGPoint(x: screen.frame.midX, y: screen.frame.midY))
            }
        case .activate:
            guard let match = selectedMatch() else { return true }
            let point = match.centerPoint
            deactivate()
            WindowActivationAction.performSyntheticClick(at: point)
        case .closeWindow, .forceQuitApp:
            guard let match = selectedMatch(), let windowID = CGWindowID(exactly: match.windowNumber) else { return true }
            let forceQuit = effect == .forceQuitApp
            // Clear selection before dispatch so holding a destructive shortcut cannot target another window.
            searchSession.selectedIndex = -1
            windows = []
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isActive, self.missionControl.checkMissionControlActive(force: true) else { return }
                if forceQuit {
                    self.accessibility.forceQuitApp(for: windowID)
                } else {
                    self.accessibility.closeWindow(windowID)
                }
            }
        }
        return true
    }

    private func refreshWindows() {
        let connected = screens
        if screenSession.current(in: connected) == nil {
            clearSearch()
            windows = []
            screenSession.begin(at: CGEvent(source: nil)?.location ?? .zero, in: connected)
        }
        guard let screen = screenSession.current(in: connected) else {
            windows = []
            return
        }
        let selectedID = selectedMatch()?.windowNumber
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = list.filter { window in
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let owner = window[kCGWindowOwnerName as String] as? String,
                  !["Dock", "CheeseTrap", "Window Server", "WindowManager"].contains(owner),
                  let frame = WindowSelectionEngine.boundsRect(for: window), frame.width >= 100, frame.height >= 100,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID else { return false }
            return spaces.isWindowOnCurrentSpace(windowID: windowID)
        }
        let frames = accessibility.previewFrames(for: Set(candidates.compactMap { $0[kCGWindowNumber as String] as? CGWindowID }))
        windows = candidates.compactMap { window in
            guard let windowID = window[kCGWindowNumber as String] as? CGWindowID, let frame = frames[windowID],
                  screen.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return nil }
            // Use thumbnail geometry rather than desktop window geometry for both navigation and clicking.
            return [
                kCGWindowNumber as String: windowID,
                kCGWindowOwnerName as String: window[kCGWindowOwnerName as String] ?? "",
                kCGWindowBounds as String: ["X": frame.minX, "Y": frame.minY, "Width": frame.width, "Height": frame.height]
            ]
        }
        if let selectedID {
            searchSession.selectedIndex = matches.firstIndex { $0.windowNumber == selectedID } ?? -1
        }
    }

    private func updateSearchUI() {
        if searchSession.query.isEmpty {
            searchOverlay.hide()
        } else if let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == screenSession.screenID
        }) {
            searchOverlay.show(query: searchSession.query, on: screen)
        }
        if let match = selectedMatch() {
            WindowActivationAction.postSyntheticMouseMoved(to: match.centerPoint)
        }
    }

    private func selectedMatch() -> WindowSelectionEngine.Match? {
        let hits = matches
        guard hits.indices.contains(searchSession.selectedIndex) else { return nil }
        return hits[searchSession.selectedIndex]
    }

    private func clearSearch() {
        searchSession.clear()
        searchOverlay.hide()
    }

    isolated deinit { stop() }
}
