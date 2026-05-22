import Foundation
import Testing
import DiscordHTTP
import DiscordPersistence
@testable import DiscordKit

private actor HydrationFixtureTransport: DiscordTransport {
    func send<Response>(
        _ request: DiscordRequest<Response>,
        baseURL: URL,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        defaultHeaders: [String: String]
    ) async throws(DiscordHTTPError) -> DiscordResponse<Response> where Response: Decodable & Sendable {
        switch (request.method.rawValue, request.path) {
        case ("GET", "/users/@me"):
            try decodeResponse(
                [
                    "id": "1",
                    "username": "avi",
                    "global_name": "Avi"
                ],
                decoder: decoder
            )

        case ("GET", "/users/@me/guilds"):
            try decodeResponse(
                [
                    [
                        "id": "100",
                        "name": "Swift Guild",
                        "unavailable": false
                    ]
                ],
                decoder: decoder
            )

        case ("GET", "/users/@me/relationships"):
            try decodeResponse(
                [
                    [
                        "id": "2",
                        "type": 1,
                        "user": [
                            "id": "2",
                            "username": "ada",
                            "global_name": "Ada"
                        ]
                    ]
                ],
                decoder: decoder
            )

        case ("GET", "/users/@me/channels"):
            try decodeResponse(
                [
                    [
                        "id": "200",
                        "type": 1,
                        "recipients": [
                            [
                                "id": "2",
                                "username": "ada",
                                "global_name": "Ada"
                            ]
                        ],
                        "last_message_id": "901"
                    ]
                ],
                decoder: decoder
            )

        case ("GET", "/guilds/100/channels"):
            try decodeResponse(
                [
                    [
                        "id": "300",
                        "type": 0,
                        "guild_id": "100",
                        "name": "general",
                        "last_message_id": "910"
                    ],
                    [
                        "id": "301",
                        "type": 0,
                        "guild_id": "100",
                        "name": "performance",
                        "last_message_id": "911"
                    ]
                ],
                decoder: decoder
            )

        case ("GET", "/guilds/100/roles"):
            try decodeResponse(
                [
                    [
                        "id": "500",
                        "name": "Moderator",
                        "color": 43775,
                        "position": 20
                    ],
                    [
                        "id": "501",
                        "name": "Compiler",
                        "color": 16733440,
                        "position": 40
                    ]
                ],
                decoder: decoder
            )

        case ("GET", "/guilds/100/emojis"):
            try decodeResponse(
                [
                    [
                        "id": "812217273670565888",
                        "name": "blobwave",
                        "animated": false
                    ],
                    [
                        "id": "812217273670565889",
                        "name": "partyparrot",
                        "animated": true
                    ]
                ],
                decoder: decoder
            )

        case ("GET", "/channels/300/messages"):
            try decodeResponse(
                [
                    [
                        "id": "909",
                        "channel_id": "300",
                        "author": [
                            "id": "3",
                            "username": "sam",
                            "global_name": "Sam"
                        ],
                        "content": "Original message is gone.",
                        "timestamp": "2026-05-20T09:58:00Z"
                    ],
                    [
                        "id": "910",
                        "channel_id": "300",
                        "author": [
                            "id": "2",
                            "username": "ada",
                            "global_name": "Ada"
                        ],
                        "member": [
                            "nick": "Compiler Ada",
                            "roles": ["501"]
                        ],
                        "content": "General is hydrated.",
                        "timestamp": "2026-05-20T10:00:00Z"
                    ],
                    [
                        "id": "911",
                        "channel_id": "300",
                        "author": [
                            "id": "2",
                            "username": "ada",
                            "global_name": "Ada"
                        ],
                        "content": "Reply survives even when the source is deleted.",
                        "timestamp": "2026-05-20T10:02:00Z",
                        "message_reference": [
                            "message_id": "908",
                            "channel_id": "300",
                            "guild_id": "100"
                        ],
                        "referenced_message": NSNull()
                    ]
                ],
                decoder: decoder
            )

        case ("GET", "/channels/200/messages"):
            try decodeResponse(
                [
                    [
                        "id": "901",
                        "channel_id": "200",
                        "author": [
                            "id": "2",
                            "username": "ada",
                            "global_name": "Ada"
                        ],
                        "content": "DMs are hydrated too. Hi <@3>.",
                        "timestamp": "2026-05-20T10:01:00Z",
                        "mentions": [
                            [
                                "id": "3",
                                "username": "sam",
                                "global_name": "Sam"
                            ]
                        ]
                    ]
                ],
                decoder: decoder
            )

        case ("GET", "/users/2/profile"):
            try decodeResponse(
                [
                    "user": [
                        "id": "2",
                        "username": "ada",
                        "global_name": "Ada",
                        "avatar": "a_avatar_hash",
                        "banner": "banner_hash",
                        "accent_color": 5793266,
                        "bio": "Compiler engineer"
                    ],
                    "user_profile": [
                        "bio": "Compiler engineer",
                        "pronouns": "she/her",
                        "banner": "banner_hash",
                        "accent_color": 5793266
                    ],
                    "guild_member": [
                        "nick": "Compiler Ada",
                        "roles": ["500", "501"]
                    ],
                    "mutual_guilds": [
                        [
                            "id": "100",
                            "nick": "Compiler Ada"
                        ]
                    ],
                    "mutual_friends": [
                        [
                            "id": "3",
                            "username": "sam",
                            "global_name": "Sam"
                        ]
                    ],
                    "premium_type": 2
                ],
                decoder: decoder
            )

        case ("POST", "/users/@me/channels"):
            try decodeResponse(
                [
                    "id": "201",
                    "type": 1,
                    "recipients": [
                        [
                            "id": "4",
                            "username": "zoe",
                            "global_name": "Zoe",
                            "avatar": "zoe_hash"
                        ]
                    ],
                    "last_message_id": "0"
                ],
                decoder: decoder
            )

        default:
            throw .transportFailed("Unhandled fixture request: \(request.method.rawValue) \(request.path)")
        }
    }

    private func decodeResponse<Response>(
        _ object: Any,
        decoder: JSONDecoder
    ) throws(DiscordHTTPError) -> DiscordResponse<Response> where Response: Decodable & Sendable {
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: object)
        } catch {
            throw .encodingFailed(error.localizedDescription)
        }

        do {
            let value = try decoder.decode(Response.self, from: data)
            return DiscordResponse(statusCode: 200, headers: [:], value: value)
        } catch {
            throw .decodingFailed(String(reflecting: error))
        }
    }
}

