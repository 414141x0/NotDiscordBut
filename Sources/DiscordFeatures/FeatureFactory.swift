import Foundation
import DiscordAuth
import DiscordHTTP
import DiscordPrimitives
import DiscordState

public struct FeatureFactory: Sendable {
    public var auth: AuthAPI
    public var users: UsersAPI
    public var guilds: GuildsAPI
    public var channels: ChannelsAPI
    public var messages: MessagesAPI
    public var relationships: RelationshipsAPI
    public var presence: PresenceAPI
    public var settings: SettingsAPI
    public var search: SearchAPI
    public var notifications: NotificationsAPI
    public var invites: InvitesAPI

    public init(
        http: HTTPRuntime,
        authRuntime: AuthRuntime,
        store: StoreRuntime,
        query: QueryRuntime
    ) {
        let authorization = { @Sendable in
            await authRuntime.currentAuthorization()
        }

        self.auth = AuthAPI(runtime: authRuntime)
        self.users = UsersAPI(http: http, authorization: authorization, store: store)
        self.guilds = GuildsAPI(http: http, authorization: authorization, store: store, query: query)
        self.channels = ChannelsAPI(http: http, authorization: authorization, store: store, query: query)
        self.messages = MessagesAPI(http: http, authorization: authorization, store: store, query: query)
        self.relationships = RelationshipsAPI(http: http, authorization: authorization, store: store)
        self.presence = PresenceAPI(http: http, authorization: authorization)
        self.settings = SettingsAPI(store: store)
        self.search = SearchAPI(http: http, authorization: authorization, store: store)
        self.notifications = NotificationsAPI(store: store)
        self.invites = InvitesAPI(http: http, authorization: authorization)
    }
}
