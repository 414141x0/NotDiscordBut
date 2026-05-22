import DiscordKit
import Foundation
import Observation

@MainActor
@Observable
final class ServerWindowModel {
    let appModel: AppModel
    let guildID: GuildID
    let timeline = TimelineModel()
    let composer = ComposerModel()

    var guild: DiscordGuild?
    var channels: [DiscordChannel] = []
    var selectedChannelID: ChannelID?
    var statusMessage = "Loading channels…"
    var inspectorUserID: UserID?
    var inspectorProjection: UserInspectorProjection?

    @ObservationIgnored
    private var hasBootstrapped = false

    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    @ObservationIgnored
    private var hydratedChannelIDs: Set<ChannelID> = []

    @ObservationIgnored
    private var hydratedProfiles = Set<UserID>()

    init(appModel: AppModel, guildID: GuildID, initialChannelID: ChannelID? = nil) {
        self.appModel = appModel
        self.guildID = guildID
        self.selectedChannelID = initialChannelID
    }

    deinit {
        observationTask?.cancel()
    }

    var title: String {
        guild?.name ?? "Server"
    }

    var reactionPickerGuildEmojis: [DiscordGuildEmoji] {
        appModel.client.state.guildEmojiInventoryProjection(for: guildID, from: latestSnapshot)?.emojis ?? []
    }

    func bootstrap() async {
        guard !hasBootstrapped else {
            return
        }

        hasBootstrapped = true
        await refreshSnapshot()
        await hydrateSelectedChannelIfNeeded()
        startObservation()

        statusMessage = channels.isEmpty
            ? "Loading server state…"
            : "Refreshing server state…"
        do {
            try await appModel.client.hydrateGuildState(for: guildID)
        } catch {
            statusMessage = appModel.describe(error)
        }
        await refreshSnapshot()
        await hydrateSelectedChannelIfNeeded()
    }

    func selectChannel(_ channelID: ChannelID?) {
        guard selectedChannelID != channelID else {
            return
        }

        selectedChannelID = channelID
        Task {
            await hydrateSelectedChannelIfNeeded()
            await refreshSnapshot()
        }
    }

    func sendDraft() async {
        guard let input = composer.makeSendInput(nonce: .generated()) else {
            return
        }

        composer.markSending()
        statusMessage = "Sending message…"

        do {
            _ = try await appModel.client.messages.send(input)
            composer.finishSending()
            statusMessage = "Message queued."
        } catch {
            composer.fail(error)
            statusMessage = "Message send failed."
        }
    }

    func openInspector(for userID: UserID) {
        inspectorUserID = userID
        inspectorProjection = appModel.client.state.userInspectorProjection(for: userID, from: latestSnapshot)

        Task {
            await prefetchProfileIfNeeded(userID)
        }
    }

    func prefetchProfile(for userID: UserID) {
        Task {
            await prefetchProfileIfNeeded(userID)
        }
    }

    func cachedInspectorProjection(for userID: UserID) -> UserInspectorProjection? {
        appModel.client.state.userInspectorProjection(for: userID, from: latestSnapshot)
    }

    func refreshTimeline(forceFullReload: Bool = false) async {
        guard let selectedChannelID else {
            return
        }

        do {
            if forceFullReload || timeline.lastDisplayedMessageID == nil {
                try await appModel.client.hydrateChannelTimeline(for: selectedChannelID)
            } else if let lastMessageID = timeline.lastDisplayedMessageID {
                _ = try await appModel.client.messages.list(
                    in: selectedChannelID,
                    after: lastMessageID,
                    limit: 100
                )
            }
            await refreshSnapshot()
            let authorIDs = Set(timeline.displayedClusters.prefix(24).map(\.author.id))
            for authorID in authorIDs {
                await prefetchProfileIfNeeded(authorID)
            }
            await refreshSnapshot()
        } catch {
            statusMessage = appModel.describe(error)
        }
    }

