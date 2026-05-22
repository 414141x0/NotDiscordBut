import DiscordPrimitives
import DiscordState

public final class ClientStateAPI: @unchecked Sendable {
    private let store: StoreRuntime
    private let query: QueryRuntime

    public init(store: StoreRuntime, query: QueryRuntime) {
        self.store = store
        self.query = query
    }

    public func snapshot() async -> NormalizedState {
        await store.snapshot()
    }

    public func subscribe() async -> AsyncStream<NormalizedState> {
        await store.subscribe()
    }

    public func sidebarProjection() async -> SidebarProjection {
        let snapshot = await store.snapshot()
        return query.sidebarProjection(from: snapshot)
    }

    public func sidebarProjection(from snapshot: NormalizedState) -> SidebarProjection {
        query.sidebarProjection(from: snapshot)
    }

    public func channelListProjection(for guildID: GuildID?) async -> ChannelListProjection {
        let snapshot = await store.snapshot()
        return query.channelListProjection(for: guildID, from: snapshot)
    }

    public func channelListProjection(for guildID: GuildID?, from snapshot: NormalizedState) -> ChannelListProjection {
        query.channelListProjection(for: guildID, from: snapshot)
    }

    public func guildEmojiInventoryProjection(for guildID: GuildID?) async -> GuildEmojiInventoryProjection? {
        let snapshot = await store.snapshot()
        return query.guildEmojiInventoryProjection(for: guildID, from: snapshot)
    }

    public func guildEmojiInventoryProjection(for guildID: GuildID?, from snapshot: NormalizedState) -> GuildEmojiInventoryProjection? {
        query.guildEmojiInventoryProjection(for: guildID, from: snapshot)
    }

    public func timelineProjection(for channelID: ChannelID?) async -> TimelineProjection {
        let snapshot = await store.snapshot()
        return query.timelineProjection(for: channelID, from: snapshot)
    }

    public func timelineProjection(for channelID: ChannelID?, from snapshot: NormalizedState) -> TimelineProjection {
        query.timelineProjection(for: channelID, from: snapshot)
    }

    public func richTimelineProjection(for channelID: ChannelID?) async -> RichTimelineProjection {
        let snapshot = await store.snapshot()
        return query.richTimelineProjection(for: channelID, from: snapshot)
    }

    public func richTimelineProjection(for channelID: ChannelID?, from snapshot: NormalizedState) -> RichTimelineProjection {
        query.richTimelineProjection(for: channelID, from: snapshot)
    }

    public func richTimelineProjection(
        for messages: [DiscordMessage],
        channelID: ChannelID?,
        from snapshot: NormalizedState
    ) -> RichTimelineProjection {
        query.richTimelineProjection(for: messages, channelID: channelID, from: snapshot)
    }

    public func clusteredTimelineProjection(for channelID: ChannelID?) async -> ClusteredTimelineProjection {
        let snapshot = await store.snapshot()
        return query.clusteredTimelineProjection(for: channelID, from: snapshot)
    }

    public func clusteredTimelineProjection(for channelID: ChannelID?, from snapshot: NormalizedState) -> ClusteredTimelineProjection {
        query.clusteredTimelineProjection(for: channelID, from: snapshot)
    }

    public func clusteredTimelineProjection(
        for messages: [DiscordMessage],
        channelID: ChannelID?,
        from snapshot: NormalizedState
    ) -> ClusteredTimelineProjection {
        query.clusteredTimelineProjection(for: messages, channelID: channelID, from: snapshot)
    }

    public func userInspectorProjection(for userID: UserID) async -> UserInspectorProjection? {
        let snapshot = await store.snapshot()
        return query.userInspectorProjection(for: userID, from: snapshot)
    }

    public func userInspectorProjection(for userID: UserID, from snapshot: NormalizedState) -> UserInspectorProjection? {
        query.userInspectorProjection(for: userID, from: snapshot)
    }
}
