import AppKit

// Guida rapida: tre schede, mostrate una volta sola al primo avvio e poi
// richiamabili dal menu. Senza questa finestra l'app, non avendo icona nel
// Dock né interfaccia, sembrerebbe non essersi installata.
final class WelcomeWindow: NSWindowController {
    private struct Slide {
        let titleKey: String
        let bodyKey: String
        let media: String // file in Resources, senza estensione
        var showsDiagram = false
    }

    private let slides = [
        Slide(titleKey: "welcome.1.title", bodyKey: "welcome.1.body", media: "welcome1"),
        Slide(titleKey: "welcome.2.title", bodyKey: "welcome.2.body", media: "welcome2"),
        Slide(titleKey: "welcome.3.title", bodyKey: "welcome.3.body", media: "welcome3",
              showsDiagram: true),
    ]
    private var index = 0
    private static var controllerName: String?

    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let imageView = NSImageView()
    private let nextButton = NSButton()
    private let dots = NSStackView()
    private var contentStack: NSStackView?

    private static var shared: WelcomeWindow?

    static func show(controller: String? = nil) {
        if controller != nil { controllerName = controller }
        if shared == nil { shared = WelcomeWindow() }
        shared?.index = 0
        shared?.render()
        NSApp.activate(ignoringOtherApps: true)
        shared?.window?.center()
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
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

        nextButton.bezelStyle = .push
        nextButton.controlSize = .large
        nextButton.keyEquivalent = "\r"
        nextButton.target = self
        nextButton.action = #selector(advance)

        let stack = NSStackView(views: [imageView, titleLabel, bodyLabel, dots, nextButton])
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

    private func render() {
        let slide = slides[index]
        titleLabel.stringValue = L.t(slide.titleKey)
        bodyLabel.stringValue = L.t(slide.bodyKey)

        // Il file nel bundle ha la precedenza (le GIF dimostrative); in sua
        // assenza la terza scheda disegna lo schema del controller.
        let image = NSImage.bundled(named: slide.media)
            ?? (slide.showsDiagram ? ControllerDiagram.image(controller: Self.controllerName) : nil)
        imageView.image = image
        imageView.isHidden = image == nil
        imageView.animates = true

        for (i, dot) in dots.arrangedSubviews.enumerated() {
            dot.layer?.backgroundColor = (i == index
                ? NSColor.controlAccentColor
                : NSColor.quaternaryLabelColor).cgColor
        }

        nextButton.title = index == slides.count - 1 ? L.t("welcome.done") : L.t("welcome.next")
        window?.title = "CouchPilot"

        // la finestra si adatta alla scheda: i testi cambiano lunghezza tra le
        // schede e tra le lingue, un'altezza fissa taglierebbe qualcosa
        contentStack?.layoutSubtreeIfNeeded()
        if let fitting = contentStack?.fittingSize {
            window?.setContentSize(NSSize(width: 520, height: fitting.height + 24))
        }
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
