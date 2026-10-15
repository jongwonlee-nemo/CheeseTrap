import Cocoa

@MainActor
final class SearchBarOverlay {
    private var panel: NSPanel?
    private var textField: NSTextField?
    private var isVisible = false

    private static func panelFrame(query: String, screen: NSScreen) -> NSRect {
        let font = NSFont.systemFont(ofSize: 22, weight: .heavy)
        let textWidth = (query.uppercased() as NSString).size(withAttributes: [.font: font]).width
        let width = min(max(textWidth + 72, 120), max(120, screen.frame.width - 200))
        let y = max(screen.visibleFrame.minY + 24, screen.frame.minY + 155)
        return NSRect(x: screen.frame.midX - width / 2, y: y, width: width, height: 52)
    }

    func show(query: String, on screen: NSScreen) {
        if panel == nil { setupPanel() }
        guard let panel else { return }
        textField?.stringValue = query.uppercased()
        panel.setFrame(Self.panelFrame(query: query, screen: screen), display: true)
        panel.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        guard isVisible else { return }
        panel?.orderOut(nil)
        textField?.stringValue = ""
        isVisible = false
    }

    private func setupPanel() {
        let rect = NSRect(x: 0, y: 0, width: 120, height: 52)
        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        let effectView = NSVisualEffectView(frame: rect)
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 16
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 0.5
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        effectView.autoresizingMask = [.width, .height]

        let field = NSTextField(labelWithString: "")
        field.font = NSFont.systemFont(ofSize: 22, weight: .heavy)
        field.textColor = .labelColor
        field.alignment = .center
        field.drawsBackground = false
        field.isBezeled = false
        field.isEditable = false
        field.isSelectable = false
        field.focusRingType = .none
        field.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(field)
        NSLayoutConstraint.activate([
            field.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
            field.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            field.leadingAnchor.constraint(greaterThanOrEqualTo: effectView.leadingAnchor, constant: 16),
            field.trailingAnchor.constraint(lessThanOrEqualTo: effectView.trailingAnchor, constant: -16)
        ])
        panel.contentView = effectView
        self.panel = panel
        textField = field
    }
}
