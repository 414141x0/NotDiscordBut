import DiscordKit
import SwiftUI

struct ServerDirectoryView: View {
    let launchProfile: AppLaunchProfile
    let sidebar: SidebarProjection
    let statusMessage: String
    let badgeSnapshot: NotificationBadgeSnapshot
    @Binding var selectedGuildID: GuildID?
    let onOpenGuildWindow: (GuildID) -> Void

    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    private var selectedGuild: DiscordGuild? {
        sidebar.guilds.first { $0.id == selectedGuildID }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedGuildID) {
                Section("Servers") {
                    ForEach(sidebar.guilds, id: \.id) { guild in
                        NavigationLink(value: guild.id) {
                            Label(guild.name, systemImage: "server.rack")
                        }
                    }
                }

                if !sidebar.privateChannels.isEmpty {
                    Section("Direct Messages") {
                        ForEach(sidebar.privateChannels, id: \.id) { channel in
                            Label(channel.name ?? channel.id.rawValue, systemImage: "bubble.left.and.text.bubble.right")
                        }
                    }
                }

                if !sidebar.friends.isEmpty {
                    Section("Friends & Requests") {
                        ForEach(sidebar.friends, id: \.user.id) { friend in
                            FriendRow(friend: friend)
                        }
                    }
                }
            }
            .navigationTitle("NotDiscordBut")
        } detail: {
            Group {
                if let selectedGuild {
                    GuildOverviewView(
                        guild: selectedGuild,
                        openDisabled: !supportsMultipleWindows,
                        badgeSnapshot: badgeSnapshot,
                        onOpen: {
                            onOpenGuildWindow(selectedGuild.id)
                        }
                    )
                } else {
                    LauncherWelcomeView(
                        launchProfile: launchProfile,
                        statusMessage: statusMessage,
                        guildCount: sidebar.guilds.count,
                        dmCount: sidebar.privateChannels.count,
                        friendCount: sidebar.friends.count,
                        badgeSnapshot: badgeSnapshot
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct LauncherWelcomeView: View {
    let launchProfile: AppLaunchProfile
    let statusMessage: String
    let guildCount: Int
    let dmCount: Int
    let friendCount: Int
    let badgeSnapshot: NotificationBadgeSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspace Launcher")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                    Text(launchProfile.label)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(statusMessage)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 18)], spacing: 18) {
                    SummaryCard(title: "Servers", value: "\(guildCount)", symbol: "server.rack")
                    SummaryCard(title: "Direct Messages", value: "\(dmCount)", symbol: "bubble.left.and.text.bubble.right")
                    SummaryCard(title: "Friends", value: "\(friendCount)", symbol: "person.2")
                    SummaryCard(title: "Unread Buckets", value: "\(badgeSnapshot.unreadChannelCount)", symbol: "bell.badge")
                    SummaryCard(title: "Pending Sends", value: "\(badgeSnapshot.pendingMessageCount)", symbol: "clock.badge.exclamationmark")
                }
            }
            .padding(28)
        }
    }
}

private struct GuildOverviewView: View {
    let guild: DiscordGuild
    let openDisabled: Bool
    let badgeSnapshot: NotificationBadgeSnapshot
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(guild.name)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                Text("Open this server in its own window and switch channels there.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button("Open Server Window", action: onOpen)
                    .buttonStyle(.borderedProminent)
                    .disabled(openDisabled)
                Label("\(badgeSnapshot.unreadChannelCount) unread buckets", systemImage: "bell.badge")
                    .foregroundStyle(.secondary)
            }

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thinMaterial)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Why separate windows?")
                            .font(.headline)
                        Text("Each server window keeps its own channel selection, scroll context, and inspector state, which matches the multiwindow pattern from Apple’s sample apps.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                }

            Spacer(minLength: 0)
        }
        .padding(28)
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
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct FriendRow: View {
    let friend: SidebarFriendProjection

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.user.globalName ?? friend.user.username)
                    .lineLimit(1)

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var symbolName: String {
        switch friend.relationship.kind {
        case .friend:
            return "person.crop.circle"
        case .incomingRequest:
            return "person.badge.plus"
        case .outgoingRequest:
            return "paperplane"
        case .blocked:
            return "hand.raised"
        case .implicit:
            return "sparkles"
        }
    }

    private var detailText: String {
        switch friend.relationship.kind {
        case .friend:
            return friend.relationship.nickname ?? "Friend"
        case .incomingRequest:
            return "Incoming request"
        case .outgoingRequest:
            return "Outgoing request"
        case .blocked:
            return "Blocked"
        case .implicit:
            return "Affinity"
        }
    }
}
