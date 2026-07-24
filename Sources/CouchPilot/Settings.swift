import Foundation

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

    // Riporta tutti i tasti alle azioni predefinite.
    static func resetBindings() {
        let d = UserDefaults.standard
        for button in PadButton.all { d.removeObject(forKey: button.settingsKey) }
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
    let bindings: [String: PadAction]

    static func load() -> Tunables {
        let d = UserDefaults.standard
        var bindings: [String: PadAction] = [:]
        for button in PadButton.all { bindings[button.id] = button.action }
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
            bindings: bindings
        )
    }
}
