import AVFoundation
import CoreImage

// Da video a spezzone per le dimostrazioni della guida rapida.
//
//   swift Tools/videotoclip.swift <video> <uscita.mp4> [--seconds 10] [--width 960] [--fps 30] [--mbps 1.6]
//
// Come videotogif.swift prende i fotogrammi a intervalli regolari su tutta la
// durata, quindi accelera da sé per rientrare nei secondi richiesti. A
// differenza della GIF sceglie anche quanti fotogrammi al secondo tenere: il
// video sorgente ne ha 60, e comprimerli tutti in dieci secondi è peso buttato.

func arg(_ name: String, _ fallback: Double) -> Double {
    guard let i = CommandLine.arguments.firstIndex(of: "--\(name)"),
          i + 1 < CommandLine.arguments.count,
          let value = Double(CommandLine.arguments[i + 1]) else { return fallback }
    return value
}

let plain = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }
guard plain.count >= 2 else {
    print("uso: videotoclip <video> <uscita.mp4> [--seconds 10] [--width 960] [--fps 30] [--mbps 1.6]")
    exit(1)
}
let input = plain[plain.startIndex]
let output = plain[plain.index(after: plain.startIndex)]
let seconds = arg("seconds", 10)
let width = Int(arg("width", 960))
let fps = arg("fps", 30)
let mbps = arg("mbps", 1.6)

let asset = AVURLAsset(url: URL(fileURLWithPath: input))
let duration = CMTimeGetSeconds(asset.duration)
guard duration > 0, let source = asset.tracks(withMediaType: .video).first else {
    print("video non leggibile: \(input)")
    exit(1)
}

let natural = source.naturalSize.applying(source.preferredTransform)
let height = Int((Double(width) * abs(natural.height) / abs(natural.width)).rounded() / 2) * 2
let count = max(2, Int((seconds * fps).rounded()))
let size = CGSize(width: width, height: height)

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = size
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
try? FileManager.default.removeItem(at: url)
let writer = try! AVAssetWriter(outputURL: url, fileType: .mp4)
let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: Int(mbps * 1_000_000),
        AVVideoExpectedSourceFrameRateKey: Int(fps),
        AVVideoMaxKeyFrameIntervalKey: Int(fps) * 2,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    ],
])
videoInput.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: videoInput,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ])
writer.add(videoInput)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let context = CIContext()
var written = 0
for key in frames.keys.sorted() {
    guard let frame = frames[key], let pool = adaptor.pixelBufferPool else { continue }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer)
    guard let buffer else { continue }
    context.render(CIImage(cgImage: frame), to: buffer)
    while !videoInput.isReadyForMoreMediaData { usleep(2000) }
    adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(written),
                                                        timescale: CMTimeScale(fps)))
    written += 1
}
videoInput.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()

guard writer.status == .completed else {
    print("scrittura fallita: \(writer.error?.localizedDescription ?? "?")")
    exit(1)
}
let bytes = (try? FileManager.default.attributesOfItem(atPath: output)[.size] as? Int) ?? 0
print(String(format: "%@ — %d fotogrammi, %dx%d, %.0f fps, %.1fs (da %.1fs, ×%.2f), %.2f MB",
             (output as NSString).lastPathComponent, written, width, height, fps,
             Double(written) / fps, duration, duration / (Double(written) / fps),
             Double(bytes ?? 0) / 1_048_576))
