import AppKit
import CoreGraphics

// Un'unica sorgente eventi HID riusata per tutto (movimento, click, scroll).
final class EventPoster {
    private let source = CGEventSource(stateID: .hidSystemState)
    private let doubleClickInterval = NSEvent.doubleClickInterval
    private var lastLeftDownTime: TimeInterval = 0
    private var lastLeftDownPos = CGPoint.zero
    private var clickState: Int64 = 1

    func move(to p: CGPoint, dx: Int, dy: Int, leftDown: Bool, rightDown: Bool) {
        let type: CGEventType = leftDown ? .leftMouseDragged : (rightDown ? .rightMouseDragged : .mouseMoved)
        let button: CGMouseButton = (rightDown && !leftDown) ? .right : .left
        guard let e = CGEvent(mouseEventSource: source, mouseType: type,
                              mouseCursorPosition: p, mouseButton: button) else { return }
        // alcune app leggono i delta invece della posizione assoluta
        e.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx))
        e.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy))
        e.post(tap: .cghidEventTap)
    }

    func left(down: Bool, at p: CGPoint) {
        if down {
            let now = Date.timeIntervalSinceReferenceDate
            let near = hypot(p.x - lastLeftDownPos.x, p.y - lastLeftDownPos.y) < 6
            clickState = (near && now - lastLeftDownTime < doubleClickInterval) ? min(clickState + 1, 3) : 1
            lastLeftDownTime = now
            lastLeftDownPos = p
        }
        guard let e = CGEvent(mouseEventSource: source,
                              mouseType: down ? .leftMouseDown : .leftMouseUp,
                              mouseCursorPosition: p, mouseButton: .left) else { return }
        e.setIntegerValueField(.mouseEventClickState, value: clickState)
        e.post(tap: .cghidEventTap)
    }

    func right(down: Bool, at p: CGPoint) {
        guard let e = CGEvent(mouseEventSource: source,
                              mouseType: down ? .rightMouseDown : .rightMouseUp,
                              mouseCursorPosition: p, mouseButton: .right) else { return }
        e.setIntegerValueField(.mouseEventClickState, value: 1)
        e.post(tap: .cghidEventTap)
    }

    func middleClick(at p: CGPoint) {
        for down in [true, false] {
            guard let e = CGEvent(mouseEventSource: source,
                                  mouseType: down ? .otherMouseDown : .otherMouseUp,
                                  mouseCursorPosition: p, mouseButton: .center) else { continue }
            e.setIntegerValueField(.mouseEventClickState, value: 1)
            e.post(tap: .cghidEventTap)
        }
    }

    func scroll(vertical: Int32, horizontal: Int32) {
        guard let e = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2,
                              wheel1: vertical, wheel2: horizontal, wheel3: 0) else { return }
        e.post(tap: .cghidEventTap)
    }

    // Scorciatoia di tastiera sintetizzata (es. Ctrl+↑ per Mission Control).
    // I modificatori vanno premuti come tasti veri, in sequenza: le scorciatoie
    // di sistema non scattano se i flag compaiono solo dentro l'evento del tasto.
    func keyCombo(_ virtualKey: CGKeyCode, _ flags: CGEventFlags = []) {
        let modifiers: [(CGEventFlags, CGKeyCode)] = [
            (.maskCommand, 55), (.maskShift, 56), (.maskAlternate, 58), (.maskControl, 59),
        ]
        var held: CGEventFlags = []
        for (flag, code) in modifiers where flags.contains(flag) {
            held.insert(flag)
            postKey(code, down: true, flags: held)
        }
        var keyFlags = held
        let functionKeys: Set<Int> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109,
                                      103, 111, 105, 107, 113, 106] // F1...F16
        if (123...126).contains(Int(virtualKey)) {
            // le frecce reali viaggiano con questi flag; senza, il match può fallire
            keyFlags.insert(.maskSecondaryFn)
            keyFlags.insert(.maskNumericPad)
        } else if functionKeys.contains(Int(virtualKey)) {
            // sui portatili i tasti funzione fisici portano il flag fn: idem sopra
            keyFlags.insert(.maskSecondaryFn)
        }
        postKey(virtualKey, down: true, flags: keyFlags)
        postKey(virtualKey, down: false, flags: keyFlags)
        for (flag, code) in modifiers.reversed() where flags.contains(flag) {
            held.remove(flag)
            postKey(code, down: false, flags: held)
        }
    }

    private func postKey(_ key: CGKeyCode, down: Bool, flags: CGEventFlags) {
        guard let e = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { return }
        e.flags = flags
        e.post(tap: .cghidEventTap)
        usleep(2000)
    }
}
