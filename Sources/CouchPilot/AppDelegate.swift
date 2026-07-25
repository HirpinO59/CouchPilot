import AppKit
import GameController
import ServiceManagement
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = ControllerMonitor()
    private let driver = CursorDriver()
    private var enabled = true
    private var suspended = false
    private var trusted = false
    private var trustTimer: Timer?
    private var lastFrontApp: NSRunningApplication?

    // Stato mostrato nel menu, tenuto a parte dai testi: cambiando lingua il
    // menu si ricostruisce e le etichette vanno ricalcolate da qui.
    private var controllerName: String?
    private var pauseReason: String?
    private var calibrating = false
    private var battery: BatteryReader.Reading?
    private var lastBatteryCheck = 0.0
    private var batteryRetries = 0

    private let statusInfoItem = NSMenuItem()
    private let pauseInfoItem = NSMenuItem()
    private var enabledItem: NSMenuItem!
    private var calibrateItem: NSMenuItem!
    private var gamesPauseItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var axItem: NSMenuItem!
    private let exclusionsMenu = NSMenu()
    private let languageMenu = NSMenu()
    private var rootMenu: NSMenu?
    private var presetSubmenus: [(menu: NSMenu, key: String)] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.register()
        // senza questa riga l'input del pad arriva solo con l'app in primo piano
        GCController.shouldMonitorBackgroundEvents = true

        trusted = PermissionsGate.requestIfNeeded()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        buildMenu()

        driver.onEnabledChanged = { [weak self] on in
            self?.enabled = on
            self?.refreshUI()
        }
        driver.onCalibrationDone = { [weak self] in
            self?.calibrating = false
            self?.refreshUI()
        }
        // ☰ da solo apre il menu in barra: un click finto sull'icona, così si
        // apre come se l'avessi cliccata col mouse — e col pad ci si naviga
        // dentro, visto che cursore e click continuano a funzionare.
        driver.onOpenMenu = { [weak self] in
            self?.statusItem.button?.performClick(nil)
        }

        monitor.onConnect = { [weak self] controller in
            guard let self, let pad = controller.extendedGamepad else { return }
            self.driver.updateScreens(ScreenMap.current())
            self.driver.start(gamepad: pad)
            self.controllerName = controller.vendorName ?? L.t("status.connected")
            self.batteryRetries = 0
            self.refreshUI()
            self.refreshBattery(force: true)
        }
        monitor.onDisconnect = { [weak self] _ in
            guard let self else { return }
            self.driver.stop()
            self.controllerName = nil
            self.battery = nil
            self.refreshUI()
        }
        monitor.start()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.driver.updateScreens(ScreenMap.current())
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.frontAppChanged(app)
        }
        if let front = NSWorkspace.shared.frontmostApplication {
            frontAppChanged(front)
        }

        if !trusted { startTrustPolling() }
        refreshUI()
        WelcomeWindow.showIfFirstRun(controller: controllerName)
    }

    func applicationWillTerminate(_ notification: Notification) {
        driver.stop()
    }

    // MARK: - Esclusioni (auto-pausa per app in primo piano)

    private static func excludedIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: "excludedApps") ?? []
    }

    private func frontAppChanged(_ app: NSRunningApplication) {
        guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        lastFrontApp = app
        evaluateSuspension()
    }

    private func evaluateSuspension() {
        var reason: String?
        if let app = lastFrontApp, let id = app.bundleIdentifier {
            let name = app.localizedName ?? id
            if Self.excludedIds().contains(id) {
                reason = name
            } else if UserDefaults.standard.bool(forKey: "autoPauseGames"), Self.isGame(app) {
                reason = L.t("status.gameSuffix", name)
            }
        }
        pauseReason = reason
        let suspend = reason != nil
        if suspend != suspended {
            suspended = suspend
            driver.setSuspended(suspend)
            Log.write(suspend ? "in pausa (\(reason ?? "?"))" : "riattivata")
        }
        refreshUI()
    }

    // Stessa informazione usata da macOS per la modalità gioco: la categoria
    // dichiarata nell'Info.plist dell'app (non esiste un'API pubblica per la
    // modalità gioco in sé).
    private static func isGame(_ app: NSRunningApplication) -> Bool {
        guard let url = app.bundleURL,
              let category = Bundle(url: url)?.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        else { return false }
        return category == "public.app-category.games" || category.hasSuffix("-games")
    }

    private func appName(forBundleId id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return url.deletingPathExtension().lastPathComponent
    }

    // ☰ dal pad apre e chiude: il driver deve sapere qual è lo stato attuale,
    // altrimenti la seconda pressione riaprirebbe invece di chiudere.
    func menuWillOpen(_ menu: NSMenu) {
        if menu === rootMenu { driver.setMenuOpen(true) }
    }

    func menuDidClose(_ menu: NSMenu) {
        if menu === rootMenu { driver.setMenuOpen(false) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === rootMenu {
            refreshBattery()
            refreshUI()
            return
        }
        if let entry = presetSubmenus.first(where: { $0.menu === menu }) {
            let current = UserDefaults.standard.double(forKey: entry.key)
            for item in menu.items {
                let value = item.representedObject as? Double
                item.state = (value != nil && abs(value! - current) < 0.001) ? .on : .off
            }
            return
        }
        if menu === languageMenu {
            for item in menu.items {
                item.state = (item.representedObject as? String) == L.current.rawValue ? .on : .off
            }
            return
        }
        guard menu === exclusionsMenu else { return }
        menu.removeAllItems()
        let ids = Self.excludedIds()
        for id in ids {
            let item = NSMenuItem(title: appName(forBundleId: id),
                                  action: #selector(removeExclusion(_:)), keyEquivalent: "")
            item.target = self
            item.state = .on
            item.representedObject = id
            menu.addItem(item)
        }
        if ids.isEmpty {
            let empty = NSMenuItem(title: L.t("menu.noExcluded"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        menu.addItem(.separator())
        let add = NSMenuItem(title: L.t("menu.addApp"), action: #selector(addExclusion), keyEquivalent: "")
        add.target = self
        menu.addItem(add)
    }

    // Selettore vero sulla cartella Applicazioni: proporre l'app in primo piano
    // non serviva, davanti c'è sempre quella da cui apri il menu.
    @objc private func addExclusion() {
        // fuori dal ciclo del menu, altrimenti il pannello nasce dietro
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let panel = NSOpenPanel()
            panel.message = L.t("panel.title")
            panel.prompt = L.t("panel.choose")
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
            panel.allowedContentTypes = [.application]
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.treatsFilePackagesAsDirectories = false
            NSApp.activate(ignoringOtherApps: true)
            guard panel.runModal() == .OK else { return }

            var ids = Self.excludedIds()
            for url in panel.urls {
                guard let id = Bundle(url: url)?.bundleIdentifier else {
                    Log.write("app senza identificativo, ignorata: \(url.lastPathComponent)")
                    continue
                }
                if !ids.contains(id) { ids.append(id) }
            }
            UserDefaults.standard.set(ids, forKey: "excludedApps")
            self.evaluateSuspension()
        }
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double,
              let key = presetSubmenus.first(where: { $0.menu === sender.menu })?.key else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = Language(rawValue: raw) else { return }
        L.current = language
        buildMenu() // le voci sono già create: vanno rifatte con i testi nuovi
        refreshUI()
    }

    @objc private func resetSettings() {
        ["maxSpeed", "scrollSpeed", "deadzone", "scrollDeadzone", "exponent",
         "precisionFactor", "boostFactor"].forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }
    }

    @objc private func removeExclusion(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        UserDefaults.standard.set(Self.excludedIds().filter { $0 != id }, forKey: "excludedApps")
        evaluateSuspension()
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        rootMenu = menu

        statusInfoItem.isEnabled = false
        menu.addItem(statusInfoItem)
        pauseInfoItem.isEnabled = false
        menu.addItem(pauseInfoItem)
        menu.addItem(.separator())

        enabledItem = NSMenuItem(title: L.t("menu.active"), action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        menu.addItem(enabledItem)

        calibrateItem = NSMenuItem(title: L.t("menu.calibrate"), action: #selector(calibrate), keyEquivalent: "")
        calibrateItem.target = self
        menu.addItem(calibrateItem)

        menu.addItem(buildSettingsItem())
        menu.addItem(.separator())

        loginItem = NSMenuItem(title: L.t("menu.login"), action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        axItem = NSMenuItem(title: L.t("menu.accessibility"), action: #selector(openAX), keyEquivalent: "")
        axItem.target = self
        menu.addItem(axItem)

        let keybindsItem = NSMenuItem(title: L.t("menu.keybinds"),
                                      action: #selector(openKeybinds), keyEquivalent: "")
        keybindsItem.target = self
        menu.addItem(keybindsItem)

        let guideItem = NSMenuItem(title: L.t("menu.welcome"), action: #selector(openWelcome), keyEquivalent: "")
        guideItem.target = self
        menu.addItem(guideItem)

        if let feedbackItem = buildFeedbackItem() { menu.addItem(feedbackItem) }

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: L.t("menu.quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // nil se non è configurato nessun canale: meglio niente voce che una voce morta
    private func buildFeedbackItem() -> NSMenuItem? {
        let channels: [(Bool, String, Selector)] = [
            (Feedback.hasIssues, "feedback.issues", #selector(openIssues)),
            (Feedback.hasEmail, "feedback.email", #selector(composeFeedbackEmail)),
        ].filter { $0.0 }
        guard !channels.isEmpty else { return nil }

        // un canale solo: voce diretta, senza sottomenu inutile
        if channels.count == 1 {
            let item = NSMenuItem(title: L.t(channels[0].1), action: channels[0].2, keyEquivalent: "")
            item.target = self
            return item
        }
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for (_, key, action) in channels {
            let item = NSMenuItem(title: L.t(key), action: action, keyEquivalent: "")
            item.target = self
            submenu.addItem(item)
        }
        let holder = NSMenuItem(title: L.t("menu.feedback"), action: nil, keyEquivalent: "")
        holder.submenu = submenu
        return holder
    }

    private func buildSettingsItem() -> NSMenuItem {
        let settingsMenu = NSMenu()
        settingsMenu.autoenablesItems = false

        presetSubmenus.removeAll()
        let presets: [(String, String, [(String, Double)])] = [
            ("set.cursorSpeed", "maxSpeed",
             [("val.slow", 800), ("val.normal", 1400), ("val.fast", 2000), ("val.turbo", 2800)]),
            ("set.scrollSpeed", "scrollSpeed",
             [("val.slow", 400), ("val.normal", 700), ("val.fast", 1100)]),
            ("set.deadzone", "deadzone",
             [("val.low", 0.10), ("val.normal", 0.15), ("val.high", 0.25)]),
            ("set.curve", "exponent",
             [("val.linear", 1.0), ("val.soft", 1.5), ("val.standard", 2.0), ("val.progressive", 2.5)]),
            ("set.precision", "precisionFactor",
             [("val.eighth", 0.125), ("val.quarter", 0.25), ("val.half", 0.5)]),
            ("set.boost", "boostFactor",
             [("val.x15", 1.5), ("val.x2", 2.0), ("val.x3", 3.0)]),
        ]
        for (titleKey, key, options) in presets {
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            submenu.delegate = self
            for (labelKey, value) in options {
                let item = NSMenuItem(title: L.t(labelKey), action: #selector(selectPreset(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = value
                submenu.addItem(item)
            }
            presetSubmenus.append((submenu, key))
            let holder = NSMenuItem(title: L.t(titleKey), action: nil, keyEquivalent: "")
            holder.submenu = submenu
            settingsMenu.addItem(holder)
        }

        settingsMenu.addItem(.separator())


        settingsMenu.addItem(.separator())

        let exclusionsItem = NSMenuItem(title: L.t("menu.excluded"), action: nil, keyEquivalent: "")
        exclusionsMenu.autoenablesItems = false
        exclusionsMenu.delegate = self
        exclusionsItem.submenu = exclusionsMenu
        settingsMenu.addItem(exclusionsItem)

        gamesPauseItem = NSMenuItem(title: L.t("menu.gamesPause"),
                                    action: #selector(toggleGamesPause), keyEquivalent: "")
        gamesPauseItem.target = self
        settingsMenu.addItem(gamesPauseItem)

        settingsMenu.addItem(.separator())

        languageMenu.removeAllItems()
        languageMenu.autoenablesItems = false
        languageMenu.delegate = self
        for language in Language.allCases {
            let item = NSMenuItem(title: language.title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            languageMenu.addItem(item)
            if language == .auto { languageMenu.addItem(.separator()) }
        }
        let languageItem = NSMenuItem(title: L.t("menu.language"), action: nil, keyEquivalent: "")
        languageItem.submenu = languageMenu
        settingsMenu.addItem(languageItem)

        let resetItem = NSMenuItem(title: L.t("menu.reset"), action: #selector(resetSettings), keyEquivalent: "")
        resetItem.target = self
        settingsMenu.addItem(resetItem)

        let settingsItem = NSMenuItem(title: L.t("menu.settings"), action: nil, keyEquivalent: "")
        settingsItem.submenu = settingsMenu
        return settingsItem
    }

    private func refreshUI() {
        let symbol: String
        if !trusted {
            symbol = "exclamationmark.triangle"
        } else {
            symbol = (monitor.current != nil && enabled && !suspended) ? "gamecontroller.fill" : "gamecontroller"
        }
        // isTemplate + configurazione esplicita: senza, la barra dei menu scala
        // l'immagine per conto suo e il risultato è sgranato
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular, scale: .medium)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "CouchPilot")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.imageScaling = .scaleNone
        statusItem.button?.appearsDisabled = (monitor.current == nil || !enabled || suspended)

        statusInfoItem.title = controllerName.map { L.t("status.controller", $0) } ?? L.t("status.noController")
        statusInfoItem.image = currentBattery.map { BatteryIcon.image(percent: $0.percent, charging: $0.charging) }
        pauseInfoItem.title = pauseReason.map { L.t("status.paused", $0) } ?? ""
        pauseInfoItem.isHidden = !suspended

        enabledItem.state = enabled ? .on : .off
        calibrateItem.title = calibrating ? L.t("menu.calibrating") : L.t("menu.calibrate")
        calibrateItem.isEnabled = monitor.current != nil && !calibrating
        gamesPauseItem.state = UserDefaults.standard.bool(forKey: "autoPauseGames") ? .on : .off
        axItem.isHidden = trusted
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // Livello attuale: la via ufficiale se risponde, altrimenti quella Bluetooth.
    private var currentBattery: BatteryReader.Reading? {
        BatteryReader.fromGameController(monitor.current) ?? battery
    }

    // Il livello non arriva per notifica: si rilegge all'apertura del menu,
    // con una pausa minima per non lanciare un processo a ogni clic.
    private func refreshBattery(force: Bool = false) {
        guard let name = controllerName else {
            battery = nil
            return
        }
        guard BatteryReader.fromGameController(monitor.current) == nil else { return }
        let now = Date.timeIntervalSinceReferenceDate
        guard force || now - lastBatteryCheck > 30 else { return }
        lastBatteryCheck = now
        BatteryReader.fromBluetooth(deviceName: name) { [weak self] reading in
            guard let self else { return }
            // Appena il pad si collega il Bluetooth può non aver ancora
            // pubblicato il livello: si riprova, altrimenti resterebbe vuoto
            // fino alla prossima apertura del menu.
            if reading == nil, self.battery == nil, self.batteryRetries < 3 {
                self.batteryRetries += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                    self?.refreshBattery(force: true)
                }
                return
            }
            guard reading != nil || self.battery != nil else { return }
            self.batteryRetries = 0
            self.battery = reading
            self.refreshUI()
        }
    }

    private func startTrustPolling() {
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, PermissionsGate.isTrusted else { return }
            self.trusted = true
            self.trustTimer?.invalidate()
            self.trustTimer = nil
            Log.write("permesso Accessibilità concesso")
            self.refreshUI()
            NotificationCenter.default.post(name: PermissionsGate.granted, object: nil)
        }
    }

    // MARK: - Azioni

    @objc private func toggleEnabled() {
        driver.setEnabled(!enabled)
    }

    @objc private func toggleGamesPause() {
        let d = UserDefaults.standard
        d.set(!d.bool(forKey: "autoPauseGames"), forKey: "autoPauseGames")
        evaluateSuspension()
    }

    @objc private func calibrate() {
        calibrating = true
        refreshUI()
        driver.calibrate()
    }

    @objc private func toggleLogin() {
        LoginItem.toggle()
        refreshUI()
    }

    @objc private func openKeybinds() {
        WelcomeWindow.showKeybinds(controller: controllerName)
    }

    @objc private func openWelcome() {
        WelcomeWindow.show(controller: controllerName)
    }

    @objc private func openIssues() {
        Feedback.openIssues(controller: controllerName)
    }

    @objc private func composeFeedbackEmail() {
        Feedback.composeEmail(controller: controllerName)
    }

    @objc private func openAX() {
        PermissionsGate.openSystemSettings()
    }

    @objc private func quit() {
        driver.stop()
        NSApp.terminate(nil)
    }
}
