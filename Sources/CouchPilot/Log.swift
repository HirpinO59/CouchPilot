import Foundation

// Log su file (~/Library/Logs/CouchPilot.log) oltre che su NSLog:
// il log unificato di macOS non conserva in modo affidabile i messaggi dell'app.
enum Log {
    private static let url: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("CouchPilot.log")
        // il log non deve crescere per sempre: oltre 1 MB si riparte da vuoto
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? UInt64
        if let size, size > 1_000_000 {
            try? FileManager.default.removeItem(at: file)
        }
        return file
    }()
    private static let queue = DispatchQueue(label: "com.hirpino.couchpilot.log")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func write(_ message: String) {
        NSLog("CouchPilot: %@", message)
        queue.async {
            let line = "\(formatter.string(from: Date())) \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}
