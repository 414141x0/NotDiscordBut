import DiscordKit
import SwiftUI

struct IOSTimelineView: View {
    let channelID: ChannelID
    @Environment(IOSAppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            timelineContent
            IOSComposerBar()
        }
        .navigationTitle(model.timeline.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }

    @ViewBuilder
    private var timelineContent: some View {
        if !model.timeline.rendersTimeline {
            emptyState
        } else if model.timeline.displayedClusters.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.timeline.displayedClusters, id: \.id) { cluster in
                            IOSMessageClusterRow(
                                cluster: cluster,
                                guildID: model.selectedSource?.guildID
                            )
                            .id(cluster.messages.last?.id.rawValue)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .refreshable {
                    await model.refreshSelectedTimeline(forceFullReload: true)
                }
                .onChange(of: model.timeline.pendingJumpMessageID) { _, newValue in
                    if let messageID = newValue {
                        _ = model.timeline.consumePendingJumpMessageID()
                        withAnimation {
                            proxy.scrollTo(messageID.rawValue, anchor: .center)
                        }
                    }
                }
                .onAppear {
                    if let scrollID = model.timeline.currentScrollMessageIDRaw {
                        proxy.scrollTo(scrollID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(model.timeline.emptyStateTitle)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(model.timeline.emptyStateDescription)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

struct IOSInlineTimelineView: View {
    @Environment(IOSAppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if model.timeline.displayedClusters.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text(model.timeline.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.timeline.displayedClusters, id: \.id) { cluster in
                                IOSMessageClusterRow(
                                    cluster: cluster,
                                    guildID: model.selectedSource?.guildID
                                )
                                .id(cluster.messages.last?.id.rawValue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable {
                        await model.refreshSelectedTimeline(forceFullReload: true)
                    }
                    .onChange(of: model.timeline.pendingJumpMessageID) { _, newValue in
                        if let messageID = newValue {
                            _ = model.timeline.consumePendingJumpMessageID()
                            withAnimation {
                                proxy.scrollTo(messageID.rawValue, anchor: .center)
                            }
                        }
                    }
                }
            }

            IOSComposerBar()
        }
    }
}
