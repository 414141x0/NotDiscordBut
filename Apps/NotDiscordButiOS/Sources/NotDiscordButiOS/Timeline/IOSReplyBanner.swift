import DiscordKit
import SwiftUI

struct IOSReplyBanner: View {
    let reference: DiscordMessageReference
    let referencedMessage: DiscordReferencedMessage

    @Environment(IOSAppModel.self) private var model

    var body: some View {
        Button {
            Task {
                await model.jumpToMessageReference(reference)
            }
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(.secondary)
                    .frame(width: 2, height: 16)

                Text(referencedMessage.author.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(referencedMessage.content)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
