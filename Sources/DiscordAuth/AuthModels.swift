import Foundation
import DiscordHTTP
import DiscordPrimitives

public struct AuthSessionClientInfo: Codable, Hashable, Sendable {
    public var os: String?
    public var platform: String?
    public var location: String?

    public init(os: String? = nil, platform: String? = nil, location: String? = nil) {
        self.os = os
        self.platform = platform
        self.location = location
    }
}

public struct AuthSessionInfo: Codable, Hashable, Sendable {
    public var idHash: AuthSessionIDHash
    public var approxLastUsedTime: Date
    public var clientInfo: AuthSessionClientInfo

    public init(idHash: AuthSessionIDHash, approxLastUsedTime: Date, clientInfo: AuthSessionClientInfo) {
        self.idHash = idHash
        self.approxLastUsedTime = approxLastUsedTime
        self.clientInfo = clientInfo
    }
}

public struct AuthSessionsResponse: Codable, Hashable, Sendable {
    public var userSessions: [AuthSessionInfo]

    public init(userSessions: [AuthSessionInfo]) {
        self.userSessions = userSessions
    }
}

public struct LoginCredentials: Codable, Hashable, Sendable {
    public var login: String
    public var password: String
    public var undelete: Bool
    public var loginSource: LoginSource?

    public init(login: String, password: String, undelete: Bool = false, loginSource: LoginSource? = nil) {
        self.login = login
        self.password = password
        self.undelete = undelete
        self.loginSource = loginSource
    }
}

public enum LoginSource: String, Codable, Hashable, Sendable, CaseIterable {
    case gift
    case guildTemplate = "guild_template"
    case guildInvite = "guild_invite"
    case dmInvite = "dm_invite"
    case friendInvite = "friend_invite"
    case roleSubscription = "role_subscription"
    case roleSubscriptionSetting = "role_subscription_setting"
}

public struct LoginResponse: Codable, Hashable, Sendable {
    public var userID: UserID
    public var token: String?
    public var userSettings: DiscordUserSettings?
    public var requiredActions: [String]?
    public var ticket: SessionTicket?
    public var loginInstanceID: String?
    public var mfa: Bool
    public var totp: Bool
    public var sms: Bool
    public var backup: Bool
    public var webauthn: String?

    public init(
        userID: UserID,
        token: String? = nil,
        userSettings: DiscordUserSettings? = nil,
        requiredActions: [String]? = nil,
        ticket: SessionTicket? = nil,
        loginInstanceID: String? = nil,
        mfa: Bool = false,
        totp: Bool = false,
        sms: Bool = false,
        backup: Bool = false,
        webauthn: String? = nil
    ) {
        self.userID = userID
        self.token = token
        self.userSettings = userSettings
        self.requiredActions = requiredActions
        self.ticket = ticket
        self.loginInstanceID = loginInstanceID
        self.mfa = mfa
        self.totp = totp
        self.sms = sms
        self.backup = backup
        self.webauthn = webauthn
    }
}

public struct LoginSuccess: Hashable, Sendable {
    public var userID: UserID
    public var token: String
    public var userSettings: DiscordUserSettings?
    public var requiredActions: [String]

    public init(
        userID: UserID,
        token: String,
        userSettings: DiscordUserSettings? = nil,
        requiredActions: [String] = []
    ) {
        self.userID = userID
        self.token = token
        self.userSettings = userSettings
        self.requiredActions = requiredActions
    }
}

public struct MFALoginChallenge: Hashable, Sendable {
    public var userID: UserID
    public var ticket: SessionTicket
    public var loginInstanceID: String?
    public var authenticators: Set<MFAAuthenticatorType>
    public var webauthnRequest: String?

    public init(
        userID: UserID,
        ticket: SessionTicket,
        loginInstanceID: String? = nil,
        authenticators: Set<MFAAuthenticatorType> = [],
        webauthnRequest: String? = nil
    ) {
        self.userID = userID
        self.ticket = ticket
        self.loginInstanceID = loginInstanceID
        self.authenticators = authenticators
        self.webauthnRequest = webauthnRequest
    }

    public var recommendedAuthenticator: MFAAuthenticatorType? {
        MFAAuthenticatorType.recommendedLoginOrder.first(where: authenticators.contains)
            ?? authenticators.first
    }
}

public enum LoginChallenge: Hashable, Sendable {
    case mfa(MFALoginChallenge)
    case captcha(CaptchaChallenge)
}

public enum LoginResult: Hashable, Sendable {
    case authenticated(LoginSuccess)
    case challenge(LoginChallenge)
}

