import ApplicationServices
import Cocoa

@_silgen_name("_AXUIElementGetWindow")
@discardableResult
private func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

final class AccessibilityService {
    private var cachedElements: [String: (pid: pid_t, element: AXUIElement)] = [:]

    func closeWindow(_ windowID: CGWindowID) {
        guard let app = targetApp(for: windowID) else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows: [AXUIElement] = attribute(kAXWindowsAttribute, for: appElement),
              let window = windows.first(where: {
                  var identifier: CGWindowID = 0
                  return _AXUIElementGetWindow($0, &identifier) == .success && identifier == windowID
              }) else { return }
        if let button: AXUIElement = attribute(kAXCloseButtonAttribute, for: window),
           AXUIElementPerformAction(button, kAXPressAction as CFString) == .success {
            return
        }

        // Custom title bars may require Cmd+W; verify focus before sending it to the owning process.
        app.activate()
        _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        _ = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        guard let focused: AXUIElement = attribute(kAXFocusedWindowAttribute, for: appElement),
              CFEqual(focused, window) else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 13, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 13, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(app.processIdentifier)
        up.postToPid(app.processIdentifier)
    }

    func forceQuitApp(for windowID: CGWindowID) {
        targetApp(for: windowID)?.forceTerminate()
    }

    private func targetApp(for windowID: CGWindowID) -> NSRunningApplication? {
        guard windowID != kCGNullWindowID,
              let list = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
              let info = list.first(where: { ($0[kCGWindowNumber as String] as? CGWindowID) == windowID }),
              let pid = info[kCGWindowOwnerPID as String] as? pid_t,
              let app = NSRunningApplication(processIdentifier: pid),
              pid != NSRunningApplication.current.processIdentifier,
              app.activationPolicy == .regular,
              !["com.apple.dock", "com.apple.WindowManager", "com.apple.WindowServer"].contains(app.bundleIdentifier ?? "") else {
            return nil
        }
        return app
    }

    func previewFrames(for windowIDs: Set<CGWindowID>) -> [CGWindowID: CGRect] {
        guard !windowIDs.isEmpty else { return [:] }
        var frames: [CGWindowID: CGRect] = [:]
        for bundleID in ["com.apple.WindowManager", "com.apple.dock"] {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { continue }
            if cachedElements[bundleID]?.pid != app.processIdentifier {
                cachedElements[bundleID] = (app.processIdentifier, AXUIElementCreateApplication(app.processIdentifier))
            }
            if let element = cachedElements[bundleID]?.element {
                collectPreviewFrames(in: element, windowIDs: windowIDs, depth: 0, frames: &frames)
            }
            if frames.count == windowIDs.count { break }
        }
        return frames
    }

    private func collectPreviewFrames(
        in element: AXUIElement,
        windowIDs: Set<CGWindowID>,
        depth: Int,
        frames: inout [CGWindowID: CGRect]
    ) {
        guard depth < 8 else { return }
        var windowID = (attribute("wid", for: element) as NSNumber?)?.uint32Value ?? 0
        if windowID == 0 { _ = _AXUIElementGetWindow(element, &windowID) }
        if windowIDs.contains(windowID), frames[windowID] == nil,
           let frame = frame(for: element), !frame.isEmpty {
            frames[windowID] = frame
        }
        if frames.count == windowIDs.count { return }
        guard let children: [AXUIElement] = attribute(kAXChildrenAttribute, for: element) else { return }
        for child in children {
            collectPreviewFrames(in: child, windowIDs: windowIDs, depth: depth + 1, frames: &frames)
        }
    }

    private func attribute<T>(_ name: String, for element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private func frame(for element: AXUIElement) -> CGRect? {
        let attributes = [kAXPositionAttribute as CFString, kAXSizeAttribute as CFString]
        var valuesRef: CFArray?
        if AXUIElementCopyMultipleAttributeValues(element, attributes as CFArray, .stopOnError, &valuesRef) == .success,
           let values = valuesRef as? [CFTypeRef], values.count == 2,
           CFGetTypeID(values[0]) == AXValueGetTypeID(), CFGetTypeID(values[1]) == AXValueGetTypeID() {
            var point = CGPoint.zero
            var size = CGSize.zero
            if AXValueGetValue(unsafeDowncast(values[0], to: AXValue.self), .cgPoint, &point),
               AXValueGetValue(unsafeDowncast(values[1], to: AXValue.self), .cgSize, &size) {
                return CGRect(origin: point, size: size)
            }
        }
        // Some AX elements reject the batched request, so retain individual attribute reads.
        var position: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              let position, CFGetTypeID(position) == AXValueGetTypeID(),
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let sizeValue, CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(sizeValue, to: AXValue.self), .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
}
