import AppKit
import CoreGraphics

// Tasti media di sistema: eventi .systemDefined con subtype 8,
// data1 = (keycode << 16) | (keyState << 8), keyState 0xA = down / 0xB = up.
enum MediaKey: Int32 {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
    case play = 16
    case next = 17
    case previous = 18
}

// Azioni di sistema con scorciatoia configurabile: la combinazione reale viene
// letta da com.apple.symbolichotkeys a ogni uso (segue le impostazioni utente),
// con fallback sul default macOS se la voce non esiste.
enum SystemShortcut {
    case missionControl
    case showDesktop
    case spaceLeft
    case spaceRight

    private var hotKeyID: Int {
        switch self {
        case .missionControl: return 32
        case .showDesktop: return 36
        case .spaceLeft: return 79
        case .spaceRight: return 81
        }
    }

    private var fallback: (CGKeyCode, CGEventFlags) {
        switch self {
        case .missionControl: return (126, .maskControl)
        case .showDesktop: return (103, [])
        case .spaceLeft: return (123, .maskControl)
        case .spaceRight: return (124, .maskControl)
        }
    }

    // nil = scorciatoia disattivata dall'utente
    func resolve() -> (CGKeyCode, CGEventFlags)? {
        guard let all = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
                .dictionary(forKey: "AppleSymbolicHotKeys"),
              let entry = all["\(hotKeyID)"] as? [String: Any]
        else { return fallback }
        if let enabled = entry["enabled"] as? NSNumber, !enabled.boolValue { return nil }
        guard let value = entry["value"] as? [String: Any],
              let params = value["parameters"] as? [Any], params.count >= 3,
              let key = (params[1] as? NSNumber)?.intValue,
              let mods = (params[2] as? NSNumber)?.intValue,
              key >= 0, key < 0xFFFF
        else { return fallback }
        var flags: CGEventFlags = []
        if mods & 0x20000 != 0 { flags.insert(.maskShift) }
        if mods & 0x40000 != 0 { flags.insert(.maskControl) }
        if mods & 0x80000 != 0 { flags.insert(.maskAlternate) }
        if mods & 0x100000 != 0 { flags.insert(.maskCommand) }
        if mods & 0x800000 != 0 { flags.insert(.maskSecondaryFn) }
        return (CGKeyCode(key), flags)
    }
}

extension EventPoster {
    func systemShortcut(_ shortcut: SystemShortcut) {
        guard let (key, flags) = shortcut.resolve() else {
            Log.write("scorciatoia \(shortcut): disattivata nelle impostazioni, nessun invio")
            return
        }
        keyCombo(key, flags)
    }

    func mediaKey(_ key: MediaKey) {
        postMediaKey(key, down: true)
        postMediaKey(key, down: false)
    }

    private func postMediaKey(_ key: MediaKey, down: Bool) {
        let keyState: Int32 = down ? 0xA : 0xB
        let data1 = Int((key.rawValue << 16) | (keyState << 8))
        guard let ev = NSEvent.otherEvent(with: .systemDefined,
                                          location: .zero,
                                          modifierFlags: NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00),
                                          timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: 0,
                                          context: nil,
                                          subtype: 8,
                                          data1: data1,
                                          data2: -1) else { return }
        ev.cgEvent?.post(tap: .cghidEventTap)
    }
}
