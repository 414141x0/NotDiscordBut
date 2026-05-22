import DiscordKit
import Observation
import SwiftUI

struct CompactRailView: View {
    @Bindable var model: AppModel
    let onOpenConversationWindow: (ConversationWindowRoute) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if !model.compactRailRecents.isEmpty {
                    recentsSection
                    compactDivider
                }

                currentModeItems
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollPosition(id: $model.compactRailScrollAnchorID)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var recentsSection: some View {
        ForEach(model.compactRailRecents) { recent in
            Button {
                model.setSelectedSource(recent.selection)
            } label: {
                if let user = recent.user {
                    DiscordAvatarView(user: user, size: 36)
                } else if let guild = recent.guild {
                    DiscordGuildIconView(guild: guild, size: 36)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: 36, height: 36)
                }
            }
            .buttonStyle(.plain)
            .help(recent.title)
            .id("recent:\(recent.id)")
        }
    }

    private var compactDivider: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(.quaternary)
            .frame(width: 28, height: 2)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private var currentModeItems: some View {
        switch model.compactRailMode {
        case .friends:
            ForEach(model.people, id: \.user.id) { person in
                Button {
                    model.setSelectedSource(.friend(person.user.id))
                } label: {
                    DiscordAvatarView(user: person.user, size: 42)
                }
                .buttonStyle(.plain)
                .help(person.displayName)
                .id(WorkspaceSelection.friend(person.user.id).persistenceKey)
                .contextMenu {
                    Button("Open in New Window") {
                        onOpenConversationWindow(.directMessage(person.user.id, nil))
                    }

                    Button("Show Profile") {
                        model.openInspector(for: person.user.id)
                    }
                }
            }

        case .servers:
            ForEach(model.guilds, id: \.id) { guild in
                Button {
                    model.setSelectedSource(.guild(guild.id))
                } label: {
                    DiscordGuildIconView(guild: guild, size: 42)
                }
                .buttonStyle(.plain)
                .help(guild.name)
                .id(WorkspaceSelection.guild(guild.id).persistenceKey)
                .contextMenu {
                    Button("Open in New Window") {
                        onOpenConversationWindow(.guild(guild.id, nil))
                    }
                }
            }

        case nil:
            EmptyView()
        }
    }
}
