import AppKit
import ApplicationServices

enum PermissionsGate {
    // Segnalata quando il permesso viene concesso ad app avviata: la guida
    // rapida se ne accorge e aggiorna il riquadro senza doverla riaprire.
    static let granted = Notification.Name("CouchPilotAccessibilityGranted")

    static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func requestIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
