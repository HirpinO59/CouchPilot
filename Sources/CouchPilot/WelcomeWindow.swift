import AppKit

// Guida rapida in tre schede: le prime due spiegano, la terza è la
// configurazione dei tasti, raggiungibile anche direttamente dal menu.
// Senza questa finestra l'app, non avendo icona nel Dock né interfaccia,
// sembrerebbe non essersi installata.
final class WelcomeWindow: NSWindowController {
    private struct Slide {
        let titleKey: String
        let bodyKey: String
        let media: String
        var isConfig = false
    }

    private let slides = [
        Slide(titleKey: "welcome.1.title", bodyKey: "welcome.1.body", media: "welcome1"),
        Slide(titleKey: "welcome.2.title", bodyKey: "welcome.2.body", media: "welcome2"),
        Slide(titleKey: "welcome.3.title", bodyKey: "welcome.3.body", media: "welcome3",
              isConfig: true),
    ]
    private var index = 0
    private static var controllerName: String?

    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let imageView = NSImageView()
    private var configView: ControllerConfigView!
    private let dots = NSStackView()
    private let nextButton = NSButton()
    private let resetButton = NSButton()
    private let saveButton = NSButton()
    private var buttonRow: NSStackView!
    private var contentStack: NSStackView?

    private static var shared: WelcomeWindow?

    static func show(controller: String? = nil, atConfig: Bool = false) {
        if controller != nil { controllerName = controller }
        if shared == nil { shared = WelcomeWindow() }
        guard let window = shared else { return }
        window.configView.update(controller: controllerName)
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 470),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    private func buildLayout() {
        guard let content = window?.contentView else { return }

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 10
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.25).cgColor

        configView = ControllerConfigView(controller: Self.controllerName)
        configView.translatesAutoresizingMaskIntoConstraints = false
        configView.onChangesChanged = { [weak self] hasChanges in
            self?.saveButton.isEnabled = hasChanges
        }

        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byWordWrapping

        // testo lungo: a bandiera si legge, centrato no
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.alignment = .natural
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.setContentCompressionResistancePriority(.required, for: .vertical)

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

        for button in [nextButton, resetButton, saveButton] {
            button.bezelStyle = .push
            button.controlSize = .large
            button.target = self
        }
        nextButton.action = #selector(advance)
        nextButton.keyEquivalent = "\r"
        resetButton.action = #selector(resetBindings)
        saveButton.action = #selector(saveBindings)
        saveButton.isEnabled = false

        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        buttonRow = NSStackView(views: [resetButton, spacer, saveButton, nextButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        let stack = NSStackView(views: [imageView, configView, titleLabel, bodyLabel, dots, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 30, bottom: 24, right: 30)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 440),
            imageView.heightAnchor.constraint(equalToConstant: 190),
            bodyLabel.widthAnchor.constraint(equalToConstant: 440),
            titleLabel.widthAnchor.constraint(equalToConstant: 440),
            configView.widthAnchor.constraint(equalToConstant: 700),
            configView.heightAnchor.constraint(equalToConstant: 430),
        ])
        stack.setCustomSpacing(24, after: bodyLabel)
        contentStack = stack
    }

    @objc private func advance() {
        if index >= slides.count - 1 {
            close()
            return
        }
        index += 1
        render()
    }

    @objc private func saveBindings() {
        configView.save()
    }

    @objc private func resetBindings() {
        configView.resetToDefaults()
    }

    private func render() {
        let slide = slides[index]
        titleLabel.stringValue = L.t(slide.titleKey)
        bodyLabel.stringValue = L.t(slide.bodyKey)

        configView.isHidden = !slide.isConfig
        bodyLabel.isHidden = slide.isConfig
        resetButton.isHidden = !slide.isConfig
        saveButton.isHidden = !slide.isConfig
        buttonRow.alignment = slide.isConfig ? .centerY : .centerY

        resetButton.title = L.t("keybinds.reset")
        saveButton.title = L.t("keybinds.save")
        nextButton.title = index == slides.count - 1 ? L.t("welcome.done") : L.t("welcome.next")

        let image = slide.isConfig ? nil : NSImage.bundled(named: slide.media)
        imageView.image = image
        imageView.isHidden = image == nil
        imageView.animates = true

        for (i, dot) in dots.arrangedSubviews.enumerated() {
            dot.layer?.backgroundColor = (i == index
                ? NSColor.controlAccentColor
                : NSColor.quaternaryLabelColor).cgColor
        }
        window?.title = "CouchPilot"
        configView.needsDisplay = true

        // la finestra si adatta alla scheda: la configurazione è larga, le
        // schede di testo no, e le lingue occupano altezze diverse
        contentStack?.layoutSubtreeIfNeeded()
        if let fitting = contentStack?.fittingSize {
            window?.setContentSize(NSSize(width: slide.isConfig ? 760 : 520,
                                          height: fitting.height + 24))
        }
        window?.invalidateCursorRects(for: configView)
    }
}

private extension NSImage {
    // Cerca il file tra i formati che ci interessano; nil se non c'è.
    static func bundled(named name: String) -> NSImage? {
        for ext in ["gif", "png", "jpg"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }
}
