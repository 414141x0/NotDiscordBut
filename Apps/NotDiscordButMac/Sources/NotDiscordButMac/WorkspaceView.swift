import DiscordKit
import Observation
import SwiftUI

struct WorkspaceView: View {
    @Environment(\.openWindow) private var openWindow
    @Bindable var model: AppModel

    @SceneStorage("workspace.inspectorPresented")
    private var sceneInspectorPresented = false

    var body: some View {
        Group {
            if model.isGuildMode {
                guildWorkspace
            } else {
                directMessageWorkspace
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $model.messageSearchText, placement: .toolbar, prompt: model.messageSearchPrompt)
        .inspector(isPresented: inspectorBinding) {
            UserInspectorView(projection: model.inspectorProjection)
                .inspectorColumnWidth(min: 300, ideal: 360, max: 480)
        }
        .toolbar {
            ToolbarItemGroup {
                if let route = model.secondaryWindowRoute {
                    Button {
                        openWindow(value: route)
                    } label: {
                        Label("Open in New Window", systemImage: "rectangle.on.rectangle")
                    }
                }

                if model.inspectorProjection != nil || model.inspectorUserID != nil {
                    Button(inspectorBinding.wrappedValue ? "Hide Profile" : "Show Profile") {
                        inspectorBinding.wrappedValue.toggle()
                    }
                }
            }
        }
        .toolbar(removing: .sidebarToggle)
        .onChange(of: model.selectedSource) { _, _ in
            sceneInspectorPresented = false
        }
        .onChange(of: model.messageSearchText) { _, _ in
            model.scheduleMessageSearch()
        }
        .onChange(of: model.inspectorPresented) { _, newValue in
            if newValue {
                sceneInspectorPresented = true
            }
        }
        .onAppear {
            sceneInspectorPresented = model.inspectorPresented
        }
    }

    private var directMessageWorkspace: some View {
        NavigationSplitView {
            sidebarColumn
                .navigationSplitViewColumnWidth(
                    min: sidebarWidth,
                    ideal: sidebarWidth,
                    max: sidebarWidth
                )
        } detail: {
            if model.selectedSource?.userID != nil {
                workspaceTimeline
                    .navigationTitle(model.timeline.title)
            } else {
                WorkspaceWelcomeView(model: model)
                    .navigationTitle("Workspace")
            }
        }
    }

    private var guildWorkspace: some View {
        NavigationSplitView {
            sidebarColumn
                .navigationSplitViewColumnWidth(
                    min: sidebarWidth,
                    ideal: sidebarWidth,
                    max: sidebarWidth
                )
        } content: {
            GuildChannelsColumn(model: model)
                .navigationTitle(model.selectedGuild?.name ?? "Channels")
        } detail: {
            workspaceTimeline
                .navigationTitle(model.timeline.title)
        }
    }

    private var sidebarColumn: some View {
        Group {
            if model.compactRailMode != nil && !model.railExpanded {
                CompactRailView(model: model, onOpenConversationWindow: openConversationWindow)
                    .transition(.opacity)
            } else {
                SourceListView(model: model, onOpenConversationWindow: openConversationWindow)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.22), value: model.railExpanded)
        .onHover { inside in
            guard model.compactRailMode != nil else {
                return
            }
            guard !model.inspectorPresented else {
                return
            }

            withAnimation(.snappy(duration: 0.18)) {
                model.setRailExpanded(inside)
            }
        }
    }

    private var workspaceTimeline: some View {
        TimelineView(
            timeline: model.timeline,
            composer: model.composer,
            badgeSnapshot: model.settings.badgeSnapshot,
            availableGuildEmojis: model.reactionPickerGuildEmojis,
            onSend: {
                Task {
                    await sendDraft()
                }
            },
            onInspectUser: { userID in
                model.openInspector(for: userID)
            },
            onPrefetchUserProfile: { userID in
                model.prefetchProfile(for: userID)
            },
            profilePreview: { userID in
                model.cachedInspectorProjection(for: userID)
            },
            onJumpToReplyReference: { reference in
                Task {
                    await model.jumpToMessageReference(reference)
                }
            },
            onRefreshLatest: {
                await model.refreshSelectedTimeline(forceFullReload: false)
            },
            onToggleReaction: { message, emoji in
                do {
                    try await model.toggleReaction(
                        for: message,
                        emoji: emoji,
                        guildID: model.selectedSource?.guildID
                    )
                } catch {
                    model.timeline.statusMessage = model.describe(error)
                }
            }
        )
    }

    private var sidebarWidth: CGFloat {
        model.compactRailMode != nil && !model.railExpanded ? 84 : 300
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: {
                guard !(model.compactRailMode != nil && model.railExpanded) else {
                    return false
                }
                return sceneInspectorPresented || model.inspectorPresented
            },
            set: { newValue in
                guard !(model.compactRailMode != nil && model.railExpanded) else {
                    sceneInspectorPresented = false
                    model.dismissInspector()
                    return
                }
                sceneInspectorPresented = newValue
                model.inspectorPresented = newValue
                if !newValue {
                    model.dismissInspector()
                }
            }
        )
    }

