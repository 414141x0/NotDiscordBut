import DiscordKit
import SwiftUI

struct IOSDiscordAvatarView: View {
    let user: DiscordUser
    var size: CGFloat = 40

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)

        RemoteAssetView(
            url: DiscordCDN.userAvatarURL(for: user, size: Int(size * 3)),
            kind: .avatar,
            scalingMode: .fit
        ) {
            shape
                .fill(Color(discordAccent: user.accentColor).opacity(0.24))
                .overlay {
                    Text(String(user.displayName.prefix(1)).uppercased())
                        .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(discordAccent: user.accentColor))
                }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(.quaternary, lineWidth: 1)
        }
        .accessibilityLabel(user.displayName)
    }
}
