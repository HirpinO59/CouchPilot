import AVFoundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

// Da video a GIF animata, per il README: su GitHub i filmati non partono da
// soli, le GIF sì. Dentro l'app si usa invece Tools/videotoclip.swift, che
// produce un H.264 molto più leggero a parità di resa.
//
//   swift Tools/videotogif.swift <video> <uscita.gif> [--seconds 5] [--width 640] [--fps 10]
//
// I fotogrammi vengono presi a intervalli regolari su tutta la durata, quindi
// il risultato accelera da sé per rientrare nei secondi richiesti.

func arg(_ name: String, _ fallback: Double) -> Double {
    guard let i = CommandLine.arguments.firstIndex(of: "--\(name)"),
          i + 1 < CommandLine.arguments.count,
          let value = Double(CommandLine.arguments[i + 1]) else { return fallback }
    return value
}

let plain = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }
guard plain.count >= 2 else {
    print("uso: videotogif <video> <uscita.gif> [--seconds 5] [--width 640] [--fps 10]")
    exit(1)
}
let input = plain[plain.startIndex]
let output = plain[plain.index(after: plain.startIndex)]
let seconds = arg("seconds", 5)
let width = arg("width", 640)
let fps = arg("fps", 10)

let asset = AVURLAsset(url: URL(fileURLWithPath: input))
let duration = CMTimeGetSeconds(asset.duration)
guard duration > 0, let track = asset.tracks(withMediaType: .video).first else {
    print("video non leggibile: \(input)")
    exit(1)
}

let count = max(2, Int((seconds * fps).rounded()))
let natural = track.naturalSize.applying(track.preferredTransform)
let target = CGSize(width: width,
                    height: (width * abs(natural.height) / max(abs(natural.width), 1)).rounded())

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = target
generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

let times = (0..<count).map {
    NSValue(time: CMTime(seconds: duration * Double($0) / Double(count), preferredTimescale: 600))
}

var frames = [Int: CGImage]()
let lock = NSLock()
let ready = DispatchSemaphore(value: 0)
var received = 0
generator.generateCGImagesAsynchronously(forTimes: times) { requested, image, _, _, _ in
    if let image {
        let index = times.firstIndex {
            abs(CMTimeGetSeconds($0.timeValue) - CMTimeGetSeconds(requested)) < 0.001
        }
        lock.lock(); frames[index ?? received] = image; lock.unlock()
    }
    lock.lock(); received += 1; let finished = received == times.count; lock.unlock()
    if finished { ready.signal() }
}
ready.wait()

let url = URL(fileURLWithPath: output)
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
    print("non riesco a creare \(output)")
    exit(1)
}
CGImageDestinationSetProperties(destination, [
    kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0],
] as CFDictionary)

let delay = 1.0 / fps
for key in frames.keys.sorted() {
    guard let frame = frames[key] else { continue }
    CGImageDestinationAddImage(destination, frame, [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFDelayTime: delay,
            kCGImagePropertyGIFUnclampedDelayTime: delay,
        ],
    ] as CFDictionary)
}
guard CGImageDestinationFinalize(destination) else {
    print("scrittura fallita")
    exit(1)
}

let bytes = (try? FileManager.default.attributesOfItem(atPath: output)[.size] as? Int) ?? 0
print(String(format: "%@ — %d fotogrammi, %.0f×%.0f, %.1fs (da %.1fs, ×%.2f), %.2f MB",
             (output as NSString).lastPathComponent, frames.count,
             target.width, target.height, Double(frames.count) / fps, duration,
             duration / (Double(frames.count) / fps), Double(bytes ?? 0) / 1_048_576))
