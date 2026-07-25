import AVFoundation
import AppKit

// Dimostrazione in riproduzione continua: muta, senza comandi, senza barra di
// avanzamento. Non è un video da guardare, è un'immagine che si muove — per
// questo un filmato e non una GIF: a parità di peso ha il triplo dei pixel e
// il triplo dei fotogrammi.
final class LoopingVideoView: NSView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.25).cgColor
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError("non usato") }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    // Caricato la prima volta che serve: se il file non c'è, la vista resta un
    // riquadro vuoto e la finestra funziona lo stesso.
    func load(_ name: String) {
        guard player == nil,
              let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(items: [item])
        queue.isMuted = true
        looper = AVPlayerLooper(player: queue, templateItem: item)
        playerLayer.player = queue
        player = queue
    }

    func play() { player?.play() }

    func pause() { player?.pause() }
}