private actor UnexpectedBootstrapNetworkTransport: DiscordTransport {
    private var requestCount = 0

    func send<Response>(
        _ request: DiscordRequest<Response>,
        baseURL: URL,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        defaultHeaders: [String: String]
    ) async throws(DiscordHTTPError) -> DiscordResponse<Response> where Response: Decodable & Sendable {
        requestCount += 1
        throw .transportFailed("Bootstrap should not hit the network.")
    }

    func callCount() -> Int {
        requestCount
    }
}

@Test
func clientExposesCoreFeatureFamilies() async throws {
    let client = DiscordClient.preview()
    try await client.bootstrap()
    let session = await client.currentSession()
    let timeline = await client.state.timelineProjection(for: nil)

    #expect(client.configuration.apiVersion == 9)
    #expect(session != nil)
    #expect(timeline.messages.isEmpty == false)
}

@Test
func previewClientSeedsLauncherAndServerWindowData() async throws {
    let client = DiscordClient.preview()
    try await client.bootstrap()
    let snapshot = await client.state.snapshot()
    let sidebar = await client.state.sidebarProjection()
    let guildChannels = await client.state.channelListProjection(for: GuildID(rawValue: "100"))

    #expect(snapshot.guilds.count == 2)
    #expect(sidebar.guilds.count == 2)
    #expect(sidebar.privateChannels.count == 2)
    #expect(guildChannels.channels.map { $0.name ?? "" } == ["design", "general"])
}

@Test
func ephemeralClientStartsWithoutCachedSession() async throws {
    let supportURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let client = DiscordClient.ephemeral(configuration: DiscordConfiguration(applicationSupportURL: supportURL))
    try await client.bootstrap()

    #expect(await client.currentSession() == nil)
}

@Test
func bootstrapRestoresSessionWithoutHydratingNetworkState() async throws {
    let supportURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let transport = UnexpectedBootstrapNetworkTransport()
    let sessionVault = InMemorySessionVault(
        session: DiscordSession(
            userID: "1",
            authKind: .user,
            token: "restored-token"
        )
    )
    let client = DiscordClient.ephemeral(
        configuration: DiscordConfiguration(applicationSupportURL: supportURL),
        transport: transport,
        sessionVault: sessionVault
    )

    try await client.bootstrap()

    #expect(await client.currentSession()?.token == "restored-token")
    #expect(await transport.callCount() == 0)
}

