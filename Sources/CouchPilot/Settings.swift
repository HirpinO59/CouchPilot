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
            "actionL3": "mute",
            "actionR3": "middleClick",
            "language": "auto",
            "menuHoldSeconds": 2.0,
            "debugLog": false,
            "autoPauseGames": true,
            "excludedApps": ["com.nvidia.gfnpc.mall", "com.valvesoftware.steam"],
            "offsetRX": 0.0, "offsetRY": 0.0,
            "offsetLX": 0.0, "offsetLY": 0.0,
        ])
    }
}

// Snapshot dei parametri letto a ogni tick (UserDefaults tiene la cache in memoria).
struct Tunables {
    let deadzone: Double
    let exponent: Double
    let maxSpeed: Double
    let scrollDeadzone: Double
    let scrollSpeed: Double
    let precisionFactor: Double
    let boostFactor: Double
    let actionL3: String
    let actionR3: String
    let debugLog: Bool
    let offsetRX: Double
    let offsetRY: Double
    let offsetLX: Double
    let offsetLY: Double

    // Letta a parte: serve anche quando l'app è disattivata, prima del resto.
    static func menuHoldSeconds() -> Double {
        max(UserDefaults.standard.double(forKey: "menuHoldSeconds"), 0.15)
    }

    static func load() -> Tunables {
        let d = UserDefaults.standard
        return Tunables(
            deadzone: d.double(forKey: "deadzone"),
            exponent: d.double(forKey: "exponent"),
            maxSpeed: d.double(forKey: "maxSpeed"),
            scrollDeadzone: d.double(forKey: "scrollDeadzone"),
            scrollSpeed: d.double(forKey: "scrollSpeed"),
            precisionFactor: d.double(forKey: "precisionFactor"),
            boostFactor: d.double(forKey: "boostFactor"),
            actionL3: d.string(forKey: "actionL3") ?? "none",
            actionR3: d.string(forKey: "actionR3") ?? "none",
            debugLog: d.bool(forKey: "debugLog"),
            offsetRX: d.double(forKey: "offsetRX"),
            offsetRY: d.double(forKey: "offsetRY"),
            offsetLX: d.double(forKey: "offsetLX"),
            offsetLY: d.double(forKey: "offsetLY")
        )
    }
}
