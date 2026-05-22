import Foundation
import DiscordAuth
import DiscordFeatures
import DiscordGateway
import DiscordHTTP
import DiscordPersistence
import DiscordPrimitives
import DiscordState

public final class DiscordClient: @unchecked Sendable {
    public let configuration: DiscordConfiguration

    public let auth: AuthAPI
    public let users: UsersAPI
    public let guilds: GuildsAPI
    public let channels: ChannelsAPI
    public let messages: MessagesAPI
    public let relationships: RelationshipsAPI
    public let presence: PresenceAPI
    public let settings: SettingsAPI
    public let search: SearchAPI
    public let notifications: NotificationsAPI
    public let invites: InvitesAPI
    public let state: ClientStateAPI

    let httpRuntime: HTTPRuntime
    let authRuntime: AuthRuntime
    let gatewayRuntime: GatewayRuntime
    let storeRuntime: StoreRuntime
    let queryRuntime: QueryRuntime

    private init(
        configuration: DiscordConfiguration,
        httpRuntime: HTTPRuntime,
        authRuntime: AuthRuntime,
        gatewayRuntime: GatewayRuntime,
        storeRuntime: StoreRuntime,
        queryRuntime: QueryRuntime,
        features: FeatureFactory
    ) {
        self.configuration = configuration
        self.httpRuntime = httpRuntime
        self.authRuntime = authRuntime
        self.gatewayRuntime = gatewayRuntime
        self.storeRuntime = storeRuntime
        self.queryRuntime = queryRuntime
        self.auth = features.auth
        self.users = features.users
        self.guilds = features.guilds
        self.channels = features.channels
        self.messages = features.messages
        self.relationships = features.relationships
        self.presence = features.presence
        self.settings = features.settings
        self.search = features.search
        self.notifications = features.notifications
        self.invites = features.invites
        self.state = ClientStateAPI(store: storeRuntime, query: queryRuntime)
    }

