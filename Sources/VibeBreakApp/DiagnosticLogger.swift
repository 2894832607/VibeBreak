import Foundation

final class DiagnosticLogger {
    let fileURL: URL

    private let queue = DispatchQueue(label: "app.vibebreak.diagnostics")
    private let maximumBytes: UInt64 = 1_000_000
    private let formatter: ISO8601DateFormatter

    init(fileManager: FileManager = .default) {
        fileURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/VibeBreak.log")
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func write(_ message: String) {
        let line = "\(formatter.string(from: Date())) \(message)\n"
        queue.async { [fileURL, maximumBytes] in
            guard let data = line.data(using: .utf8) else { return }
            Self.rotateIfNeeded(fileURL: fileURL, maximumBytes: maximumBytes)

            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    private static func rotateIfNeeded(fileURL: URL, maximumBytes: UInt64) {
        let fileManager = FileManager.default
        guard
            let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
            let size = attributes[.size] as? UInt64,
            size >= maximumBytes
        else {
            return
        }

        let archiveURL = fileURL.appendingPathExtension("1")
        try? fileManager.removeItem(at: archiveURL)
        try? fileManager.moveItem(at: fileURL, to: archiveURL)
    }
}
