import AppKit

// Schermata di configurazione: il disegno del pad al centro, una didascalia per
// ogni comando ai lati, e una linea di richiamo che collega le due cose.
//
// Le linee non si incrociano mai e non si sovrappongono mai, per costruzione:
// i comandi sono ordinati per altezza dell'aggancio, le righe di testo vengono
// assegnate nello stesso ordine, e all'uscita dal disegno ogni linea prende una
// corsia sua, distanziata dalle altre. Il resto è un tratto dritto: si segue
// con l'occhio senza doverlo rincorrere.
final class ControllerConfigView: NSView {
    var onChangesChanged: ((Bool) -> Void)?

    private var pendingBindings: [String: Binding] = [:] { didSet { changed() } }
    private var pendingRoles: [String: StickRole] = [:] { didSet { changed() } }

    private var controllerName: String?
    private let capture = InputCapture()
    private var capturing: PadControl?

    // MARK: - Misure

    private let nameFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    private let valueFont = NSFont.systemFont(ofSize: 15)
    private let sideMargin: CGFloat = 18
    private let leaderGap: CGFloat = 64      // spazio riservato alle linee
    private let laneSpacing: CGFloat = 18    // distanza minima fra due corsie
    private let laneSpread: CGFloat = 0.35   // quanto la corsia si avvicina alla riga

    private struct Row {
        let control: PadControl
        let anchor: CGPoint
        let laneY: CGFloat
        let rowY: CGFloat
        let token: NSRect     // riquadro del valore: è la parte cliccabile
    }
    private var rows: [Row] = []

