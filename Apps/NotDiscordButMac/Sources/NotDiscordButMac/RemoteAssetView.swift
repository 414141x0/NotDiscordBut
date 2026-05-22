import AppKit
import CryptoKit
import DiscordKit
import SwiftUI

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

enum RemoteAssetAnimationPolicy: Hashable, Sendable {
    case never
    case always
    case onHover
}

enum RemoteAssetScalingMode: Hashable, Sendable {
    case fit
    case fill
}

struct DiscordAvatarView: View {
    let user: DiscordUser
    var size: CGFloat = 40

    @State
    private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)

        RemoteAssetView(
            url: DiscordCDN.userAvatarURL(for: user, size: Int(size * 3)),
            contentInset: 0,
            kind: .avatar,
            animationPolicy: .onHover,
            scalingMode: .fit,
            isAnimating: hovered
        ) {
            shape
                .fill(Color(discordAccent: user.accentColor).opacity(0.24))
                .overlay {
                    Text(user.displayNameInitial)
                        .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(discordAccent: user.accentColor))
                }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay {
            shape
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .accessibilityLabel(user.displayName)
        .onHover { inside in
            hovered = inside
        }
    }
}

struct DiscordGuildIconView: View {
    let guild: DiscordGuild
    var size: CGFloat = 44

    @State
    private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)

        RemoteAssetView(
            url: DiscordCDN.guildIconURL(for: guild, size: Int(size * 3)),
            contentInset: 0,
            kind: .guildIcon,
            animationPolicy: .onHover,
            scalingMode: .fit,
            isAnimating: hovered
        ) {
            shape
                .fill(.quaternary)
                .overlay {
                    Text(guild.nameInitial)
                        .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay {
            shape
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .accessibilityLabel(guild.name)
        .onHover { inside in
            hovered = inside
        }
    }
}

struct DiscordBannerView: View {
    let url: URL?
    var height: CGFloat = 144
    var accentColor: Color = .accentColor

    var body: some View {
        RemoteAssetView(
            url: url,
            kind: .banner,
            scalingMode: .fill
        ) {
            LinearGradient(
                colors: [accentColor.opacity(0.9), accentColor.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct RemoteAssetView<Placeholder: View>: View {
    let url: URL?
    var contentInset: CGFloat = 0
    var kind: RemoteAssetKind = .inlineMedia
    var animationPolicy: RemoteAssetAnimationPolicy = .never
    var scalingMode: RemoteAssetScalingMode = .fit
    var showsBackground = true
    var isAnimating = false
    @ViewBuilder let placeholder: () -> Placeholder

    var body: some View {
        if let url {
            ZStack {
                placeholder()
                AnimatedRemoteImageView(
                    url: url,
                    kind: kind,
                    scalingMode: scalingMode,
                    animates: resolvedAnimation
                )
                .padding(contentInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
            .background(showsBackground ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
        } else {
            placeholder()
        }
    }

    private var resolvedAnimation: Bool {
        switch animationPolicy {
        case .never:
            false
        case .always:
            true
        case .onHover:
            isAnimating
        }
    }
}

private struct AnimatedRemoteImageView: NSViewRepresentable {
    let url: URL
    let kind: RemoteAssetKind
    let scalingMode: RemoteAssetScalingMode
    let animates: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        if scalingMode == .fill {
            let view = AspectFillLayerView()
            return view
        } else {
            let imageView = ConstrainedAnimatedImageView()
            imageView.animates = animates
            imageView.imageScaling = .scaleProportionallyDown
            imageView.imageAlignment = .alignCenter
            imageView.canDrawSubviewsIntoLayer = true
            imageView.wantsLayer = true
            imageView.layer?.masksToBounds = true
            return imageView
        }
    }

    func updateNSView(_ view: NSView, context: Context) {
        if let imageView = view as? NSImageView {
            imageView.animates = animates
            imageView.imageScaling = .scaleProportionallyDown
        }
        context.coordinator.load(url: url, kind: kind, scalingMode: scalingMode, into: view)
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        coordinator.cancel()
    }

    @MainActor
    final class Coordinator {
        private var task: Task<Void, Never>?
        private var currentURL: URL?

        func load(url: URL, kind: RemoteAssetKind, scalingMode: RemoteAssetScalingMode, into view: NSView) {
            guard currentURL != url else {
                return
            }

            currentURL = url
            task?.cancel()

            if let imageView = view as? NSImageView {
                imageView.image = nil
            } else if let fillView = view as? AspectFillLayerView {
                fillView.image = nil
            }

            task = Task {
                let data: Data
                if let cachedData = await RemoteAssetCache.shared.data(for: url, kind: kind) {
                    data = cachedData
                } else {
                    do {
                        let (loadedData, _) = try await URLSession.shared.data(from: url)
                        await RemoteAssetCache.shared.insert(loadedData, for: url, kind: kind)
                        data = loadedData
                    } catch {
                        return
                    }
                }

                guard !Task.isCancelled, let image = NSImage(data: data) else {
                    return
                }

                await MainActor.run {
                    if let imageView = view as? NSImageView {
                        imageView.image = image
                    } else if let fillView = view as? AspectFillLayerView {
                        fillView.image = image
                    }
                }
            }
        }

        func cancel() {
            task?.cancel()
        }
    }
}

private final class ConstrainedAnimatedImageView: NSImageView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override var fittingSize: NSSize {
        .zero
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
}

private final class AspectFillLayerView: NSView {
    var image: NSImage? {
        didSet {
            layer?.contents = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.contentsGravity = .resizeAspectFill
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
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

        entries[url] = MemoryEntry(
            data: data,
            expiryDate: expiryDate,
            lastAccessDate: accessedAt
        )
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
