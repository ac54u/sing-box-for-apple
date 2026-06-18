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
    private static let monoFont = Font.system(size: 11, design: .monospaced)

    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    if truncated {
                        Text("日志文件过大 (\(entry.formattedSize))，仅显示末尾 \(Int(Self.maxReadSize / 1024)) KB")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }
                    LogFileTextView(content: content, font: Self.monoFont)
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

// MARK: - Native text view for O(1) viewport-based layout

/// Uses `UITextView` (iOS) / `NSTextView` (macOS) backed by TextKit 2 so that only
/// the visible viewport is laid out — 481 KB renders as fast as 4 KB. SwiftUIʼs
/// `Text` would lay out every line in the document even when it is off-screen.
private struct LogFileTextView: View {
    let content: String
    let font: Font

    var body: some View {
        #if os(iOS)
            LogFileTextViewIOS(content: content, font: font)
        #elseif os(macOS)
            LogFileTextViewMacOS(content: content, font: font)
        #endif
    }
}

#if os(iOS)
    private struct LogFileTextViewIOS: UIViewRepresentable {
        let content: String
        let font: Font

        private static let monoFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        private static let defaultColor = UIColor.label

        func makeUIView(context _: Context) -> UITextView {
            let textView = UITextView()
            textView.isEditable = false
            textView.isSelectable = true
            textView.isScrollEnabled = true
            textView.backgroundColor = .clear
            textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            textView.textContainer.lineFragmentPadding = 0
            textView.font = Self.monoFont
            textView.textColor = Self.defaultColor
            textView.text = content
            return textView
        }

        func updateUIView(_ textView: UITextView, context: Context) {
            // content is static — set once, no updates needed
        }

        static func dismantleUIView(_ textView: UITextView, coordinator _: ()) {
            // Break retain cycle: setting text = nil releases the backing NSTextStorage
            textView.text = nil
        }
    }
#endif

#if os(macOS)
    private struct LogFileTextViewMacOS: NSViewRepresentable {
        let content: String
        let font: Font

        private static let monoFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        private static let defaultColor = NSColor.labelColor

        func makeNSView(context _: Context) -> NSScrollView {
            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.autohidesScrollers = true

            let textView = NSTextView(usingTextLayoutManager: true)
            textView.isEditable = false
            textView.isSelectable = true
            textView.drawsBackground = false
            textView.textContainerInset = NSSize(width: 16, height: 16)
            textView.font = Self.monoFont
            textView.textColor = Self.defaultColor
            textView.string = content
            textView.autoresizingMask = [.width]

            if let textContainer = textView.textContainer {
                textContainer.widthTracksTextView = true
                textContainer.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
                textContainer.lineFragmentPadding = 0
            }

            scrollView.documentView = textView
            return scrollView
        }

        func updateNSView(_ scrollView: NSScrollView, context: Context) {
            // content is static — set once, no updates needed
        }
    }
#endif

#if os(iOS)
    private struct ActivityView: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context _: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: [url], applicationActivities: nil)
        }

        func updateUIViewController(_: UIActivityViewController, context _: Context) {}
    }
#endif
