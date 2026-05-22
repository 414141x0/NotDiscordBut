import DiscordKit
import SwiftUI

struct IOSChannelRow: View {
    let channel: DiscordChannel
    let hasMentions: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: channelIcon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(channel.name ?? channel.id.rawValue)
                    .font(.body)
                    .fontWeight(hasMentions ? .semibold : .regular)
                    .lineLimit(1)

                if let topic = channel.topic, !topic.isEmpty {
                    Text(topic)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if hasMentions {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
    }

    private var channelIcon: String {
        switch channel.kind {
        case .guildVoice:
            return "speaker.wave.2.fill"
        case .guildStageVoice:
            return "person.wave.2"
        case .guildForum:
            return "rectangle.3.group.bubble"
        case .guildMedia:
            return "photo.on.rectangle.angled"
        case .guildCategory:
            return "folder"
        case .publicThread, .privateThread:
            return "bubble.left.and.text.bubble.right"
        default:
            return "number"
        }
    }
}
