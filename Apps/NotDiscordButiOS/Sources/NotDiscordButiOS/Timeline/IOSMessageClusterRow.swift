import DiscordKit
import SwiftUI

struct IOSMessageClusterRow: View {
    let cluster: MessageClusterProjection
    let guildID: GuildID?

    @Environment(IOSAppModel.self) private var model

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                model.openProfileSheet(for: cluster.author.id)
            } label: {
                IOSDiscordAvatarView(user: cluster.author, size: 36)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                clusterHeader

                ForEach(cluster.messages, id: \.id) { message in
                    IOSMessageBubble(
                        message: message,
                        guildID: guildID,
                        author: cluster.author,
                        displayName: cluster.displayName
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var clusterHeader: some View {
        HStack(spacing: 6) {
            Text(cluster.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(formattedDate(cluster.startedAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
