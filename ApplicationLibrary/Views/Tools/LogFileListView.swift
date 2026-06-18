import Library
import SwiftUI

@MainActor
public struct LogFileListView: View {
    @State private var files: [LogFileEntry] = []
    @State private var isLoading = true

    public init() {}

    public var body: some View {
        FormView {
            Section {
                if isLoading {
                    ProgressView()
                } else if files.isEmpty {
                    Text("暂无日志")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(files) { file in
                        FormNavigationLink {
                            LogFileDetailView(entry: file)
                        } label: {
                            LogFileRow(entry: file)
                        }
                    }
                    .onDelete(perform: deleteFiles)
                }
            } header: {
                Text("会话日志")
            } footer: {
                Text("每次开启 VPN 自动生成一份日志，最多保留 50 份。")
            }
        }
        .navigationTitle("日志记录")
        .onAppear(perform: loadFiles)
    }

    private func loadFiles() {
        let dir = FilePath.logsDirectory
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            isLoading = false
            return
        }

        files = urls
            .filter { $0.pathExtension == "log" }
            .compactMap { url -> LogFileEntry? in
                let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
                return LogFileEntry(
                    url: url,
                    name: url.lastPathComponent,
                    size: Int64(values?.fileSize ?? 0),
                    date: values?.creationDate ?? .distantPast
                )
            }
            .sorted { $0.date > $1.date }

        isLoading = false
    }

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            try? FileManager.default.removeItem(at: files[index].url)
        }
        files.remove(atOffsets: offsets)
    }
}

struct LogFileEntry: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let date: Date

    var formattedSize: String {
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024)
        } else {
            return String(format: "%.1f MB", Double(size) / 1024 / 1024)
        }
    }
}

private struct LogFileRow: View {
    let entry: LogFileEntry

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.name)
                .font(.system(size: 14, design: .monospaced))
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(Self.displayFormatter.string(from: entry.date))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(entry.formattedSize)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
