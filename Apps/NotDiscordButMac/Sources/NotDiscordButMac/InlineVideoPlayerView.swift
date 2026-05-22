import AVKit
import AppKit
import SwiftUI

struct InlineVideoPlayerView: View {
    let url: URL?
    let posterURL: URL?
    let idealAspectRatio: CGFloat?
    let onOpenMedia: (() -> Void)?

    @State
    private var controller = VideoPlaybackController()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PlayerViewRepresentable(player: controller.player, showsControls: false)
                .background(videoBackground)
                .aspectRatio(idealAspectRatio ?? (16.0 / 9.0), contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }

            if let onOpenMedia {
                Button(action: onOpenMedia) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.semibold))
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
        .frame(maxWidth: 440)
        .frame(maxHeight: 360)
        .onAppear {
            controller.configure(url: url, loops: false)
            controller.play()
        }
        .onDisappear {
            controller.pause()
        }
        .onChange(of: url) { _, newURL in
            controller.configure(url: newURL, loops: false)
            controller.play()
        }
    }

    @ViewBuilder
    private var videoBackground: some View {
        if let posterURL {
            RemoteAssetView(
                url: posterURL,
                kind: .inlineMedia,
                animationPolicy: .never
            ) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.quaternary)
            }
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.quaternary)
        }
    }
}

struct FocusedVideoPlayerView: View {
    let url: URL?
    let posterURL: URL?

    @State
    private var controller = VideoPlaybackController()

    var body: some View {
        PlayerViewRepresentable(player: controller.player, showsControls: true)
            .background(videoBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .onAppear {
                controller.configure(url: url, loops: true)
                controller.play()
            }
            .onDisappear {
                controller.pause()
            }
            .onChange(of: url) { _, newURL in
                controller.configure(url: newURL, loops: true)
                controller.play()
            }
    }

    @ViewBuilder
    private var videoBackground: some View {
        if let posterURL {
            RemoteAssetView(
                url: posterURL,
                kind: .focusedMedia,
                animationPolicy: .never
            ) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.quaternary)
            }
        } else {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.quaternary)
        }
    }
}

@MainActor
final class VideoPlaybackController: ObservableObject {
    let player = AVPlayer()

    private var currentURL: URL?
    nonisolated(unsafe) private var endObserver: NSObjectProtocol?
    private var loops = false

    init() {
        player.isMuted = true
        player.actionAtItemEnd = .pause
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func configure(url: URL?, loops: Bool) {
        guard currentURL != url || self.loops != loops else {
            return
        }

        currentURL = url
        self.loops = loops
        player.pause()
        player.replaceCurrentItem(with: nil)

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        guard let url else {
            return
        }

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        guard loops else {
            return
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }
}

private struct PlayerViewRepresentable: NSViewRepresentable {
    let player: AVPlayer
    let showsControls: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = showsControls ? .floating : .none
        view.showsFullScreenToggleButton = false
        view.updatesNowPlayingInfoCenter = false
        view.player = player
        view.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.player = player
        view.controlsStyle = showsControls ? .floating : .none
    }
}
