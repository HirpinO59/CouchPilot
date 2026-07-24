import AppKit

// Schema del controller con le didascalie collegate ai comandi, in stile
// schermata di configurazione. Disegnato da codice e non salvato come
// immagine: le etichette devono seguire la lingua scelta e i colori il tema
// chiaro o scuro. Nessun marchio riprodotto: è una sagoma a filo di linea.
enum ControllerDiagram {
    // Il corpo del controller è un'immagine (Resources/controller.png, sagoma a
    // filo di linea su fondo trasparente); qui sopra vengono disegnate solo le
    // linee di richiamo e le etichette, che devono restare tradotte.
    // Senza quell'immagine non si disegna nulla: meglio nessuno schema che uno
    // schema fatto male.
    static func image(controller: String?,
                      size: NSSize = NSSize(width: 440, height: 260)) -> NSImage? {
        let layout = layout(for: controller)
        guard let artwork = artwork(named: layout.artwork) else { return nil }
        return NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return true }
            draw(artwork, callouts: layout.callouts, in: ctx, rect: rect)
            return true
        }
    }

    private static func artwork(named name: String) -> NSImage? {
        for ext in ["pdf", "png"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext),
               let image = NSImage(contentsOf: url) { return image }
        }
        // ripiego sul disegno predefinito se manca quello specifico
        if name != "controller",
           let url = Bundle.main.url(forResource: "controller", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    private struct Layout {
        let artwork: String
        let callouts: [Callout]
    }

    private static func layout(for controller: String?) -> Layout {
        let name = (controller ?? "").lowercased()
        let isPlayStation = ["dualsense", "dualshock", "wireless controller", "playstation"]
            .contains { name.contains($0) }
        return isPlayStation ? dualSense : xbox
    }

    private struct Callout {
        let anchor: CGPoint   // aggancio, in unità di `s` dal centro del pad
        let labelKey: String
        let onLeft: Bool
        let row: Int          // 0 = riga più in alto
    }

    // L'ordine delle righe segue l'altezza degli agganci: le linee non si
    // incrociano mai.
    // Posizioni ricavate dai due disegni: l'ordine delle righe segue
    // l'altezza degli agganci, così le linee non si incrociano.
    private static let xbox = Layout(artwork: "controller", callouts: [
        Callout(anchor: CGPoint(x: -0.49, y: 0.15), labelKey: "diagram.cursor", onLeft: true, row: 0),
        Callout(anchor: CGPoint(x: -0.25, y: -0.25), labelKey: "diagram.volume", onLeft: true, row: 2),
        Callout(anchor: CGPoint(x: 0.35, y: 0.17), labelKey: "diagram.rightClick", onLeft: false, row: 0),
        Callout(anchor: CGPoint(x: 0.48, y: -0.01), labelKey: "diagram.click", onLeft: false, row: 1),
        Callout(anchor: CGPoint(x: 0.23, y: -0.25), labelKey: "diagram.scroll", onLeft: false, row: 2),
    ])

    // Sul DualSense la croce sta in alto e gli stick in basso: righe invertite.
    private static let dualSense = Layout(artwork: "controller-dualsense", callouts: [
        Callout(anchor: CGPoint(x: -0.67, y: 0.51), labelKey: "diagram.volume", onLeft: true, row: 0),
        Callout(anchor: CGPoint(x: -0.35, y: 0.13), labelKey: "diagram.cursor", onLeft: true, row: 2),
        Callout(anchor: CGPoint(x: 0.50, y: 0.51), labelKey: "diagram.rightClick", onLeft: false, row: 0),
        Callout(anchor: CGPoint(x: 0.64, y: 0.30), labelKey: "diagram.click", onLeft: false, row: 1),
        Callout(anchor: CGPoint(x: 0.30, y: 0.13), labelKey: "diagram.scroll", onLeft: false, row: 2),
    ])

    private static func draw(_ artwork: NSImage, callouts: [Callout],
                             in ctx: CGContext, rect: NSRect) {
        let ink = NSColor.labelColor
        let faint = NSColor.tertiaryLabelColor

        // il disegno sta al centro, le didascalie ai lati
        let artWidth = rect.width * 0.58
        let artHeight = artWidth * (artwork.size.height / max(artwork.size.width, 1))
        let artRect = NSRect(x: rect.midX - artWidth / 2, y: rect.midY - artHeight / 2,
                             width: artWidth, height: artHeight)
        artwork.draw(in: artRect)

        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
        let rows: [CGFloat] = [rect.maxY - 26, rect.midY + 6, rect.minY + 26]
        let margin: CGFloat = 10

        for callout in callouts {
            // gli agganci sono in frazioni del riquadro del disegno: restano
            // giusti anche cambiando immagine, basta ritararli una volta
            let anchor = CGPoint(x: artRect.midX + callout.anchor.x * artRect.width / 2,
                                 y: artRect.midY + callout.anchor.y * artRect.height / 2)
            let y = rows[min(callout.row, rows.count - 1)]
            let text = L.t(callout.labelKey) as NSString
            let size = text.size(withAttributes: attrs)
            let bend = callout.onLeft ? artRect.minX - 22 : artRect.maxX + 22
            let labelEdge = callout.onLeft ? margin + size.width : rect.maxX - margin - size.width

            ctx.setStrokeColor(faint.cgColor)
            ctx.setLineWidth(1)
            ctx.beginPath()
            ctx.move(to: anchor)
            ctx.addLine(to: CGPoint(x: bend, y: anchor.y))
            ctx.addLine(to: CGPoint(x: bend, y: y))
            ctx.addLine(to: CGPoint(x: labelEdge, y: y))
            ctx.strokePath()

            ctx.setFillColor(faint.cgColor)
            ctx.fillEllipse(in: CGRect(x: anchor.x - 2.2, y: anchor.y - 2.2, width: 4.4, height: 4.4))

            text.draw(at: NSPoint(x: callout.onLeft ? margin : labelEdge, y: y - size.height / 2),
                      withAttributes: attrs)
        }
    }
}
