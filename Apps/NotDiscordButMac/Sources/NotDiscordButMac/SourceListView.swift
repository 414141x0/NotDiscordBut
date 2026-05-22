import DiscordKit
import Observation
import SwiftUI

struct SourceListView: View {
    @Bindable var model: AppModel
    let onOpenConversationWindow: (ConversationWindowRoute) -> Void

    @State
    private var overscroll: CGFloat = 0

    var body: some View {
        ScrollView {
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: SourceListOverscrollPreferenceKey.self,
                        value: max(0, proxy.frame(in: .named("source-list-scroll")).minY)
                    )
            }
            .frame(height: 0)

            VStack(alignment: .leading, spacing: 14) {
                revealableSearchField

                if !model.recentSelections.isEmpty {
                    SourcePanelSection(title: "Recents", isExpanded: .constant(true), showsDisclosure: false) {
                        ForEach(model.recentSelections) { recent in
                            SourceSelectionRow(
                                isSelected: model.selectedSource == recent.selection,
                                action: {
                                    model.setSelectedSource(recent.selection)
                                }
                            ) {
                                RecentSourceRow(recent: recent)
                            }
                            .id(recent.id)
                        }
                    }
                }

                SourcePanelSection(title: "Friends", isExpanded: $model.friendsExpanded) {
                    if model.people.isEmpty {
                        Text(emptyPeopleMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(model.people, id: \.user.id) { person in
                            SourceSelectionRow(
                                isSelected: model.selectedSource == .friend(person.user.id),
                                action: {
                                    model.setSelectedSource(.friend(person.user.id))
                                }
                            ) {
                                PersonSourceRow(person: person)
                            }
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
                    }
                }

                SourcePanelSection(title: "Servers", isExpanded: $model.guildsExpanded) {
                    if model.guilds.isEmpty {
                        Text(emptyGuildMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(model.guilds, id: \.id) { guild in
                            SourceSelectionRow(
                                isSelected: model.selectedSource == .guild(guild.id),
                                action: {
                                    model.setSelectedSource(.guild(guild.id))
                                }
                            ) {
                                GuildSourceRow(guild: guild)
                            }
                            .id(WorkspaceSelection.guild(guild.id).persistenceKey)
                            .contextMenu {
                                Button("Open in New Window") {
                                    onOpenConversationWindow(.guild(guild.id, nil))
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .scrollTargetLayout()
        }
        .coordinateSpace(name: "source-list-scroll")
        .scrollIndicators(.never)
        .scrollPosition(id: $model.sourceListScrollAnchorID)
        .background(sourceListBackground)
        .onPreferenceChange(SourceListOverscrollPreferenceKey.self) { value in
            withAnimation(.snappy(duration: 0.16)) {
                overscroll = value
            }
        }
    }

    private var searchRevealProgress: CGFloat {
        if !model.sourceSearchText.isEmpty {
            return 1
        }
        return min(max(overscroll / 52, 0), 1)
    }

    private var revealableSearchField: some View {
        SourceSearchField(text: $model.sourceSearchText)
            .frame(height: max(0.001, 46 * searchRevealProgress))
            .clipped()
            .opacity(searchRevealProgress)
            .offset(y: (1 - searchRevealProgress) * -14)
            .allowsHitTesting(searchRevealProgress > 0.96 || !model.sourceSearchText.isEmpty)
            .accessibilityHidden(searchRevealProgress < 0.96 && model.sourceSearchText.isEmpty)
    }

    @ViewBuilder
    private var sourceListBackground: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 0))
        } else {
            Color.clear
        }
    }

    private var emptyPeopleMessage: String {
        model.sourceSearchText.isEmpty
            ? "No direct-message contacts are available yet."
            : "No friends match that search."
    }

    private var emptyGuildMessage: String {
        model.sourceSearchText.isEmpty
            ? "No servers are loaded yet."
            : "No servers match that search."
    }
}

private struct SourcePanelSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    var showsDisclosure = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsDisclosure {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    content()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct RecentSourceRow: View {
    let recent: RecentSelectionEntry

    var body: some View {
        switch (recent.user, recent.guild) {
        case let (.some(user), _):
            HStack(spacing: 12) {
                DiscordAvatarView(user: user, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recent.title)
                        .lineLimit(1)
                    Text(recent.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        case let (_, .some(guild)):
            HStack(spacing: 12) {
                DiscordGuildIconView(guild: guild, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recent.title)
                        .lineLimit(1)
                    Text(recent.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(recent.title)
                    .lineLimit(1)
                Text(recent.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct SourceSelectionRow<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @State
    private var hovered = false

    var body: some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onHover { inside in
            hovered = inside
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        if isSelected {
            if #available(macOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                    .overlay {
                        shape.fill(.white.opacity(0.06))
                    }
            } else {
                shape.fill(.thinMaterial)
            }
        } else if hovered {
            shape.fill(.white.opacity(0.06))
        } else {
            shape.fill(.clear)
        }
    }
}

private struct SourceSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search friends and servers", text: $text)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(searchBackground)
    }

    @ViewBuilder
    private var searchBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            shape.fill(.thinMaterial)
        }
    }
}

private struct PersonSourceRow: View {
    let person: WorkspacePerson

    var body: some View {
        HStack(spacing: 12) {
            DiscordAvatarView(user: person.user, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .lineLimit(1)
                Text(person.detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct GuildSourceRow: View {
    let guild: DiscordGuild

    var body: some View {
        HStack(spacing: 12) {
            DiscordGuildIconView(guild: guild, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(guild.name)
                    .lineLimit(1)
                Text("Server")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SourceListOverscrollPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
