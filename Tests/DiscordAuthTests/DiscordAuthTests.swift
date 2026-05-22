import Foundation
import Testing
@testable import DiscordAuth
import DiscordHTTP
import DiscordPrimitives

@Test
func loginResultDecodesMFABranch() throws {
    let data = """
    {
      "user_id": "852892297661906993",
      "mfa": true,
      "sms": true,
      "ticket": "ticket-value",
      "login_instance_id": "instance-id",
      "backup": true,
      "totp": true
    }
    """.data(using: .utf8)!

    let result = try makeRuntimeDecoder().decode(LoginResponse.self, from: data)

    #expect(result.mfa == true)
    #expect(result.ticket == "ticket-value")
    #expect(result.loginInstanceID == "instance-id")
}

@Test
func loginResultDecodesCompletedBranchWithDefaultFlags() throws {
    let data = """
    {
      "user_id": "852892297661906993",
      "token": "token-value",
      "user_settings": {
        "locale": "en-US",
        "theme": "midnight"
      },
      "required_actions": ["update_password"]
    }
    """.data(using: .utf8)!

    let result = try makeRuntimeDecoder().decode(LoginResponse.self, from: data)

    #expect(result.userID == UserID(rawValue: "852892297661906993"))
    #expect(result.token == "token-value")
    #expect(result.mfa == false)
    #expect(result.totp == false)
    #expect(result.sms == false)
    #expect(result.backup == false)
    #expect(result.requiredActions == ["update_password"])
    #expect(result.userSettings?.locale == "en-US")
    #expect(result.userSettings?.theme == "midnight")
}

@Test
func passwordlessStartResponseDecodesChallengeField() throws {
    let data = """
    {
      "challenge": "{\\"publicKey\\":{\\"challenge\\":\\"abc\\"}}",
      "ticket": "b9f98b82-c3a7-49b6-b881-f83418fa2dbe"
    }
    """.data(using: .utf8)!

    let result = try makeRuntimeDecoder().decode(PasswordlessStartResponse.self, from: data)

    #expect(result.ticket == "b9f98b82-c3a7-49b6-b881-f83418fa2dbe")
    #expect(result.webauthn == "{\"publicKey\":{\"challenge\":\"abc\"}}")
}

@Test
func authRuntimeLoginReturnsMFAChallenge() async throws {
    let transport = StubDiscordTransport(
        statusCode: 200,
        body: """
        {
          "user_id": "852892297661906993",
          "mfa": true,
          "sms": true,
          "ticket": "ticket-value",
          "login_instance_id": "instance-id",
          "backup": true,
          "totp": true,
          "webauthn": "{\\"publicKey\\":{\\"challenge\\":\\"abc\\"}}"
        }
        """
    )
    let runtime = AuthRuntime(
        http: HTTPRuntime(
            transport: transport,
            configuration: DiscordHTTPConfiguration(baseURL: URL(string: "https://discord.com/api")!)
        ),
        vault: TestSessionVault()
    )

    let result = try await runtime.login(credentials: LoginCredentials(login: "user@example.com", password: "password"))

    switch result {
    case let .challenge(.mfa(challenge)):
        #expect(challenge.userID == UserID(rawValue: "852892297661906993"))
        #expect(challenge.ticket == "ticket-value")
        #expect(challenge.loginInstanceID == "instance-id")
        #expect(challenge.authenticators.contains(.totp))
        #expect(challenge.authenticators.contains(.sms))
        #expect(challenge.authenticators.contains(.backup))
        #expect(challenge.authenticators.contains(.webauthn))
    default:
        Issue.record("Expected MFA challenge result")
    }
}

@Test
func authRuntimeLoginReturnsCaptchaChallenge() async throws {
    let transport = StubDiscordTransport(
        statusCode: 400,
        body: """
        {
          "captcha_key": ["invalid-input-response"],
          "captcha_sitekey": "dynamic-site-key",
          "captcha_service": "hcaptcha",
          "captcha_session_id": "session-id",
          "captcha_rqtoken": "request-token"
        }
        """
    )
    let runtime = AuthRuntime(
        http: HTTPRuntime(
            transport: transport,
            configuration: DiscordHTTPConfiguration(baseURL: URL(string: "https://discord.com/api")!)
        ),
        vault: TestSessionVault()
    )

    let result = try await runtime.login(credentials: LoginCredentials(login: "user@example.com", password: "password"))

    switch result {
    case let .challenge(.captcha(challenge)):
        #expect(challenge.service == .hcaptcha)
        #expect(challenge.siteKey == "dynamic-site-key")
        #expect(challenge.sessionID == "session-id")
        #expect(challenge.requestToken == "request-token")
    default:
        Issue.record("Expected captcha challenge result")
    }
}

@Test
func mfaChallengePrefersCodeBasedAuthenticatorBeforeWebAuthn() {
    let challenge = MFALoginChallenge(
        userID: UserID(rawValue: "852892297661906993"),
        ticket: SessionTicket(rawValue: "ticket-value"),
        authenticators: [.webauthn, .backup, .totp]
    )

    #expect(challenge.recommendedAuthenticator == .totp)
}

@Test
func mfaChallengeFallsBackToWebAuthnWhenItIsTheOnlyAuthenticator() {
    let challenge = MFALoginChallenge(
        userID: UserID(rawValue: "852892297661906993"),
        ticket: SessionTicket(rawValue: "ticket-value"),
        authenticators: [.webauthn]
    )

    #expect(challenge.recommendedAuthenticator == .webauthn)
}

@Test
func importedUserTokenIsStoredAsCurrentSession() async throws {
    let runtime = AuthRuntime(
        http: HTTPRuntime(
            transport: StubDiscordTransport(
                statusCode: 200,
                body: #"{"token":"unused"}"#
            ),
            configuration: DiscordHTTPConfiguration(baseURL: URL(string: "https://discord.com/api")!)
        ),
        vault: TestSessionVault()
    )

    let session = try await runtime.importUserToken(#""imported-token""#, userID: UserID(rawValue: "852892297661906993"))

    #expect(session.token == "imported-token")
    #expect(session.userID == UserID(rawValue: "852892297661906993"))
    #expect(await runtime.currentSession()?.token == "imported-token")
}

private func makeRuntimeDecoder() -> JSONDecoder {
    DiscordHTTP.HTTPRuntime.makeDecoder()
}

private actor StubDiscordTransport: DiscordTransport {
    let statusCode: Int
    let body: String

    init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    func send<Response>(
        _ request: DiscordRequest<Response>,
        baseURL: URL,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        defaultHeaders: [String: String]
    ) async throws(DiscordHTTPError) -> DiscordResponse<Response> where Response: Decodable & Sendable {
        let data = Data(body.utf8)
        guard (200..<300).contains(statusCode) else {
            throw .badStatus(statusCode, data)
        }

        do {
            let value = try decoder.decode(Response.self, from: data)
            return DiscordResponse(statusCode: statusCode, headers: [:], value: value)
        } catch {
            throw .decodingFailed(error.localizedDescription)
        }
    }
}

private actor TestSessionVault: SessionVault {
    private var session: DiscordSession?

    func load() async throws -> DiscordSession? {
        session
    }

    func store(_ session: DiscordSession) async throws {
        self.session = session
    }

    func clear() async throws {
        session = nil
    }
}