    private func sendDraft() async {
        guard let input = model.composer.makeSendInput(nonce: .generated()) else {
            return
        }

        model.composer.markSending()

        do {
            _ = try await model.client.messages.send(input)
            model.composer.finishSending()
        } catch {
            model.composer.fail(error)
        }
    }

    private func openConversationWindow(_ route: ConversationWindowRoute) {
        openWindow(value: route)
    }
}

private struct GuildChannelsColumn: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(model.guildChannelSections) { section in
                    GuildChannelSectionView(
                        section: section,
                        selectedChannelID: model.selectedGuildChannelID,
                        onSelectChannel: { channelID in
                            model.selectGuildChannel(channelID)
                        },
                        onToggleCategory: { categoryID in
                            model.toggleCategory(categoryID)
                        }
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollPosition(id: Binding(
            get: { model.currentChannelListScrollAnchorID },
            set: { model.updateChannelListScrollAnchor($0) }
        ))
    }
}

private struct GuildChannelSectionView: View {
    let section: GuildChannelSectionModel
    let selectedChannelID: ChannelID?
    let onSelectChannel: (ChannelID?) -> Void
    let onToggleCategory: (ChannelID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let category = section.category {
                Button {
                    onToggleCategory(category.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .rotationEffect(.degrees(section.isCollapsed ? 0 : 90))
                            .foregroundStyle(.secondary)
                        Text(category.name ?? "Category")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
            }

            if !section.isCollapsed {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(section.channels, id: \.id) { channel in
                        ChannelSelectionRow(
                            channel: channel,
                            isSelected: selectedChannelID == channel.id,
                            isEnabled: channel.kind.supportsWorkspaceTimelineInteraction,
                            onSelectChannel: onSelectChannel
                        )
                        .id(channel.id.rawValue)
                    }
                }
                .padding(.leading, section.category == nil ? 0 : 12)
            }
        }
    }
}

private struct ChannelSelectionRow: View {
    let channel: DiscordChannel
    let isSelected: Bool
    let isEnabled: Bool
    let onSelectChannel: (ChannelID?) -> Void

    @State
    private var hovered = false

    var body: some View {
        Button {
            onSelectChannel(channel.id)
        } label: {
            ChannelRow(channel: channel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.58)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { inside in
            hovered = inside && isEnabled
        }
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if isSelected {
            if #available(macOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    .overlay {
                        shape.fill(.white.opacity(0.06))
                    }
            } else {
                shape.fill(.thinMaterial)
            }
        } else if hovered {
            shape.fill(.white.opacity(0.05))
        } else {
            shape.fill(.clear)
        }
    }
}

private struct ChannelRow: View {
    let channel: DiscordChannel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name ?? channel.id.rawValue)
                    .lineLimit(1)
                if let topic = channel.topic, !topic.isEmpty {
                    Text(topic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var symbolName: String {
        switch channel.kind {
        case .guildVoice, .guildStageVoice:
            return "speaker.wave.2.fill"
        case .guildForum:
            return "rectangle.text.magnifyingglass"
        case .guildMedia:
            return "photo.on.rectangle.angled"
        case .guildCategory:
            return "folder"
        default:
            return "number"
        }
    }
}

private struct WorkspaceWelcomeView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspace")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text("Search, collapse, and switch between direct messages and servers in the same window.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    SummaryCard(title: "Friends", value: "\(model.people.count)", symbol: "person.2.fill")
                    SummaryCard(title: "Servers", value: "\(model.guilds.count)", symbol: "server.rack")
                    SummaryCard(title: "Unread Buckets", value: "\(model.settings.badgeSnapshot.unreadChannelCount)", symbol: "bell.badge")
                    SummaryCard(title: "Pending Sends", value: "\(model.settings.badgeSnapshot.pendingMessageCount)", symbol: "clock.badge.exclamationmark")
                }
            }
            .padding(28)
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
