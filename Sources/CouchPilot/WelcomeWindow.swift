import AppKit

// Guida rapida in tre schede. La prima presenta l'app e chiede feedback, la
// seconda insegna il comando di accensione, la terza è l'assegnazione dei
// tasti, raggiungibile anche direttamente dal menu. Senza questa finestra
// l'app, non avendo icona nel Dock né interfaccia, sembrerebbe non essersi
// installata. I colori sono tutti di sistema: la finestra segue da sé il tema
// chiaro o scuro di macOS.
final class WelcomeWindow: NSWindowController {
    private struct Slide {
        var titleKey: String?
        var bodyKey: String?
        var video: String?          // schermata di sola dimostrazione: niente testo
        var isIntro = false
        var isConfig = false
    }

    private let slides = [
        Slide(titleKey: "welcome.1.title", bodyKey: "welcome.1.body", isIntro: true),
        Slide(video: "welcome2"),
        Slide(titleKey: "welcome.3.title", bodyKey: "config.header", isConfig: true),
    ]
    private var index = 0
    // Assegnazione tasti aperta dal menu: è la stessa scheda, ma da sola non è
    // una guida. Senza puntini né "Avanti" non sembra il terzo passo di un
    // percorso, che era il malinteso di chi la apriva dal menu.
    private var keybindsOnly = false
    private static var controllerName: String?

    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let videoView = LoopingVideoView()
    private var configView: ControllerConfigView!
    private let dots = NSStackView()
    private let backButton = NSButton()
    private let nextButton = NSButton()
    private let resetButton = NSButton()
    private let saveButton = NSButton()
    private let feedbackButton = NSButton()
    private let coffeeButton = NSButton()
    private let permissionLabel = NSTextField(wrappingLabelWithString: "")
    private let permissionButton = NSButton()
    private var permissionRow: NSStackView!
    private let loginCheckbox = NSButton()
    private var linkRow: NSStackView!
    private var buttonRow: NSStackView!
    private var contentStack: NSStackView?
    private var bodyWidth: NSLayoutConstraint!

    private static var shared: WelcomeWindow?

    static func show(controller: String? = nil, atConfig: Bool = false) {
        if controller != nil { controllerName = controller }
        if shared == nil { shared = WelcomeWindow() }
        guard let window = shared else { return }
        window.configView.update(controller: controllerName)
        window.keybindsOnly = atConfig
        window.index = atConfig ? window.slides.count - 1 : 0
        window.render()
        NSApp.activate(ignoringOtherApps: true)
        window.window?.center()
        window.showWindow(nil)
        window.window?.makeKeyAndOrderFront(nil)
    }

    static func showKeybinds(controller: String? = nil) {
        show(controller: controller, atConfig: true)
    }

    // Mostrata una sola volta; il menu resta la via per rivederla.
    static func showIfFirstRun(controller: String? = nil) {
        if controller != nil { controllerName = controller }
        let key = "hasSeenWelcome"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { show() }
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 470),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildLayout()
        // il permesso può arrivare mentre la finestra è aperta: l'utente esce,
        // lo concede in Impostazioni e torna qui
        NotificationCenter.default.addObserver(self, selector: #selector(externalChange),
                                               name: PermissionsGate.granted, object: nil)
        // l'avvio al login si cambia anche dal menu: la spunta deve seguirlo
        NotificationCenter.default.addObserver(self, selector: #selector(externalChange),
                                               name: LoginItem.changed, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func externalChange() { render() }

    required init?(coder: NSCoder) { fatalError("non usato") }

    private func buildLayout() {
        guard let content = window?.contentView else { return }

        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byWordWrapping

        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        videoView.translatesAutoresizingMaskIntoConstraints = false

        configView = ControllerConfigView(controller: Self.controllerName)
        configView.translatesAutoresizingMaskIntoConstraints = false
        configView.onChangesChanged = { [weak self] hasChanges in
            self?.saveButton.isEnabled = hasChanges
        }

        dots.orientation = .horizontal
        dots.spacing = 7
        for _ in slides {
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 3.5
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 7).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 7).isActive = true
            dots.addArrangedSubview(dot)
        }

        permissionLabel.alignment = .center
        permissionLabel.font = .systemFont(ofSize: 13)

        for button in [backButton, nextButton, resetButton, saveButton,
                       feedbackButton, coffeeButton, permissionButton] {
            button.bezelStyle = .push
            button.controlSize = .large
            button.target = self
        }
        backButton.action = #selector(goBack)
        nextButton.action = #selector(advance)
        nextButton.keyEquivalent = "\r"        // l'unico blu: Indietro resta neutro
        resetButton.action = #selector(resetBindings)
        saveButton.action = #selector(saveBindings)
        saveButton.isEnabled = false
        feedbackButton.action = #selector(openFeedback)
        coffeeButton.action = #selector(openCoffee)
        permissionButton.action = #selector(openAccessibility)

        linkRow = NSStackView(views: [feedbackButton, coffeeButton])
        linkRow.orientation = .horizontal
        linkRow.spacing = 12

        permissionRow = NSStackView(views: [permissionLabel, permissionButton])
        permissionRow.orientation = .vertical
        permissionRow.alignment = .centerX
        permissionRow.spacing = 10

