import DiscordKit
import Observation
import SwiftUI

struct DirectMessageWindowView: View {
    @Bindable var model: DirectMessageWindowModel

    @SceneStorage("dmWindow.inspectorPresented")
    private var inspectorPresented = false

    var body: some View {
        TimelineView(
            timeline: model.timeline,
            composer: model.composer,
            badgeSnapshot: model.appModel.settings.badgeSnapshot,
            availableGuildEmojis: model.reactionPickerGuildEmojis,
            onSend: {
                Task {
                    await model.sendDraft()
                }
            },
            onInspectUser: { userID in
                model.openInspector(for: userID)
                inspectorPresented = true
            },
            onPrefetchUserProfile: { userID in
                model.prefetchProfile(for: userID)
            },
            profilePreview: { userID in
                model.cachedInspectorProjection(for: userID)
            },
            onJumpToReplyReference: { reference in
                Task {
                    await model.jumpToMessageReference(reference)
                }
            },
            onRefreshLatest: {
                await model.refreshTimeline(forceFullReload: false)
            },
            onToggleReaction: { message, emoji in
                await model.toggleReaction(for: message, emoji: emoji)
            }
        )
        .navigationTitle(model.title)
        .inspector(isPresented: inspectorBinding) {
            UserInspectorView(projection: model.inspectorProjection)
                .inspectorColumnWidth(min: 300, ideal: 360, max: 480)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title)
                        .font(.headline)
                    Text(model.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { inspectorPresented },
            set: { newValue in
                inspectorPresented = newValue
                if !newValue {
                    model.inspectorUserID = nil
                    model.inspectorProjection = nil
                }
            }
        )
    }
}
