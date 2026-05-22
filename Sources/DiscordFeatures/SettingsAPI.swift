import Foundation
import DiscordPrimitives
import DiscordState

public final class SettingsAPI: @unchecked Sendable {
    private let store: StoreRuntime

    public init(store: StoreRuntime) {
        self.store = store
    }

    public func currentUserSettings() async -> DiscordUserSettings? {
        let snapshot = await store.snapshot()
        return snapshot.users.values.first.map { _ in DiscordUserSettings(locale: "en-US", theme: "system") }
    }
}

