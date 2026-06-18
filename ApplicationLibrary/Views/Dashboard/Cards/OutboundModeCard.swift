import Libbox
import Library
import SwiftUI

public struct OutboundModeCard: View {
    @EnvironmentObject private var commandClient: CommandClient
    @State private var clashMode: String = ""
    @State private var alert: AlertState?
    @State private var showGroups = false

    public init() {}

    public var body: some View {
        if commandClient.clashModeList.count > 1 {
            DashboardCardView(title: "", isHalfWidth: false) {
                VStack(alignment: .leading, spacing: 12) {
                    DashboardCardHeader(icon: "arrow.triangle.branch", title: "出站模式")
                    modeButtons
                    #if !os(tvOS)
                    HStack {
                        Spacer()
                        Button {
                            showGroups = true
                        } label: {
                            HStack(spacing: 3) {
                                Text("代理服务器")
                                    .font(.system(size: 12, weight: .medium))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    #endif
                }
            }
            .onAppear {
                clashMode = commandClient.clashMode
            }
            .onChangeCompat(of: commandClient.clashMode) { newValue in
                clashMode = newValue
            }
            .alert($alert)
            #if !os(tvOS)
            .sheet(isPresented: $showGroups) {
                GroupsSheetContent()
            }
            #endif
        }
    }

    private var modeButtons: some View {
        HStack(spacing: 10) {
            ForEach(commandClient.clashModeList, id: \.self) { mode in
                OutboundModeButton(mode: mode, isSelected: mode == clashMode) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        clashMode = mode
                    }
                    Task {
                        await setMode(mode)
                    }
                }
            }
        }
    }

    private nonisolated func setMode(_ newMode: String) async {
        do {
            let client = try CommandTarget.standaloneClient()
            try client.setClashMode(newMode)
            // Close all existing connections so they reconnect under the new routing rule immediately.
            try client.closeConnections()
        } catch {
            await MainActor.run {
                alert = AlertState(action: "set outbound mode", error: error)
            }
        }
    }
}

private struct OutboundModeButton: View {
    let mode: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: modeIcon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(height: iconSize + 4)
                Text(modeDisplayText)
                    .font(.system(size: labelSize, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    private var modeIcon: String {
        switch mode.lowercased() {
        case "rule", "rules":
            return "list.bullet"
        case "global":
            return "globe"
        case "direct":
            return "arrow.up.right.circle.fill"
        default:
            return "circle.grid.2x2.fill"
        }
    }

    private var modeDisplayText: String {
        switch mode.lowercased() {
        case "rule", "rules":
            return "规则模式"
        case "global":
            return "全局代理"
        case "direct":
            return "直接连接"
        default:
            return mode.capitalized
        }
    }

    private var buttonHeight: CGFloat {
        #if os(tvOS)
            90
        #elseif os(macOS)
            64
        #else
            76
        #endif
    }

    private var iconSize: CGFloat {
        #if os(tvOS)
            32
        #elseif os(macOS)
            20
        #else
            24
        #endif
    }

    private var labelSize: CGFloat {
        #if os(macOS)
            12
        #else
            13
        #endif
    }
}
