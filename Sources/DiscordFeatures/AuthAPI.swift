import Foundation
import DiscordAuth
import DiscordHTTP
import DiscordPrimitives

public final class AuthAPI: @unchecked Sendable {
    private let runtime: AuthRuntime

    public init(runtime: AuthRuntime) {
        self.runtime = runtime
    }

    public func restoreSession() async throws -> DiscordSession? {
        try await runtime.restoreSession()
    }

    public func currentSession() async -> DiscordSession? {
        await runtime.currentSession()
    }

    public func importUserToken(_ token: String, userID: UserID? = nil) async throws -> DiscordSession {
        try await runtime.importUserToken(token, userID: userID)
    }

    public func updateCurrentSessionUserID(_ userID: UserID) async throws {
        try await runtime.updateCurrentSessionUserID(userID)
    }

    public func login(
        credentials: LoginCredentials,
        fingerprint: Fingerprint? = nil,
        captchaAnswer: CaptchaAnswer? = nil
    ) async throws -> LoginResult {
        try await runtime.login(credentials: credentials, fingerprint: fingerprint, captchaAnswer: captchaAnswer)
    }

    public func completeMFA(
        ticket: SessionTicket,
        authenticator: MFAAuthenticatorType,
        code: String,
        loginInstanceID: String? = nil
    ) async throws -> MFALoginResponse {
        try await runtime.completeMFALogin(
            ticket: ticket,
            authenticator: authenticator,
            code: code,
            loginInstanceID: loginInstanceID
        )
    }

    public func sendMFASMS(ticket: SessionTicket) async throws -> MFASMSResponse {
        try await runtime.sendMFASMS(ticket: ticket)
    }

    public func fetchSessions() async throws -> [AuthSessionInfo] {
        try await runtime.fetchSessions()
    }

    public func logoutCurrentSession() async throws {
        try await runtime.logoutCurrentSession()
    }

    public func startPasswordlessLogin(login: String) async throws -> PasswordlessStartResponse {
        try await runtime.startPasswordlessLogin(login: login)
    }

    public func finishPasswordlessLogin(
        ticket: SessionTicket,
        credential: String,
        captchaAnswer: CaptchaAnswer? = nil
    ) async throws -> LoginResult {
        try await runtime.finishPasswordlessLogin(
            ticket: ticket,
            credential: credential,
            captchaAnswer: captchaAnswer
        )
    }

    public func createHandoffToken(key: String) async throws -> HandoffTokenResponse {
        try await runtime.createHandoffToken(key: key)
    }

    public func exchangeHandoffToken(key: String, handoffToken: String) async throws -> ExchangeHandoffResponse {
        try await runtime.exchangeHandoffToken(key: key, handoffToken: handoffToken)
    }

    public func prepareRemoteAuthentication() throws -> RemoteAuthBootstrap {
        try runtime.prepareRemoteAuthentication()
    }
}
