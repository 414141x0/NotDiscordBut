import Foundation
import Testing
@testable import DiscordHTTP
import DiscordPrimitives

@Test
func authorizationHeaderValuesMatchDiscordConventions() {
    #expect(DiscordAuthorization.user("user-token").headerValue == "user-token")
    #expect(DiscordAuthorization.bearer("bearer-token").headerValue == "Bearer bearer-token")
}

@Test
func requestBuildIncludesCaptchaRetryHeaders() throws {
    let challenge = CaptchaChallenge(
        service: .hcaptcha,
        siteKey: "dynamic-site-key",
        sessionID: "session-id",
        requestToken: "request-token",
        requestData: nil,
        shouldServeInvisible: false,
        errors: ["invalid-input-response"]
    )

    let headers = challenge.retryHeaders(solution: "captcha-solution")

    #expect(headers["X-Captcha-Key"] == "captcha-solution")
    #expect(headers["X-Captcha-Session-Id"] == "session-id")
    #expect(headers["X-Captcha-Rqtoken"] == "request-token")
}

@Test
func decodingFailureSummaryRedactsSensitiveValuesAndShowsKeys() {
    let error = NSError(domain: "DiscordHTTPTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "The data couldn’t be read because it is missing."])
    let data = """
    {
      "token": "super-secret-token",
      "user_settings": {
        "locale": "en-US"
      },
      "required_actions": ["update_password"]
    }
    """.data(using: .utf8)!

    let summary = HTTPResponseDebugSummary.decodingFailureDescription(for: data, underlyingError: error)

    #expect(summary.contains("The data couldn’t be read because it is missing."))
    #expect(summary.contains("token"))
    #expect(summary.contains("required_actions"))
    #expect(summary.contains("user_settings"))
    #expect(!summary.contains("super-secret-token"))
}

@Test
func captchaChallengeDecodesRuntimePayloadKeys() throws {
    let data = """
    {
      "captcha_key": ["invalid-input-response"],
      "captcha_service": "hcaptcha",
      "captcha_sitekey": "dynamic-site-key",
      "captcha_session_id": "session-id",
      "captcha_rqdata": "request-data",
      "captcha_rqtoken": "request-token",
      "should_serve_invisible": true
    }
    """.data(using: .utf8)!

    let challenge = try HTTPRuntime.makeDecoder().decode(CaptchaChallenge.self, from: data)

    #expect(challenge.service == .hcaptcha)
    #expect(challenge.siteKey == "dynamic-site-key")
    #expect(challenge.sessionID == "session-id")
    #expect(challenge.requestData == "request-data")
    #expect(challenge.requestToken == "request-token")
    #expect(challenge.shouldServeInvisible == true)
    #expect(challenge.errors == ["invalid-input-response"])
}

@Test
func badStatusReportsDecodedDiscordServiceMessage() {
    let data = #"{"message": "Invalid two-factor code", "code": 60008}"#.data(using: .utf8)!
    let error = DiscordHTTPError.badStatus(400, data)

    #expect(error.errorDescription == "Discord rejected the request with HTTP 400: Invalid two-factor code (Discord code 60008)")
}

@Test
func badStatusIncludesNestedValidationFieldErrors() {
    let data = """
    {
      "message": "Invalid Form Body",
      "code": 50035,
      "errors": {
        "nonce": {
          "_errors": [
            {
              "code": "BASE_TYPE_BAD_LENGTH",
              "message": "Must be between 1 and 25 in length."
            }
          ]
        }
      }
    }
    """.data(using: .utf8)!
    let error = DiscordHTTPError.badStatus(400, data)

    #expect(
        error.errorDescription ==
        "Discord rejected the request with HTTP 400: Invalid Form Body (Discord code 50035): nonce: Must be between 1 and 25 in length."
    )
}

@Test
func userSessionRequestsIncludeDiscordLikeBrowserHeaders() throws {
    var request = DiscordRequest<VoidResponse>(
        method: .post,
        path: "/channels/42/messages",
        authorization: .user("user-token")
    )
    request.headers = DiscordUserSessionRequestProfile.headers(referer: "https://discord.com/channels/@me")

    let urlRequest = try request.makeURLRequest(
        baseURL: URL(string: "https://discord.com/api/v9")!,
        encoder: HTTPRuntime.makeEncoder(),
        defaultHeaders: ["Accept": "application/json"]
    )

    #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "user-token")
    #expect(urlRequest.value(forHTTPHeaderField: "Origin") == "https://discord.com")
    #expect(urlRequest.value(forHTTPHeaderField: "Referer") == "https://discord.com/channels/@me")
    #expect(urlRequest.value(forHTTPHeaderField: "X-Super-Properties") != nil)
    #expect(urlRequest.value(forHTTPHeaderField: "User-Agent") != nil)
}
