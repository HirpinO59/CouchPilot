#!/usr/bin/env swift
// Generatore dell'icona di CouchPilot. Disegna tutto con CoreGraphics: nessun
// asset binario nel progetto, l'icona si rigenera con
//   swift Tools/makeicon.swift <cartella-di-output>
// Poi build.sh assembla l'.icns con iconutil.
import AppKit

let outDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("icon")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let drawCursor = !CommandLine.arguments.contains("--nocursor") // per valutare la sola sagoma
// macOS 26 applica da sé la maschera a squircle e, se trova margini
// trasparenti, incolla l'icona su un vassoio bianco. Quindi si disegna a
// tutto campo e si lascia ritagliare al sistema.
let fullBleed = !CommandLine.arguments.contains("--legacy-plate")

// MARK: - Forme

// Squircle stile macOS: superellisse, non un rounded rect qualsiasi.
func squirclePath(in rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let n = 5.0 // esponente della superellisse
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 720
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * copysign(pow(abs(ct), 2 / n), ct)
        let y = cy + b * copysign(pow(abs(st), 2 / n), st)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

// Sagoma del gamepad, contorno disegnato a mano con curve di Bézier.
// Coordinate normalizzate: x in [-1,1], y dal bordo alto (0.52) alle
// punte delle impugnature (-0.80). Scala unica `s` per non deformare.
func gamepadPath(center c: CGPoint, width w: CGFloat) -> CGPath {
    let s = w / 2
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: c.x + x * s, y: c.y + y * s)
    }
    let path = CGMutablePath()
    path.move(to: p(-0.58, 0.46))
    path.addCurve(to: p(0.58, 0.46), control1: p(-0.26, 0.58), control2: p(0.26, 0.58))    // bordo superiore
    path.addCurve(to: p(0.98, 0.02), control1: p(0.84, 0.44), control2: p(0.99, 0.28))     // spalla destra
    path.addCurve(to: p(0.74, -0.88), control1: p(0.99, -0.44), control2: p(0.96, -0.76))  // impugnatura destra
    path.addCurve(to: p(0.42, -0.66), control1: p(0.58, -1.00), control2: p(0.46, -0.86))  // punta impugnatura
    path.addCurve(to: p(0.28, -0.36), control1: p(0.38, -0.56), control2: p(0.34, -0.42))  // risalita all'incavo
    path.addCurve(to: p(-0.28, -0.36), control1: p(0.14, -0.28), control2: p(-0.14, -0.28)) // incavo centrale
    path.addCurve(to: p(-0.42, -0.66), control1: p(-0.34, -0.42), control2: p(-0.38, -0.56))
    path.addCurve(to: p(-0.74, -0.88), control1: p(-0.46, -0.86), control2: p(-0.58, -1.00))
    path.addCurve(to: p(-0.98, 0.02), control1: p(-0.96, -0.76), control2: p(-0.99, -0.44))
    path.addCurve(to: p(-0.58, 0.46), control1: p(-0.99, 0.28), control2: p(-0.84, 0.44))
    path.closeSubpath()
    return path
}

// Comandi in negativo: croce direzionale a sinistra, quattro tasti a destra.
// L'asimmetria è voluta: due cerchi simmetrici leggerebbero come occhi.
func controlsPath(center c: CGPoint, width w: CGFloat) -> CGPath {
    let s = w / 2
    let path = CGMutablePath()
    let y = c.y + s * 0.06

    let dx = c.x - s * 0.44
    let arm = s * 0.175, th = s * 0.115
    path.addRoundedRect(in: CGRect(x: dx - arm, y: y - th / 2, width: arm * 2, height: th),
                        cornerWidth: th * 0.35, cornerHeight: th * 0.35)
    path.addRoundedRect(in: CGRect(x: dx - th / 2, y: y - arm, width: th, height: arm * 2),
                        cornerWidth: th * 0.35, cornerHeight: th * 0.35)

    let bx = c.x + s * 0.44
    let r = s * 0.072, spread = s * 0.155
    for (ox, oy) in [(-spread, 0), (spread, 0), (0, -spread), (0, spread)] as [(CGFloat, CGFloat)] {
        path.addEllipse(in: CGRect(x: bx + ox - r, y: y + oy - r, width: r * 2, height: r * 2))
    }
    return path
}