    init(controller: String?) {
        self.controllerName = controller
        super.init(frame: NSRect(x: 0, y: 0, width: 1060, height: 520))
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    override var isFlipped: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else { return }
        // La cattura si mangia gli eventi mentre è attiva: se la finestra si
        // chiude o passa in secondo piano va spenta subito, non deve restare
        // in mezzo fra l'utente e la tastiera.
        for name in [NSWindow.willCloseNotification, NSWindow.didResignKeyNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(windowLeft),
                                                   name: name, object: window)
        }
    }

    @objc private func windowLeft() { stopCapture() }

    deinit { NotificationCenter.default.removeObserver(self) }

    func update(controller: String?) {
        controllerName = controller
        needsDisplay = true
    }

    // MARK: - Valori

    func binding(for control: PadControl) -> Binding {
        pendingBindings[control.id] ?? control.binding
    }

    func role(for control: PadControl) -> StickRole {
        pendingRoles[control.id] ?? control.role
    }

    private var hasChanges: Bool { !pendingBindings.isEmpty || !pendingRoles.isEmpty }

    private func changed() {
        onChangesChanged?(hasChanges)
    }

    func save() {
        let d = UserDefaults.standard
        for (id, binding) in pendingBindings { d.set(binding.raw, forKey: "bind\(id)") }
        for (id, role) in pendingRoles { d.set(role.rawValue, forKey: "role\(id)") }
        pendingBindings.removeAll()
        pendingRoles.removeAll()
        needsDisplay = true
    }

    func resetToDefaults() {
        stopCapture()
        Settings.resetBindings()
        pendingBindings.removeAll()
        pendingRoles.removeAll()
        needsDisplay = true
    }

    private func isPending(_ control: PadControl) -> Bool {
        pendingBindings[control.id] != nil || pendingRoles[control.id] != nil
    }

    private func valueText(for control: PadControl) -> String {
        control.kind == .stickMove ? role(for: control).title : binding(for: control).title
    }

    // MARK: - Disegno

    private var isPlayStation: Bool { Controllers.isPlayStation(controllerName) }

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
        rows.removeAll()

        let canvas = bounds
        let art = artwork()
        let aspect = art.map { $0.size.height / max($0.size.width, 1) } ?? 480.0 / 700.0

        // Le colonne di testo prendono lo spazio che serve davvero; il disegno
        // si accontenta di quello che resta, così le linee hanno sempre agio.
        let leftWidth = columnWidth(.left)
        let rightWidth = columnWidth(.right)
        let leftEdge = sideMargin + leftWidth
        let rightEdge = bounds.width - sideMargin - rightWidth
        let artWidth = min(rightEdge - leftEdge - leaderGap * 2, canvas.width * 0.5)
        let artHeight = min(artWidth * aspect, canvas.height - 24)
        let artRect = NSRect(x: (leftEdge + rightEdge) / 2 - artWidth / 2,
                             y: canvas.midY - artHeight / 2,
                             width: artWidth, height: artHeight)
        art?.draw(in: artRect)

        layout(.left, canvas: canvas, artRect: artRect, edge: leftEdge)
        layout(.right, canvas: canvas, artRect: artRect, edge: rightEdge)
        layoutAbove(artRect: artRect, canvas: canvas)

        for row in rows { drawLeader(row, artRect: artRect, ctx: ctx) }
        for row in rows { drawLabel(row) }

        if capturing != nil { drawCaptureOverlay() }
    }

    private func controls(_ side: PadControl.Side) -> [PadControl] {
        PadControl.all
            .filter { $0.side == side }
            .sorted { $0.anchor(playStation: isPlayStation).y > $1.anchor(playStation: isPlayStation).y }
    }

    private func columnWidth(_ side: PadControl.Side) -> CGFloat {
        var width: CGFloat = 0
        for control in controls(side) {
            let name = control.name(playStation: isPlayStation) as NSString
            let value = valueText(for: control) as NSString
            width = max(width, name.size(withAttributes: [.font: nameFont]).width)
            width = max(width, value.size(withAttributes: [.font: valueFont]).width + 16)
        }
        return min(width, bounds.width * 0.28)
    }

    private func layout(_ side: PadControl.Side, canvas: NSRect, artRect: NSRect, edge: CGFloat) {
        let onLeft = side == .left
        let list = controls(side)
        guard !list.isEmpty else { return }

        let spacing = min(66, canvas.height / CGFloat(list.count))
        let top = canvas.midY + spacing * CGFloat(list.count) / 2 - spacing / 2
        var lastLane = CGFloat.greatestFiniteMagnitude

        for (index, control) in list.enumerated() {
            let a = control.anchor(playStation: isPlayStation)
            let anchor = CGPoint(x: artRect.midX + a.x * artRect.width / 2,
                                 y: artRect.midY + a.y * artRect.height / 2)
            let rowY = top - spacing * CGFloat(index)

            // La corsia in cui la linea esce dal disegno parte dall'altezza
            // dell'aggancio e si sposta un po' verso la propria riga: così le
            // linee si separano subito invece di uscire tutte appiccicate.
            // Agganci e righe scendono nello stesso ordine, quindi anche le
            // corsie restano in ordine e le linee non possono incrociarsi.
            let pulled = anchor.y + (rowY - anchor.y) * laneSpread
            let laneY = min(pulled, lastLane - laneSpacing)
            lastLane = laneY

            let value = valueText(for: control) as NSString
            let size = value.size(withAttributes: [.font: valueFont])
            let token = NSRect(x: onLeft ? edge - size.width - 12 : edge,
                               y: rowY - size.height / 2 - 4,
                               width: size.width + 12, height: size.height + 8)
            rows.append(Row(control: control, anchor: anchor, laneY: laneY, rowY: rowY, token: token))
        }
    }

    // I tasti centrali non stanno in nessuna colonna: la didascalia va sopra il
    // disegno, con una linea che sale dritta. Lo spazio in mezzo, sopra il pad,
    // è libero — le due colonne stanno ai bordi — quindi non disturba niente.
    private func layoutAbove(artRect: NSRect, canvas: NSRect) {
        for control in controls(.above) {
            let a = control.anchor(playStation: isPlayStation)
            let anchor = CGPoint(x: artRect.midX + a.x * artRect.width / 2,
                                 y: artRect.midY + a.y * artRect.height / 2)
            let value = valueText(for: control) as NSString
            let size = value.size(withAttributes: [.font: valueFont])
            let rowY = min(artRect.maxY + 36, canvas.maxY - 30)
            let token = NSRect(x: anchor.x - (size.width + 12) / 2,
                               y: rowY - size.height / 2 - 4,
                               width: size.width + 12, height: size.height + 8)
            rows.append(Row(control: control, anchor: anchor, laneY: rowY, rowY: rowY, token: token))
        }
    }

    private func drawLeader(_ row: Row, artRect: NSRect, ctx: CGContext) {
        let pending = isPending(row.control)
        let color = pending ? NSColor.systemYellow : NSColor.secondaryLabelColor

        ctx.setStrokeColor(color.withAlphaComponent(pending ? 1 : 0.55).cgColor)
        ctx.setLineWidth(pending ? 2 : 1.2)
        ctx.setLineJoin(.round)
        ctx.beginPath()
        ctx.move(to: row.anchor)
        if row.control.side == .above {
            ctx.addLine(to: CGPoint(x: row.anchor.x, y: row.token.minY - 6))
        } else {
            let onLeft = row.control.side == .left
            let corridor = onLeft ? artRect.minX - 16 : artRect.maxX + 16
            let landing = onLeft ? row.token.maxX + 6 : row.token.minX - 6
            let elbow = onLeft ? landing + 16 : landing - 16
            ctx.addLine(to: CGPoint(x: corridor, y: row.laneY))   // esce dal disegno nella sua corsia
            ctx.addLine(to: CGPoint(x: elbow, y: row.rowY))       // un solo tratto dritto verso la riga
            ctx.addLine(to: CGPoint(x: landing, y: row.rowY))
        }
        ctx.strokePath()

        let r: CGFloat = pending ? 4.5 : 3
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: row.anchor.x - r, y: row.anchor.y - r, width: r * 2, height: r * 2))
    }

    private func drawLabel(_ row: Row) {
        let pending = isPending(row.control)
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: nameFont, .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: pending ? NSColor.systemYellow : NSColor.labelColor,
        ]

        // il valore sta in un riquadro: si vede che è la parte da cliccare
        let path = NSBezierPath(roundedRect: row.token, xRadius: 6, yRadius: 6)
        (pending ? NSColor.systemYellow.withAlphaComponent(0.16)
                 : NSColor.labelColor.withAlphaComponent(0.06)).setFill()
        path.fill()
        if capturing?.id == row.control.id {
            NSColor.systemYellow.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }

        let value = valueText(for: row.control) as NSString
        let valueSize = value.size(withAttributes: valueAttrs)
        value.draw(at: NSPoint(x: row.token.midX - valueSize.width / 2,
                               y: row.token.midY - valueSize.height / 2),
                   withAttributes: valueAttrs)

        let name = row.control.name(playStation: isPlayStation) as NSString
        let nameSize = name.size(withAttributes: nameAttrs)
        let nameX: CGFloat
        switch row.control.side {
        case .left:  nameX = row.token.maxX - nameSize.width
        case .right: nameX = row.token.minX
        case .above: nameX = row.token.midX - nameSize.width / 2
        }
        name.draw(at: NSPoint(x: nameX, y: row.token.maxY + 3), withAttributes: nameAttrs)
    }

    // MARK: - Cattura

    // Il riquadro si misura sul testo che deve contenere: niente scritte che
    // escono dai bordi, in nessuna lingua.
    private struct CaptureLayout {
        let box: NSRect
        let blocks: [(text: NSAttributedString, height: CGFloat)]
    }

    private func captureLayout(for control: PadControl) -> CaptureLayout {
        let width: CGFloat = 560
        let padding: CGFloat = 30
        let textWidth = width - padding * 2

        func block(_ text: String, _ font: NSFont, _ color: NSColor) -> (NSAttributedString, CGFloat) {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributed = NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
            ])
            let bounds = attributed.boundingRect(with: NSSize(width: textWidth, height: 400),
                                                 options: [.usesLineFragmentOrigin])
            return (attributed, ceil(bounds.height))
        }

        let name = control.name(playStation: isPlayStation)
        let blocks = [
            block(String(format: L.t("capture.title"), name),
                  .systemFont(ofSize: 17, weight: .semibold), .labelColor),
            block(L.t("capture.body"), .systemFont(ofSize: 13), .secondaryLabelColor),
            block(L.t("capture.hint"), .systemFont(ofSize: 12), .tertiaryLabelColor),
        ]
        let spacing: CGFloat = 14
        let height = blocks.reduce(0) { $0 + $1.1 } + spacing * CGFloat(blocks.count - 1) + padding * 2
        let box = NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2,
                         width: width, height: height)
        return CaptureLayout(box: box, blocks: blocks)
    }

    private func drawCaptureOverlay() {
        guard let control = capturing else { return }
        NSColor.black.withAlphaComponent(0.55).setFill()
        bounds.fill()

        let layout = captureLayout(for: control)
        let path = NSBezierPath(roundedRect: layout.box, xRadius: 14, yRadius: 14)
        NSColor.windowBackgroundColor.setFill()
        path.fill()
        NSColor.systemYellow.setStroke()
        path.lineWidth = 2
        path.stroke()

        let padding: CGFloat = 30
        let textWidth = layout.box.width - padding * 2
        var y = layout.box.maxY - padding
        for (text, height) in layout.blocks {
            text.draw(in: NSRect(x: layout.box.minX + padding, y: y - height,
                                 width: textWidth, height: height))
            y -= height + 14
        }
    }

    private func startCapture(for control: PadControl) {
        capturing = control
        needsDisplay = true
        window?.makeFirstResponder(self)

        // La cattura parte al giro dopo: il click che ha chiuso il menu non deve
        // finire registrato come se fosse l'input scelto.
        DispatchQueue.main.async { [weak self] in
            guard let self, let control = self.capturing else { return }
            let box = self.captureLayout(for: control).box
            self.capture.start(mouseArea: self.eventSpaceRect(box)) { [weak self] result in
                guard let self else { return }
                self.capturing = nil
                if case .captured(let binding) = result { self.apply(binding, to: control) }
                self.window?.invalidateCursorRects(for: self)
                self.needsDisplay = true
            }
        }
    }

    private func stopCapture() {
        guard capturing != nil else { return }
        capturing = nil
        capture.stop()
        needsDisplay = true
    }

    // Il tap ragiona in coordinate CGEvent: origine in alto a sinistra dello
    // schermo principale, mentre AppKit misura dal basso.
    private func eventSpaceRect(_ rect: NSRect) -> CGRect {
        guard let window else { return .zero }
        let onScreen = window.convertToScreen(convert(rect, to: nil))
        let height = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: onScreen.minX, y: height - onScreen.maxY,
                      width: onScreen.width, height: onScreen.height)
    }

    // MARK: - Interazione

    override func mouseDown(with event: NSEvent) {
        if capturing != nil { return }   // durante la cattura decide il tap
        let point = convert(event.locationInWindow, from: nil)
        guard let row = rows.first(where: { $0.token.contains(point) }) else { return }
        showMenu(for: row.control, at: NSPoint(x: row.token.minX, y: row.token.minY))
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard capturing == nil else { return }
        for row in rows { addCursorRect(row.token, cursor: .pointingHand) }
    }

    private func showMenu(for control: PadControl, at point: NSPoint) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if control.kind == .stickMove {
            let current = role(for: control)
            for role in StickRole.allCases {
                let item = NSMenuItem(title: role.title, action: #selector(pickRole(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = [control.id, role.rawValue]
                item.state = role == current ? .on : .off
                menu.addItem(item)
            }
        } else {
            let current = binding(for: control)
            // le tre scelte utili, più quella in uso se l'utente ne ha registrata una
            var options = control.suggestions
            if current != .none, !options.contains(current) { options.insert(current, at: 0) }
            for option in options {
                let item = NSMenuItem(title: option.title, action: #selector(pickBinding(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = [control.id, option.raw]
                item.state = option == current ? .on : .off
                menu.addItem(item)
            }
            menu.addItem(.separator())
            let record = NSMenuItem(title: L.t("capture.menu"), action: #selector(record(_:)), keyEquivalent: "")
            record.target = self
            record.representedObject = control.id
            menu.addItem(record)
            let clear = NSMenuItem(title: L.t("action.none"), action: #selector(pickBinding(_:)), keyEquivalent: "")
            clear.target = self
            clear.representedObject = [control.id, Binding.none.raw]
            clear.state = current == .none ? .on : .off
            menu.addItem(clear)
        }
        menu.popUp(positioning: nil, at: point, in: self)
    }

    @objc private func pickBinding(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2,
              let binding = Binding(raw: pair[1]),
              let control = PadControl.all.first(where: { $0.id == pair[0] }) else { return }
        apply(binding, to: control)
    }

    @objc private func pickRole(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2,
              let role = StickRole(rawValue: pair[1]),
              let control = PadControl.all.first(where: { $0.id == pair[0] }) else { return }
        if role == control.role {
            pendingRoles.removeValue(forKey: control.id)
        } else {
            pendingRoles[control.id] = role
        }
        refresh()
    }

    @objc private func record(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let control = PadControl.all.first(where: { $0.id == id }) else { return }
        startCapture(for: control)
    }

    private func apply(_ binding: Binding, to control: PadControl) {
        if binding == control.binding {
            pendingBindings.removeValue(forKey: control.id)   // tornato al valore salvato
        } else {
            pendingBindings[control.id] = binding
        }
        refresh()
    }

    private func refresh() {
        window?.invalidateCursorRects(for: self)
        needsDisplay = true
    }
}
