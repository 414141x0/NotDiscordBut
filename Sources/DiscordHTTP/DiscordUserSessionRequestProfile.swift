import Foundation

public enum DiscordUserSessionRequestProfile {
    public static func headers(referer: String? = nil) -> [String: String] {
        var headers = [
            "Accept-Language": "\(locale),en;q=0.9",
            "Origin": "https://discord.com",
            "User-Agent": browserUserAgent,
            "X-Super-Properties": superProperties
        ]
        if let referer {
            headers["Referer"] = referer
        }
        return headers
    }

    static let locale = Locale.autoupdatingCurrent.identifier.replacingOccurrences(of: "_", with: "-")

    static var superProperties: String {
        let payload: [String: Any] = [
            "os": "Mac OS X",
            "browser": "Discord Client",
            "release_channel": "stable",
            "client_version": "0.0.275",
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
            "os_arch": architecture,
            "system_locale": locale,
            "client_build_number": 9999,
            "client_event_source": NSNull()
        ]

        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [])) ?? Data()
        return data.base64EncodedString()
    }

    static var browserUserAgent: String {
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) discord/0.0.275 Chrome/128.0.6613.186 Electron/32.2.7 Safari/537.36"
    }

    static var architecture: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }
}
