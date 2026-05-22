import Foundation

public enum CaptchaService: String, Codable, Sendable, Hashable {
    case hcaptcha
    case recaptcha
    case recaptchaEnterprise = "recaptcha_enterprise"
}

public struct CaptchaChallenge: Codable, Sendable, Hashable {
    public var service: CaptchaService
    public var siteKey: String?
    public var sessionID: String?
    public var requestToken: String?
    public var requestData: String?
    public var shouldServeInvisible: Bool
    public var errors: [String]

    public init(
        service: CaptchaService,
        siteKey: String?,
        sessionID: String?,
        requestToken: String?,
        requestData: String?,
        shouldServeInvisible: Bool,
        errors: [String]
    ) {
        self.service = service
        self.siteKey = siteKey
        self.sessionID = sessionID
        self.requestToken = requestToken
        self.requestData = requestData
        self.shouldServeInvisible = shouldServeInvisible
        self.errors = errors
    }

    public func retryHeaders(solution: String) -> [String: String] {
        var headers = ["X-Captcha-Key": solution]

        if let sessionID {
            headers["X-Captcha-Session-Id"] = sessionID
        }

        if let requestToken {
            headers["X-Captcha-Rqtoken"] = requestToken
        }

        return headers
    }

    public func answer(_ solution: String) -> CaptchaAnswer {
        CaptchaAnswer(
            solution: solution,
            sessionID: sessionID,
            requestToken: requestToken
        )
    }
}

public struct CaptchaAnswer: Sendable, Hashable {
    public var solution: String
    public var sessionID: String?
    public var requestToken: String?

    public init(solution: String, sessionID: String? = nil, requestToken: String? = nil) {
        self.solution = solution
        self.sessionID = sessionID
        self.requestToken = requestToken
    }

    public var retryHeaders: [String: String] {
        var headers = ["X-Captcha-Key": solution]

        if let sessionID {
            headers["X-Captcha-Session-Id"] = sessionID
        }

        if let requestToken {
            headers["X-Captcha-Rqtoken"] = requestToken
        }

        return headers
    }
}

extension CaptchaChallenge {
    enum CodingKeys: String, CodingKey {
        case errors = "captchaKey"
        case service = "captchaService"
        case siteKey = "captchaSitekey"
        case sessionID = "captchaSessionId"
        case requestData = "captchaRqdata"
        case requestToken = "captchaRqtoken"
        case shouldServeInvisible = "shouldServeInvisible"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        service = try container.decode(CaptchaService.self, forKey: .service)
        siteKey = try container.decodeIfPresent(String.self, forKey: .siteKey)
        sessionID = try container.decodeIfPresent(String.self, forKey: .sessionID)
        requestToken = try container.decodeIfPresent(String.self, forKey: .requestToken)
        requestData = try container.decodeIfPresent(String.self, forKey: .requestData)
        shouldServeInvisible = try container.decodeIfPresent(Bool.self, forKey: .shouldServeInvisible) ?? false
        errors = try container.decodeIfPresent([String].self, forKey: .errors) ?? []
    }
}
