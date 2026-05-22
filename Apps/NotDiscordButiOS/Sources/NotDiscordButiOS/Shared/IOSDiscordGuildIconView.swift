import DiscordKit
import SwiftUI

struct IOSDiscordGuildIconView: View {
    let guild: DiscordGuild
    var size: CGFloat = 44

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)

        RemoteAssetView(
            url: DiscordCDN.guildIconURL(for: guild, size: Int(size * 3)),
            kind: .guildIcon,
            scalingMode: .fit
        ) {
            shape
                .fill(.quaternary)
                .overlay {
                    Text(String(guild.name.prefix(1)).uppercased())
                        .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(.quaternary, lineWidth: 1)
        }
        .accessibilityLabel(guild.name)
    }
}
