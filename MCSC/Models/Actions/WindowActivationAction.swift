import CoreGraphics
import Foundation

enum WindowActivationAction {
    static func postSyntheticMouseMoved(to point: CGPoint) {
        _ = CGWarpMouseCursorPosition(point)
        CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        )?.post(tap: .cghidEventTap)
    }

    static func performSyntheticClick(at point: CGPoint) {
        postSyntheticMouseMoved(to: point)
        CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        )?.post(tap: .cghidEventTap)

        // WindowServer needs the existing 50 ms dwell to register a Mission Control click reliably.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            CGEvent(
                mouseEventSource: CGEventSource(stateID: .hidSystemState),
                mouseType: .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: .left
            )?.post(tap: .cghidEventTap)
        }
    }
}
