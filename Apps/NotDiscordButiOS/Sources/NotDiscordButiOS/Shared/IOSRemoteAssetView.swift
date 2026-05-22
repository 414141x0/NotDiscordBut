import CryptoKit
import DiscordKit
import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

enum RemoteAssetKind: Hashable, Sendable {
    case avatar
    case guildIcon
    case banner
    case customEmoji
    case inlineMedia
    case focusedMedia
    case linkPreview

    var timeToLive: TimeInterval {
        switch self {
        case .avatar, .guildIcon:
            60 * 60 * 24 * 3
        case .banner:
            60 * 60 * 24
        case .customEmoji:
            60 * 60 * 24 * 7
        case .inlineMedia, .focusedMedia:
            60 * 60 * 12
        case .linkPreview:
            60 * 60 * 6
        }
    }
}

enum RemoteAssetScalingMode: Hashable, Sendable {
    case fit
    case fill
}

struct RemoteAssetView<Placeholder: View>: View {
    let url: URL?
    var kind: RemoteAssetKind = .inlineMedia
    var scalingMode: RemoteAssetScalingMode = .fit

    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: PlatformImage?

    var body: some View {
        if let url {
            ZStack {
                placeholder()
                if let image {
                    platformImage(image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: scalingMode == .fill ? .fill : .fit)
                }
            }
            .task(id: url) {
                image = nil
                image = await loadImage(from: url, kind: kind)
            }
        } else {
            placeholder()
        }
    }

    private func platformImage(_ image: PlatformImage) -> Image {
        #if canImport(UIKit)
        Image(uiImage: image)
        #else
        Image(nsImage: image)
        #endif
    }

    private func loadImage(from url: URL, kind: RemoteAssetKind) async -> PlatformImage? {
        if let cachedData = await RemoteAssetCache.shared.data(for: url, kind: kind) {
            return PlatformImage(data: cachedData)
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            await RemoteAssetCache.shared.insert(data, for: url, kind: kind)
            return PlatformImage(data: data)
        } catch {
            return nil
        }
    }
}

actor RemoteAssetCache {
    private struct MemoryEntry: Sendable {
        var data: Data
        var expiryDate: Date
        var lastAccessDate: Date
    }

    private struct DiskEntry: Codable, Sendable {
        var expiryDate: Date
        var data: Data
    }

    static let shared = RemoteAssetCache()

    private let directoryURL: URL
    private let now: @Sendable () -> Date
    private let maxMemoryBytes = 64 * 1_024 * 1_024
    private var entries = [URL: MemoryEntry]()
    private var totalMemoryBytes = 0

    init(
        directoryURL: URL? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            self.directoryURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appending(path: "NotDiscordBut")
                .appending(path: "RemoteAssets")
        }
        self.now = now
    }

    func data(for url: URL, kind: RemoteAssetKind) -> Data? {
        let currentDate = now()

        if let entry = entries[url] {
            guard entry.expiryDate > currentDate else {
                removeMemoryEntry(for: url)
                deleteDiskEntry(for: url)
                return nil
            }
            entries[url]?.lastAccessDate = currentDate
            return entry.data
        }

        let diskURL = fileURL(for: url)
        guard let data = try? Data(contentsOf: diskURL),
              let entry = try? PropertyListDecoder().decode(DiskEntry.self, from: data) else {
            return nil
        }

        guard entry.expiryDate > currentDate else {
            try? FileManager.default.removeItem(at: diskURL)
            return nil
        }

        setMemoryEntry(entry.data, for: url, expiryDate: entry.expiryDate, accessedAt: currentDate)
        trimMemoryIfNeeded()
        return entry.data
    }

    func insert(_ data: Data, for url: URL, kind: RemoteAssetKind) {
        let currentDate = now()
        let expiryDate = currentDate.addingTimeInterval(kind.timeToLive)
        setMemoryEntry(data, for: url, expiryDate: expiryDate, accessedAt: currentDate)
        trimMemoryIfNeeded()

        let entry = DiskEntry(expiryDate: expiryDate, data: data)
        if let encoded = try? PropertyListEncoder().encode(entry) {
            try? FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try? encoded.write(to: fileURL(for: url), options: .atomic)
        }
    }

    func clear() {
        entries.removeAll()
        totalMemoryBytes = 0
        try? FileManager.default.removeItem(at: directoryURL)
    }

    private func setMemoryEntry(_ data: Data, for url: URL, expiryDate: Date, accessedAt: Date) {
        if let existing = entries[url] {
            totalMemoryBytes -= existing.data.count
        }
        entries[url] = MemoryEntry(data: data, expiryDate: expiryDate, lastAccessDate: accessedAt)
        totalMemoryBytes += data.count
    }

    private func removeMemoryEntry(for url: URL) {
        if let existing = entries.removeValue(forKey: url) {
            totalMemoryBytes -= existing.data.count
        }
    }

    private func trimMemoryIfNeeded() {
        guard totalMemoryBytes > maxMemoryBytes else {
            return
        }

        let orderedKeys = entries.keys.sorted { lhs, rhs in
            entries[lhs]?.lastAccessDate ?? .distantPast < entries[rhs]?.lastAccessDate ?? .distantPast
        }

        for url in orderedKeys where totalMemoryBytes > maxMemoryBytes {
            removeMemoryEntry(for: url)
        }
    }

    private func deleteDiskEntry(for url: URL) {
        try? FileManager.default.removeItem(at: fileURL(for: url))
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directoryURL.appending(path: digest).appendingPathExtension("plist")
    }
}