@Test
func hydrateHomeStatePopulatesGuildsFriendsAndDirectMessages() async throws {
    let supportURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let client = DiscordClient.ephemeral(
        configuration: DiscordConfiguration(applicationSupportURL: supportURL),
        transport: HydrationFixtureTransport()
    )

    try await client.bootstrap()
    _ = try await client.auth.importUserToken("fixture-token")
    try await client.hydrateHomeState()

    let sidebar = await client.state.sidebarProjection()
    let session = await client.currentSession()

    #expect(session?.userID == UserID(rawValue: "1"))
    #expect(sidebar.guilds.map(\.name) == ["Swift Guild"])
    #expect(sidebar.privateChannels.map { $0.name ?? "" } == ["Ada"])
    #expect(sidebar.friends.map(\.user.id.rawValue) == ["2"])
}

@Test
func hydrateGuildAndChannelTimelinePopulateVisibleServerState() async throws {
    let supportURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let client = DiscordClient.ephemeral(
        configuration: DiscordConfiguration(applicationSupportURL: supportURL),
        transport: HydrationFixtureTransport()
    )

    try await client.bootstrap()
    _ = try await client.auth.importUserToken("fixture-token")
    do {
        try await client.hydrateGuildState(for: GuildID(rawValue: "100"))
    } catch {
        Issue.record("hydrateGuildState failed: \(String(describing: error))")
        throw error
    }

    let channels = await client.state.channelListProjection(for: GuildID(rawValue: "100"))
    let initialTimeline = await client.state.timelineProjection(for: ChannelID(rawValue: "300"))

    #expect(channels.channels.map { $0.name ?? "" } == ["general", "performance"])
    #expect(initialTimeline.messages.map(\.content) == ["Original message is gone.", "General is hydrated.", "Reply survives even when the source is deleted."])

    do {
        try await client.hydrateChannelTimeline(for: ChannelID(rawValue: "200"))
    } catch {
        Issue.record("hydrateChannelTimeline failed: \(String(describing: error))")
        throw error
    }
    let directTimeline = await client.state.timelineProjection(for: ChannelID(rawValue: "200"))
    let richDirectTimeline = await client.state.richTimelineProjection(for: ChannelID(rawValue: "200"))

    #expect(directTimeline.messages.map(\.content) == ["DMs are hydrated too. Hi <@3>."])
    #expect(richDirectTimeline.entries.first?.renderedContent == "DMs are hydrated too. Hi @Sam.")
}

@Test
func hydrateChannelTimelineDecodesDeletedReplyReferenceContext() async throws {
    let supportURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let client = DiscordClient.ephemeral(
        configuration: DiscordConfiguration(applicationSupportURL: supportURL),
        transport: HydrationFixtureTransport()
    )

    try await client.bootstrap()
    _ = try await client.auth.importUserToken("fixture-token")
    try await client.hydrateGuildState(for: GuildID(rawValue: "100"))

    let timeline = await client.state.timelineProjection(for: ChannelID(rawValue: "300"))
    let reply = try #require(timeline.messages.last)

    #expect(reply.messageReference?.messageID == MessageID(rawValue: "908"))
    #expect(reply.messageReference?.channelID == ChannelID(rawValue: "300"))
    #expect(reply.didLoadReferencedMessage)
    #expect(reply.referencedMessage == nil)
}

@Test
func hydrateGuildStateStoresGuildEmojiInventory() async throws {
    let supportURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let client = DiscordClient.ephemeral(
        configuration: DiscordConfiguration(applicationSupportURL: supportURL),
        transport: HydrationFixtureTransport()
    )

    try await client.bootstrap()
    _ = try await client.auth.importUserToken("fixture-token")
    try await client.hydrateGuildState(for: GuildID(rawValue: "100"))

    let inventory = await client.state.guildEmojiInventoryProjection(for: GuildID(rawValue: "100"))

    #expect(inventory?.emojis.map(\.name) == ["blobwave", "partyparrot"])
    #expect(inventory?.emojis.first?.guildID == GuildID(rawValue: "100"))
}

@Test
func previewClientSendPreservesReplyReference() async throws {
    let client = DiscordClient.preview()
    try await client.bootstrap()

    let reply = try await client.messages.send(
        MessageSendInput(
            channelID: ChannelID(rawValue: "200"),
            content: "Replying from preview.",
            nonce: MessageNonce(rawValue: "preview-reply"),
            messageReference: MessageReferenceSendInput(
                messageID: MessageID(rawValue: "300"),
                channelID: ChannelID(rawValue: "200"),
                guildID: GuildID(rawValue: "100")
            )
        )
    )

    #expect(reply.messageReference?.messageID == MessageID(rawValue: "300"))
    #expect(reply.messageReference?.channelID == ChannelID(rawValue: "200"))
    #expect(reply.messageReference?.guildID == GuildID(rawValue: "100"))
}

