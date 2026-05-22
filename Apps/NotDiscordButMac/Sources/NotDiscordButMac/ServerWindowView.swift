import DiscordKit
import Observation
import SwiftUI

struct ServerWindowView: View {
    @Bindable var model: ServerWindowModel

    @SceneStorage("serverWindow.selectedChannelID")
    private var selectedChannelRawValue: String?

    @SceneStorage("serverWindow.inspectorPresented")
    private var inspectorPresented = true

    var body: some View {
        NavigationSplitView {
            List(selection: selectedChannelBinding) {
                ForEach(model.channels, id: \.id) { channel in
                    NavigationLink(value: channel.id) {
                        ChannelRowView(channel: channel)
                    }
                }
            }
            .navigationTitle(model.title)
            .frame(minWidth: 240, idealWidth: 260)
        } detail: {
            TimelineView(
                timeline: model.timeline,
                composer: model.composer,
                badgeSnapshot: model.appModel.settings.badgeSnapshot,
                availableGuildEmojis: model.reactionPickerGuildEmojis,
                onSend: {
                    Task {
                        await model.sendDraft()
                    }
                },
                onInspectUser: { userID in
                    model.openInspector(for: userID)
                    inspectorPresented = true
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
                    await model.refreshTimeline(forceFullReload: false)
                },
                onToggleReaction: { message, emoji in
                    await model.toggleReaction(for: message, emoji: emoji)
                }
            )
            .navigationTitle(model.timeline.title)
        }
        .inspector(isPresented: inspectorBinding) {
            if model.inspectorProjection != nil || model.inspectorUserID != nil {
                UserInspectorView(projection: model.inspectorProjection)
                    .inspectorColumnWidth(min: 300, ideal: 360, max: 480)
            } else {
                ServerInspectorView(model: model, settings: model.appModel.settings)
                    .inspectorColumnWidth(min: 240, ideal: 280, max: 340)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title)
                        .font(.headline)
                    Text(model.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var selectedChannelBinding: Binding<ChannelID?> {
        Binding(
            get: {
                selectedChannelRawValue.map(ChannelID.init(rawValue:)) ?? model.selectedChannelID
            },
            set: { newValue in
                selectedChannelRawValue = newValue?.rawValue
                model.selectChannel(newValue)
            }
        )
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { inspectorPresented },
            set: { inspectorPresented = $0 }
        )
    }
}

private struct ChannelRowView: View {
    let channel: DiscordChannel

    var body: some View {
        Label(channel.name ?? channel.id.rawValue, systemImage: symbolName)
    }

    private var symbolName: String {
        switch channel.kind {
        case .guildVoice, .guildStageVoice:
            return "speaker.wave.2.fill"
        case .guildForum, .guildMedia:
            return "rectangle.grid.1x2"
        default:
            return "number"
        }
    }
}

private struct ServerInspectorView: View {
    let model: ServerWindowModel
    let settings: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Inspector")
                .font(.title3.weight(.semibold))

            LabeledContent("Server", value: model.title)
            LabeledContent("Selected Channel", value: model.timeline.selectedChannel?.name ?? "none")
            LabeledContent("Auth Kind", value: settings.currentSession?.authKind.rawValue ?? "none")
            LabeledContent("User ID", value: settings.currentSession?.userID?.rawValue ?? "unknown")
            LabeledContent("Unread Buckets", value: "\(settings.badgeSnapshot.unreadChannelCount)")
            LabeledContent("Pending Sends", value: "\(settings.badgeSnapshot.pendingMessageCount)")

            if let runtimeNotice = settings.runtimeNotice {
                Divider()
                Text(runtimeNotice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
    }
}