// Puntatore del mouse, stile freccia di macOS.
func cursorPath(tip: CGPoint, size s: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let pts: [(CGFloat, CGFloat)] = [
        (0, 0), (0, -1.00), (0.26, -0.74), (0.42, -1.06),
        (0.60, -0.98), (0.44, -0.66), (0.78, -0.62),
    ]
    for (i, pt) in pts.enumerated() {
        let point = CGPoint(x: tip.x + pt.0 * s, y: tip.y + pt.1 * s)
        if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
    }
    p.closeSubpath()
    return p
}

// MARK: - Render

func renderIcon(size: CGFloat) -> CGImage {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let k = size / 1024 // tutto è disegnato in scala 1024
    ctx.scaleBy(x: k, y: k)

    // sfondo: gradiente notturno (blu profondo -> viola)
    let inset: CGFloat = fullBleed ? 0 : 100
    let plate = CGRect(x: inset, y: inset, width: 1024 - inset * 2, height: 1024 - inset * 2)
    let shape = fullBleed ? CGPath(rect: plate, transform: nil) : squirclePath(in: plate)

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let colors = [
        CGColor(red: 0.42, green: 0.34, blue: 0.92, alpha: 1),
        CGColor(red: 0.24, green: 0.18, blue: 0.62, alpha: 1),
        CGColor(red: 0.13, green: 0.09, blue: 0.36, alpha: 1),
    ] as CFArray
    let gradient = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: plate.minX, y: plate.maxY),
                           end: CGPoint(x: plate.maxX, y: plate.minY),
                           options: [])
    // luce morbida in alto
    let sheen = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.22),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0),
    ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(sheen,
                           startCenter: CGPoint(x: plate.midX, y: plate.maxY - 40), startRadius: 0,
                           endCenter: CGPoint(x: plate.midX, y: plate.maxY - 40), endRadius: plate.width * 0.75,
                           options: [])
    ctx.restoreGState()

    // glifo su layer separato: i fori devono mostrare il gradiente, non il vuoto
    let glyphCtx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                             bytesPerRow: 0, space: cs,
                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // a tutto campo il disegno riempie la tela perché il sistema la ritaglia;
    // dentro lo squircle va rimpicciolito o tocca i bordi
    let glyphScale: CGFloat = fullBleed ? 1.0 : 0.84
    func scaled(_ p: CGPoint) -> CGPoint {
        CGPoint(x: 512 + (p.x - 512) * glyphScale, y: 512 + (p.y - 512) * glyphScale)
    }

    let padCenter = scaled(CGPoint(x: 460, y: 634))
    let padWidth: CGFloat = 648 * glyphScale
    let s = padWidth / 2
    glyphCtx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    glyphCtx.addPath(gamepadPath(center: padCenter, width: padWidth))
    glyphCtx.fillPath()

    // comandi in negativo
    glyphCtx.setBlendMode(.clear)
    glyphCtx.addPath(controlsPath(center: padCenter, width: padWidth))
    glyphCtx.fillPath()
    _ = s

    // stacco attorno al cursore, così le due forme non si fondono
    let cursorTip = scaled(CGPoint(x: 672, y: 446))
    let cursorSize: CGFloat = 296 * glyphScale
    if drawCursor {
        glyphCtx.addPath(cursorPath(tip: CGPoint(x: cursorTip.x, y: cursorTip.y), size: cursorSize * 1.12))
        glyphCtx.fillPath()
    }
    glyphCtx.setBlendMode(.normal)

    ctx.draw(glyphCtx.makeImage()!, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))

    // cursore bianco pieno sopra lo stacco
    if drawCursor {
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.addPath(cursorPath(tip: cursorTip, size: cursorSize))
        ctx.fillPath()
    }

    return ctx.makeImage()!
}

// MARK: - Output

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    let image = renderIcon(size: CGFloat(px))
    let url = outDir.appendingPathComponent("\(name).png")
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: px, height: px)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}
print("icone scritte in \(outDir.path)")
