import Carbon
import Cocoa

@MainActor
final class DisplayFocusService {
    var onShortcut: ((_ forward: Bool) -> Void)?
    private(set) var shortcutsUnavailable = false
    private let accessibility = AccessibilityService()
    private let spaces = SpaceManagementService()
    private var lastFocusedWindows: [CGDirectDisplayID: CGWindowID] = [:]
    private var hotKeys: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var applicationObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var focusObserver: AXObserver?
    private var missionControlActive = false

    func start() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var key = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &key) == noErr,
                  key.signature == 0x43685470, key.id == 1 || key.id == 2 else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<DisplayFocusService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.onShortcut?(key.id == 1) }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        guard status == noErr else {
            shortcutsUnavailable = true
            return
        }
        applicationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.observeFocusedApplication() }
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let connectedIDs = Set(ScreenNavigationSession.connectedScreens.map(\.id))
                self.lastFocusedWindows = self.lastFocusedWindows.filter { connectedIDs.contains($0.key) }
                self.refreshHotKeys()
            }
        }
        observeFocusedApplication()
        refreshHotKeys()
    }

    func stop() {
        unregisterHotKeys()
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
        if let applicationObserver { NSWorkspace.shared.notificationCenter.removeObserver(applicationObserver) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        applicationObserver = nil
        screenObserver = nil
        removeFocusObserver()
        lastFocusedWindows = [:]
    }

    func setMissionControlActive(_ active: Bool) {
        guard missionControlActive != active else { return }
        missionControlActive = active
        refreshHotKeys()
    }

    func focusDisplay(forward: Bool) {
        let screens = ScreenNavigationSession.connectedScreens
        guard screens.count > 1 else { return }
        rememberFocus()
        let focused = accessibility.focusedWindow()
        let point = focused.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? CGEvent(source: nil)?.location ?? .zero
        var session = ScreenNavigationSession()
        session.begin(at: point, in: screens)
        let regularPIDs = Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map(\.processIdentifier))
        let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).filter {
            guard let layer = $0[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = $0[kCGWindowOwnerPID as String] as? pid_t, regularPIDs.contains(pid),
                  let id = $0[kCGWindowNumber as String] as? CGWindowID else { return false }
            return spaces.isWindowOnCurrentSpace(windowID: id)
        }
        for _ in 1..<screens.count {
            guard let screen = session.move(forward: forward, in: screens),
                  let target = Self.preferredWindow(on: screen, rememberedID: lastFocusedWindows[screen.id], in: windows),
                  let id = target[kCGWindowNumber as String] as? CGWindowID,
                  let frame = WindowSelectionEngine.boundsRect(for: target),
                  accessibility.focusWindow(id) else { continue }
            lastFocusedWindows[screen.id] = id
            WindowActivationAction.postSyntheticMouseMoved(to: CGPoint(x: frame.midX, y: frame.midY))
            return
        }
    }

    static func preferredWindow(on screen: ScreenNavigationSession.Screen, rememberedID: CGWindowID?, in windows: [[String: Any]]) -> [String: Any]? {
        let candidates = windows.filter {
            guard let layer = $0[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = $0[kCGWindowOwnerPID as String] as? pid_t, pid != getpid(),
                  let id = $0[kCGWindowNumber as String] as? CGWindowID, id != 0,
                  let frame = WindowSelectionEngine.boundsRect(for: $0), frame.width >= 100, frame.height >= 100 else { return false }
            return screen.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
        }
        return candidates.first { ($0[kCGWindowNumber as String] as? CGWindowID) == rememberedID } ?? candidates.first
    }

    private func refreshHotKeys() {
        guard eventHandler != nil else { return }
        unregisterHotKeys()
        shortcutsUnavailable = false
        guard !missionControlActive, NSScreen.screens.count > 1 else { return }
        for (id, modifiers) in [(UInt32(1), UInt32(optionKey)), (UInt32(2), UInt32(optionKey | shiftKey))] {
            var hotKey: EventHotKeyRef?
            let status = RegisterEventHotKey(48, modifiers, EventHotKeyID(signature: 0x43685470, id: id),
                                             GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &hotKey)
            guard status == noErr, let hotKey else {
                unregisterHotKeys()
                shortcutsUnavailable = true
                return
            }
            hotKeys.append(hotKey)
        }
    }

    private func unregisterHotKeys() {
        for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
        hotKeys = []
    }

    private func observeFocusedApplication() {
        removeFocusObserver()
        rememberFocus()
        guard let app = NSWorkspace.shared.frontmostApplication, app.activationPolicy == .regular else { return }
        var observer: AXObserver?
        guard AXObserverCreate(app.processIdentifier, { _, _, _, context in
            guard let context else { return }
            let service = Unmanaged<DisplayFocusService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.rememberFocus() }
        }, &observer) == .success, let observer else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        let notifications = [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification]
        let registrations = notifications.map {
            AXObserverAddNotification(observer, element, $0 as CFString, Unmanaged.passUnretained(self).toOpaque())
        }
        guard registrations.contains(.success) else { return }
        focusObserver = observer
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func rememberFocus() {
        guard let focused = accessibility.focusedWindow(),
              let screen = ScreenNavigationSession.connectedScreens.first(where: {
                  $0.frame.contains(CGPoint(x: focused.frame.midX, y: focused.frame.midY))
              }) else { return }
        lastFocusedWindows[screen.id] = focused.id
    }

    private func removeFocusObserver() {
        if let focusObserver { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(focusObserver), .commonModes) }
        focusObserver = nil
    }

    isolated deinit { stop() }
}
