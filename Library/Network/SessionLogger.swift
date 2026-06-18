import Foundation

final class SessionLogger: @unchecked Sendable {
    let fileURL: URL
    private let fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "com.singbox.session-logger", qos: .utility)

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f
    }()

    init() {
        let dir = FilePath.logsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let name = "\(Self.dateFormatter.string(from: Date())).log"
        fileURL = dir.appendingPathComponent(name)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: fileURL)

        Self.pruneOldFiles(in: dir)
    }

    func write(_ entries: [LogEntry]) {
        guard let fileHandle, !entries.isEmpty else { return }
        let data = (entries.map(\.message).joined(separator: "\n") + "\n").data(using: .utf8)!
        queue.async { fileHandle.write(data) }
    }

    func close() {
        queue.async { [fileHandle] in try? fileHandle?.close() }
    }

    private static func pruneOldFiles(in dir: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let sorted = files
            .filter { $0.pathExtension == "log" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return a > b
            }

        for old in sorted.dropFirst(50) {
            try? FileManager.default.removeItem(at: old)
        }
    }
}
