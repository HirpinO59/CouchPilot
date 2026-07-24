import Foundation

// Azioni assegnabili ai pulsanti configurabili (L3/R3) dal menu.
enum PadAction: String, CaseIterable {
    case none
    case middleClick
    case mute
    case playPause
    case volumeUp
    case volumeDown
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
}
