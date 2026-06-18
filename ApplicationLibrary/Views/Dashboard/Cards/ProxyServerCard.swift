import Libbox
import Library
import SwiftUI

public struct ProxyServerCard: View {
    @EnvironmentObject private var commandClient: CommandClient
    @State private var groups: [OutboundGroup] = []
    @State private var alert: AlertState?

    public init() {}

    public var body: some View {
        let selectableGroups = groups.filter(\.selectable)
        if !selectableGroups.isEmpty {
            DashboardCardView(title: "", isHalfWidth: false) {
                VStack(alignment: .leading, spacing: 12) {
                    DashboardCardHeader(icon: "server.rack", title: "代理服务器")
                    VStack(spacing: 0) {
                        ForEach(Array(selectableGroups.enumerated()), id: \.element.tag) { index, group in
                            if index > 0 {
                                Divider().padding(.leading, 4)
                            }
                            GroupRow(group: group) { outboundTag in
                                updateSelected(groupTag: group.tag, outboundTag: outboundTag)
                                Task {
                                    await selectOutbound(groupTag: group.tag, outboundTag: outboundTag)
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                syncGroups(commandClient.groups)
            }
            .onChangeCompat(of: commandClient.groups) { newGroups in
                syncGroups(newGroups)
            }
            .alert($alert)
        }
    }

    private func syncGroups(_ rawGroups: [LibboxOutboundGroup]?) {
        guard let rawGroups else { return }
        var result: [OutboundGroup] = []
        for raw in rawGroups {
            var items: [OutboundGroupItem] = []
            let iter = raw.getItems()!
            while iter.hasNext() {
                items.append(OutboundGroupItem(iter.next()!))
            }
            let existing = groups.first { $0.tag == raw.tag }
            result.append(OutboundGroup(
                tag: raw.tag,
                type: raw.type,
                selected: raw.selected,
                selectable: raw.selectable,
                isExpand: existing?.isExpand ?? raw.isExpand,
                items: items
            ))
        }
        groups = result
    }

    private func updateSelected(groupTag: String, outboundTag: String) {
        guard let i = groups.firstIndex(where: { $0.tag == groupTag }) else { return }
        groups[i].selected = outboundTag
    }

    private nonisolated func selectOutbound(groupTag: String, outboundTag: String) async {
        do {
            try await CommandTarget.standaloneClient().selectOutbound(groupTag, outboundTag: outboundTag)
        } catch {
            await MainActor.run {
                alert = AlertState(action: "select outbound", error: error)
            }
        }
    }
}

private struct GroupRow: View {
    let group: OutboundGroup
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(group.tag)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(group.displayType)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(group.items.count) 个节点")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            selectedOutboundMenu
        }
        .padding(.vertical, 10)
    }

    private var selectedOutboundMenu: some View {
        Menu {
            ForEach(group.items, id: \.tag) { item in
                Button {
                    onSelect(item.tag)
                } label: {
                    if item.tag == group.selected {
                        Label(itemLabel(item), systemImage: "checkmark")
                    } else {
                        Text(itemLabel(item))
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                if let selected = group.items.first(where: { $0.tag == group.selected }) {
                    if selected.urlTestDelay > 0 {
                        Circle()
                            .fill(selected.delayColor)
                            .frame(width: 7, height: 7)
                    }
                }
                Text(group.selected)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func itemLabel(_ item: OutboundGroupItem) -> String {
        if item.urlTestDelay > 0 {
            return "\(item.tag)  \(item.urlTestDelay)ms"
        }
        return item.tag
    }
}
