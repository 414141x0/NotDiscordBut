import DiscordKit
import SwiftUI

struct IOSLinkPreviewCard: View {
    let preview: LinkPreviewBlock

    var body: some View {
        Link(destination: preview.url) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preview.url.host ?? preview.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)

                    Text(preview.url.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
            )
        }
    }
}