    func jumpToMessageReference(_ reference: DiscordMessageReference) async {
        guard let messageID = reference.messageID else {
            return
        }

        if timeline.displayedClusters.contains(where: { cluster in
            cluster.messages.contains(where: { $0.id == messageID })
        }) {
            timeline.requestJump(to: messageID)
            return
        }

        do {
            _ = try await appModel.client.messages.list(in: reference.channelID, around: messageID, limit: 50)
            await refreshSnapshot()
            timeline.requestJump(to: messageID)
        } catch {
            statusMessage = appModel.describe(error)
        }
    }

    func toggleReaction(for message: DiscordMessage, emoji: DiscordReactionEmoji) async {
        do {
            try await appModel.toggleReaction(for: message, emoji: emoji, guildID: guildID)
        } catch {
            statusMessage = appModel.describe(error)
        }
    }

    private var latestSnapshot = NormalizedState.empty

    private func startObservation() {
        observationTask?.cancel()
        observationTask = Task {
            let stream = await appModel.client.state.subscribe()
            for await snapshot in stream {
                if Task.isCancelled {
                    return
                }
                await consume(snapshot: snapshot)
            }
        }
    }

    private func refreshSnapshot() async {
        let snapshot = await appModel.client.state.snapshot()
        await consume(snapshot: snapshot)
    }

    private func hydrateSelectedChannelIfNeeded() async {
        guard let channelID = selectedChannelID else {
            return
        }

        guard let channel = channels.first(where: { $0.id == channelID }),
              channel.kind.supportsTimelineHydration else {
            return
        }

        guard !hydratedChannelIDs.contains(channelID) else {
            return
        }

        do {
            try await appModel.client.hydrateChannelTimeline(for: channelID)
            hydratedChannelIDs.insert(channelID)
        } catch {
            statusMessage = appModel.describe(error)
        }
    }

    private func consume(snapshot: NormalizedState) async {
        latestSnapshot = snapshot
        guild = snapshot.guilds[guildID.rawValue]
        channels = appModel.client.state.channelListProjection(for: guildID, from: snapshot).channels

        if let selectedChannelID,
           channels.contains(where: { $0.id == selectedChannelID }) {
            self.selectedChannelID = selectedChannelID
        } else {
            self.selectedChannelID = channels.first?.id
        }

        let resolvedChannel = self.selectedChannelID.flatMap { snapshot.channels[$0.rawValue] }
        let timelineProjection: ClusteredTimelineProjection
        if let selectedChannelID = self.selectedChannelID,
           resolvedChannel?.kind.supportsTimelineHydration == true {
            timelineProjection = appModel.client.state.clusteredTimelineProjection(for: selectedChannelID, from: snapshot)
        } else {
            timelineProjection = ClusteredTimelineProjection(channelID: nil, clusters: [])
        }

        timeline.apply(channel: resolvedChannel, projection: timelineProjection)
        composer.prepareForChannel(
            resolvedChannel?.kind.supportsTimelineHydration == true ? self.selectedChannelID : nil
        )

        if let guild {
            statusMessage = channels.isEmpty
                ? "\(guild.name) does not have any loaded text channels yet."
                : "Showing \(channels.count) channels in \(guild.name)."
        } else {
            statusMessage = "This server is not loaded in local state yet."
        }

        if let inspectorUserID {
            inspectorProjection = appModel.client.state.userInspectorProjection(for: inspectorUserID, from: snapshot)
        } else {
            inspectorProjection = nil
        }
    }

    private func prefetchProfileIfNeeded(_ userID: UserID) async {
        guard !hydratedProfiles.contains(userID) else {
            return
        }

        do {
            try await appModel.client.hydrateUserProfile(for: userID, guildID: guildID)
            hydratedProfiles.insert(userID)
        } catch {
            statusMessage = appModel.describe(error)
        }
    }
}
