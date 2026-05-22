import DiscordKit
import Observation

@MainActor
@Observable
final class SettingsModel {
    var currentSession: DiscordSession?
    var userSettings: DiscordUserSettings?
    var badgeSnapshot = NotificationBadgeSnapshot(unreadChannelCount: 0, pendingMessageCount: 0)
    var launchProfileLabel = AppLaunchProfile.live.label
    var runtimeNotice: String?
    var cacheStatus = "Warm"

    func apply(
        session: DiscordSession?,
        userSettings: DiscordUserSettings?,
        badgeSnapshot: NotificationBadgeSnapshot,
        cacheStatus: String? = nil
    ) {
        currentSession = session
        self.userSettings = userSettings
        self.badgeSnapshot = badgeSnapshot
        if let cacheStatus {
            self.cacheStatus = cacheStatus
        }
    }
}
