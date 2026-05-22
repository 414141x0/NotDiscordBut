import AppKit
import Foundation
import Testing
@testable import NotDiscordButMac
import DiscordKit
import SwiftUI

@MainActor
@Test
func selectedConversationRouteTracksFriendAndGuildSelections() {
    let model = AppModel(client: .preview(), launchProfile: .preview)

    model.selectedSource = .friend(UserID(rawValue: "2"))
    #expect(model.secondaryWindowRoute == .directMessage(UserID(rawValue: "2"), nil))

    model.selectedSource = .guild(GuildID(rawValue: "100"))
    model.selectedGuildChannelID = ChannelID(rawValue: "200")
    #expect(model.secondaryWindowRoute == .guild(GuildID(rawValue: "100"), ChannelID(rawValue: "200")))
}

@Test
func discordCDNResolvesSupportedCustomAndDefaultAvatarURLs() {
    let customAvatarUser = DiscordUser(
        id: "474885576336736266",
        username: "batmite.",
        discriminator: "0",
        globalName: "Batmite",
        avatarHash: "778965ff1510e517d09367a4ac5ad36a"
    )
    let defaultAvatarUser = DiscordUser(
        id: "175928847299117063",
        username: "wumpus",
        discriminator: "0"
    )

    let customURL = DiscordCDN.userAvatarURL(for: customAvatarUser, size: 126)
    let defaultURL = DiscordCDN.userAvatarURL(for: defaultAvatarUser, size: 34)

    #expect(customURL?.absoluteString == "https://cdn.discordapp.com/avatars/474885576336736266/778965ff1510e517d09367a4ac5ad36a.png?size=128")
    #expect(defaultURL?.absoluteString == "https://cdn.discordapp.com/embed/avatars/2.png?size=64")
}

@MainActor
@Test
func timelineModelCountsMessagesAcrossClusters() {
    let model = TimelineModel()
    let channel = DiscordChannel(id: "99", kind: .directMessage, name: "Ada")
    let projection = ClusteredTimelineProjection(
        channelID: channel.id,
        clusters: [
            MessageClusterProjection(
                id: "10",
                author: DiscordUser(id: "2", username: "ada", discriminator: "0", globalName: "Ada"),
                profile: nil,
                displayName: "Ada",
                displayAccentColor: nil,
                startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                endedAt: Date(timeIntervalSince1970: 1_700_000_240),
                messages: [
                    ClusteredMessageProjection(
                        id: "10",
                        message: DiscordMessage(
                            id: "10",
                            channelID: channel.id,
                            authorID: "2",
                            content: "First",
                            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
                        ),
                        blocks: [.text(MessageTextBlock(id: "10-text-0", content: AttributedString("First")))]
                    ),
                    ClusteredMessageProjection(
                        id: "11",
                        message: DiscordMessage(
                            id: "11",
                            channelID: channel.id,
                            authorID: "2",
                            content: "Second",
                            timestamp: Date(timeIntervalSince1970: 1_700_000_240)
                        ),
                        blocks: [.text(MessageTextBlock(id: "11-text-0", content: AttributedString("Second")))]
                    )
                ]
            )
        ]
    )

    model.apply(channel: channel, projection: projection)

    #expect(model.displayedClusters.count == 1)
    #expect(model.statusMessage == "Showing 2 messages.")
}

@MainActor
@Test
func profileHoverControllerWaitsBeforePresenting() async {
    let controller = ProfileHoverController(showDelay: .milliseconds(40), hideDelay: .milliseconds(20))

    controller.enterAvatar()
    #expect(controller.isPresented == false)

    try? await Task.sleep(for: .milliseconds(20))
    #expect(controller.isPresented == false)

    try? await Task.sleep(for: .milliseconds(35))
    #expect(controller.isPresented)
}

@MainActor
@Test
func profileHoverControllerCancelsPendingDismissWhenPointerReturns() async {
    let controller = ProfileHoverController(showDelay: .milliseconds(0), hideDelay: .milliseconds(40))

    controller.enterAvatar()
    #expect(controller.isPresented)

    controller.exitAvatar()
    controller.enterCard()

    try? await Task.sleep(for: .milliseconds(60))
    #expect(controller.isPresented)
}

@MainActor
@Test
func profileHoverControllerDefaultsToOneSecondDelay() async {
    let controller = ProfileHoverController()

    controller.enterAvatar()
    try? await Task.sleep(for: .milliseconds(750))
    #expect(controller.isPresented == false)

    try? await Task.sleep(for: .milliseconds(350))
    #expect(controller.isPresented)
}

