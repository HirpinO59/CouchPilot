import AppKit

// Indicatore di batteria in stile macOS: contorno, riempimento proporzionale e
// percentuale ritagliata dentro. È una template image, così AppKit la tinge da
// sé secondo il tema e la evidenziazione del menu.
enum BatteryIcon {
    static func image(percent: Int, charging: Bool) -> NSImage {
        let size = NSSize(width: 31, height: 14)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return true }
            let level = max(0, min(100, percent))

            let body = CGRect(x: 0.5, y: 1.5, width: 25, height: 11)
            let radius: CGFloat = 3.2
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setFillColor(NSColor.black.cgColor)

            // guscio
            ctx.setLineWidth(1)
            ctx.addPath(CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.strokePath()

            // polo positivo
            let nub = CGRect(x: body.maxX + 1.2, y: body.midY - 2.4, width: 2.2, height: 4.8)
            ctx.addPath(CGPath(roundedRect: nub, cornerWidth: 1, cornerHeight: 1, transform: nil))
            ctx.fillPath()

            // riempimento proporzionale
            let track = body.insetBy(dx: 2, dy: 2)
            let filled = CGRect(x: track.minX, y: track.minY,
                                width: track.width * CGFloat(level) / 100, height: track.height)
            if filled.width > 0.5 {
                ctx.addPath(CGPath(roundedRect: filled, cornerWidth: 1.6, cornerHeight: 1.6, transform: nil))
                ctx.fillPath()
            }

            // numero: in XOR, così si scava nel riempimento e resta pieno fuori
            let text = charging ? "⚡︎" : "\(level)"
            // tre cifre non ci stanno alla stessa misura di due
            let pointSize: CGFloat = charging ? 9 : (text.count >= 3 ? 7.6 : 8.6)
            let font = NSFont.systemFont(ofSize: pointSize, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let measured = (text as NSString).size(withAttributes: attributes)
            let origin = NSPoint(x: body.midX - measured.width / 2,
                                 y: body.midY - measured.height / 2)
            ctx.saveGState()
            ctx.setBlendMode(.xor)
            (text as NSString).draw(at: origin, withAttributes: attributes)
            ctx.restoreGState()
            return true
        }
        image.isTemplate = true
        return image
    }
}
