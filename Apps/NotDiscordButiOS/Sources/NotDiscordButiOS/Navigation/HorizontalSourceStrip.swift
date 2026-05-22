import DiscordKit
import SwiftUI

struct HorizontalSourceStrip: View {
    let items: [SourceStripItem]
    let selectedSource: WorkspaceSelection?
    let onSelect: (WorkspaceSelection) -> Void

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        SourceStripButton(
                            item: item,
                            isSelected: item.selection == selectedSource,
                            onSelect: { onSelect(item.selection) }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            .frame(height: 72)
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            Text("No items to show")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(height: 72)
    }
}

private struct SourceStripButton: View {
    let item: SourceStripItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                sourceIcon
                    .overlay(alignment: .bottomTrailing) {
                        if isSelected {
                            Circle()
                                .fill(.green)
                                .frame(width: 10, height: 10)
                                .overlay {
                                    Circle().stroke(.background, lineWidth: 2)
                                }
                        }
                    }

                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(maxWidth: 56)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sourceIcon: some View {
        switch item {
        case let .friend(person):
            IOSDiscordAvatarView(user: person.user, size: 48)
        case let .guild(guild):
            IOSDiscordGuildIconView(guild: guild, size: 48)
        }
    }

    private var title: String {
        switch item {
        case let .friend(person):
            return person.displayName
        case let .guild(guild):
            return guild.name
        }
    }
}