@MainActor
@Test
func appModelTracksRecentSelectionsAfterRepeatedAccesses() {
    let model = AppModel(client: .preview(), launchProfile: .preview)

    for _ in 0..<4 {
        model.recordSelectionAccess(.friend(UserID(rawValue: "2")))
    }
    for _ in 0..<5 {
        model.recordSelectionAccess(.guild(GuildID(rawValue: "100")))
    }
    for _ in 0..<4 {
        model.recordSelectionAccess(.guild(GuildID(rawValue: "101")))
    }
    for _ in 0..<4 {
        model.recordSelectionAccess(.friend(UserID(rawValue: "3")))
    }

    #expect(model.recentSelections.count == 3)
    #expect(model.recentSelections.map(\.selection) == [
        .friend(UserID(rawValue: "3")),
        .guild(GuildID(rawValue: "101")),
        .guild(GuildID(rawValue: "100"))
    ])
}

@Test
func guildChannelSectionsGroupChannelsUnderCategories() {
    let channels: [DiscordChannel] = [
        DiscordChannel(id: "cat-1", kind: .guildCategory, guildID: "100", name: "Core", position: 0),
        DiscordChannel(id: "text-1", kind: .guildText, guildID: "100", parentID: "cat-1", name: "general", position: 1),
        DiscordChannel(id: "voice-1", kind: .guildVoice, guildID: "100", parentID: "cat-1", name: "Standup", position: 2),
        DiscordChannel(id: "text-2", kind: .guildText, guildID: "100", name: "backyard", position: 8)
    ]

    let sections = GuildChannelSectionModel.makeSections(
        from: channels,
        collapsedCategoryIDs: ["cat-1"]
    )

    #expect(sections.count == 2)
    #expect(sections[0].category?.id == ChannelID(rawValue: "cat-1"))
    #expect(sections[0].isCollapsed)
    #expect(sections[0].channels.map(\.id.rawValue) == ["text-1", "voice-1"])
    #expect(sections[1].category == nil)
    #expect(sections[1].channels.map(\.id.rawValue) == ["text-2"])
}

@MainActor
@Test
func appModelCategoryCollapseStateIsScopedPerGuild() {
    let model = AppModel(client: .preview(), launchProfile: .preview)
    let channels: [DiscordChannel] = [
        DiscordChannel(id: "cat-1", kind: .guildCategory, guildID: "100", name: "Core", position: 0),
        DiscordChannel(id: "text-1", kind: .guildText, guildID: "100", parentID: "cat-1", name: "general", position: 1),
        DiscordChannel(id: "cat-2", kind: .guildCategory, guildID: "101", name: "Ops", position: 0),
        DiscordChannel(id: "text-2", kind: .guildText, guildID: "101", parentID: "cat-2", name: "alerts", position: 1)
    ]

    model.selectedSource = .guild(GuildID(rawValue: "100"))
    model.channelListProjection = ChannelListProjection(
        guildID: GuildID(rawValue: "100"),
        channels: channels.filter { $0.guildID == GuildID(rawValue: "100") }
    )
    model.toggleCategory(ChannelID(rawValue: "cat-1"))

    #expect(model.guildChannelSections.first?.isCollapsed == true)

    model.selectedSource = .guild(GuildID(rawValue: "101"))
    model.channelListProjection = ChannelListProjection(
        guildID: GuildID(rawValue: "101"),
        channels: channels.filter { $0.guildID == GuildID(rawValue: "101") }
    )

    #expect(model.guildChannelSections.first?.isCollapsed == false)
}

@Test
func workspaceTimelineCapabilityExcludesForumAndMediaChannels() {
    #expect(DiscordChannelKind.guildText.supportsWorkspaceTimelineInteraction)
    #expect(DiscordChannelKind.publicThread.supportsWorkspaceTimelineInteraction)
    #expect(DiscordChannelKind.guildForum.supportsWorkspaceTimelineInteraction == false)
    #expect(DiscordChannelKind.guildMedia.supportsWorkspaceTimelineInteraction == false)
    #expect(DiscordChannelKind.guildVoice.supportsWorkspaceTimelineInteraction == false)
}

@MainActor
@Test
func composerBuildsReplyAwareSendInputAndClearsReplyOnFinish() {
    let composer = ComposerModel()
    composer.prepareForChannel(ChannelID(rawValue: "200"))
    composer.beginReply(
        MessageReplyTarget(
            channelID: ChannelID(rawValue: "200"),
            messageID: MessageID(rawValue: "300"),
            guildID: GuildID(rawValue: "100"),
            authorDisplayName: "Ada",
            previewText: "Original message"
        )
    )
    composer.draft = "Reply body"

    let input = composer.makeSendInput(nonce: MessageNonce(rawValue: "nonce-9"))

    #expect(input?.messageReference?.messageID == MessageID(rawValue: "300"))

    composer.finishSending()
    #expect(composer.replyTarget == nil)
}