        // due stati, non un'azione secca: dev'essere una spunta, così si vede
        // se è già attiva senza doverla premere per scoprirlo
        loginCheckbox.setButtonType(.switch)
        loginCheckbox.target = self
        loginCheckbox.action = #selector(toggleLogin)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        buttonRow = NSStackView(views: [backButton, resetButton, spacer, saveButton, nextButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        let stack = NSStackView(views: [titleLabel, bodyLabel, permissionRow, loginCheckbox,
                                        linkRow, videoView, configView, dots, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 30, bottom: 24, right: 30)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        bodyWidth = bodyLabel.widthAnchor.constraint(equalToConstant: 460)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            videoView.widthAnchor.constraint(equalToConstant: 600),
            videoView.heightAnchor.constraint(equalToConstant: 338),   // 16:9 come il filmato
            titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 460),
            permissionLabel.widthAnchor.constraint(equalToConstant: 460),
            bodyWidth,
            configView.widthAnchor.constraint(equalToConstant: 1060),
            configView.heightAnchor.constraint(equalToConstant: 520),
        ])
        stack.setCustomSpacing(24, after: dots)
        contentStack = stack
    }

    // MARK: - Azioni

    @objc private func advance() {
        if index >= slides.count - 1 {
            close()
            return
        }
        index += 1
        render()
    }

    @objc private func goBack() {
        guard index > 0 else { return }
        index -= 1
        render()
    }

    @objc private func saveBindings() {
        configView.save()
    }

    @objc private func resetBindings() {
        configView.resetToDefaults()
    }

    @objc private func openFeedback() {
        Feedback.openIssues(controller: Self.controllerName)
    }

    @objc private func openCoffee() {
        guard let url = URL(string: Feedback.coffee) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openAccessibility() {
        PermissionsGate.openSystemSettings()
    }

    @objc private func toggleLogin() {
        LoginItem.toggle()   // la notifica rimette la spunta sullo stato vero
    }

    // MARK: - Resa

    private func render() {
        let slide = slides[index]
        let family = Controllers.family(Self.controllerName)
        let toggles = family.toggleNames
        let triggers = family.triggerNames

        // i testi citano i tasti coi nomi veri del pad collegato: View/Menu su
        // Xbox, Create/Options su DualSense, − e + sui pad 8BitDo, e i grilletti
        // LT/RT o L2/R2 a seconda di chi l'ha fatto
        titleLabel.stringValue = slide.titleKey.map(L.t) ?? ""
        bodyLabel.stringValue = slide.bodyKey.map {
            L.t($0, [toggles.left, toggles.right, triggers.left, triggers.right])
        } ?? ""
        titleLabel.isHidden = slide.titleKey == nil
        bodyLabel.isHidden = slide.bodyKey == nil

        switch true {
        case slide.isConfig:
            bodyLabel.font = .systemFont(ofSize: 14)
            bodyLabel.alignment = .center
            bodyWidth.constant = 900
        case slide.isIntro:
            bodyLabel.font = .systemFont(ofSize: 13)
            bodyLabel.alignment = .natural
            bodyWidth.constant = 460
        default:
            bodyLabel.font = .systemFont(ofSize: 15)
            bodyLabel.alignment = .center
            bodyWidth.constant = 460
        }

        configView.isHidden = !slide.isConfig
        linkRow.isHidden = !slide.isIntro

        // Il permesso di Accessibilità è ciò che rende l'app capace di muovere
        // il cursore: senza, non fa niente. Lo si dice solo a chi non l'ha
        // ancora dato — a cose fatte, un'istruzione da eseguire confonde.
        let trusted = PermissionsGate.isTrusted
        permissionRow.isHidden = !slide.isIntro
        permissionButton.isHidden = trusted
        permissionButton.title = L.t("menu.accessibility")
        permissionLabel.stringValue = L.t(trusted ? "welcome.ax.ok" : "welcome.ax.needed")
        permissionLabel.textColor = trusted ? .secondaryLabelColor : .labelColor

        loginCheckbox.isHidden = !slide.isIntro
        loginCheckbox.title = L.t("welcome.login")
        // lo stato vero è quello di sistema, non quello che l'utente ha appena
        // cliccato: se la registrazione fallisce, la spunta torna indietro
        loginCheckbox.state = LoginItem.isEnabled ? .on : .off
        resetButton.isHidden = !slide.isConfig
        saveButton.isHidden = !slide.isConfig
        // Aperta da sola non è un percorso: niente passo indietro, niente
        // puntini, e il pulsante di destra chiude invece di "andare avanti".
        backButton.isHidden = keybindsOnly || index == 0
        dots.isHidden = keybindsOnly

        backButton.title = L.t("welcome.back")
        resetButton.title = L.t("keybinds.reset")
        saveButton.title = L.t("keybinds.save")
        nextButton.title = keybindsOnly ? L.t("keybinds.close")
            : (index == slides.count - 1 ? L.t("welcome.done") : L.t("welcome.next"))
        feedbackButton.title = L.t("welcome.feedback")
        coffeeButton.title = L.t("welcome.coffee")

        // la dimostrazione parte solo quando è in vista: fuori resta ferma
        if let video = slide.video {
            videoView.load(video)
            videoView.isHidden = false
            videoView.play()
        } else {
            videoView.isHidden = true
            videoView.pause()
        }

        for (i, dot) in dots.arrangedSubviews.enumerated() {
            dot.layer?.backgroundColor = (i == index
                ? NSColor.controlAccentColor
                : NSColor.quaternaryLabelColor).cgColor
        }
        window?.title = "CouchPilot"
        configView.needsDisplay = true

        // la finestra si adatta alla scheda: l'assegnazione è larga, le schede
        // di testo no, e le lingue occupano altezze diverse
        contentStack?.layoutSubtreeIfNeeded()
        if let fitting = contentStack?.fittingSize {
            let width: CGFloat = slide.isConfig ? 1120 : (slide.video != nil ? 680 : 540)
            window?.setContentSize(NSSize(width: width, height: fitting.height + 24))
        }
        window?.invalidateCursorRects(for: configView)
    }
}
