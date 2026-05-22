import SwiftUI

struct IOSDiscordBannerView: View {
    let url: URL?
    var height: CGFloat = 144
    var accentColor: Color = .accentColor

    var body: some View {
        RemoteAssetView(
            url: url,
            kind: .banner,
            scalingMode: .fill
        ) {
            LinearGradient(
                colors: [accentColor.opacity(0.9), accentColor.opacity(0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
