import Foundation
import ServiceManagement

// Avvio automatico al login. Si comanda da due posti — il menu e la guida
// rapida — quindi la logica sta qui una volta sola: così non possono
// raccontare due cose diverse.
enum LoginItem {
    static let changed = Notification.Name("CouchPilotLoginItemChanged")

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            Log.write("errore login item: \(error.localizedDescription)")
        }
        NotificationCenter.default.post(name: changed, object: nil)
    }
}

// Parametri regolabili da terminale:
//   defaults write com.hirpino.couchpilot maxSpeed -float 1400
enum Settings {
    static func register() {
        UserDefaults.standard.register(defaults: [
            "deadzone": 0.15,
            "exponent": 2.0,
            "maxSpeed": 1400.0,
            "scrollDeadzone": 0.20,
            "scrollSpeed": 700.0,
            "precisionFactor": 0.25,
            "boostFactor": 2.0,
            "language": "auto",
            "debugLog": false,
            "autoPauseGames": true,
            "excludedApps": ["com.nvidia.gfnpc.mall", "com.valvesoftware.steam"],
            "offsetRX": 0.0, "offsetRY": 0.0,
            "offsetLX": 0.0, "offsetLY": 0.0,
        ])
        migrateOldBindings()
        migrateToRecordedInput()
    }

    // Le assegnazioni prima stavano in chiavi separate (actionL3, actionDpadUp…):
    // si trasferiscono una volta sola nel nuovo schema bind<ID>.
    private static func migrateOldBindings() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "bindingsMigrated") else { return }
        let map = ["actionL3": "bindL3", "actionR3": "bindR3",
                   "actionDpadUp": "bindDpadUp", "actionDpadDown": "bindDpadDown",
                   "actionDpadLeft": "bindDpadLeft", "actionDpadRight": "bindDpadRight"]
        for (old, new) in map {
            if let value = d.string(forKey: old), d.string(forKey: new) == nil {
                d.set(value, forKey: new)
            }
            d.removeObject(forKey: old)
        }
        d.set(true, forKey: "bindingsMigrated")
    }

    // Fino alla 1.0 l'azione era una voce scelta da un elenco ("volumeUp").
    // Ora è l'input registrato dall'utente: le vecchie voci si traducono nel
    // corrispondente tasto media, click o scorciatoia di sistema.
    private static let legacyActions: [String: Binding] = [
        "none": .none,
        "leftClick": .mouse(.left),
        "rightClick": .mouse(.right),
        "middleClick": .mouse(.middle),
        "mute": .media(.mute),
        "playPause": .media(.play),
        "volumeUp": .media(.soundUp),
        "volumeDown": .media(.soundDown),
        "previousTrack": .media(.previous),
        "nextTrack": .media(.next),
        "brightnessUp": .media(.brightnessUp),
        "brightnessDown": .media(.brightnessDown),
        "missionControl": .system(.missionControl),
        "showDesktop": .system(.showDesktop),
        "spaceLeft": .system(.spaceLeft),
        "spaceRight": .system(.spaceRight),
        "screenshotArea": .key(21, [.maskCommand, .maskShift]),   // ⌘⇧4
    ]

    private static func migrateToRecordedInput() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "inputBindingsMigrated") else { return }
        for control in PadControl.buttons {
            guard let raw = d.string(forKey: control.settingsKey) else { continue }
            if let binding = legacyActions[raw] {
                d.set(binding.raw, forKey: control.settingsKey)
            } else if Binding(raw: raw) == nil {
                d.removeObject(forKey: control.settingsKey)   // valore illeggibile: torna al predefinito
            }
        }
        d.set(true, forKey: "inputBindingsMigrated")
    }

    // Riporta tutti i comandi ai valori predefiniti.
    static func resetBindings() {
        let d = UserDefaults.standard
        for control in PadControl.all { d.removeObject(forKey: control.settingsKey) }
    }
}

// Snapshot dei parametri, letto dal driver a intervalli regolari.
struct Tunables {
    let deadzone: Double
    let exponent: Double
    let maxSpeed: Double
    let scrollDeadzone: Double
    let scrollSpeed: Double
    let precisionFactor: Double
    let boostFactor: Double
    let debugLog: Bool
    let offsetRX: Double
    let offsetRY: Double
    let offsetLX: Double
    let offsetLY: Double
    let bindings: [String: Binding]
    let leftStick: StickRole
    let rightStick: StickRole

    static func load() -> Tunables {
        let d = UserDefaults.standard
        var bindings: [String: Binding] = [:]
        for control in PadControl.buttons { bindings[control.id] = control.binding }
        let sticks = PadControl.sticks
        return Tunables(
            deadzone: d.double(forKey: "deadzone"),
            exponent: d.double(forKey: "exponent"),
            maxSpeed: d.double(forKey: "maxSpeed"),
            scrollDeadzone: d.double(forKey: "scrollDeadzone"),
            scrollSpeed: d.double(forKey: "scrollSpeed"),
            precisionFactor: d.double(forKey: "precisionFactor"),
            boostFactor: d.double(forKey: "boostFactor"),
            debugLog: d.bool(forKey: "debugLog"),
            offsetRX: d.double(forKey: "offsetRX"),
            offsetRY: d.double(forKey: "offsetRY"),
            offsetLX: d.double(forKey: "offsetLX"),
            offsetLY: d.double(forKey: "offsetLY"),
            bindings: bindings,
            leftStick: sticks.first { $0.id == "LStick" }?.role ?? .cursor,
            rightStick: sticks.first { $0.id == "RStick" }?.role ?? .scroll
        )
    }
}
