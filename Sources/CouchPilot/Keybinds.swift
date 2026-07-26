import CoreGraphics
import GameController

// Le famiglie di pad che l'app sa nominare. Non è una tassonomia dei pad in
// commercio: è l'insieme delle sigle stampate sui tasti, che è la sola cosa che
// serve per non dire all'utente "premi R2" mentre lui legge "RT".
enum PadFamily {
    case xbox, playStation, eightBitDo

    // I due tasti piccoli al centro, coi nomi ufficiali di ciascun pad.
    var toggleNames: (left: String, right: String) {
        switch self {
        case .xbox:        return ("View", "Menu")
        case .playStation: return ("Create", "Options")
        case .eightBitDo:  return ("−", "+")
        }
    }

    // I grilletti: non si riassegnano (precisione e turbo), ma vanno chiamati
    // col nome che l'utente si trova stampato sul pad.
    var triggerNames: (left: String, right: String) {
        self == .playStation ? ("L2", "R2") : ("LT", "RT")
    }
}

// Riconoscimento del pad: prima dal profilo che dichiara al sistema, che è
// l'unica informazione certa; il nome resta un ripiego per i pad che non si
// dichiarano né Xbox né PlayStation.
enum Controllers {
    // Famiglia rilevata dal profilo del pad collegato. nil = nessun pad, o pad
    // che non rientra in nessuna delle famiglie che il profilo sa distinguere.
    private static var detected: PadFamily?

    // Chiamata quando un pad viene adottato o lasciato: da qui in poi le sigle
    // seguono il profilo, non il nome.
    static func adopt(_ controller: GCController?) {
        guard let controller, let pad = controller.extendedGamepad else {
            detected = nil
            return
        }
        if pad is GCDualSenseGamepad || pad is GCDualShockGamepad {
            detected = .playStation
        } else if named8BitDo(controller.vendorName) {
            // Anche col profilo Xbox (i loro pad lo espongono spesso) le sigle
            // stampate restano le loro: i tasti centrali sono − e +.
            detected = .eightBitDo
        } else if pad is GCXboxGamepad {
            detected = .xbox
        } else {
            detected = nil
        }
    }

    static func family(_ name: String?) -> PadFamily {
        detected ?? familyFromName(name)
    }

    static func isPlayStation(_ name: String?) -> Bool {
        family(name) == .playStation
    }

    // Che profilo espone il pad e che famiglia gli abbiamo assegnato. Finisce
    // nel log: quando qualcuno segnala che vede il pad sbagliato, questa riga
    // dice subito se il profilo era generico e abbiamo tirato a indovinare.
    static func describe(_ controller: GCController) -> String {
        let profile: String
        switch controller.extendedGamepad {
        case is GCDualSenseGamepad: profile = "DualSense"
        case is GCDualShockGamepad: profile = "DualShock"
        case is GCXboxGamepad:      profile = "Xbox"
        default:                    profile = "generico"
        }
        return "profilo \(profile) → sigle \(family(controller.vendorName))"
    }

    // Ripiego sul nome, per i pad che espongono un profilo esteso generico.
    // Deve restare avaro: sbagliare qui vuol dire chiamare i tasti col nome
    // che non hanno.
    private static func familyFromName(_ name: String?) -> PadFamily {
        let name = (name ?? "").lowercased().trimmingCharacters(in: .whitespaces)
        if named8BitDo(name) { return .eightBitDo }
        guard !name.contains("xbox") else { return .xbox }
        // "Wireless Controller" da solo è il DualShock 4. Dentro un nome più
        // lungo (8BitDo Ultimate Wireless Controller e simili) non dice niente:
        // vale solo se il pad non ha altro da dire su di sé.
        if name == "wireless controller" { return .playStation }
        let playStation = ["dualsense", "dualshock", "playstation"]
        return playStation.contains { name.contains($0) } ? .playStation : .xbox
    }

    private static func named8BitDo(_ name: String?) -> Bool {
        (name ?? "").lowercased().contains("8bitdo")
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
    // Sigla sui pad 8BitDo, solo dove è diversa da quella Xbox: lettere,
    // dorsali e direzionale hanno gli stessi nomi, i due centrali no.
    let altName: String?
    let defaultBinding: Binding
    let defaultRole: StickRole
    let side: Side
    let xbox: CGPoint
    let dualSense: CGPoint
    // Aggancio sul disegno 8BitDo: manca finché il disegno non c'è, e finché
    // manca si mostra il pad Xbox coi suoi agganci.
    let eightBitDo: CGPoint?

    init(id: String, kind: Kind = .button, xboxName: String, psName: String,
         altName: String? = nil, binding: Binding = .none, role: StickRole = .off,
         side: Side, xbox: CGPoint, dualSense: CGPoint, eightBitDo: CGPoint? = nil) {
        self.id = id
        self.kind = kind
        self.xboxName = xboxName
        self.psName = psName
        self.altName = altName
        self.defaultBinding = binding
        self.defaultRole = role
        self.side = side
        self.xbox = xbox
        self.dualSense = dualSense
        self.eightBitDo = eightBitDo
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

    // L'aggancio segue il disegno che si sta mostrando, non la famiglia del pad:
    // se il pad non ha un disegno suo si vede l'Xbox, e le didascalie devono
    // puntare ai tasti di quello.
    func anchor(on art: PadFamily) -> CGPoint {
        switch art {
        case .playStation: return dualSense
        case .eightBitDo:  return eightBitDo ?? xbox
        case .xbox:        return xbox
        }
    }

    // La sigla invece segue il pad vero: è quella che l'utente legge sui tasti.
    // Gli stick portano una chiave di traduzione al posto della sigla.
    func name(for family: PadFamily) -> String {
        let raw: String
        switch family {
        case .playStation: raw = psName
        case .eightBitDo:  raw = altName ?? xboxName
        case .xbox:        raw = xboxName
        }
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
        PadControl(id: "View", xboxName: "View", psName: "Create", altName: "−",
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
