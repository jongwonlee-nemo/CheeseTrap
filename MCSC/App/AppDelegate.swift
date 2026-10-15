import ApplicationServices
import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let navigation = MissionControlNavigationService()
    private var statusItem: NSStatusItem?
    private var accessibilityPollTimer: Timer?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        updateStatusBar(isTrusted: isTrusted)
        if isTrusted {
            navigation.start()
        } else {
            accessibilityPollTimer = Timer.scheduledCommon(interval: 1, repeats: true, tolerance: 0.1) { [weak self] timer in
                MainActor.assumeIsolated {
                    guard AXIsProcessTrusted() else { return }
                    self?.updateStatusBar(isTrusted: true)
                    self?.navigation.start()
                    self?.accessibilityPollTimer = nil
                    timer.invalidate()
                }
            }
        }

        let center = NSWorkspace.shared.notificationCenter
        sleepObserver = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.navigation.stop() }
        }
        wakeObserver = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if AXIsProcessTrusted() { self?.navigation.start() }
            }
        }
    }

    private func updateStatusBar(isTrusted: Bool) {
        let symbolName = isTrusted ? "command.circle" : "command.circle.fill"
        statusItem?.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MCSC")
        statusItem?.button?.toolTip = isTrusted ? "MCSC" : "MCSC (Accessibility Permission Required)"
        let menu = NSMenu()
        if !isTrusted {
            let item = NSMenuItem(title: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            menu.addItem(NSMenuItem.separator())
        }
        menu.addItem(NSMenuItem(title: "Quit MCSC", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func applicationWillTerminate(_: Notification) {
        navigation.stop()
        accessibilityPollTimer?.invalidate()
        let center = NSWorkspace.shared.notificationCenter
        if let sleepObserver { center.removeObserver(sleepObserver) }
        if let wakeObserver { center.removeObserver(wakeObserver) }
    }
}
