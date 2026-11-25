import Cocoa

@MainActor
final class MissionControlNavigationService {
    private let missionControl = MissionControlService()
    private let accessibility = AccessibilityService()
    private let spaces = SpaceManagementService()
    private let keyboardTap = MCKeyboardTapService()
    private let displayFocus = DisplayFocusService()
    private let labelOverlay = WindowLabelOverlay()
    private var selection = WindowSelectionSession()
    private var screenSession = ScreenNavigationSession()
    private var windows: [[String: Any]] = []
    private var spaceObserver: NSObjectProtocol?
    private var labelTimer: Timer?
    private var labelsVisible = false
    private var isActive = false
    // ponytail: fixed wait for Mission Control/Space animations to settle; tune on real hardware.
    private static let labelDelay: TimeInterval = 0.4

    var displayShortcutsUnavailable: Bool { displayFocus.shortcutsUnavailable }

    init() {
        missionControl.onActivated = { [weak self] in self?.activate() }
        missionControl.onDeactivated = { [weak self] in self?.deactivate() }
        keyboardTap.onKeyDown = { [weak self] keyCode, flags in
            MainActor.assumeIsolated {
                self?.handleKeyDown(keyCode: keyCode, flags: flags) ?? false
            }
        }
        displayFocus.onShortcut = { [weak self] forward in
            guard let self else { return }
            if self.missionControl.checkMissionControlActive(force: true) {
                let flags: CGEventFlags = forward ? .maskAlternate : [.maskAlternate, .maskShift]
                _ = self.handleKeyDown(keyCode: 48, flags: flags)
            } else {
                self.displayFocus.focusDisplay(forward: forward)
            }
        }
    }

    func start() {
        guard spaceObserver == nil else { return }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.selection.clear()
                self.windows = []
                if self.isActive { self.scheduleLabels() }
            }
        }
        displayFocus.start()
        missionControl.start()
    }

    func stop() {
        displayFocus.stop()
        missionControl.stop()
        deactivate()
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
    }

    private func activate() {
        guard !isActive else { return }
        selection.clear()
        screenSession.begin(at: CGEvent(source: nil)?.location ?? .zero, in: screens)
        isActive = keyboardTap.start()
        displayFocus.setMissionControlActive(isActive)
        if isActive { scheduleLabels() }
    }

    private func deactivate() {
        isActive = false
        keyboardTap.stop()
        displayFocus.setMissionControlActive(false)
        hideLabels()
        selection.clear()
        windows = []
        screenSession = ScreenNavigationSession()
    }

    private var matches: [WindowSelectionEngine.Match] {
        matches(on: screenSession.current(in: screens))
    }

    private func matches(on screen: ScreenNavigationSession.Screen?) -> [WindowSelectionEngine.Match] {
        guard let screen else { return [] }
        return WindowSelectionEngine.rowMajorSorted(in: windows.filter {
            guard let frame = WindowSelectionEngine.boundsRect(for: $0) else { return false }
            return screen.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
        })
    }

    private var screens: [ScreenNavigationSession.Screen] {
        ScreenNavigationSession.connectedScreens
    }

    private func handleKeyDown(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard isActive, missionControl.checkMissionControlActive(force: true) else {
            deactivate()
            return false
        }
        if keyCode == 99 || keyCode == 160 || (keyCode == 126 && flags.contains(.maskControl)) || keyCode == 53 {
            deactivate()
            return false
        }
        if flags.contains(.maskControl) {
            selection.clear()
            windows = []
            scheduleLabels()
            return false
        }
        if flags.contains(.maskCommand), keyCode != 12 && keyCode != 13 { return false }
        if flags.contains(.maskAlternate), keyCode != 48 { return false }

        refreshWindows()
        let effect = selection.handleKey(keyCode: keyCode, flags: flags, matchCount: matches.count)
        switch effect {
        case .ignore:
            return false
        case .updated:
            highlightSelection()
        case let .moveScreen(forward):
            guard let screen = screenSession.move(forward: forward, in: screens) else { return false }
            selection.selectedIndex = -1
            windows = []
            refreshWindows()
            if !matches.isEmpty { selection.selectedIndex = 0 }
            highlightSelection()
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
            selection.selectedIndex = -1
            windows = []
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isActive, self.missionControl.checkMissionControlActive(force: true) else { return }
                if forceQuit {
                    self.accessibility.forceQuitApp(for: windowID)
                } else {
                    self.accessibility.closeWindow(windowID)
                }
                self.scheduleLabels()
            }
        }
        return true
    }

    private func refreshWindows() {
        let connected = screens
        if screenSession.current(in: connected) == nil {
            selection.clear()
            windows = []
            screenSession.begin(at: CGEvent(source: nil)?.location ?? .zero, in: connected)
        }
        guard screenSession.current(in: connected) != nil else {
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
            guard let windowID = window[kCGWindowNumber as String] as? CGWindowID, let frame = frames[windowID] else { return nil }
            // Use thumbnail geometry rather than desktop window geometry for both navigation and clicking.
            return [
                kCGWindowNumber as String: windowID,
                kCGWindowOwnerName as String: window[kCGWindowOwnerName as String] ?? "",
                kCGWindowBounds as String: ["X": frame.minX, "Y": frame.minY, "Width": frame.width, "Height": frame.height]
            ]
        }
        if let selectedID {
            selection.selectedIndex = matches.firstIndex { $0.windowNumber == selectedID } ?? -1
        }
        updateLabels()
    }

    // ponytail: labels refresh on key presses, closes, and Space changes; windows appearing on their own wait for the next one.
    private func updateLabels() {
        guard labelsVisible else { return }
        labelOverlay.show(screens.map { screen in
            WindowLabelOverlay.Group(
                screenFrame: screen.frame,
                thumbnails: matches(on: screen).prefix(WindowLabelOverlay.labels.count).map(\.bounds),
                isActive: screen.id == screenSession.screenID
            )
        })
    }

    private func scheduleLabels() {
        hideLabels()
        labelTimer = Timer.scheduledCommon(interval: Self.labelDelay, repeats: false, tolerance: 0.05) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isActive else { return }
                self.labelTimer = nil
                self.labelsVisible = true
                self.refreshWindows()
            }
        }
    }

    private func hideLabels() {
        labelTimer?.invalidate()
        labelTimer = nil
        labelsVisible = false
        labelOverlay.hide()
    }

    private func highlightSelection() {
        if let match = selectedMatch() {
            WindowActivationAction.postSyntheticMouseMoved(to: match.centerPoint)
        }
    }

    private func selectedMatch() -> WindowSelectionEngine.Match? {
        let hits = matches
        guard hits.indices.contains(selection.selectedIndex) else { return nil }
        return hits[selection.selectedIndex]
    }

    isolated deinit { stop() }
}
