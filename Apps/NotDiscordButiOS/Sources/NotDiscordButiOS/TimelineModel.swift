import DiscordKit
import Foundation
import Observation

@MainActor
@Observable
final class TimelineModel {
    var projection = ClusteredTimelineProjection(channelID: nil, clusters: [])
    var selectedChannel: DiscordChannel?
    var currentScrollMessageIDRaw: String?
    var statusMessage = "Choose a friend or text channel to start reading."
    var emptyStateTitle = "No Conversation Selected"
    var emptyStateDescription = "Pick a friend or guild channel to populate the timeline."
    var rendersTimeline = false
    var searchQuery = ""
    var searchProjection = ClusteredTimelineProjection(channelID: nil, clusters: [])
    var searchStatusMessage: String?
    var isSearching = false
    var pendingJumpMessageID: MessageID?

    @ObservationIgnored
    private var scrollMessageIDByChannelID = [String: String?]()

    var title: String {
        selectedChannel?.name ?? "Inbox"
    }

    var displayedClusters: [MessageClusterProjection] {
        searchQuery.isEmpty ? projection.clusters : searchProjection.clusters
    }

    var displayedMessageCount: Int {
        displayedClusters.reduce(into: 0) { count, cluster in
            count += cluster.messages.count
        }
    }

    var lastDisplayedMessageID: MessageID? {
        displayedClusters.last?.messages.last?.id
    }

    func apply(channel: DiscordChannel?, projection: ClusteredTimelineProjection) {
        selectedChannel = channel
        if self.projection != projection {
            self.projection = projection
        }
        rendersTimeline = channel?.kind.supportsTimelineHydration == true
        if let channelID = channel?.id.rawValue {
            currentScrollMessageIDRaw = scrollMessageIDByChannelID[channelID] ?? projection.clusters.last?.messages.last?.id.rawValue
        } else {
            currentScrollMessageIDRaw = nil
        }

        guard let channel else {
            statusMessage = "Choose a friend or text channel to start reading."
            emptyStateTitle = "No Conversation Selected"
            emptyStateDescription = "Pick a friend or guild channel to populate the timeline."
            return
        }

        if !rendersTimeline {
            statusMessage = "\(channel.name ?? channel.id.rawValue) is not a text timeline."
            emptyStateTitle = "No Message Timeline"
            emptyStateDescription = "Voice, stage, and category channels are listed here for navigation, but they do not render messages yet."
            return
        }

        if projection.messageCount == 0 {
            statusMessage = "No messages in \(channel.name ?? channel.id.rawValue) yet."
            emptyStateTitle = "No Messages Yet"
            emptyStateDescription = "This conversation is ready. Send the first message to create local activity."
        } else {
            statusMessage = "Showing \(projection.messageCount) messages."
            emptyStateTitle = ""
            emptyStateDescription = ""
        }

        if !searchQuery.isEmpty {
            refreshSearchPresentation()
        }
    }

    func beginSearch(query: String) {
        searchQuery = query
        searchProjection = ClusteredTimelineProjection(channelID: selectedChannel?.id, clusters: [])
        isSearching = true
        refreshSearchPresentation()
    }

    func completeSearch(query: String, projection: ClusteredTimelineProjection, totalResults: Int) {
        searchQuery = query
        searchProjection = projection
        isSearching = false
        searchStatusMessage = totalResults == 0
            ? "No matches for \"\(query)\"."
            : "Showing \(projection.messageCount) matching messages for \"\(query)\"."
        refreshSearchPresentation()
    }

    func failSearch(query: String, error: some Error) {
        searchQuery = query
        searchProjection = ClusteredTimelineProjection(channelID: selectedChannel?.id, clusters: [])
        isSearching = false
        searchStatusMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        refreshSearchPresentation()
    }

    func clearSearch() {
        searchQuery = ""
        searchProjection = ClusteredTimelineProjection(channelID: selectedChannel?.id, clusters: [])
        searchStatusMessage = nil
        isSearching = false
        apply(channel: selectedChannel, projection: projection)
    }

    func updateScrollMessageID(_ rawValue: String?) {
        currentScrollMessageIDRaw = rawValue
        guard let channelID = selectedChannel?.id.rawValue else {
            return
        }
        scrollMessageIDByChannelID[channelID] = rawValue
    }

    func requestJump(to messageID: MessageID) {
        pendingJumpMessageID = messageID
        updateScrollMessageID(messageID.rawValue)
    }

    func consumePendingJumpMessageID() -> MessageID? {
        defer {
            pendingJumpMessageID = nil
        }
        return pendingJumpMessageID
    }

    private func refreshSearchPresentation() {
        guard !searchQuery.isEmpty else {
            return
        }

        if isSearching {
            statusMessage = "Searching messages for \"\(searchQuery)\"…"
            emptyStateTitle = "Searching Messages"
            emptyStateDescription = "Discord is searching the current conversation."
            return
        }

        statusMessage = searchStatusMessage ?? "Showing search results."
        if searchProjection.messageCount == 0 {
            emptyStateTitle = "No Search Results"
            emptyStateDescription = "Try a different phrase or clear the search field."
        } else {
            emptyStateTitle = ""
            emptyStateDescription = ""
        }
    }
}