@Test
func conversationRouteStoresPrefilledDirectMessageDraft() {
    let route = ConversationWindowRoute.directMessage(
        UserID(rawValue: "2"),
        "https://discord.com/channels/100/200/300"
    )

    switch route {
    case let .directMessage(userID, prefilledDraft):
        #expect(userID == UserID(rawValue: "2"))
        #expect(prefilledDraft == "https://discord.com/channels/100/200/300")
    default:
        Issue.record("Expected direct-message route.")
    }
}

@Test
func messageActionTargetBuildsReplyTargetAndGuildLink() {
    let target = MessageActionTarget(
        channelID: ChannelID(rawValue: "200"),
        messageID: MessageID(rawValue: "300"),
        guildID: GuildID(rawValue: "100"),
        authorID: UserID(rawValue: "2"),
        authorDisplayName: "Ada",
        previewText: "Original message"
    )

    #expect(target.replyTarget.messageID == MessageID(rawValue: "300"))
    #expect(target.replyTarget.authorDisplayName == "Ada")
    #expect(target.messageLink == "https://discord.com/channels/100/200/300")
}

@Test
func messageActionDockMetricsUseUpperRightActivationZone() {
    let messageSize = CGSize(width: 420, height: 160)

    #expect(
        MessageActionDockMetrics.shouldPresentDock(
            pointerLocation: CGPoint(x: 380, y: 18),
            messageSize: messageSize,
            isDockHovered: false,
            isMenuPresented: false
        )
    )

    #expect(
        MessageActionDockMetrics.shouldPresentDock(
            pointerLocation: CGPoint(x: 120, y: 18),
            messageSize: messageSize,
            isDockHovered: false,
            isMenuPresented: false
        ) == false
    )
}

@MainActor
@Test
func timelineModelRecordsRequestedReplyJumpTarget() {
    let model = TimelineModel()

    model.requestJump(to: MessageID(rawValue: "42"))

    #expect(model.pendingJumpMessageID == MessageID(rawValue: "42"))
}

@Test
func remoteAssetCacheExpiresEntriesAfterTTL() async throws {
    final class TestClock: @unchecked Sendable {
        var now: Date

        init(now: Date) {
            self.now = now
        }
    }

    let clock = TestClock(now: Date(timeIntervalSince1970: 1_700_000_000))
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let cache = RemoteAssetCache(directoryURL: directory, now: { clock.now })
    let url = try #require(URL(string: "https://cdn.discordapp.com/avatars/1/hash.png?size=128"))
    let data = Data("avatar".utf8)

    await cache.insert(data, for: url, kind: .avatar)
    #expect(await cache.data(for: url, kind: .avatar) == data)

    clock.now = clock.now.addingTimeInterval(RemoteAssetKind.avatar.timeToLive + 1)
    #expect(await cache.data(for: url, kind: .avatar) == nil)
}

@Test
func remoteAssetCacheClearRemovesStoredEntries() async throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let cache = RemoteAssetCache(directoryURL: directory)
    let url = try #require(URL(string: "https://cdn.discordapp.com/icons/1/hash.png?size=128"))
    let data = Data("icon".utf8)

    await cache.insert(data, for: url, kind: .guildIcon)
    #expect(await cache.data(for: url, kind: .guildIcon) == data)

    await cache.clear()
    #expect(await cache.data(for: url, kind: .guildIcon) == nil)
}

@Test
func linkPreviewMetadataParserExtractsImageSummaryAndVideoFields() throws {
    let html = """
    <html>
      <head>
        <title>Fallback Title</title>
        <meta property="og:title" content="Swift 6.3.2 Release">
        <meta property="og:description" content="A patch release with fixes.">
        <meta property="og:site_name" content="Swift.org">
        <meta property="og:image" content="/images/swift.png">
        <meta property="og:video:url" content="https://cdn.example.com/swift.mp4">
      </head>
    </html>
    """

    let sourceURL = try #require(URL(string: "https://www.swift.org/blog/swift-6-3-2"))
    let responseURL = try #require(URL(string: "https://www.swift.org/blog/swift-6-3-2"))

    let metadata = LinkPreviewMetadataDocument.parse(
        html: html,
        sourceURL: sourceURL,
        responseURL: responseURL
    )

    #expect(metadata.title == "Swift 6.3.2 Release")
    #expect(metadata.summary == "A patch release with fixes.")
    #expect(metadata.siteName == "Swift.org")
    #expect(metadata.imageURL?.absoluteString == "https://www.swift.org/images/swift.png")
    #expect(metadata.videoURL?.absoluteString == "https://cdn.example.com/swift.mp4")
}

