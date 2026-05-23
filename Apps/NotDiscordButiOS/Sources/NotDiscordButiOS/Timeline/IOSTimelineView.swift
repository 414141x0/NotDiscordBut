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
            TimelineScrollContent()
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

private struct TimelineScrollContent: View {
    @Environment(IOSAppModel.self) private var model
    @State private var isLoadingOlder = false
    @State private var oldestRequestedID: String?
    @State private var reachedOldest = false
    @State private var anchorID: String?
    @State private var hasInitiallyScrolled = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    topSection

                    ForEach(model.timeline.displayedClusters, id: \.id) { cluster in
                        IOSMessageClusterRow(
                            cluster: cluster,
                            guildID: model.selectedSource?.guildID
                        )
                        .id(cluster.messages.last?.id.rawValue ?? cluster.id)
                    }
                }
                .padding(.top, 8)
            }
            .defaultScrollAnchor(.bottom)
            .onAppear {
                guard !hasInitiallyScrolled else { return }
                hasInitiallyScrolled = true
                if let lastID = model.timeline.displayedClusters.last?.messages.last?.id.rawValue {
                    DispatchQueue.main.async {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
            .onChange(of: model.timeline.pendingJumpMessageID) { _, newValue in
                if let messageID = newValue {
                    _ = model.timeline.consumePendingJumpMessageID()
                    withAnimation {
                        proxy.scrollTo(messageID.rawValue, anchor: .center)
                    }
                }
            }
            .onChange(of: anchorID) { _, newValue in
                if let id = newValue {
                    anchorID = nil
                    DispatchQueue.main.async {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var topSection: some View {
        if isLoadingOlder {
            HStack {
                Spacer()
                ProgressView()
                    .padding(.vertical, 16)
                Spacer()
            }
        } else if reachedOldest {
            HStack {
                Spacer()
                Text("Beginning of conversation")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 12)
                Spacer()
            }
        } else {
            Button {
                loadOlderMessages()
            } label: {
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle")
                            .font(.caption)
                        Text("Load older messages")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .onAppear {
                if hasInitiallyScrolled {
                    loadOlderMessages()
                }
            }
        }
    }

    private func loadOlderMessages() {
        guard !isLoadingOlder, !reachedOldest else { return }
        let clusters = model.timeline.displayedClusters
        guard let firstMessageID = clusters.first?.messages.first?.id else { return }

        let idRaw = firstMessageID.rawValue
        guard oldestRequestedID != idRaw else { return }
        oldestRequestedID = idRaw

        let prevTopRowID = clusters.first?.messages.last?.id.rawValue
        let prevCount = clusters.reduce(0) { $0 + $1.messages.count }

        isLoadingOlder = true
        Task {
            await model.loadOlderMessages(before: firstMessageID)

            let newCount = model.timeline.displayedClusters.reduce(0) { $0 + $1.messages.count }
            if newCount <= prevCount {
                reachedOldest = true
            }
            isLoadingOlder = false

            if let prevTopRowID {
                anchorID = prevTopRowID
            }
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
                TimelineScrollContent()
            }

            IOSComposerBar()
        }
    }
}
