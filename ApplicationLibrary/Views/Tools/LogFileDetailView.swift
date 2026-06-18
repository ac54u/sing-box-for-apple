import Library
import SwiftUI
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

@MainActor
public struct LogFileDetailView: View {
    let entry: LogFileEntry

    @State private var content = ""
    @State private var isLoading = true
    @State private var truncated = false
    #if os(iOS)
        @State private var showShareSheet = false
    #endif

    private static let maxReadSize: Int64 = 512 * 1024 // 512 KB

    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if truncated {
                                Text("日志文件过大 (\(entry.formattedSize))，仅显示末尾 \(Int(Self.maxReadSize / 1024)) KB")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                            }
                            Text(content)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .id("bottom")
                        }
                    }
                    .onAppear {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle(entry.name)
        #if !os(tvOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: copyToClipboard) {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    #if os(iOS)
                        Button { showShareSheet = true } label: {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    #endif
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        #endif
        #if os(iOS)
        .sheet(isPresented: $showShareSheet) {
            ActivityView(url: entry.url)
        }
        #endif
        .onAppear(perform: loadContent)
    }

    private func loadContent() {
        let fileSize = entry.size

        guard let fileHandle = try? FileHandle(forReadingFrom: entry.url) else {
            content = "(读取失败)"
            isLoading = false
            return
        }
        defer { try? fileHandle.close() }

        if fileSize <= Self.maxReadSize {
            guard let data = try? fileHandle.readToEnd(),
                  let text = String(data: data, encoding: .utf8)
            else {
                content = "(读取失败)"
                isLoading = false
                return
            }
            content = text
        } else {
            // Seek back a few extra bytes to avoid splitting a multi-byte UTF-8 character
            let tailSize = min(Self.maxReadSize, fileSize)
            let safeOffset = max(0, fileSize - tailSize - 4)
            try? fileHandle.seek(toOffset: UInt64(safeOffset))
            guard let data = try? fileHandle.readToEnd(),
                  var text = String(data: data, encoding: .utf8)
            else {
                content = "(读取失败)"
                isLoading = false
                return
            }
            // Skip to first newline to discard any partial line from the seek offset
            if let newlineRange = text.range(of: "\n") {
                text = String(text[newlineRange.upperBound...])
            }
            truncated = true
            content = text
        }
        isLoading = false
    }

    private func copyToClipboard() {
        #if os(iOS)
            UIPasteboard.general.string = content
        #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
        #endif
    }
}

#if os(iOS)
    private struct ActivityView: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context _: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: [url], applicationActivities: nil)
        }

        func updateUIViewController(_: UIActivityViewController, context _: Context) {}
    }
#endif
