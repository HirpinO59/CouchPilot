import AppKit

// Disegno del pad → immagine per l'app.
//
// I disegni arrivano come line art nera su fondo bianco, quadrati e con molto
// margine attorno. Nell'app servono trasparenti (la finestra segue il tema di
// macOS: un fondo bianco diventerebbe un rettangolo in dark mode), col tratto
// dello stesso grigio degli altri disegni, e ritagliati sul pad, perché gli
// agganci delle didascalie sono normalizzati sul riquadro dell'immagine.
//
// Uso: swift Tools/padtoart.swift ingresso.jpg uscita.png
//
// Il fondo non viene ritagliato per soglia secca: l'alpha di ogni pixel si
// ricava dalla sua luminanza, così l'antialiasing del tratto si conserva. Sopra
// `white` è fondo pieno (e va tolto anche l'alone che il JPEG lascia attorno
// alle linee), sotto `ink` è cuore del tratto.
let inkLuma: CGFloat = 60      // da qui in giù il tratto è pieno
let whiteLuma: CGFloat = 232   // da qui in su è fondo
let strokeGray: CGFloat = 109 / 255   // il grigio degli altri disegni
let margin = 6                 // respiro attorno al ritaglio, in pixel

let args = CommandLine.arguments
guard args.count == 3 else {
    print("uso: padtoart <ingresso> <uscita.png>")
    exit(2)
}

guard let source = NSImage(contentsOfFile: args[1]),
      let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("non riesco a leggere \(args[1])")
    exit(1)
}

let w = cg.width, h = cg.height

// I pixel dell'originale, in RGBA a 8 bit.
var pixels = [UInt8](repeating: 0, count: w * h * 4)
guard let readContext = CGContext(data: &pixels, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    exit(1)
}
readContext.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

// Alpha dalla luminanza, colore fisso: il tratto esce grigio uniforme e il
// fondo sparisce del tutto.
var out = [UInt8](repeating: 0, count: w * h * 4)
let ink = UInt8(strokeGray * 255)
for i in stride(from: 0, to: pixels.count, by: 4) {
    let r = CGFloat(pixels[i]), g = CGFloat(pixels[i + 1]), b = CGFloat(pixels[i + 2])
    let luma = (r * 0.299 + g * 0.587 + b * 0.114)
    let alpha = max(0, min(1, (whiteLuma - luma) / (whiteLuma - inkLuma)))
    // premultiplicato: i canali colore vanno scalati per l'alpha
    let value = UInt8(strokeGray * alpha * 255)
    out[i] = value; out[i + 1] = value; out[i + 2] = value
    out[i + 3] = UInt8(alpha * 255)
    _ = ink
}

// Ritaglio sul pad: il riquadro dei pixel che si vedono davvero.
var minX = w, minY = h, maxX = -1, maxY = -1
for y in 0..<h {
    for x in 0..<w where out[(y * w + x) * 4 + 3] > 12 {
        if x < minX { minX = x }
        if x > maxX { maxX = x }
        if y < minY { minY = y }
        if y > maxY { maxY = y }
    }
}
guard maxX >= minX, maxY >= minY else {
    print("immagine vuota dopo la soglia")
    exit(1)
}
minX = max(0, minX - margin); minY = max(0, minY - margin)
maxX = min(w - 1, maxX + margin); maxY = min(h - 1, maxY + margin)
let cropW = maxX - minX + 1, cropH = maxY - minY + 1

var cropped = [UInt8](repeating: 0, count: cropW * cropH * 4)
for y in 0..<cropH {
    let from = ((minY + y) * w + minX) * 4
    let to = y * cropW * 4
    cropped.replaceSubrange(to..<(to + cropW * 4), with: out[from..<(from + cropW * 4)])
}

guard let outContext = CGContext(data: &cropped, width: cropW, height: cropH,
                                 bitsPerComponent: 8, bytesPerRow: cropW * 4,
                                 space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
      let result = outContext.makeImage() else {
    exit(1)
}

// Scritto ridisegnando i soli pixel: nessun metadata dell'originale sopravvive.
let rep = NSBitmapImageRep(cgImage: result)
rep.size = NSSize(width: cropW, height: cropH)
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: args[2]))

let ratio = Double(cropW) / Double(cropH)
print("\(args[2]): \(cropW)×\(cropH) (proporzione \(String(format: "%.3f", ratio))), tratto grigio \(Int(strokeGray * 255))")
