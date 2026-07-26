import Foundation

// Controllo aggiornamenti.
//
// È l'unica cosa che l'app manda in rete, e fa una cosa sola: chiedere a GitHub
// il numero dell'ultima versione pubblicata. Nessun dato viene inviato — nessun
// identificativo, nessuna statistica, nessun contenuto — e la risposta serve
// solo a scrivere una riga diversa nel menu. Lo scaricamento resta un gesto
// dell'utente, sulla pagina delle release aperta nel browser.
//
// Si può spegnere da Impostazioni: spento, non parte nessuna richiesta.
enum UpdateCheck {
    // L'ultima versione vista su GitHub, se è più recente di quella installata.
    private(set) static var available: String?

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "checkForUpdates") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "checkForUpdates") }
    }

    static var installedVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    // Una volta al giorno basta: un'app che sta in barra viene riavviata spesso,
    // e non c'è ragione di chiedere la stessa cosa a ogni avvio.
    private static let interval: TimeInterval = 24 * 60 * 60
    private static let lastCheckKey = "lastUpdateCheck"

    // `force` salta l'attesa fra due controlli, per la voce di menu.
    static func run(force: Bool = false, then done: (() -> Void)? = nil) {
        guard enabled else {
            available = nil
            done?()
            return
        }
        let last = UserDefaults.standard.double(forKey: lastCheckKey)
        let now = Date.timeIntervalSinceReferenceDate
        guard force || now - last > interval else {
            done?()
            return
        }

        guard let url = URL(string: "https://api.github.com/repos/HirpinO59/CouchPilot/releases/latest") else { return }
        var request = URLRequest(url: url, timeoutInterval: 10)
        // GitHub vuole un User-Agent: quello predefinito racconta più cose di
        // quante servano, questo dice il minimo indispensabile.
        request.setValue("CouchPilot", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            defer { DispatchQueue.main.async { done?() } }
            // Un controllo fallito non è un problema dell'utente: si riprova
            // domani, senza avvisi né finestre.
            guard error == nil, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                Log.write("controllo aggiornamenti non riuscito")
                return
            }
            UserDefaults.standard.set(now, forKey: lastCheckKey)
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            let newer = isNewer(latest, than: installedVersion)
            DispatchQueue.main.async { available = newer ? latest : nil }
            Log.write("ultima versione pubblicata \(latest), installata \(installedVersion)")
        }.resume()
    }

    // Confronto per numeri, non per stringa: "1.10.0" viene dopo "1.9.0".
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
