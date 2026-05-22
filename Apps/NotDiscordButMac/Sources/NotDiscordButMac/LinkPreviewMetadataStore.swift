import CryptoKit
import Foundation

struct LinkPreviewMetadata: Codable, Hashable, Sendable {
    var sourceURL: URL
    var canonicalURL: URL?
    var title: String?
    var summary: String?
    var siteName: String?
    var imageURL: URL?
    var videoURL: URL?
}

actor LinkPreviewMetadataStore {
    private struct MemoryEntry: Sendable {
        var metadata: LinkPreviewMetadata
        var expiryDate: Date
        var lastAccessDate: Date
    }

    private struct DiskEntry: Codable, Sendable {
        var expiryDate: Date
        var metadata: LinkPreviewMetadata
    }

    static let shared = LinkPreviewMetadataStore()

    private let directoryURL: URL
    private let now: @Sendable () -> Date
    private var entries = [URL: MemoryEntry]()
    private var inFlight = [URL: Task<LinkPreviewMetadata?, Never>]()
    private let timeToLive: TimeInterval = 60 * 60 * 12
    private let maxMemoryEntries = 256

    init(
        directoryURL: URL? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.now = now
        let baseURL =
            directoryURL ??
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "NotDiscordBut")
                .appending(path: "LinkPreviewMetadata")
        self.directoryURL = baseURL
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func metadata(for url: URL) async -> LinkPreviewMetadata? {
        let normalizedURL = normalized(url)
        let currentDate = now()

        if var entry = entries[normalizedURL], entry.expiryDate > currentDate {
            entry.lastAccessDate = currentDate
            entries[normalizedURL] = entry
            return entry.metadata
        }

        if let diskEntry = loadDiskEntry(for: normalizedURL), diskEntry.expiryDate > currentDate {
            entries[normalizedURL] = MemoryEntry(
                metadata: diskEntry.metadata,
                expiryDate: diskEntry.expiryDate,
                lastAccessDate: currentDate
            )
            trimMemoryEntriesIfNeeded()
            return diskEntry.metadata
        }

        if let task = inFlight[normalizedURL] {
            return await task.value
        }

        let task = Task<LinkPreviewMetadata?, Never> {
            let metadata = await fetchMetadata(for: normalizedURL)
            finishInFlightTask(for: normalizedURL)
            return metadata
        }

        inFlight[normalizedURL] = task
        return await task.value
    }

    func clear() {
        entries.removeAll()
        inFlight.removeAll()
        try? FileManager.default.removeItem(at: directoryURL)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func finishInFlightTask(for url: URL) {
        inFlight.removeValue(forKey: url)
    }

    private func fetchMetadata(for url: URL) async -> LinkPreviewMetadata? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let responseURL = response.url else {
                return nil
            }
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }

            let metadata = LinkPreviewMetadataDocument.parse(
                html: html,
                sourceURL: url,
                responseURL: responseURL
            )
            store(metadata, for: url)
            return metadata
        } catch {
            return nil
        }
    }

    private func store(_ metadata: LinkPreviewMetadata, for url: URL) {
        let expiryDate = now().addingTimeInterval(timeToLive)
        entries[url] = MemoryEntry(
            metadata: metadata,
            expiryDate: expiryDate,
            lastAccessDate: now()
        )
        trimMemoryEntriesIfNeeded()

        let diskEntry = DiskEntry(expiryDate: expiryDate, metadata: metadata)
        if let encoded = try? PropertyListEncoder().encode(diskEntry) {
            try? encoded.write(to: fileURL(for: url), options: .atomic)
        }
    }

    private func loadDiskEntry(for url: URL) -> DiskEntry? {
        let fileURL = fileURL(for: url)
        guard
            let data = try? Data(contentsOf: fileURL),
            let entry = try? PropertyListDecoder().decode(DiskEntry.self, from: data)
        else {
            return nil
        }
        return entry
    }

    private func trimMemoryEntriesIfNeeded() {
        guard entries.count > maxMemoryEntries else {
            return
        }

        let sortedKeys = entries.keys.sorted {
            let lhs = entries[$0]?.lastAccessDate ?? .distantPast
            let rhs = entries[$1]?.lastAccessDate ?? .distantPast
            return lhs < rhs
        }

        let overflow = entries.count - maxMemoryEntries
        for key in sortedKeys.prefix(overflow) {
            entries.removeValue(forKey: key)
        }
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256Digest.hexDigest(for: url.absoluteString)
        return directoryURL.appending(path: digest).appendingPathExtension("plist")
    }

    private func normalized(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return url
        }
        if components.scheme == nil {
            components.scheme = "https"
        }
        return components.url ?? url
    }
}