    public static func live(
        configuration: DiscordConfiguration,
        transport: any DiscordTransport = URLSessionDiscordTransport(),
        sessionVault: any SessionVault = KeychainSessionVault()
    ) throws -> DiscordClient {
        try FileManager.default.createDirectory(
            at: configuration.applicationSupportURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let databaseURL = configuration.applicationSupportURL.appending(path: "Discord.sqlite")

        let httpRuntime = HTTPRuntime(
            transport: transport,
            configuration: DiscordHTTPConfiguration(
                baseURL: configuration.httpBaseURL,
                apiVersion: configuration.apiVersion
            )
        )
        let authRuntime = AuthRuntime(http: httpRuntime, vault: sessionVault)
        let gatewayRuntime = GatewayRuntime()
        let storeRuntime = try StoreRuntime(database: SQLiteDatabase(path: databaseURL.path))
        let queryRuntime = QueryRuntime()
        let features = FeatureFactory(http: httpRuntime, authRuntime: authRuntime, store: storeRuntime, query: queryRuntime)

        return DiscordClient(
            configuration: configuration,
            httpRuntime: httpRuntime,
            authRuntime: authRuntime,
            gatewayRuntime: gatewayRuntime,
            storeRuntime: storeRuntime,
            queryRuntime: queryRuntime,
            features: features
        )
    }

    public static func ephemeral(
        configuration: DiscordConfiguration,
        transport: any DiscordTransport = URLSessionDiscordTransport(),
        sessionVault: any SessionVault = InMemorySessionVault()
    ) -> DiscordClient {
        let database = try! SQLiteDatabase.temporary()
        let httpRuntime = HTTPRuntime(
            transport: transport,
            configuration: DiscordHTTPConfiguration(
                baseURL: configuration.httpBaseURL,
                apiVersion: configuration.apiVersion
            )
        )
        let authRuntime = AuthRuntime(http: httpRuntime, vault: sessionVault)
        let gatewayRuntime = GatewayRuntime()
        let storeRuntime = StoreRuntime(database: database)
        let queryRuntime = QueryRuntime()
        let features = FeatureFactory(http: httpRuntime, authRuntime: authRuntime, store: storeRuntime, query: queryRuntime)

        return DiscordClient(
            configuration: configuration,
            httpRuntime: httpRuntime,
            authRuntime: authRuntime,
            gatewayRuntime: gatewayRuntime,
            storeRuntime: storeRuntime,
            queryRuntime: queryRuntime,
            features: features
        )
    }

    public static func preview() -> DiscordClient {
        let database = try! SQLiteDatabase.temporary()
        let session = DiscordSession(userID: "1", authKind: .user, token: "preview-token")
        let storeRuntime = StoreRuntime(
            database: database,
            initialState: NormalizedState(
                users: [
                    "1": DiscordUser(id: "1", username: "preview", globalName: "Preview"),
                    "2": DiscordUser(id: "2", username: "ada", globalName: "Ada"),
                    "3": DiscordUser(id: "3", username: "sam", globalName: "Sam")
                ],
                guilds: [
                    "100": DiscordGuild(id: "100", name: "Preview Guild"),
                    "101": DiscordGuild(id: "101", name: "Swift Systems")
                ],
                guildEmojis: [
                    "812217273670565888": DiscordGuildEmoji(
                        id: "812217273670565888",
                        guildID: "100",
                        name: "blobwave"
                    ),
                    "812217273670565889": DiscordGuildEmoji(
                        id: "812217273670565889",
                        guildID: "100",
                        name: "partyparrot",
                        animated: true
                    )
                ],
                channels: [
                    "200": DiscordChannel(id: "200", kind: .guildText, guildID: "100", name: "general", lastMessageID: "300"),
                    "201": DiscordChannel(id: "201", kind: .guildText, guildID: "100", name: "design", lastMessageID: "301"),
                    "202": DiscordChannel(id: "202", kind: .guildText, guildID: "101", name: "announcements", lastMessageID: "302"),
                    "203": DiscordChannel(id: "203", kind: .guildText, guildID: "101", name: "performance", lastMessageID: "303"),
                    "210": DiscordChannel(id: "210", kind: .directMessage, name: "Ada", lastMessageID: "304", recipientIDs: ["2"]),
                    "211": DiscordChannel(id: "211", kind: .groupDM, name: "Compiler Crew", lastMessageID: "305", recipientIDs: ["2", "3"])
                ],
                messages: [
                    "300": DiscordMessage(
                        id: "300",
                        channelID: "200",
                        authorID: "1",
                        content: "Welcome to NotDiscordBut",
                        timestamp: .now,
                        attachments: [
                            DiscordMessageAttachment(
                                id: "a300",
                                filename: "preview-landscape.jpg",
                                contentType: "image/jpeg",
                                url: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3f/Fronalpstock_big.jpg/640px-Fronalpstock_big.jpg",
                                width: 640,
                                height: 288
                            )
                        ]
                    ),
                    "301": DiscordMessage(
                        id: "301",
                        channelID: "201",
                        authorID: "2",
                        content: "Let’s keep the layout intentionally simple.",
                        timestamp: .now
                    ),
                    "302": DiscordMessage(
                        id: "302",
                        channelID: "202",
                        authorID: "3",
                        content: "Server windows should feel like native document spaces.",
                        timestamp: .now
                    ),
                    "303": DiscordMessage(
                        id: "303",
                        channelID: "203",
                        authorID: "1",
                        content: "Profile first, optimize second, keep the abstractions narrow.",
                        timestamp: .now
                    ),
                    "304": DiscordMessage(
                        id: "304",
                        channelID: "210",
                        authorID: "2",
                        content: "Want to pair on the timeline view later?",
                        timestamp: .now
                    ),
                    "305": DiscordMessage(
                        id: "305",
                        channelID: "211",
                        authorID: "3",
                        content: "The next step is to open each server in its own window.",
                        timestamp: .now
                    )
                ],
                readStates: [
                    "200": DiscordReadState(channelID: "200", lastMessageID: "300"),
                    "202": DiscordReadState(channelID: "202", lastMessageID: "302"),
                    "210": DiscordReadState(channelID: "210", lastMessageID: "304")
                ]
            )
        )

        let queryRuntime = QueryRuntime()
        let previewTransport = PreviewDiscordTransport(currentUserID: "1")
        let httpRuntime = HTTPRuntime(
            transport: previewTransport,
            configuration: DiscordHTTPConfiguration(baseURL: URL(string: "https://discord.com/api")!)
        )
        let authRuntime = AuthRuntime(http: httpRuntime, vault: InMemorySessionVault(session: session))
        let gatewayRuntime = GatewayRuntime()
        let features = FeatureFactory(http: httpRuntime, authRuntime: authRuntime, store: storeRuntime, query: queryRuntime)

        let configuration = DiscordConfiguration(applicationSupportURL: FileManager.default.temporaryDirectory)
        return DiscordClient(
            configuration: configuration,
            httpRuntime: httpRuntime,
            authRuntime: authRuntime,
            gatewayRuntime: gatewayRuntime,
            storeRuntime: storeRuntime,
            queryRuntime: queryRuntime,
            features: features
        )
    }

    public func processGatewayEvent(_ event: GatewayEvent) async throws {
        switch event {
        case let .messageCreate(message, users), let .messageUpdate(message, users):
            try await storeRuntime.apply(.merge(StateMergeSnapshot(users: users, messages: [message])))

        case let .messageDelete(delete):
            try await storeRuntime.apply(.messageDelete(channelID: delete.channelID, messageID: delete.messageID))

        case let .channelCreate(channel), let .channelUpdate(channel):
            try await storeRuntime.apply(.merge(StateMergeSnapshot(channels: [channel])))

        case let .channelDelete(channel):
            try await storeRuntime.apply(.channelDelete(channel.id))

        case .presenceUpdate:
            break

        case let .relationshipAdd(relationship, user):
            try await storeRuntime.apply(.merge(StateMergeSnapshot(users: [user], relationships: [relationship])))

        case let .relationshipRemove(userID):
            try await storeRuntime.apply(.relationshipRemove(userID))

        case let .guildMemberAdd(member, user):
            try await storeRuntime.apply(.merge(StateMergeSnapshot(users: [user], guildMembers: [member])))

        case let .guildMemberUpdate(member):
            try await storeRuntime.apply(.merge(StateMergeSnapshot(guildMembers: [member])))

        case let .guildMemberRemove(remove):
            try await storeRuntime.apply(.guildMemberRemove(guildID: remove.guildID, userID: remove.userID))

        case let .authSessionChange(change):
            try await storeRuntime.apply(.authSessionDidChange(change.authSessionIDHash))

        case let .messageReactionAdd(update):
            try await applyReactionUpdate(update, isAdding: true)

        case let .messageReactionRemove(update):
            try await applyReactionUpdate(update, isAdding: false)

        case .typingStart:
            break

        case .ready, .readySupplemental, .resumed, .unknown:
            break
        }
    }

    public func bootstrap() async throws {
        try await storeRuntime.bootstrap()
        _ = try await authRuntime.restoreSession()
    }

    public func currentSession() async -> DiscordSession? {
        await authRuntime.currentSession()
    }

    public func clearLocalCache() async throws {
        try await storeRuntime.reset()
    }

    public func hydrateHomeState() async throws {
        let currentUser: APIUserDTO = try await executeAuthorized(
            DiscordRequest(method: .get, path: "/users/@me")
        )
        async let guildsTask: [APIGuildDTO] = executeAuthorized(
            DiscordRequest(
                method: .get,
                path: "/users/@me/guilds",
                query: [URLQueryItem(name: "limit", value: "200")]
            )
        )
        async let relationshipsTask: [APIRelationshipDTO] = executeAuthorized(
            DiscordRequest(method: .get, path: "/users/@me/relationships")
        )
        async let privateChannelsTask: [APIChannelDTO] = executeAuthorized(
            DiscordRequest(method: .get, path: "/users/@me/channels")
        )

        let guilds = try await guildsTask.map { $0.toDomain() }
        let relationshipPayloads = try await relationshipsTask
        let privateChannelPayloads = try await privateChannelsTask

        var usersByID = [currentUser.id.rawValue: currentUser.toDomain()]
        var relationships: [DiscordRelationship] = []
        for payload in relationshipPayloads {
            usersByID[payload.user.id.rawValue] = payload.user.toDomain()
            if let relationship = payload.toDomain() {
                relationships.append(relationship)
            }
        }

        var channels: [DiscordChannel] = []
        for payload in privateChannelPayloads {
            guard let mapped = payload.toDomain(currentUserID: currentUser.id) else {
                continue
            }
            channels.append(mapped.channel)
            for user in mapped.users {
                usersByID[user.id.rawValue] = user
            }
        }

        try await storeRuntime.apply(
            .merge(
                StateMergeSnapshot(
                    users: Array(usersByID.values),
                    guilds: guilds,
                    channels: channels,
                    relationships: relationships
                )
            )
        )
        try await authRuntime.updateCurrentSessionUserID(currentUser.id)
    }

    public func hydrateUserProfile(for userID: UserID, guildID: GuildID? = nil) async throws {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "with_mutual_guilds", value: "true"),
            URLQueryItem(name: "with_mutual_friends", value: "true")
        ]
        if let guildID {
            query.append(URLQueryItem(name: "guild_id", value: guildID.rawValue))
        }