@Test
func processGatewayReactionUpdatesMutatesStoredMessageReactions() async throws {
    let client = DiscordClient.preview()
    try await client.bootstrap()

    try await client.processGatewayEvent(
        .messageReactionAdd(
            GatewayReactionUpdate(
                channelID: ChannelID(rawValue: "200"),
                messageID: MessageID(rawValue: "300"),
                userID: UserID(rawValue: "1"),
                guildID: GuildID(rawValue: "100"),
                emoji: DiscordReactionEmoji(name: "🔥")
            )
        )
    )

    var timeline = await client.state.timelineProjection(for: ChannelID(rawValue: "200"))
    #expect(timeline.messages.first?.reactions.first?.emoji.name == "🔥")
    #expect(timeline.messages.first?.reactions.first?.me == true)

    try await client.processGatewayEvent(
        .messageReactionRemove(
            GatewayReactionUpdate(
                channelID: ChannelID(rawValue: "200"),
                messageID: MessageID(rawValue: "300"),
                userID: UserID(rawValue: "1"),
                guildID: GuildID(rawValue: "100"),
                emoji: DiscordReactionEmoji(name: "🔥")
            )
        )
    )

    timeline = await client.state.timelineProjection(for: ChannelID(rawValue: "200"))
    #expect(timeline.messages.first?.reactions.isEmpty == true)
}

@Test
func hydrateUserProfileStoresBioMutualsAndBannerData() async throws {
    let supportURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let client = DiscordClient.ephemeral(
        configuration: DiscordConfiguration(applicationSupportURL: supportURL),
        transport: HydrationFixtureTransport()
    )

    try await client.bootstrap()
    _ = try await client.auth.importUserToken("fixture-token")
    try await client.hydrateHomeState()
    try await client.hydrateUserProfile(for: UserID(rawValue: "2"))

    let snapshot = await client.state.snapshot()
    let inspector = await client.state.userInspectorProjection(for: UserID(rawValue: "2"))

    #expect(snapshot.userProfiles["2"]?.bio == "Compiler engineer")
    #expect(inspector?.profile?.pronouns == "she/her")
    #expect(inspector?.mutualGuilds.map(\.name) == ["Swift Guild"])
    #expect(inspector?.mutualFriends.map(\.username) == ["sam"])
}

@Test
func hydrateGuildStateAndUserProfileResolveGuildRolesForInspectorAndTimeline() async throws {
    let supportURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let client = DiscordClient.ephemeral(
        configuration: DiscordConfiguration(applicationSupportURL: supportURL),
        transport: HydrationFixtureTransport()
    )

    try await client.bootstrap()
    _ = try await client.auth.importUserToken("fixture-token")
    try await client.hydrateGuildState(for: GuildID(rawValue: "100"))
    try await client.hydrateUserProfile(for: UserID(rawValue: "2"), guildID: GuildID(rawValue: "100"))

    let timeline = await client.state.clusteredTimelineProjection(for: ChannelID(rawValue: "300"))
    let inspector = await client.state.userInspectorProjection(for: UserID(rawValue: "2"))
    let compilerAdaCluster = timeline.clusters.first { $0.author.id == UserID(rawValue: "2") }

    #expect(compilerAdaCluster?.displayAccentColor == 0xFF5500)
    #expect(inspector?.resolvedRoles.map(\.name) == ["Compiler", "Moderator"])
    #expect(inspector?.displayAccentColor == 0xFF5500)
}

@Test
func ensureDirectMessageChannelCreatesChannelWhenMissing() async throws {
    let supportURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let client = DiscordClient.ephemeral(
        configuration: DiscordConfiguration(applicationSupportURL: supportURL),
        transport: HydrationFixtureTransport()
    )

    try await client.bootstrap()
    _ = try await client.auth.importUserToken("fixture-token")

    let channelID = try await client.ensureDirectMessageChannel(with: UserID(rawValue: "4"))
    let channels = await client.state.channelListProjection(for: nil)

    #expect(channelID == ChannelID(rawValue: "201"))
    #expect(channels.channels.contains { $0.id == channelID })
    #expect(channels.channels.contains { $0.recipientIDs.contains(UserID(rawValue: "4")) })
}
