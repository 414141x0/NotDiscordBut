import DiscordKit
import SwiftUI

struct IOSChannelListView: View {
    let guildID: GuildID
    @Environment(IOSAppModel.self) private var model

    var body: some View {
        List {
            ForEach(model.guildChannelSections) { section in
                Section {
                    if !section.isCollapsed {
                        ForEach(section.channels, id: \.id) { channel in
                            IOSChannelRow(
                                channel: channel,
                                hasMentions: model.channelHasMentions(channel.id),
                                isSelected: channel.id == model.selectedGuildChannelID
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selectGuildChannel(channel.id)
                                model.navigationPath.append(.timeline(channel.id))
                            }
                            .disabled(!channel.kind.supportsWorkspaceTimelineInteraction)
                            .opacity(channel.kind.supportsWorkspaceTimelineInteraction ? 1 : 0.5)
                        }
                    }
                } header: {
                    if let category = section.category {
                        Button {
                            withAnimation {
                                model.toggleCategory(category.id)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .rotationEffect(.degrees(section.isCollapsed ? 0 : 90))

                                Text((category.name ?? "").uppercased())
                                    .font(.caption.weight(.semibold))

                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(model.selectedGuild?.name ?? "Channels")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }
}

struct IOSInlineChannelList: View {
    @Environment(IOSAppModel.self) private var model

    var body: some View {
        List {
            ForEach(model.guildChannelSections) { section in
                Section {
                    if !section.isCollapsed {
                        ForEach(section.channels, id: \.id) { channel in
                            IOSChannelRow(
                                channel: channel,
                                hasMentions: model.channelHasMentions(channel.id),
                                isSelected: channel.id == model.selectedGuildChannelID
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selectGuildChannel(channel.id)
                                model.navigationPath.append(.timeline(channel.id))
                            }
                            .disabled(!channel.kind.supportsWorkspaceTimelineInteraction)
                            .opacity(channel.kind.supportsWorkspaceTimelineInteraction ? 1 : 0.5)
                        }
                    }
                } header: {
                    if let category = section.category {
                        Button {
                            withAnimation {
                                model.toggleCategory(category.id)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .rotationEffect(.degrees(section.isCollapsed ? 0 : 90))

                                Text((category.name ?? "").uppercased())
                                    .font(.caption.weight(.semibold))

                                Spacer()
                            }
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
