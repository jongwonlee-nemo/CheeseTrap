import Cocoa

@MainActor
final class MissionControlNavigationService {
    private let missionControl = MissionControlService()
    private let accessibility = AccessibilityService()
    private let spaces = SpaceManagementService()
    private let keyboardTap = MCKeyboardTapService()
    private let searchOverlay = SearchBarOverlay()
    private var searchSession = WindowSearchSession()
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
        isActive = keyboardTap.start()
    }

    private func deactivate() {
        isActive = false
        keyboardTap.stop()
        clearSearch()
        windows = []
    }

    private var matches: [WindowSelectionEngine.Match] {
        searchSession.query.isEmpty
            ? WindowSelectionEngine.rowMajorSorted(in: windows)
            : searchSession.matches(in: windows)
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
        if flags.contains(.maskCommand) || flags.contains(.maskAlternate) { return false }

        refreshWindows()
        switch searchSession.handleKey(keyCode: keyCode, characters: characters, flags: flags, windows: windows) {
        case .ignore:
            return false
        case .clear:
            clearSearch()
        case .updated:
            if searchSession.query.isEmpty {
                searchOverlay.hide()
            } else {
                searchOverlay.show(query: searchSession.query)
            }
            if let match = selectedMatch() {
                WindowActivationAction.postSyntheticMouseMoved(to: match.centerPoint)
            }
        case .activate:
            guard let match = selectedMatch() else { return true }
            let point = match.centerPoint
            deactivate()
            WindowActivationAction.performSyntheticClick(at: point)
        }
        return true
    }

    private func refreshWindows() {
        let selectedID = selectedMatch()?.windowNumber
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = list.filter { window in
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let owner = window[kCGWindowOwnerName as String] as? String,
                  !["Dock", "MCSC", "Window Server", "WindowManager"].contains(owner),
                  let frame = WindowSelectionEngine.boundsRect(for: window), frame.width >= 100, frame.height >= 100,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID else { return false }
            return spaces.isWindowOnCurrentSpace(windowID: windowID)
        }
        let frames = accessibility.previewFrames(for: Set(candidates.compactMap { $0[kCGWindowNumber as String] as? CGWindowID }))
        windows = candidates.compactMap { window in
            guard let windowID = window[kCGWindowNumber as String] as? CGWindowID, let frame = frames[windowID] else { return nil }
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
