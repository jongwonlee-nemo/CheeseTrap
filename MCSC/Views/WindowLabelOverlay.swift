import Cocoa

@MainActor
final class WindowLabelOverlay {
    struct Group: Equatable {
        let screenFrame: CGRect
        let thumbnails: [CGRect]
        let isActive: Bool
    }

    static let labels = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private static let badgeSize: CGFloat = 36
    private var panels: [NSPanel] = []
    private var shown: [Group] = []

    func show(_ groups: [Group]) {
        guard groups != shown else { return }
        hide()
        shown = groups
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        for group in groups where !group.thumbnails.isEmpty {
            let screen = group.screenFrame
            // Panels use Cocoa's bottom-left origin; screen and thumbnail frames are Quartz top-left.
            let panel = makePanel(frame: NSRect(x: screen.minX, y: primaryHeight - screen.maxY, width: screen.width, height: screen.height))
            for (label, thumbnail) in zip(Self.labels, group.thumbnails) {
                let size = Self.badgeSize
                let badge = makeBadge(label, frame: NSRect(
                    x: thumbnail.midX - screen.minX - size / 2,
                    y: screen.maxY - thumbnail.minY - 8 - size,
                    width: size,
                    height: size
                ))
                badge.alphaValue = group.isActive ? 1 : 0.4
                panel.contentView?.addSubview(badge)
            }
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    func hide() {
        for panel in panels { panel.orderOut(nil) }
        panels = []
        shown = []
    }

    private func makePanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSView(frame: NSRect(origin: .zero, size: frame.size))
        return panel
    }

    private func makeBadge(_ label: String, frame: NSRect) -> NSView {
        let badge = NSVisualEffectView(frame: frame)
        badge.material = .hudWindow
        badge.blendingMode = .behindWindow
        badge.state = .active
        badge.wantsLayer = true
        badge.layer?.cornerRadius = frame.height / 2
        badge.layer?.masksToBounds = true
        badge.layer?.borderWidth = 0.5
        badge.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor

        let field = NSTextField(labelWithString: label)
        field.font = NSFont.systemFont(ofSize: 20, weight: .heavy)
        field.textColor = .labelColor
        field.alignment = .center
        field.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(field)
        NSLayoutConstraint.activate([
            field.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            field.centerYAnchor.constraint(equalTo: badge.centerYAnchor)
        ])
        return badge
    }
}
