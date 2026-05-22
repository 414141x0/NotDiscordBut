import Foundation
import Testing
@testable import DiscordState
import DiscordPrimitives

@Test
func optimisticMessageInsertCreatesPendingRecord() {
    var state = NormalizedState.empty
    let operation = PendingMessageOperation.makePreview(channelID: "42", messageID: "77")

    StateReducer.apply(.optimisticMessageSend(operation), to: &state)

    #expect(state.messages["77"]?.id.rawValue == "77")
    #expect(state.pendingMessageOperations["77"]?.messageID.rawValue == "77")
}

@Test
func channelProjectionFiltersGuildAndPrivateSurfacesSeparately() {
    let query = QueryRuntime()
    let state = NormalizedState(
        channels: [
            "10": DiscordChannel(id: "10", kind: .directMessage, name: "Ada"),
            "20": DiscordChannel(id: "20", kind: .guildText, guildID: "100", name: "general", position: 3),
            "21": DiscordChannel(id: "21", kind: .guildText, guildID: "100", name: "swift", position: 1),
            "30": DiscordChannel(id: "30", kind: .guildText, guildID: "200", name: "other")
        ]
    )

    let privateProjection = query.channelListProjection(for: nil, from: state)
    let guildProjection = query.channelListProjection(for: "100", from: state)

    #expect(privateProjection.channels.map(\.id.rawValue) == ["10"])
    #expect(guildProjection.channels.map(\.id.rawValue) == ["21", "20"])
}

@Test
func sidebarProjectionIncludesFriendsAndSortsByRelationshipKindThenName() {
    let query = QueryRuntime()
    let state = NormalizedState(
        users: [
            "1": DiscordUser(id: "1", username: "zoe"),
            "2": DiscordUser(id: "2", username: "ada"),
            "3": DiscordUser(id: "3", username: "max")
        ],
        relationships: [
            "1": DiscordRelationship(userID: "1", kind: .blocked),
            "2": DiscordRelationship(userID: "2", kind: .friend),
            "3": DiscordRelationship(userID: "3", kind: .incomingRequest)
        ]
    )

    let sidebar = query.sidebarProjection(from: state)

    #expect(sidebar.friends.map(\.user.id.rawValue) == ["2", "3", "1"])
}

@Test
func richTimelineProjectionJoinsAuthorProfileAndNicknameData() {
    let query = QueryRuntime()
    let state = NormalizedState(
        users: [
            "2": DiscordUser(
                id: "2",
                username: "ada",
                discriminator: "0",
                globalName: "Ada",
                avatarHash: "a_avatar",
                accentColor: 0x5865F2
            )
        ],
        userProfiles: [
            "2": DiscordUserProfile(
                userID: "2",
                bio: "Compiler engineer",
                pronouns: "she/her",
                bannerHash: "banner_hash",
                accentColor: 0x5865F2
            )
        ],
        messages: [
            "10": DiscordMessage(
                id: "10",
                channelID: "99",
                authorID: "2",
                content: "Hello",
                timestamp: .now,
                memberNickname: "Compiler Ada"
            )
        ]
    )

    let projection = query.richTimelineProjection(for: "99", from: state)

    #expect(projection.entries.count == 1)
    #expect(projection.entries[0].displayName == "Compiler Ada")
    #expect(projection.entries[0].author.tag == "@ada")
    #expect(projection.entries[0].profile?.bio == "Compiler engineer")
}

