import Foundation
import DiscordState

public final class NotificationsAPI: @unchecked Sendable {
    private let store: StoreRuntime

    public init(store: StoreRuntime) {
        self.store = store
    }

    public func badgeSnapshot() async -> NotificationBadgeSnapshot {
        let snapshot = await store.snapshot()
        return NotificationBadgeSnapshot(
            unreadChannelCount: snapshot.readStates.count,
            pendingMessageCount: snapshot.pendingMessageOperations.count
        )
    }
}

