import AppKit

// Canali di contatto. Le voci di menu compaiono solo se il canale è configurato
// qui sotto: se un campo resta vuoto, la voce non viene mostrata affatto.
enum Feedback {
    // Il pulsante funziona per gli altri solo quando il repository è pubblico:
    // finché resta privato, chi non è HirpinO59 vede una pagina inesistente.
    static let repository = "https://github.com/HirpinO59/CouchPilot"

    // Pagina delle offerte, aperta dal pulsante "Buy Me a Coffee" della guida.
    static let coffee = "https://ko-fi.com/hirpino59"

    // Indirizzo per chi non ha un account GitHub: senza, quella fetta di utenti
    // resta senza modo di scrivere.
    // ⚠️ Finisce nel sorgente pubblico e dentro l'app, quindi i bot lo
    // raccolgono: metti in conto lo spam. Se un giorno diventa ingestibile si
    // cambia qui e basta — la voce di menu compare solo se questo campo è pieno.
    static let supportEmail = "gamerfromif95@gmail.com"

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

    // Apre la pagina delle versioni nel browser. L'app non chiede niente alla
    // rete da sé: nessun controllo in background, nessuna chiamata all'avvio.
    // Il confronto lo fa l'utente, che sulla pagina vede l'ultima versione e qui
    // sotto, nel menu, la propria.
    static func openReleases() {
        guard hasIssues, let url = URL(string: repository + "/releases/latest") else { return }
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