        let payload: APIUserProfileResponseDTO = try await executeAuthorized(
            DiscordRequest(
                method: .get,
                path: "/users/\(userID.rawValue)/profile",
                query: query
            )
        )

        var users = [payload.user.toDomain()]
        users.append(contentsOf: payload.mutualFriends?.map { $0.toDomain() } ?? [])

        try await storeRuntime.apply(
            .merge(
                StateMergeSnapshot(
                    users: users,
                    userProfiles: [payload.toUserProfile(guildID: guildID)]
                )
            )
        )
    }

    public func ensureDirectMessageChannel(with userID: UserID) async throws -> ChannelID {
        let snapshot = await storeRuntime.snapshot()
        if let existingChannel = snapshot.channels.values.first(where: { channel in
            channel.guildID == nil &&
            channel.kind == .directMessage &&
            channel.recipientIDs.contains(userID)
        }) {
            return existingChannel.id
        }

        struct CreateDMRequest: Codable, Sendable {
            var recipientID: UserID
        }

        guard let authorization = await authRuntime.currentAuthorization() else {
            throw AuthError.sessionUnavailable
        }

        var request = DiscordRequest<APIChannelDTO>(
            method: .post,
            path: "/users/@me/channels",
            body: AnyEncodable(CreateDMRequest(recipientID: userID))
        )
        request.authorization = authorization
        if authorization.sessionKind == .user {
            request.headers = DiscordUserSessionRequestProfile.headers(referer: "https://discord.com/channels/@me")
        }

        let payload = try await httpRuntime.execute(request).value

        guard let mapped = payload.toDomain(currentUserID: await authRuntime.currentSession()?.userID) else {
            throw DiscordHTTPError.decodingFailed("Could not map created DM channel payload into a domain channel.")
        }

        try await storeRuntime.apply(
            .merge(
                StateMergeSnapshot(
                    users: mapped.users,
                    channels: [mapped.channel]
                )
            )
        )

        return mapped.channel.id
    }

    public func hydrateGuildState(for guildID: GuildID, messageLimit: Int = 50) async throws {
        async let channelPayloadsTask: [APIChannelDTO] = executeAuthorized(
            DiscordRequest(method: .get, path: "/guilds/\(guildID.rawValue)/channels")
        )
        async let guildRolePayloadsTask: [APIGuildRoleDTO] = executeAuthorized(
            DiscordRequest(method: .get, path: "/guilds/\(guildID.rawValue)/roles")
        )
        async let guildEmojiPayloadsTask: [APIGuildEmojiDTO] = executeAuthorized(
            DiscordRequest(method: .get, path: "/guilds/\(guildID.rawValue)/emojis")
        )

        let channelPayloads = try await channelPayloadsTask
        let guildRoles = try await guildRolePayloadsTask.map { $0.toDomain(guildID: guildID) }
        let guildEmojis = try await guildEmojiPayloadsTask.map { $0.toDomain(guildID: guildID) }

        var usersByID: [String: DiscordUser] = [:]
        var channels: [DiscordChannel] = []
        for payload in channelPayloads {
            guard let mapped = payload.toDomain(currentUserID: nil) else {
                continue
            }
            channels.append(mapped.channel)
            for user in mapped.users {
                usersByID[user.id.rawValue] = user
            }
        }

        var messages: [DiscordMessage] = []
        if let initialChannel = channels.first(where: \.supportsTimelineHydration) {
            let (mapped, users) = try await fetchMessages(channelID: initialChannel.id, limit: messageLimit)
            messages = mapped
            for user in users { usersByID[user.id.rawValue] = user }
        }

        try await storeRuntime.apply(
            .merge(
                StateMergeSnapshot(
                    users: Array(usersByID.values),
                    guildRoles: guildRoles,
                    guildEmojis: guildEmojis,
                    channels: channels,
                    messages: messages
                )
            )
        )
    }

    public func hydrateChannelTimeline(for channelID: ChannelID, limit: Int = 50) async throws {
        let (messages, users) = try await fetchMessages(channelID: channelID, limit: limit)
        try await storeRuntime.apply(
            .merge(StateMergeSnapshot(users: users, messages: messages))
        )
    }

    private func fetchMessages(
        channelID: ChannelID,
        limit: Int,
        query: [URLQueryItem] = []
    ) async throws -> (messages: [DiscordMessage], users: [DiscordUser]) {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        queryItems.append(contentsOf: query)

        let payloads: [APIMessageDTO] = try await executeAuthorized(
            DiscordRequest(
                method: .get,
                path: "/channels/\(channelID.rawValue)/messages",
                query: queryItems
            )
        )

        var usersByID: [String: DiscordUser] = [:]
        var messages: [DiscordMessage] = []
        messages.reserveCapacity(payloads.count)
        for payload in payloads {
            let mapped = payload.toDomain()
            messages.append(mapped.message)
            for user in mapped.users {
                usersByID[user.id.rawValue] = user
            }
        }
        return (messages, Array(usersByID.values))
    }

    private func executeAuthorized<Response>(
        _ request: DiscordRequest<Response>
    ) async throws -> Response where Response: Decodable & Sendable {
        guard let authorization = await authRuntime.currentAuthorization() else {
            throw AuthError.sessionUnavailable
        }

        var request = request
        request.authorization = authorization
        return try await httpRuntime.execute(request).value
    }

    private func applyReactionUpdate(_ update: GatewayReactionUpdate, isAdding: Bool) async throws {
        let snapshot = await storeRuntime.snapshot()
        guard var message = snapshot.messages[update.messageID.rawValue] else {
            return
        }

        let currentUserID = await authRuntime.currentSession()?.userID
        let isCurrentUser = update.userID == currentUserID

        if let index = message.reactions.firstIndex(where: { $0.emoji == update.emoji }) {
            var reaction = message.reactions[index]
            if isAdding {
                reaction.count += 1
                reaction.countDetails.normal += 1
                if isCurrentUser {
                    reaction.me = true
                }
                message.reactions[index] = reaction
            } else {
                reaction.count = max(0, reaction.count - 1)
                reaction.countDetails.normal = max(0, reaction.countDetails.normal - 1)
                if isCurrentUser {
                    reaction.me = false
                }
                if reaction.count == 0 {
                    message.reactions.remove(at: index)
                } else {
                    message.reactions[index] = reaction
                }
            }
        } else if isAdding {
            message.reactions.append(
                DiscordMessageReaction(
                    emoji: update.emoji,
                    count: 1,
                    countDetails: .init(normal: 1),
                    me: isCurrentUser
                )
            )
        }

        try await storeRuntime.apply(.messageUpsert(message))
    }
}

private extension DiscordChannel {
    var supportsTimelineHydration: Bool { kind.supportsTimeline }
}
