import Foundation
import DiscordHTTP
import DiscordPersistence
import DiscordPrimitives

public actor AuthRuntime {
    private let http: HTTPRuntime
    private let vault: any SessionVault
    private var session: DiscordSession?

    public init(http: HTTPRuntime, vault: any SessionVault) {
        self.http = http
        self.vault = vault
    }

    public func restoreSession() async throws -> DiscordSession? {
        let restored = try await loadFromVault()
        session = restored
        return restored
    }

    public func currentSession() -> DiscordSession? {
        session
    }

    public func updateCurrentSessionUserID(_ userID: UserID) async throws(AuthError) {
        guard var session else {
            throw .sessionUnavailable
        }

        session.userID = userID
        try await storeInVault(session)
        self.session = session
    }

    public func importUserToken(_ token: String, userID: UserID? = nil) async throws(AuthError) -> DiscordSession {
        let normalizedToken = token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")

        guard !normalizedToken.isEmpty else {
            throw .security("Refusing to import an empty Discord token.")
        }

        let imported = DiscordSession(
            userID: userID,
            authKind: .user,
            token: normalizedToken
        )
        try await storeInVault(imported)
        session = imported
        return imported
    }

    public func login(
        credentials: LoginCredentials,
        fingerprint: Fingerprint? = nil,
        captchaAnswer: CaptchaAnswer? = nil
    ) async throws(AuthError) -> LoginResult {
        var request = DiscordRequest<LoginResponse>(
            method: .post,
            path: "/auth/login",
            body: AnyEncodable(credentials),
            fingerprint: fingerprint
        )
        if let captchaAnswer {
            request.headers.merge(captchaAnswer.retryHeaders) { _, new in new }
        }

        switch await executeHTTP(request) {
        case let .success(response):
            return try await resolveLoginResult(from: response)

        case let .failure(error):
            if let challenge = decodeCaptchaChallenge(from: error) {
                return .challenge(.captcha(challenge))
            }
            throw .http(error)
        }
    }

    public func completeMFALogin(
        ticket: SessionTicket,
        authenticator: MFAAuthenticatorType,
        code: String,
        loginInstanceID: String? = nil
    ) async throws(AuthError) -> MFALoginResponse {
        struct Request: Codable, Sendable {
            var ticket: SessionTicket
            var loginInstanceID: String?
            var code: String
        }

        let request = DiscordRequest<MFALoginResponse>(
            method: .post,
            path: "/auth/mfa/\(authenticator.rawValue)",
            body: AnyEncodable(Request(ticket: ticket, loginInstanceID: loginInstanceID, code: code))
        )

        let response = try await execute(request)
        let stored = DiscordSession(
            userID: nil,
            authKind: .user,
            token: response.token,
            authSessionIDHash: response.authSessionIDHash
        )
        try await storeInVault(stored)
        session = stored
        return response
    }

    public func sendMFASMS(ticket: SessionTicket) async throws(AuthError) -> MFASMSResponse {
        struct Request: Codable, Sendable {
            var ticket: SessionTicket
        }

        let request = DiscordRequest<MFASMSResponse>(
            method: .post,
            path: "/auth/mfa/sms/send",
            body: AnyEncodable(Request(ticket: ticket))
        )

        return try await execute(request)
    }

    public func fetchSessions() async throws(AuthError) -> [AuthSessionInfo] {
        let request = try authenticatedRequest(
            DiscordRequest<AuthSessionsResponse>(
                method: .get,
                path: "/auth/sessions"
            )
        )

        return try await execute(request).userSessions
    }

    public func logoutSessions(_ ids: [AuthSessionIDHash]) async throws(AuthError) {
        struct Request: Codable, Sendable {
            var sessionIDHashes: [AuthSessionIDHash]
        }

        let request = try authenticatedRequest(
            DiscordRequest<VoidResponse>(
                method: .post,
                path: "/auth/sessions/logout",
                body: AnyEncodable(Request(sessionIDHashes: ids))
            )
        )

        _ = try await execute(request)
    }

    public func logoutCurrentSession() async throws(AuthError) {
        let request = try authenticatedRequest(
            DiscordRequest<VoidResponse>(
                method: .post,
                path: "/auth/logout"
            )
        )

        _ = try await execute(request)
        try await clearVault()
        session = nil
    }

    public func startPasswordlessLogin(login: String) async throws(AuthError) -> PasswordlessStartResponse {
        struct Request: Codable, Sendable {
            var login: String
        }

        let request = DiscordRequest<PasswordlessStartResponse>(
            method: .post,
            path: "/auth/conditional/start",
            body: AnyEncodable(Request(login: login))
        )

        return try await execute(request)
    }

    public func finishPasswordlessLogin(
        ticket: SessionTicket,
        credential: String,
        captchaAnswer: CaptchaAnswer? = nil
    ) async throws(AuthError) -> LoginResult {
        struct Request: Codable, Sendable {
            var ticket: SessionTicket
            var credential: String
        }

        var request = DiscordRequest<LoginResponse>(
            method: .post,
            path: "/auth/conditional/finish",
            body: AnyEncodable(Request(ticket: ticket, credential: credential))
        )
        if let captchaAnswer {
            request.headers.merge(captchaAnswer.retryHeaders) { _, new in new }
        }

        switch await executeHTTP(request) {
        case let .success(response):
            return try await resolveLoginResult(from: response)

        case let .failure(error):
            if let challenge = decodeCaptchaChallenge(from: error) {
                return .challenge(.captcha(challenge))
            }
            throw .http(error)
        }
    }

    public func createHandoffToken(key: String) async throws(AuthError) -> HandoffTokenResponse {
        struct Request: Codable, Sendable {
            var key: String
        }

        let request = try authenticatedRequest(
            DiscordRequest<HandoffTokenResponse>(
                method: .post,
                path: "/auth/handoff",
                body: AnyEncodable(Request(key: key))
            )
        )

        return try await execute(request)
    }

    public func exchangeHandoffToken(key: String, handoffToken: String) async throws(AuthError) -> ExchangeHandoffResponse {
        struct Request: Codable, Sendable {
            var key: String
            var handoffToken: String
        }

        let request = DiscordRequest<ExchangeHandoffResponse>(
            method: .post,
            path: "/auth/handoff/exchange",
            body: AnyEncodable(Request(key: key, handoffToken: handoffToken))
        )

        return try await execute(request)
    }

    public nonisolated func prepareRemoteAuthentication() throws(AuthError) -> RemoteAuthBootstrap {
        try RemoteAuthKeyMaterial().bootstrap()
    }

    public func currentAuthorization() -> DiscordAuthorization? {
        guard let session else {
            return nil
        }

        switch session.authKind {
        case .user:
            return .user(session.token)
        case .bearer:
            return .bearer(session.token)
        }
    }

    private func authenticatedRequest<Response>(
        _ request: DiscordRequest<Response>
    ) throws(AuthError) -> DiscordRequest<Response> where Response: Decodable & Sendable {
        guard let authorization = currentAuthorization() else {
            throw .sessionUnavailable
        }

        var request = request
        request.authorization = authorization
        return request
    }

    private func execute<Response>(
        _ request: DiscordRequest<Response>
    ) async throws(AuthError) -> Response where Response: Decodable & Sendable {
        do {
            let response = try await http.execute(request)
            return response.value
        } catch let error {
            throw .http(error)
        }
    }

    private func loadFromVault() async throws(AuthError) -> DiscordSession? {
        do {
            return try await vault.load()
        } catch {
            throw .storage(error.localizedDescription)
        }
    }

    private func storeInVault(_ session: DiscordSession) async throws(AuthError) {
        do {
            try await vault.store(session)
        } catch {
            throw .storage(error.localizedDescription)
        }
    }

    private func clearVault() async throws(AuthError) {
        do {
            try await vault.clear()
        } catch {
            throw .storage(error.localizedDescription)
        }
    }

    private func resolveLoginResult(from response: LoginResponse) async throws(AuthError) -> LoginResult {
        if let success = response.success {
            let stored = DiscordSession(
                userID: success.userID,
                authKind: .user,
                token: success.token
            )
            try await storeInVault(stored)
            session = stored
            return .authenticated(success)
        }

        if let challenge = response.mfaChallenge {
            return .challenge(.mfa(challenge))
        }

        throw .missingToken
    }

    private func decodeCaptchaChallenge(from error: DiscordHTTPError) -> CaptchaChallenge? {
        guard case let .badStatus(statusCode, data) = error, statusCode == 400 else {
            return nil
        }

        return try? HTTPRuntime.makeDecoder().decode(CaptchaChallenge.self, from: data)
    }

    private func executeHTTP<Response>(
        _ request: DiscordRequest<Response>
    ) async -> Result<Response, DiscordHTTPError> where Response: Decodable & Sendable {
        do {
            return .success(try await http.execute(request).value)
        } catch {
            return .failure(error)
        }
    }
}
