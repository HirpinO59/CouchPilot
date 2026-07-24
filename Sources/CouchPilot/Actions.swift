import Foundation

// Azioni assegnabili ai pulsanti configurabili (L3, R3, D-pad) dal menu.
enum PadAction: String, CaseIterable {
    case none
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
    case screenshotArea

    var title: String {
        switch self {
        case .screenshotArea: return L.t("action.screenshot")
        default: return L.t("action.\(rawValue)")
        }
    }

    // Azioni che ha senso ripetere tenendo premuto: alzare il volume di un
    // passo alla volta sarebbe scomodo, cambiare traccia a raffica no.
    var repeatsWhenHeld: Bool {
        switch self {
        case .volumeUp, .volumeDown, .brightnessUp, .brightnessDown: return true
        default: return false
        }
    }
}
