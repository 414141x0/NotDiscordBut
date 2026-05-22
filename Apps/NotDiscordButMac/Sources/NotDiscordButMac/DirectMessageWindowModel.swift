import DiscordKit
import Foundation
import Observation

@MainActor
@Observable
final class DirectMessageWindowModel {
    let appModel: AppModel
    let userID: UserID
    let timeline = TimelineModel()
    let composer = ComposerModel()

    var participant: DiscordUser?
    var channelID: ChannelID?
    var statusMessage = "Loading conversation…"
    var inspectorUserID: UserID?
    var inspectorProjection: UserInspectorProjection?

    @ObservationIgnored
    private var hasBootstrapped = false

    @ObservationIgnored
    private var observationTask: Task<Void, Never>?

    @ObservationIgnored
    private var hydratedProfiles = Set<UserID>()

    @ObservationIgnored
    private let initialDraft: String?

    @ObservationIgnored
    private var didApplyInitialDraft = false

    init(appModel: AppModel, userID: UserID, initialDraft: String? = nil) {
        self.appModel = appModel
        self.userID = userID
        self.initialDraft = initialDraft
    }

    deinit {
        observationTask?.cancel()
    }

    var title: String {
        participant?.displayName ?? "Direct Message"
    }

    var reactionPickerGuildEmojis: [DiscordGuildEmoji] {
        []
    }

    func bootstrap() async {
        guard !hasBootstrapped else {
            return
        }

        hasBootstrapped = true
        await refreshSnapshot()
        startObservation()

        do {
            let resolvedChannelID = try await appModel.client.ensureDirectMessageChannel(with: userID)
            channelID = resolvedChannelID
            try await appModel.client.hydrateChannelTimeline(for: resolvedChannelID)
        } catch {
            statusMessage = appModel.describe(error)
        }

        await prefetchProfileIfNeeded(userID)
        await refreshSnapshot()
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
        guard let channelID else {
            return
        }

        do {
            if forceFullReload || timeline.lastDisplayedMessageID == nil {
                try await appModel.client.hydrateChannelTimeline(for: channelID)
            } else if let lastMessageID = timeline.lastDisplayedMessageID {
                _ = try await appModel.client.messages.list(in: channelID, after: lastMessageID, limit: 100)
            }
            await refreshSnapshot()
            await prefetchProfileIfNeeded(userID)
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
            try await appModel.toggleReaction(for: message, emoji: emoji, guildID: nil)
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

    private func consume(snapshot: NormalizedState) async {
        latestSnapshot = snapshot
        participant = snapshot.users[userID.rawValue]

        if channelID == nil {
            channelID = snapshot.channels.values.first(where: { channel in
                channel.kind == .directMessage && channel.recipientIDs.contains(userID)
            })?.id
        }

        let resolvedChannel = channelID.flatMap { snapshot.channels[$0.rawValue] }
        let projection: ClusteredTimelineProjection
        if let channelID, resolvedChannel?.kind.supportsTimelineHydration == true {
            projection = appModel.client.state.clusteredTimelineProjection(for: channelID, from: snapshot)
        } else {
            projection = ClusteredTimelineProjection(channelID: nil, clusters: [])
        }

        timeline.apply(channel: resolvedChannel, projection: projection)
        composer.prepareForChannel(
            resolvedChannel?.kind.supportsTimelineHydration == true ? channelID : nil
        )
        applyInitialDraftIfNeeded()

        if let participant {
            statusMessage = projection.messageCount == 0
                ? "Conversation with \(participant.displayName) is ready."
                : "Showing \(projection.messageCount) messages with \(participant.displayName)."
        } else {
            statusMessage = "Direct-message participant is not loaded yet."
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
            try await appModel.client.hydrateUserProfile(for: userID)
            hydratedProfiles.insert(userID)
        } catch {
            statusMessage = appModel.describe(error)
        }
    }

    private func applyInitialDraftIfNeeded() {
        guard !didApplyInitialDraft,
              let initialDraft,
              !initialDraft.isEmpty,
              composer.draft.isEmpty else {
            return
        }

        composer.draft = initialDraft
        didApplyInitialDraft = true
    }
}
