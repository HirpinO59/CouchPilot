import AppKit
import Carbon.HIToolbox
import CoreGraphics

// Pulsanti del mouse assegnabili.
enum MouseButton: String {
    case left, right, middle

    var titleKey: String {
        switch self {
        case .left: return "action.leftClick"
        case .right: return "action.rightClick"
        case .middle: return "action.middleClick"
        }
    }
}

// Ruolo di uno stick. Il movimento non si può registrare come si registra un
// tasto — non esiste un "input da copiare" — quindi resta una scelta fra tre.
enum StickRole: String, CaseIterable {
    case cursor, scroll, off

    var titleKey: String { "stick.\(rawValue)" }
    var title: String { L.t(titleKey) }
}

// Ciò che fa un tasto del pad quando viene premuto.
//
// Tastiera e mouse vengono registrati dall'utente e riprodotti tali e quali:
// quello che premi è quello che il tasto farà, combinazioni comprese.
// `system` esiste solo per i valori predefiniti (Mission Control, Scrivanie):
// segue la scorciatoia impostata in macOS anche se l'utente la cambia. Appena
// si registra qualcosa su quel tasto diventa una `key` come tutte le altre.
enum Binding: Equatable {
    case none
    case key(CGKeyCode, CGEventFlags)
    case mouse(MouseButton)
    case media(MediaKey)
    case system(SystemShortcut)

    // Solo questi modificatori vengono conservati: gli altri bit (fn, blocco
    // maiuscole, tastierino) arrivano sporchi dall'evento e li rimette
    // `EventPoster.keyCombo` dove servono davvero.
    static let usefulFlags: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]

    // MARK: - Salvataggio

    var raw: String {
        switch self {
        case .none: return "none"
        case .key(let code, let flags): return "key:\(code):\(flags.rawValue)"
        case .mouse(let button): return "mouse:\(button.rawValue)"
        case .media(let key): return "media:\(key.rawValue)"
        case .system(let shortcut): return "system:\(shortcut.rawValue)"
        }
    }

    init?(raw: String) {
        let parts = raw.split(separator: ":").map(String.init)
        switch parts.first {
        case "none":
            self = .none
        case "key":
            guard parts.count == 3, let code = UInt16(parts[1]),
                  let flags = UInt64(parts[2]) else { return nil }
            self = .key(CGKeyCode(code), CGEventFlags(rawValue: flags))
        case "mouse":
            guard parts.count == 2, let button = MouseButton(rawValue: parts[1]) else { return nil }
            self = .mouse(button)
        case "media":
            guard parts.count == 2, let value = Int32(parts[1]),
                  let key = MediaKey(rawValue: value) else { return nil }
            self = .media(key)
        case "system":
            guard parts.count == 2, let shortcut = SystemShortcut(rawValue: parts[1]) else { return nil }
            self = .system(shortcut)
        default:
            return nil
        }
    }

    // MARK: - Comportamento

    // Click che devono restare premuti: il trascinamento nasce da qui.
    var isHold: Bool {
        switch self {
        case .mouse(.left), .mouse(.right): return true
        default: return false
        }
    }

    // Azioni sensate da ripetere tenendo premuto il tasto. Per la tastiera solo
    // frecce e scorrimento pagina: ripetere un ⌘W tenendo premuto chiuderebbe
    // mezzo browser.
    var repeatsWhenHeld: Bool {
        switch self {
        case .media(let key):
            return [.soundUp, .soundDown, .brightnessUp, .brightnessDown].contains(key)
        case .key(let code, _):
            return [123, 124, 125, 126, 116, 121].contains(Int(code))
        default:
            return false
        }
    }

    // MARK: - Come si legge

    var title: String {
        switch self {
        case .none: return L.t("action.none")
        case .key(let code, let flags): return Self.describe(code, flags)
        case .mouse(let button): return L.t(button.titleKey)
        case .media(let key): return L.t(key.titleKey)
        case .system(let shortcut): return L.t(shortcut.titleKey)
        }
    }

    static func describe(_ code: CGKeyCode, _ flags: CGEventFlags) -> String {
        var text = ""
        if flags.contains(.maskControl) { text += "⌃" }
        if flags.contains(.maskAlternate) { text += "⌥" }
        if flags.contains(.maskShift) { text += "⇧" }
        if flags.contains(.maskCommand) { text += "⌘" }
        return text + keyName(code)
    }

    // Tasti senza un carattere stampabile: glifi standard di macOS.
    private static let namedKeys: [Int: String] = [
        36: "↩", 76: "⌤", 48: "⇥", 49: "espazio", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟", 71: "⌧",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18",
        80: "F19", 90: "F20",
    ]

    static func keyName(_ code: CGKeyCode) -> String {
        if let named = namedKeys[Int(code)] {
            return named == "espazio" ? L.t("key.space") : named
        }
        if let printable = printableName(code) { return printable }
        return "#\(code)"
    }

    // Carattere che il tasto produce con la disposizione di tastiera in uso:
    // su una tastiera italiana il tasto Y deve leggersi Y, non Z.
    private static func printableName(_ code: CGKeyCode) -> String? {
        let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
            ?? TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
        guard let source,
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)

        var deadKeys: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)
        let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0,
                                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                    &deadKeys, characters.count, &length, &characters)
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: characters, count: length)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        return text.isEmpty ? nil : text
    }
}
