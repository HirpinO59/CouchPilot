import AppKit

// Canali di contatto. Le voci di menu compaiono solo se il canale è configurato
// qui sotto: se un campo resta vuoto, la voce non viene mostrata affatto.
enum Feedback {
    // Il pulsante funziona per gli altri solo quando il repository è pubblico:
    // finché resta privato, chi non è HirpinO59 vede una pagina inesistente.
    static let repository = "https://github.com/HirpinO59/CouchPilot"

    // Indirizzo per chi non ha un account GitHub.
    // ⚠️ Usare un indirizzo dedicato all'app, MAI quello personale: una volta
    // pubblicato finisce nelle liste di spam e non si torna indietro.
    // Lasciare vuoto per non mostrare la voce.
    static let supportEmail = ""

    static var hasIssues: Bool { !repository.isEmpty }
    static var hasEmail: Bool { !supportEmail.isEmpty }

    // Dati tecnici allegati alla segnalazione. Sono le stesse informazioni che
    // servirebbero a mano per capire un problema: versione, sistema, pad.
    // L'utente le vede nel modulo già compilato e può cancellarle.
    private static func diagnostics(controller: String?) -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return """
        - CouchPilot: \(version)
        - macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        - Mac: \(hardwareModel())
        - Controller: \(controller ?? L.t("status.noController"))
        """
    }

    private static func hardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "?" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    // Apre GitHub con la segnalazione già impostata: modello da compilare più
    // i dati tecnici in fondo, così non serve chiederli dopo.
    static func openIssues(controller: String?) {
        guard hasIssues, var components = URLComponents(string: repository + "/issues/new") else { return }
        let body = """
        **\(L.t("feedback.what"))**


        **\(L.t("feedback.expected"))**


        **\(L.t("feedback.steps"))**
        1.

        ---
        \(diagnostics(controller: controller))
        """
        components.queryItems = [URLQueryItem(name: "body", value: body)]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    // Apre il client di posta con una bozza già compilata. L'utente la vede e la
    // modifica prima di inviare: nulla parte a sua insaputa.
    static func composeEmail(controller: String?) {
        guard hasEmail else { return }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "CouchPilot \(version) — feedback"),
            URLQueryItem(name: "body", value: "\n\n---\n" + diagnostics(controller: controller)),
        ]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }
}
