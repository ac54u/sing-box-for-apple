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
    #if os(iOS)
        @State private var showShareSheet = false
    #endif

    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(content)
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .id("bottom")
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
        guard let text = try? String(contentsOf: entry.url, encoding: .utf8) else {
            content = "(读取失败)"
            isLoading = false
            return
        }
        content = text
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
