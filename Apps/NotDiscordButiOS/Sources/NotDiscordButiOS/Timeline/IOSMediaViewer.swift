import SwiftUI

struct IOSMediaViewer: View {
    let item: FocusedMediaItem

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RemoteAssetView(
                url: item.url,
                kind: .focusedMedia,
                scalingMode: .fit
            ) {
                ProgressView()
                    .tint(.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()
            }
        }
        #if os(iOS)
        .statusBarHidden()
        #endif
    }
}
