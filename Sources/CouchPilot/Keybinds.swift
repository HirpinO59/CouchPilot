import CoreGraphics
import GameController

// Riconoscimento del pad dal nome che dichiara.
enum Controllers {
    static func isPlayStation(_ name: String?) -> Bool {
        let name = (name ?? "").lowercased()
        // "Wireless Controller" da solo è il DualShock 4, ma compare anche in
        // "Xbox Wireless Controller": se c'è scritto Xbox non si discute.
        guard !name.contains("xbox") else { return false }
        return ["dualsense", "dualshock", "wireless controller", "playstation"]
            .contains { name.contains($0) }
    }

    // I due tasti piccoli al centro, coi nomi ufficiali di ciascun pad:
    // View/Menu su Xbox, Create/Options su DualSense.
    static func toggleNames(playStation: Bool) -> (left: String, right: String) {
        playStation ? ("Create", "Options") : ("View", "Menu")
    }
}

// Elenco dei comandi configurabili, con il valore predefinito e il punto in cui
// attaccare la didascalia su ciascun disegno.
//
// Gli stick compaiono due volte, perché sono due cose diverse: la pressione
// (L3/R3) è un tasto come gli altri e si registra; il movimento non si registra
// e sceglie solo che ruolo ha (cursore, scorrimento, niente).
//
// Gli agganci sono normalizzati sul riquadro del disegno: x da -1 (sinistra)
// a +1, y da -1 (basso) a +1. Restano validi se l'immagine cambia misura.
struct PadControl {
    enum Kind {
        case button      // si registra premendo tastiera o mouse
        case stickMove   // si sceglie il ruolo fra cursore / scorrimento / niente
    }

    // Da che parte esce la didascalia. I tasti centrali non appartengono a
    // nessuna delle due colonne: la loro linea sale dritta sopra il disegno.
    enum Side {
        case left, right, above
    }

    let id: String          // suffisso della chiave in UserDefaults
    let kind: Kind
    let xboxName: String
    let psName: String
    let defaultBinding: Binding
    let defaultRole: StickRole
    let side: Side
    let xbox: CGPoint
    let dualSense: CGPoint

    init(id: String, kind: Kind = .button, xboxName: String, psName: String,
         binding: Binding = .none, role: StickRole = .off, side: Side,
         xbox: CGPoint, dualSense: CGPoint) {
        self.id = id
        self.kind = kind
        self.xboxName = xboxName
        self.psName = psName
        self.defaultBinding = binding
        self.defaultRole = role
        self.side = side
        self.xbox = xbox
        self.dualSense = dualSense
    }

    // View è anche metà del comando di accensione: la sua azione si decide al
    // rilascio, così premendo View + Menu non parte anche questa.
    var firesOnRelease: Bool { id == "View" }

    func isPressed(_ pad: GCExtendedGamepad) -> Bool {
        switch id {
        case "A": return pad.buttonA.isPressed
        case "B": return pad.buttonB.isPressed
        case "X": return pad.buttonX.isPressed
        case "Y": return pad.buttonY.isPressed
        case "LB": return pad.leftShoulder.isPressed
        case "RB": return pad.rightShoulder.isPressed
        case "L3": return pad.leftThumbstickButton?.isPressed ?? false
        case "R3": return pad.rightThumbstickButton?.isPressed ?? false
        case "DpadUp": return pad.dpad.up.isPressed
        case "DpadDown": return pad.dpad.down.isPressed
        case "DpadLeft": return pad.dpad.left.isPressed
        case "DpadRight": return pad.dpad.right.isPressed
        case "View": return pad.buttonOptions?.isPressed ?? false
        default: return false
        }
    }

    func anchor(playStation: Bool) -> CGPoint { playStation ? dualSense : xbox }

    // Gli stick portano una chiave di traduzione al posto della sigla del tasto.
    func name(playStation: Bool) -> String {
        let raw = playStation ? psName : xboxName
        return kind == .stickMove ? L.t(raw) : raw
    }

    var settingsKey: String { kind == .button ? "bind\(id)" : "role\(id)" }

    var binding: Binding {
        let raw = UserDefaults.standard.string(forKey: settingsKey)
        return raw.flatMap(Binding.init(raw:)) ?? defaultBinding
    }

    var role: StickRole {
        let raw = UserDefaults.standard.string(forKey: settingsKey)
        return raw.flatMap(StickRole.init(rawValue:)) ?? defaultRole
    }

