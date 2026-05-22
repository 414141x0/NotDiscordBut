import DiscordKit
import SwiftUI

struct ContentView: View {
    @Environment(IOSAppModel.self) private var model

    var body: some View {
        Group {
            switch model.phase {
            case .launching:
                launchingView
            case .signedOut:
                IOSAuthView()
            case .connected:
                MainContentView()
            case let .failed(message):
                failedView(message)
            }
        }
        .task {
            await model.bootstrap()
        }
    }

    private var launchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(model.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Startup Failed")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

struct MainContentView: View {
    @Environment(IOSAppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        NavigationStack(path: $model.navigationPath) {
            VStack(spacing: 0) {
                SourceFilterBar(selected: $model.filterMode)
                    .padding(.vertical, 4)

                HorizontalSourceStrip(
                    items: model.filteredSourceItems,
                    selectedSource: model.selectedSource,
                    onSelect: { selection in
                        model.setSelectedSource(selection)
                        switch selection {
                        case .friend:
                            model.navigationPath = [.timeline(model.selectedDirectMessageChannelID ?? ChannelID(""))]
                        case let .guild(guildID):
                            model.navigationPath = [.guildChannelList(guildID)]
                        }
                    }
                )

                Divider()

                if model.selectedSource == nil {
                    emptyState
                } else if model.isGuildMode {
                    guildContent
                } else {
                    friendContent
                }
            }
            .navigationTitle("NotDiscordBut")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .navigationDestination(for: IOSNavigationDestination.self) { destination in
                switch destination {
                case let .guildChannelList(guildID):
                    IOSChannelListView(guildID: guildID)
                case let .timeline(channelID):
                    IOSTimelineView(channelID: channelID)
                }
            }
            .sheet(item: $model.profileSheetUserID) { userID in
                IOSProfileView(userID: userID)
                    .environment(model)
            }
        }
        .searchable(text: $model.messageSearchText, prompt: "Search messages")
        .onChange(of: model.messageSearchText) {
            model.scheduleMessageSearch()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Select a Friend or Server")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(model.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var guildContent: some View {
        Group {
            if model.channelListProjection.channels.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Loading channels…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                IOSInlineChannelList()
            }
        }
    }

    private var friendContent: some View {
        Group {
            if model.timeline.rendersTimeline {
                IOSInlineTimelineView()
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Opening conversation…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}

extension UserID: Identifiable {
    public var id: String { rawValue }
}
