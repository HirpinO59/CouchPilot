import AppKit

// Schermata di configurazione: il disegno del pad con una didascalia per ogni
// tasto assegnabile. Si clicca l'azione per cambiarla; le modifiche restano in
// sospeso (in giallo) finché non si salva.
final class ControllerConfigView: NSView {
    var onChangesChanged: ((Bool) -> Void)?
    private(set) var pending: [String: PadAction] = [:] {
        didSet { onChangesChanged?(!pending.isEmpty) }
    }

    private var controllerName: String?
    private var hitAreas: [(rect: NSRect, button: PadButton)] = []

    // geometria delle didascalie
    private let labelFont = NSFont.systemFont(ofSize: 11)
    private let nameFont = NSFont.systemFont(ofSize: 10, weight: .semibold)
    private let sideMargin: CGFloat = 12

    init(controller: String?) {
        self.controllerName = controller
        super.init(frame: NSRect(x: 0, y: 0, width: 720, height: 460))
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    override var isFlipped: Bool { false }

    func update(controller: String?) {
        controllerName = controller
        needsDisplay = true
    }

    func action(for button: PadButton) -> PadAction {
        pending[button.id] ?? button.action
    }

    func save() {
        for (id, action) in pending {
            UserDefaults.standard.set(action.rawValue, forKey: "bind\(id)")
        }
        pending.removeAll()
        needsDisplay = true
    }

    func resetToDefaults() {
        Settings.resetBindings()
        pending.removeAll()
        needsDisplay = true
    }

    // MARK: - Disegno

    private var isPlayStation: Bool {
        let name = (controllerName ?? "").lowercased()
        return ["dualsense", "dualshock", "wireless controller", "playstation"]
            .contains { name.contains($0) }
    }

    private func artwork() -> NSImage? {
        let name = isPlayStation ? "controller-dualsense" : "controller"
        for candidate in [name, "controller"] {
            for ext in ["pdf", "png"] {
                if let url = Bundle.main.url(forResource: candidate, withExtension: ext),
                   let image = NSImage(contentsOf: url) { return image }
            }
        }
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        hitAreas.removeAll()

        let notesHeight: CGFloat = 46
        let canvas = NSRect(x: 0, y: notesHeight, width: bounds.width, height: bounds.height - notesHeight)

        // il disegno al centro, le colonne di testo ai lati
        var artRect = NSRect.zero
        if let art = artwork() {
            let w = canvas.width * 0.47
            let h = w * (art.size.height / max(art.size.width, 1))
            artRect = NSRect(x: canvas.midX - w/2, y: canvas.midY - h/2, width: w, height: h)
            art.draw(in: artRect)
        } else {
            artRect = NSRect(x: canvas.midX - 140, y: canvas.midY - 100, width: 280, height: 200)
        }

        drawSide(onLeft: true, canvas: canvas, artRect: artRect, ctx: ctx)
        drawSide(onLeft: false, canvas: canvas, artRect: artRect, ctx: ctx)
        drawFixedNotes(in: NSRect(x: 0, y: 0, width: bounds.width, height: notesHeight))
    }

    private func drawSide(onLeft: Bool, canvas: NSRect, artRect: NSRect, ctx: CGContext) {
        // ordinate dall'alto in basso: assegnando le righe nello stesso ordine
        // degli agganci, le linee non possono incrociarsi
        let buttons = PadButton.all
            .filter { $0.onLeft == onLeft }
            .sorted { $0.anchor(playStation: isPlayStation).y > $1.anchor(playStation: isPlayStation).y }

        let rowHeight = canvas.height / CGFloat(buttons.count + 1)
        let faint = NSColor.tertiaryLabelColor
        let modified = NSColor.systemYellow

        for (row, button) in buttons.enumerated() {
            let a = button.anchor(playStation: isPlayStation)
            let anchor = CGPoint(x: artRect.midX + a.x * artRect.width / 2,
                                 y: artRect.midY + a.y * artRect.height / 2)
            let rowY = canvas.maxY - rowHeight * CGFloat(row + 1)
            // ogni riga ha la propria colonna di svolta: i tratti verticali non
            // si sovrappongono mai
            let step = CGFloat(row) * 7
            let bend = onLeft ? artRect.minX - 14 - step : artRect.maxX + 14 + step
            let isPending = pending[button.id] != nil

            ctx.setStrokeColor((isPending ? modified : faint).cgColor)
            ctx.setLineWidth(isPending ? 1.6 : 1)
            ctx.beginPath()
            ctx.move(to: anchor)
            ctx.addLine(to: CGPoint(x: bend, y: anchor.y))
            ctx.addLine(to: CGPoint(x: bend, y: rowY))
            ctx.addLine(to: CGPoint(x: onLeft ? bend - 10 : bend + 10, y: rowY))
            ctx.strokePath()

            // pallino sul tasto, giallo se modificato
            let r: CGFloat = isPending ? 4 : 2.5
            ctx.setFillColor((isPending ? modified : faint).cgColor)
            ctx.fillEllipse(in: CGRect(x: anchor.x - r, y: anchor.y - r, width: r*2, height: r*2))

            drawLabel(for: button, onLeft: onLeft, rowY: rowY, isPending: isPending)
        }
    }

    private func drawLabel(for button: PadButton, onLeft: Bool, rowY: CGFloat, isPending: Bool) {
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: nameFont, .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let actionAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: isPending ? NSColor.systemYellow : NSColor.labelColor,
        ]
        let name = button.name(playStation: isPlayStation) as NSString
        let action = action(for: button).title as NSString
        let nameSize = name.size(withAttributes: nameAttrs)
        let actionSize = action.size(withAttributes: actionAttrs)
        let width = max(nameSize.width, actionSize.width)
        let x = onLeft ? sideMargin : bounds.width - sideMargin - width

        name.draw(at: NSPoint(x: onLeft ? x : bounds.width - sideMargin - nameSize.width,
                              y: rowY + 2), withAttributes: nameAttrs)
        let actionOrigin = NSPoint(x: onLeft ? x : bounds.width - sideMargin - actionSize.width,
                                   y: rowY - actionSize.height - 1)
        action.draw(at: actionOrigin, withAttributes: actionAttrs)

        // area cliccabile un po' più generosa del testo
        let hit = NSRect(x: actionOrigin.x - 4, y: actionOrigin.y - 3,
                         width: actionSize.width + 8, height: actionSize.height + 6)
        hitAreas.append((hit, button))

        if isPending {
            NSColor.systemYellow.withAlphaComponent(0.15).setFill()
            NSBezierPath(roundedRect: hit, xRadius: 4, yRadius: 4).fill()
            action.draw(at: actionOrigin, withAttributes: actionAttrs)
        }
    }

    private func drawFixedNotes(in rect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        let text = PadButton.fixedNotes.map { L.t($0) }.joined(separator: "   ·   ") as NSString
        let size = text.size(withAttributes: attrs)
        text.draw(at: NSPoint(x: rect.midX - size.width/2, y: rect.minY + 14), withAttributes: attrs)
    }

    // MARK: - Interazione

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let hit = hitAreas.first(where: { $0.rect.contains(point) }) else { return }
        showActionMenu(for: hit.button, at: NSPoint(x: hit.rect.minX, y: hit.rect.minY))
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for area in hitAreas { addCursorRect(area.rect, cursor: .pointingHand) }
    }

    private func showActionMenu(for button: PadButton, at point: NSPoint) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let current = action(for: button)
        for action in PadAction.allCases {
            let item = NSMenuItem(title: action.title, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = [button.id, action.rawValue]
            item.state = action == current ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: point, in: self)
    }

    @objc private func pick(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String],
              pair.count == 2,
              let action = PadAction(rawValue: pair[1]),
              let button = PadButton.all.first(where: { $0.id == pair[0] }) else { return }
        if action == button.action {
            pending.removeValue(forKey: button.id)   // tornato al valore salvato
        } else {
            pending[button.id] = action
        }
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }
}