    static let all: [PadControl] = [
        // --- lato sinistro ---
        PadControl(id: "LB", xboxName: "LB", psName: "L1",
                   binding: .system(.spaceLeft), side: .left,
                   xbox: CGPoint(x: -0.37, y: 0.67), dualSense: CGPoint(x: -0.57, y: 0.88)),
        PadControl(id: "L3", xboxName: "L3", psName: "L3",
                   binding: .media(.mute), side: .left,
                   xbox: CGPoint(x: -0.44, y: 0.20), dualSense: CGPoint(x: -0.26, y: 0.24)),
        PadControl(id: "LStick", kind: .stickMove, xboxName: "pad.leftStick", psName: "pad.leftStick",
                   role: .cursor, side: .left,
                   xbox: CGPoint(x: -0.58, y: -0.01), dualSense: CGPoint(x: -0.47, y: -0.05)),
        PadControl(id: "DpadUp", xboxName: "▲", psName: "▲",
                   binding: .media(.soundUp), side: .left,
                   xbox: CGPoint(x: -0.24, y: -0.17), dualSense: CGPoint(x: -0.67, y: 0.71)),
        PadControl(id: "DpadLeft", xboxName: "◀", psName: "◀",
                   binding: .media(.previous), side: .left,
                   xbox: CGPoint(x: -0.37, y: -0.29), dualSense: CGPoint(x: -0.81, y: 0.51)),
        PadControl(id: "DpadRight", xboxName: "▶", psName: "▶",
                   binding: .media(.next), side: .left,
                   xbox: CGPoint(x: -0.11, y: -0.31), dualSense: CGPoint(x: -0.53, y: 0.50)),
        PadControl(id: "DpadDown", xboxName: "▼", psName: "▼",
                   binding: .media(.soundDown), side: .left,
                   xbox: CGPoint(x: -0.24, y: -0.44), dualSense: CGPoint(x: -0.67, y: 0.32)),
        // --- lato destro ---
        PadControl(id: "RB", xboxName: "RB", psName: "R1",
                   binding: .system(.spaceRight), side: .right,
                   xbox: CGPoint(x: 0.34, y: 0.67), dualSense: CGPoint(x: 0.57, y: 0.88)),
        PadControl(id: "Y", xboxName: "Y", psName: "△",
                   binding: .media(.play), side: .right,
                   xbox: CGPoint(x: 0.48, y: 0.32), dualSense: CGPoint(x: 0.65, y: 0.70)),
        PadControl(id: "B", xboxName: "B", psName: "◯",
                   binding: .system(.missionControl), side: .right,
                   xbox: CGPoint(x: 0.62, y: 0.12), dualSense: CGPoint(x: 0.79, y: 0.51)),
        PadControl(id: "X", xboxName: "X", psName: "▢",
                   binding: .mouse(.right), side: .right,
                   xbox: CGPoint(x: 0.34, y: 0.11), dualSense: CGPoint(x: 0.51, y: 0.50)),
        PadControl(id: "A", xboxName: "A", psName: "✕",
                   binding: .mouse(.left), side: .right,
                   xbox: CGPoint(x: 0.48, y: -0.10), dualSense: CGPoint(x: 0.65, y: 0.31)),
        PadControl(id: "R3", xboxName: "R3", psName: "R3",
                   binding: .mouse(.middle), side: .right,
                   xbox: CGPoint(x: 0.31, y: -0.19), dualSense: CGPoint(x: 0.41, y: 0.24)),
        PadControl(id: "RStick", kind: .stickMove, xboxName: "pad.rightStick", psName: "pad.rightStick",
                   role: .scroll, side: .right,
                   xbox: CGPoint(x: 0.17, y: -0.42), dualSense: CGPoint(x: 0.20, y: -0.05)),
        // --- al centro, didascalia sopra il disegno ---
        PadControl(id: "View", xboxName: "View", psName: "Create",
                   binding: .system(.showDesktop), side: .above,
                   xbox: CGPoint(x: -0.14, y: 0.14), dualSense: CGPoint(x: -0.52, y: 0.82)),
    ]

    static var buttons: [PadControl] { all.filter { $0.kind == .button } }
    static var sticks: [PadControl] { all.filter { $0.kind == .stickMove } }

    // Le tre scelte più sensate per questo tasto, in cima al menu: coprono il
    // caso normale senza far registrare niente. Chi vuole altro usa "Registra".
    // I tasti sono indicati per codice, non per lettera, così restano gli stessi
    // su qualunque disposizione di tastiera.
    var suggestions: [Binding] {
        switch id {
        case "LB":         return [.system(.spaceLeft), .key(123, .maskCommand), .system(.missionControl)]
        case "L3":         return [.media(.mute), .key(21, [.maskCommand, .maskShift]), .system(.showDesktop)]
        case "DpadUp":     return [.media(.soundUp), .key(126, []), .key(116, [])]
        case "DpadDown":   return [.media(.soundDown), .key(125, []), .key(121, [])]
        case "DpadLeft":   return [.media(.previous), .key(123, []), .system(.spaceLeft)]
        case "DpadRight":  return [.media(.next), .key(124, []), .system(.spaceRight)]
        case "RB":         return [.system(.spaceRight), .key(124, .maskCommand), .key(48, .maskCommand)]
        case "Y":          return [.media(.play), .key(3, [.maskControl, .maskCommand]), .key(53, [])]
        case "B":          return [.system(.missionControl), .key(53, []), .system(.showDesktop)]
        case "X":          return [.mouse(.right), .key(36, []), .key(13, .maskCommand)]
        case "A":          return [.mouse(.left), .key(36, []), .key(49, [])]
        case "R3":         return [.mouse(.middle), .system(.showDesktop), .key(21, [.maskCommand, .maskShift])]
        case "View":       return [.system(.showDesktop), .system(.missionControl), .key(21, [.maskCommand, .maskShift])]
        default:           return []
        }
    }

}