extension LoginResponse {
    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case token
        case userSettings = "userSettings"
        case requiredActions = "requiredActions"
        case ticket
        case loginInstanceID = "loginInstanceId"
        case mfa
        case totp
        case sms
        case backup
        case webauthn
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(UserID.self, forKey: .userID)
        token = try container.decodeIfPresent(String.self, forKey: .token)
        userSettings = try container.decodeIfPresent(DiscordUserSettings.self, forKey: .userSettings)
        requiredActions = try container.decodeIfPresent([String].self, forKey: .requiredActions)
        ticket = try container.decodeIfPresent(SessionTicket.self, forKey: .ticket)
        loginInstanceID = try container.decodeIfPresent(String.self, forKey: .loginInstanceID)
        mfa = try container.decodeIfPresent(Bool.self, forKey: .mfa) ?? false
        totp = try container.decodeIfPresent(Bool.self, forKey: .totp) ?? false
        sms = try container.decodeIfPresent(Bool.self, forKey: .sms) ?? false
        backup = try container.decodeIfPresent(Bool.self, forKey: .backup) ?? false
        webauthn = try container.decodeIfPresent(String.self, forKey: .webauthn)
    }

    public var success: LoginSuccess? {
        guard let token else {
            return nil
        }

        return LoginSuccess(
            userID: userID,
            token: token,
            userSettings: userSettings,
            requiredActions: requiredActions ?? []
        )
    }

    public var mfaChallenge: MFALoginChallenge? {
        guard mfa, let ticket else {
            return nil
        }

        var authenticators = Set<MFAAuthenticatorType>()
        if totp {
            authenticators.insert(.totp)
        }
        if sms {
            authenticators.insert(.sms)
        }
        if backup {
            authenticators.insert(.backup)
        }
        if webauthn != nil {
            authenticators.insert(.webauthn)
        }

        return MFALoginChallenge(
            userID: userID,
            ticket: ticket,
            loginInstanceID: loginInstanceID,
            authenticators: authenticators,
            webauthnRequest: webauthn
        )
    }
}

public enum MFAAuthenticatorType: String, Codable, Hashable, Sendable, CaseIterable {
    case totp
    case sms
    case backup
    case webauthn

    public static let recommendedLoginOrder: [Self] = [.totp, .backup, .sms, .webauthn]

    public var requiresTextCode: Bool {
        switch self {
        case .webauthn:
            return false
        case .totp, .sms, .backup:
            return true
        }
    }
}

public struct MFALoginResponse: Codable, Hashable, Sendable {
    public var token: String
    public var userSettings: DiscordUserSettings?
    public var authSessionIDHash: AuthSessionIDHash?

    public init(token: String, userSettings: DiscordUserSettings? = nil, authSessionIDHash: AuthSessionIDHash? = nil) {
        self.token = token
        self.userSettings = userSettings
        self.authSessionIDHash = authSessionIDHash
    }
}

public struct MFASMSResponse: Codable, Hashable, Sendable {
    public var phone: String

    public init(phone: String) {
        self.phone = phone
    }
}

extension MFALoginResponse {
    enum CodingKeys: String, CodingKey {
        case token
        case userSettings = "userSettings"
        case authSessionIDHash = "authSessionIdHash"
    }
}

public struct PasswordlessStartResponse: Codable, Hashable, Sendable {
    public var ticket: SessionTicket
    public var webauthn: String

    public init(ticket: SessionTicket, webauthn: String) {
        self.ticket = ticket
        self.webauthn = webauthn
    }
}

extension PasswordlessStartResponse {
    enum CodingKeys: String, CodingKey {
        case ticket
        case webauthn = "challenge"
    }
}

public struct HandoffTokenResponse: Codable, Hashable, Sendable {
    public var handoffToken: String

    public init(handoffToken: String) {
        self.handoffToken = handoffToken
    }
}

extension HandoffTokenResponse {
    enum CodingKeys: String, CodingKey {
        case handoffToken = "handoffToken"
    }
}

public struct ExchangeHandoffResponse: Codable, Hashable, Sendable {
    public var token: String

    public init(token: String) {
        self.token = token
    }
}

public struct RemoteAuthBootstrap: Hashable, Sendable {
    public var encodedPublicKey: String
    public var fingerprint: Fingerprint

    public init(encodedPublicKey: String, fingerprint: Fingerprint) {
        self.encodedPublicKey = encodedPublicKey
        self.fingerprint = fingerprint
    }
}

public struct RemoteAuthPendingTicket: Codable, Hashable, Sendable {
    public var fingerprint: Fingerprint
    public var user: DiscordUser

    public init(fingerprint: Fingerprint, user: DiscordUser) {
        self.fingerprint = fingerprint
        self.user = user
    }
}

public struct RemoteAuthPendingLogin: Codable, Hashable, Sendable {
    public var ticket: RemoteAuthTicket

    public init(ticket: RemoteAuthTicket) {
        self.ticket = ticket
    }
}