@Test
func linkPreviewMetadataParserDecodesHTMLCharacterEntities() throws {
    let html = """
    <html>
      <head>
        <meta property="og:title" content="Why I&#39;m still using Claude &amp; friends">
        <meta property="og:description" content="AT&amp;T, apostrophes, &quot;quotes&quot;, and more.">
      </head>
    </html>
    """

    let sourceURL = try #require(URL(string: "https://example.com/post"))
    let responseURL = try #require(URL(string: "https://example.com/post"))

    let metadata = LinkPreviewMetadataDocument.parse(
        html: html,
        sourceURL: sourceURL,
        responseURL: responseURL
    )

    #expect(metadata.title == "Why I'm still using Claude & friends")
    #expect(metadata.summary == "AT&T, apostrophes, \"quotes\", and more.")
}

@MainActor
@Test
func remoteAssetFitImageViewDoesNotExposeIntrinsicImageSize() async throws {
    let url = try #require(URL(string: "https://example.com/\(UUID().uuidString).png"))
    let imageData = try makePNGData(width: 640, height: 320, color: .systemBlue)
    await RemoteAssetCache.shared.insert(imageData, for: url, kind: .linkPreview)

    let hostingView = NSHostingView(
        rootView: RemoteAssetView(
            url: url,
            kind: .linkPreview,
            animationPolicy: .never,
            scalingMode: .fit
        ) {
            Rectangle().fill(.red)
        }
        .frame(width: 220, height: 120)
    )
    hostingView.frame = NSRect(x: 0, y: 0, width: 220, height: 120)

    let imageView = try #require(await loadedImageView(in: hostingView))
    let intrinsicSize = imageView.intrinsicContentSize

    #expect(intrinsicSize.width <= 0)
    #expect(intrinsicSize.height <= 0)
    #expect(imageView.frame.width <= 220.5)
    #expect(imageView.frame.height <= 120.5)
}

@MainActor
@Test
func linkPreviewCardKeepsLoadedImageInsideItsAssignedWidth() async throws {
    let imageURL = try #require(URL(string: "https://example.com/\(UUID().uuidString)-link.png"))
    let imageData = try makePNGData(width: 1_280, height: 720, color: .systemTeal)
    await RemoteAssetCache.shared.insert(imageData, for: imageURL, kind: .linkPreview)

    let previewURL = try #require(URL(string: "https://example.com/post"))
    let hostingView = NSHostingView(
        rootView: LinkPreviewCardView(
            preview: LinkPreviewBlock(id: "preview-1", url: previewURL),
            embed: DiscordMessageEmbed(
                type: "link",
                url: previewURL.absoluteString,
                title: "Example Preview",
                description: "A preview image should stay clipped inside the card.",
                imageURL: imageURL.absoluteString
            )
        )
        .frame(width: 320, alignment: .leading)
    )
    hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 420)

    let imageView = try #require(await loadedImageView(in: hostingView))

    #expect(imageView.frame.minX >= -0.5)
    #expect(imageView.frame.maxX <= 320.5)
}

@Test
func focusedMediaLayoutClampsLargeMediaToContainerBounds() {
    let layout = FocusedMediaOverlayLayout.mediaFrameSize(
        in: CGSize(width: 760, height: 520)
    )

    #expect(layout.width <= 760 - (FocusedMediaOverlayLayout.horizontalPadding * 2))
    #expect(layout.height <= 520 - FocusedMediaOverlayLayout.verticalChromeAllowance)
    #expect(layout.width == 696)
    #expect(layout.height == 422)
}

private func makePNGData(width: CGFloat, height: CGFloat, color: NSColor) throws -> Data {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    color.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
    image.unlockFocus()

    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    return try #require(bitmap.representation(using: .png, properties: [:]))
}

@MainActor
private func loadedImageView(in hostingView: NSHostingView<some View>) async -> NSImageView? {
    for delay in [20, 60, 120] {
        try? await Task.sleep(for: .milliseconds(delay))
        hostingView.layoutSubtreeIfNeeded()
        if let imageView = firstImageView(in: hostingView), imageView.image != nil {
            hostingView.layoutSubtreeIfNeeded()
            return imageView
        }
    }

    return firstImageView(in: hostingView)
}

@MainActor
private func firstImageView(in view: NSView) -> NSImageView? {
    if let imageView = view as? NSImageView {
        return imageView
    }

    for subview in view.subviews {
        if let imageView = firstImageView(in: subview) {
            return imageView
        }
    }

    return nil
}
