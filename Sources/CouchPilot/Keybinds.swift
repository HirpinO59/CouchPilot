import CoreGraphics
import GameController

// Elenco dei tasti assegnabili, con l'azione predefinita e il punto in cui
// attaccare la didascalia su ciascun disegno.
// Gli agganci sono normalizzati sul riquadro del disegno: x da -1 (sinistra)
// a +1, y da -1 (basso) a +1. Restano validi se l'immagine cambia misura.
struct PadButton {
    let id: String          // suffisso della chiave in UserDefaults: bind<id>
    let xboxName: String
    let psName: String
    let defaultAction: PadAction
    let onLeft: Bool        // lato su cui esce la didascalia
    let xbox: CGPoint
    let dualSense: CGPoint

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
        default: return false
        }
    }

    func anchor(playStation: Bool) -> CGPoint { playStation ? dualSense : xbox }

    func name(playStation: Bool) -> String { playStation ? psName : xboxName }

    var settingsKey: String { "bind\(id)" }

    var action: PadAction {
        let raw = UserDefaults.standard.string(forKey: settingsKey)
        return raw.flatMap(PadAction.init(rawValue:)) ?? defaultAction
    }

    static let all: [PadButton] = [
        // --- lato sinistro ---
        PadButton(id: "LB", xboxName: "LB", psName: "L1", defaultAction: .spaceLeft, onLeft: true,
                  xbox: CGPoint(x: -0.37, y: 0.67), dualSense: CGPoint(x: -0.57, y: 0.88)),
        PadButton(id: "L3", xboxName: "L3", psName: "L3", defaultAction: .mute, onLeft: true,
                  xbox: CGPoint(x: -0.57, y: 0.06), dualSense: CGPoint(x: -0.34, y: 0.15)),
        PadButton(id: "DpadUp", xboxName: "▲", psName: "▲", defaultAction: .volumeUp, onLeft: true,
                  xbox: CGPoint(x: -0.23, y: -0.21), dualSense: CGPoint(x: -0.67, y: 0.71)),
        PadButton(id: "DpadLeft", xboxName: "◀", psName: "◀", defaultAction: .previousTrack, onLeft: true,
                  xbox: CGPoint(x: -0.31, y: -0.31), dualSense: CGPoint(x: -0.81, y: 0.51)),
        PadButton(id: "DpadRight", xboxName: "▶", psName: "▶", defaultAction: .nextTrack, onLeft: true,
                  xbox: CGPoint(x: -0.16, y: -0.32), dualSense: CGPoint(x: -0.54, y: 0.50)),
        PadButton(id: "DpadDown", xboxName: "▼", psName: "▼", defaultAction: .volumeDown, onLeft: true,
                  xbox: CGPoint(x: -0.23, y: -0.42), dualSense: CGPoint(x: -0.67, y: 0.32)),
        // --- lato destro ---
        PadButton(id: "RB", xboxName: "RB", psName: "R1", defaultAction: .spaceRight, onLeft: false,
                  xbox: CGPoint(x: 0.34, y: 0.67), dualSense: CGPoint(x: 0.57, y: 0.88)),
        PadButton(id: "Y", xboxName: "Y", psName: "△", defaultAction: .playPause, onLeft: false,
                  xbox: CGPoint(x: 0.48, y: 0.32), dualSense: CGPoint(x: 0.65, y: 0.70)),
        PadButton(id: "B", xboxName: "B", psName: "◯", defaultAction: .missionControl, onLeft: false,
                  xbox: CGPoint(x: 0.62, y: 0.11), dualSense: CGPoint(x: 0.79, y: 0.51)),
        PadButton(id: "X", xboxName: "X", psName: "▢", defaultAction: .rightClick, onLeft: false,
                  xbox: CGPoint(x: 0.34, y: 0.11), dualSense: CGPoint(x: 0.51, y: 0.51)),
        PadButton(id: "A", xboxName: "A", psName: "✕", defaultAction: .leftClick, onLeft: false,
                  xbox: CGPoint(x: 0.48, y: -0.10), dualSense: CGPoint(x: 0.65, y: 0.32)),
        PadButton(id: "R3", xboxName: "R3", psName: "R3", defaultAction: .middleClick, onLeft: false,
                  xbox: CGPoint(x: 0.19, y: -0.33), dualSense: CGPoint(x: 0.30, y: 0.15)),
    ]

    // Comandi non assegnabili, elencati sotto il disegno perché la guida sia completa.
    static let fixedNotes = ["pad.fixedSticks", "pad.fixedTriggers", "pad.fixedToggle"]
}