enum DiscordCDN {
    static func userAvatarURL(for user: DiscordUser, size: Int) -> URL? {
        if let avatarHash = user.avatarHash {
            return assetURL(path: "avatars/\(user.id.rawValue)", hash: avatarHash, size: size)
        }

        guard let fallbackIndex = defaultAvatarIndex(for: user) else {
            return nil
        }
        return URL(string: "https://cdn.discordapp.com/embed/avatars/\(fallbackIndex).png?size=\(supportedSize(for: size))")
    }

    static func userBannerURL(userID: UserID, bannerHash: String?, size: Int) -> URL? {
        guard let bannerHash else {
            return nil
        }
        return assetURL(path: "banners/\(userID.rawValue)", hash: bannerHash, size: size)
    }

    static func guildIconURL(for guild: DiscordGuild, size: Int) -> URL? {
        guard let iconHash = guild.iconHash else {
            return nil
        }
        return assetURL(path: "icons/\(guild.id.rawValue)", hash: iconHash, size: size)
    }

    static func guildBannerURL(for guild: DiscordGuild, size: Int) -> URL? {
        guard let bannerHash = guild.bannerHash else {
            return nil
        }
        return assetURL(path: "banners/\(guild.id.rawValue)", hash: bannerHash, size: size)
    }

    private static func assetURL(path: String, hash: String, size: Int) -> URL? {
        let format = hash.hasPrefix("a_") ? "gif" : "png"
        return URL(string: "https://cdn.discordapp.com/\(path)/\(hash).\(format)?size=\(supportedSize(for: size))")
    }

    private static func supportedSize(for requestedSize: Int) -> Int {
        let clamped = min(max(requestedSize, 16), 4_096)
        let rounded = clamped.nextPowerOfTwo
        return min(max(rounded, 16), 4_096)
    }

    private static func defaultAvatarIndex(for user: DiscordUser) -> Int? {
        if user.discriminator == "0" {
            guard let rawID = UInt64(user.id.rawValue) else {
                return nil
            }
            return Int((rawID >> 22) % 6)
        }

        guard let discriminator = Int(user.discriminator) else {
            return nil
        }
        return discriminator % 5
    }
}

extension Color {
    init(discordAccent accentColor: Int?) {
        guard let accentColor else {
            self = .accentColor
            return
        }

        let red = Double((accentColor >> 16) & 0xFF) / 255
        let green = Double((accentColor >> 8) & 0xFF) / 255
        let blue = Double(accentColor & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }
}

private extension DiscordUser {
    var displayNameInitial: String {
        String(displayName.prefix(1)).uppercased()
    }
}

private extension DiscordGuild {
    var nameInitial: String {
        String(name.prefix(1)).uppercased()
    }
}

private extension Int {
    var nextPowerOfTwo: Int {
        var value = 1
        while value < self {
            value <<= 1
        }
        return value
    }
}
