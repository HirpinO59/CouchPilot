import Foundation

// Azioni assegnabili ai tasti del controller.
enum PadAction: String, CaseIterable {
    case none
    case leftClick
    case rightClick
    case middleClick
    case mute
    case playPause
    case volumeUp
    case volumeDown
    case previousTrack
    case nextTrack
    case brightnessUp
    case brightnessDown
    case missionControl
    case showDesktop
    case spaceLeft
    case spaceRight
    case screenshotArea

    var title: String {
        switch self {
        case .screenshotArea: return L.t("action.screenshot")
        default: return L.t("action.\(rawValue)")
        }
    }

    // Click che devono restare premuti: il trascinamento nasce da qui.
    var isHold: Bool {
        self == .leftClick || self == .rightClick
    }

    // Azioni sensate da ripetere tenendo premuto il tasto.
    var repeatsWhenHeld: Bool {
        switch self {
        case .volumeUp, .volumeDown, .brightnessUp, .brightnessDown: return true
        default: return false
        }
    }
}
