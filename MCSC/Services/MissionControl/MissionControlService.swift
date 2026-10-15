import ApplicationServices
import Cocoa

@MainActor
final class MissionControlService {
    var onActivated: (() -> Void)?
    var onDeactivated: (() -> Void)?

    private var isActive = false
    private var pollTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var axObserver: AXObserver?
    private var dockElement: AXUIElement?
    private var lastDetectionTime: Double = 0
    private let detectionCacheInterval = 0.35
    private static let dockNotifications = ["AXExposeShowAllWindows", "AXExposeExit", "AXExposeShowDesktop"]

    func start() {
        guard pollTimer == nil else { return }
        setupDockObserver()
        let center = DistributedNotificationCenter.default()
        for event in ["com.apple.expose.start", "com.apple.expose.stop", "com.apple.MissionControl.start", "com.apple.MissionControl.stop", "com.apple.showdesktop.start"] {
            let observer = center.addObserver(forName: Notification.Name(event), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.markActive(event != "com.apple.showdesktop.start" && event.hasSuffix("start"))
                }
            }
            observers.append(observer)
        }
        pollTimer = Timer.scheduledCommon(interval: 0.2, repeats: true, tolerance: 0.05) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.checkMissionControlActive() }
        }
        _ = checkMissionControlActive(force: true)
    }

    func checkMissionControlActive(force: Bool = false) -> Bool {
        let now = CACurrentMediaTime()
        if !force, now - lastDetectionTime < detectionCacheInterval { return isActive }
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            markActive(false)
            return false
        }
        var dockLayers: [Int] = []
        var hasWindowManagerOverlay = false
        for window in list {
            let owner = window[kCGWindowOwnerName as String] as? String ?? ""
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            let name = window[kCGWindowName as String] as? String ?? ""
            if owner == "Dock", name.isEmpty {
                dockLayers.append(layer)
            } else if owner == "WindowManager", layer == 19 {
                hasWindowManagerOverlay = true
            }
        }
        // Preserve the Dock and WindowManager signatures; Launchpad uses different layers.
        let hasDockOverlay = dockLayers.contains(20) && dockLayers.contains { $0 <= 18 }
        lastDetectionTime = now
        markActive(hasWindowManagerOverlay || hasDockOverlay)
        return isActive
    }

    private func markActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        lastDetectionTime = CACurrentMediaTime()
        if active { onActivated?() } else { onDeactivated?() }
    }

    private func setupDockObserver() {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }
        var observer: AXObserver?
        let result = AXObserverCreate(dock.processIdentifier, { _, _, notification, refcon in
            guard let refcon else { return }
            let service = Unmanaged<MissionControlService>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { service.markActive(notification as String == "AXExposeShowAllWindows") }
        }, &observer)
        guard result == .success, let observer else { return }
        let element = AXUIElementCreateApplication(dock.processIdentifier)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        for name in Self.dockNotifications {
            AXObserverAddNotification(observer, element, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        axObserver = observer
        dockElement = element
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        let center = DistributedNotificationCenter.default()
        for observer in observers { center.removeObserver(observer) }
        observers.removeAll()
        if let axObserver {
            if let dockElement {
                for name in Self.dockNotifications {
                    AXObserverRemoveNotification(axObserver, dockElement, name as CFString)
                }
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(axObserver), .commonModes)
        }
        axObserver = nil
        dockElement = nil
        markActive(false)
    }

    isolated deinit { stop() }
}