@Test
func legacyNormalizedStatePayloadDecodesWithoutUserProfiles() throws {
    let data = """
    {
      "users": {
        "2": {
          "id": "2",
          "username": "ada"
        }
      },
      "guilds": {},
      "channels": {},
      "messages": {
        "10": {
          "id": "10",
          "channelID": "99",
          "authorID": "2",
          "content": "Hello",
          "timestamp": "2026-05-20T10:00:00Z",
          "flags": 0
        }
      },
      "relationships": {},
      "readStates": {},
      "pendingMessageOperations": {},
      "session": {}
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let state = try decoder.decode(NormalizedState.self, from: data)

    #expect(state.userProfiles.isEmpty)
    #expect(state.messages["10"]?.attachments.isEmpty == true)
    #expect(state.messages["10"]?.embeds.isEmpty == true)
}

@Test
func partialUserMergePreservesEarlierAvatarAndProfileData() {
    var state = NormalizedState(
        users: [
            "2": DiscordUser(
                id: "2",
                username: "ada",
                discriminator: "0",
                globalName: "Ada",
                avatarHash: "avatar_hash",
                accentColor: 0x5865F2
            )
        ]
    )

    StateReducer.apply(
        .merge(
            StateMergeSnapshot(
                users: [
                    DiscordUser(
                        id: "2",
                        username: "ada",
                        discriminator: "0",
                        globalName: nil,
                        avatarHash: nil,
                        accentColor: nil
                    )
                ]
            )
        ),
        to: &state
    )

    #expect(state.users["2"]?.globalName == "Ada")
    #expect(state.users["2"]?.avatarHash == "avatar_hash")
    #expect(state.users["2"]?.accentColor == 0x5865F2)
}

@Test
func richTimelineProjectionResolvesMentionIDsIntoDisplayNames() {
    let query = QueryRuntime()
    let state = NormalizedState(
        users: [
            "2": DiscordUser(id: "2", username: "ada", discriminator: "0", globalName: "Ada"),
            "3": DiscordUser(id: "3", username: "sam", discriminator: "0", globalName: "Sam")
        ],
        messages: [
            "10": DiscordMessage(
                id: "10",
                channelID: "99",
                authorID: "2",
                content: "Hi <@3>, welcome back.",
                timestamp: .now
            )
        ]
    )

    let projection = query.richTimelineProjection(for: "99", from: state)

    #expect(projection.entries.count == 1)
    #expect(projection.entries[0].renderedContent == "Hi @Sam, welcome back.")
}

@Test
func clusteredTimelineProjectionGroupsSameAuthorMessagesWithinFiveMinutes() {
    let query = QueryRuntime()
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    let state = NormalizedState(
        users: [
            "2": DiscordUser(id: "2", username: "ada", discriminator: "0", globalName: "Ada")
        ],
        messages: [
            "10": DiscordMessage(id: "10", channelID: "99", authorID: "2", content: "First", timestamp: base),
            "11": DiscordMessage(id: "11", channelID: "99", authorID: "2", content: "Second", timestamp: base.addingTimeInterval(60 * 4)),
            "12": DiscordMessage(id: "12", channelID: "99", authorID: "2", content: "Third", timestamp: base.addingTimeInterval(60 * 11))
        ]
    )

    let projection = query.clusteredTimelineProjection(for: "99", from: state)

    #expect(projection.clusters.count == 2)
    #expect(projection.clusters[0].messages.map(\.id.rawValue) == ["10", "11"])
    #expect(projection.clusters[1].messages.map(\.id.rawValue) == ["12"])
}

@Test
func clusteredTimelineProjectionInterleavesLinkPreviewBlocksInMessageOrder() {
    let query = QueryRuntime()
    let state = NormalizedState(
        users: [
            "2": DiscordUser(id: "2", username: "ada", discriminator: "0", globalName: "Ada")
        ],
        messages: [
            "10": DiscordMessage(
                id: "10",
                channelID: "99",
                authorID: "2",
                content: "Hello\ngoogle.com\nis better then\nyt.com",
                timestamp: .now
            )
        ]
    )

    let projection = query.clusteredTimelineProjection(for: "99", from: state)
    let blocks = projection.clusters[0].messages[0].blocks

    #expect(blocks.count == 6)
    #expect(blocks[0].kind == .text)
    #expect(blocks[1].kind == .text)
    #expect(blocks[2].kind == .linkPreview)
    #expect(blocks[3].kind == .text)
    #expect(blocks[4].kind == .text)
    #expect(blocks[5].kind == .linkPreview)

    if case let .text(textBlock) = blocks[1] {
        #expect(String(textBlock.content.characters) == "google.com")
    } else {
        Issue.record("Expected second block to be text.")
    }

    if case let .linkPreview(preview) = blocks[2] {
        #expect(preview.url.absoluteString == "https://google.com")
    } else {
        Issue.record("Expected third block to be a google.com preview.")
    }

    if case let .linkPreview(preview) = blocks[5] {
        #expect(preview.url.absoluteString == "https://yt.com")
    } else {
        Issue.record("Expected final block to be a yt.com preview.")
    }
}

@Test
func renderedContentReplacesCustomEmojiTokensWithReadableFallback() {
    let query = QueryRuntime()
    let state = NormalizedState(
        users: [
            "2": DiscordUser(id: "2", username: "ada", discriminator: "0", globalName: "Ada")
        ],
        messages: [
            "10": DiscordMessage(
                id: "10",
                channelID: "99",
                authorID: "2",
                content: "hi <:lolsob:812217273670565888> <a:partyblob:987654321012345678>",
                timestamp: .now
            )
        ]
    )

    let projection = query.clusteredTimelineProjection(for: "99", from: state)
    let blocks = projection.clusters[0].messages[0].blocks

    if case let .text(textBlock) = blocks[0] {
        #expect(String(textBlock.content.characters) == "hi :lolsob: :partyblob:")
    } else {
        Issue.record("Expected custom emoji fallback to remain in the text block.")
    }
}

@Test
func clusteredTimelineProjectionEmitsCustomEmojiFragmentsForInlineRendering() {
    let query = QueryRuntime()
    let state = NormalizedState(
        users: [
            "2": DiscordUser(id: "2", username: "ada", discriminator: "0", globalName: "Ada")
        ],
        messages: [
            "10": DiscordMessage(
                id: "10",
                channelID: "99",
                authorID: "2",
                content: "hi <:lolsob:812217273670565888> there",
                timestamp: .now
            )
        ]
    )

    let projection = query.clusteredTimelineProjection(for: "99", from: state)
    let blocks = projection.clusters[0].messages[0].blocks

    guard case let .text(textBlock) = blocks[0] else {
        Issue.record("Expected a text block for the custom emoji line.")
        return
    }

    #expect(textBlock.fragments.count == 3)

    if case let .customEmoji(fragment) = textBlock.fragments[1] {
        #expect(fragment.name == "lolsob")
        #expect(fragment.imageURL?.absoluteString == "https://cdn.discordapp.com/emojis/812217273670565888.png?size=64&quality=lossless")
    } else {
        Issue.record("Expected the second fragment to be a custom emoji.")
    }
}

@Test
func clusteredTimelineProjectionCreatesPreviewBlocksForEveryEligibleLinkInALine() {
    let query = QueryRuntime()
    let state = NormalizedState(
        users: [
            "2": DiscordUser(id: "2", username: "ada", discriminator: "0", globalName: "Ada")
        ],
        messages: [
            "10": DiscordMessage(
                id: "10",
                channelID: "99",
                authorID: "2",
                content: "compare https://google.com and https://yt.com/watch?v=1",
                timestamp: .now
            )
        ]
    )

    let projection = query.clusteredTimelineProjection(for: "99", from: state)
    let blocks = projection.clusters[0].messages[0].blocks
    let previewURLs = blocks.compactMap { block -> String? in
        guard case let .linkPreview(preview) = block else {
            return nil
        }
        return preview.url.absoluteString
    }

    #expect(previewURLs == ["https://google.com", "https://yt.com/watch?v=1"])
}

@Test
func clusteredTimelineProjectionStripsAutolinkBracketsAndSuppressesPreviewForBulletLinks() {
    let query = QueryRuntime()
    let state = NormalizedState(
        users: [
            "2": DiscordUser(id: "2", username: "ada", discriminator: "0", globalName: "Ada")
        ],
        messages: [
            "10": DiscordMessage(
                id: "10",
                channelID: "99",
                authorID: "2",
                content: "- <https://www.crowdsupply.com/soldered/usb-cereal>",
                timestamp: .now
            )
        ]
    )

    let projection = query.clusteredTimelineProjection(for: "99", from: state)
    let blocks = projection.clusters[0].messages[0].blocks

    #expect(blocks.count == 1)

    guard case let .text(textBlock) = blocks[0] else {
        Issue.record("Expected bullet link line to remain a text block.")
        return
    }

    #expect(textBlock.paragraphStyle == .bullet)
    #expect(String(textBlock.content.characters) == "https://www.crowdsupply.com/soldered/usb-cereal")
}

@Test
func userInspectorProjectionResolvesGuildMemberRolesAndRoleAccentColor() {
    let query = QueryRuntime()
    let state = NormalizedState(
        users: [
            "2": DiscordUser(
                id: "2",
                username: "ada",
                discriminator: "0",
                globalName: "Ada",
                accentColor: 0x5865F2
            )
        ],
        userProfiles: [
            "2": DiscordUserProfile(
                userID: "2",
                bio: "Compiler engineer",
                guildMember: DiscordGuildMemberProfile(
                    guildID: "100",
                    nickname: "Compiler Ada",
                    roleIDs: ["500", "501"]
                )
            )
        ],
        guilds: [
            "100": DiscordGuild(id: "100", name: "Swift Guild")
        ],
        guildRoles: [
            "500": DiscordGuildRole(id: "500", guildID: "100", name: "Moderator", color: 0x00AAFF, position: 20),
            "501": DiscordGuildRole(id: "501", guildID: "100", name: "Compiler", color: 0xFF5500, position: 40)
        ]
    )

    let projection = query.userInspectorProjection(for: "2", from: state)

    #expect(projection?.guildMember?.nickname == "Compiler Ada")
    #expect(projection?.resolvedRoles.map(\.name) == ["Compiler", "Moderator"])
    #expect(projection?.displayAccentColor == 0xFF5500)
}

@Test
func clusteredTimelineProjectionPrefersGuildRoleColorOverUserAccentColor() {
    let query = QueryRuntime()
    let state = NormalizedState(
        users: [
            "2": DiscordUser(id: "2", username: "ada", discriminator: "0", globalName: "Ada", accentColor: 0x5865F2)
        ],
        userProfiles: [
            "2": DiscordUserProfile(
                userID: "2",
                guildMember: DiscordGuildMemberProfile(
                    guildID: "100",
                    nickname: "Compiler Ada",
                    roleIDs: ["501"]
                )
            )
        ],
        guildRoles: [
            "501": DiscordGuildRole(id: "501", guildID: "100", name: "Compiler", color: 0xFF5500, position: 40)
        ],
        channels: [
            "300": DiscordChannel(id: "300", kind: .guildText, guildID: "100", name: "general")
        ],
        messages: [
            "10": DiscordMessage(
                id: "10",
                channelID: "300",
                authorID: "2",
                content: "Hello",
                timestamp: .now,
                memberNickname: "Compiler Ada",
                memberRoleIDs: ["501"]
            )
        ]
    )

    let projection = query.clusteredTimelineProjection(for: "300", from: state)

    #expect(projection.clusters.count == 1)
    #expect(projection.clusters[0].displayAccentColor == 0xFF5500)
    #expect(projection.clusters[0].displayName == "Compiler Ada")
}