enum LinkPreviewMetadataDocument {
    static func parse(
        html: String,
        sourceURL: URL,
        responseURL: URL
    ) -> LinkPreviewMetadata {
        let tags = metaTags(in: html)
        let baseURL = responseURL

        var title = firstNonEmpty([
            tags["og:title"],
            tags["twitter:title"],
            pageTitle(in: html)
        ])
        var summary = firstNonEmpty([
            tags["og:description"],
            tags["twitter:description"],
            tags["description"]
        ])
        let siteName = firstNonEmpty([
            tags["og:site_name"],
            tags["twitter:site"],
            tags["application-name"],
            responseURL.host
        ])

        let imageURL = resolvedURL(
            from: firstNonEmpty([
                tags["og:image"],
                tags["twitter:image"],
                tags["twitter:image:src"]
            ]),
            relativeTo: baseURL
        )
        let videoURL = resolvedURL(
            from: firstNonEmpty([
                tags["og:video:url"],
                tags["og:video:secure_url"],
                tags["twitter:player:stream"],
                tags["og:video"]
            ]),
            relativeTo: baseURL
        )

        title = normalizedText(title)
        summary = normalizedText(summary)

        return LinkPreviewMetadata(
            sourceURL: sourceURL,
            canonicalURL: canonicalURL(in: html, responseURL: responseURL),
            title: title,
            summary: summary,
            siteName: normalizedText(siteName),
            imageURL: imageURL,
            videoURL: videoURL
        )
    }

    private static func pageTitle(in html: String) -> String? {
        capture(
            in: html,
            pattern: #"<title[^>]*>(.*?)</title>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
    }

    private static func metaTags(in html: String) -> [String: String] {
        guard let expression = try? NSRegularExpression(
            pattern: #"<meta\b[^>]*>"#,
            options: [.caseInsensitive]
        ) else {
            return [:]
        }

        let source = html as NSString
        let matches = expression.matches(in: html, range: NSRange(location: 0, length: source.length))

        var tags = [String: String]()
        for match in matches {
            let tag = source.substring(with: match.range)
            let attributes = attributes(in: tag)
            guard let content = attributes["content"], !content.isEmpty else {
                continue
            }

            if let property = attributes["property"]?.lowercased() {
                tags[property] = content
            }
            if let name = attributes["name"]?.lowercased() {
                tags[name] = content
            }
        }
        return tags
    }

    private static func canonicalURL(in html: String, responseURL: URL) -> URL? {
        guard let expression = try? NSRegularExpression(
            pattern: #"<link\b[^>]*rel=["']canonical["'][^>]*href=["']([^"']+)["'][^>]*>"#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let source = html as NSString
        guard
            let match = expression.firstMatch(in: html, range: NSRange(location: 0, length: source.length)),
            match.numberOfRanges > 1
        else {
            return responseURL
        }

        let href = source.substring(with: match.range(at: 1))
        return resolvedURL(from: href, relativeTo: responseURL) ?? responseURL
    }

    private static func attributes(in tag: String) -> [String: String] {
        guard let expression = try? NSRegularExpression(
            pattern: #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*["']([^"']*)["']"#,
            options: []
        ) else {
            return [:]
        }

        let source = tag as NSString
        let matches = expression.matches(in: tag, range: NSRange(location: 0, length: source.length))

        var attributes = [String: String]()
        for match in matches where match.numberOfRanges > 2 {
            let name = source.substring(with: match.range(at: 1)).lowercased()
            let value = source.substring(with: match.range(at: 2))
            attributes[name] = value
        }
        return attributes
    }

    private static func capture(
        in source: String,
        pattern: String,
        options: NSRegularExpression.Options
    ) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }

        let string = source as NSString
        guard
            let match = expression.firstMatch(in: source, range: NSRange(location: 0, length: string.length)),
            match.numberOfRanges > 1
        else {
            return nil
        }

        return string.substring(with: match.range(at: 1))
    }

    private static func resolvedURL(from value: String?, relativeTo baseURL: URL) -> URL? {
        guard let value = normalizedText(value) else {
            return nil
        }
        if let direct = URL(string: value), direct.scheme != nil {
            return direct
        }
        return URL(string: value, relativeTo: baseURL)?.absoluteURL
    }

    private static func firstNonEmpty(_ candidates: [String?]) -> String? {
        candidates.first { normalizedText($0) != nil } ?? nil
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let decoded = decodeHTMLEntities(in: value)
        let squashedWhitespace = decoded
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return squashedWhitespace.isEmpty ? nil : squashedWhitespace
    }

    private static func decodeHTMLEntities(in value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}

private enum SHA256Digest {
    static func hexDigest(for value: String) -> String {
        return SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
