import DiscordKit
import Foundation

struct RecentSelectionSnapshot: Codable, Hashable, Sendable {
    var selection: WorkspaceSelection
    var accessCount: Int
    var lastAccessDate: Date
}

struct RecentSelectionEntry: Hashable, Sendable, Identifiable {
    var selection: WorkspaceSelection
    var title: String
    var subtitle: String
    var user: DiscordUser?
    var guild: DiscordGuild?

    var id: String {
        selection.persistenceKey
    }
}

struct GuildChannelSectionModel: Hashable, Sendable, Identifiable {
    var category: DiscordChannel?
    var channels: [DiscordChannel]
    var isCollapsed: Bool

    var id: String {
        category?.id.rawValue ?? "uncategorized"
    }

    static func makeSections(
        from channels: [DiscordChannel],
        collapsedCategoryIDs: Set<ChannelID>
    ) -> [GuildChannelSectionModel] {
        let sortedChannels = channels.sorted(by: channelSort)
        let categories = sortedChannels.filter { $0.kind == DiscordChannelKind.guildCategory }
        let nonCategoryChannels = sortedChannels.filter { $0.kind != DiscordChannelKind.guildCategory }

        var childrenByParentID = [ChannelID: [DiscordChannel]]()
        var uncategorized = [DiscordChannel]()

        for channel in nonCategoryChannels {
            guard let parentID = channel.parentID else {
                uncategorized.append(channel)
                continue
            }
            childrenByParentID[parentID, default: []].append(channel)
        }

        var sections = categories.compactMap { category -> GuildChannelSectionModel? in
            let children = (childrenByParentID[category.id] ?? []).sorted(by: channelSort)
            guard !children.isEmpty else {
                return nil
            }
            return GuildChannelSectionModel(
                category: category,
                channels: children,
                isCollapsed: collapsedCategoryIDs.contains(category.id)
            )
        }

        if !uncategorized.isEmpty {
            sections.append(
                GuildChannelSectionModel(
                    category: nil,
                    channels: uncategorized.sorted(by: channelSort),
                    isCollapsed: false
                )
            )
        }

        return sections
    }

    private static func channelSort(lhs: DiscordChannel, rhs: DiscordChannel) -> Bool {
        if lhs.position != rhs.position {
            return (lhs.position ?? .max) < (rhs.position ?? .max)
        }

        if lhs.kind != rhs.kind {
            if lhs.kind == .guildCategory {
                return true
            }
            if rhs.kind == .guildCategory {
                return false
            }
            if lhs.kind.isVoiceRenderable != rhs.kind.isVoiceRenderable {
                return lhs.kind.isVoiceRenderable == false
            }
        }

        let leftName = lhs.name ?? lhs.id.rawValue
        let rightName = rhs.name ?? rhs.id.rawValue
        let comparison = leftName.localizedStandardCompare(rightName)
        if comparison == .orderedSame {
            return lhs.id < rhs.id
        }
        return comparison == .orderedAscending
    }
}
