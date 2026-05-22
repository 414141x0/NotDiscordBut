import DiscordKit

extension DiscordChannelKind {
    var supportsTimelineHydration: Bool { supportsTimeline }

    var supportsWorkspaceTimelineInteraction: Bool {
        switch self {
        case .guildText, .guildNews, .publicThread, .privateThread:
            true
        default:
            false
        }
    }

    var isTextRenderable: Bool {
        switch self {
        case .guildText, .guildNews, .guildForum, .guildMedia, .publicThread, .privateThread:
            true
        default:
            false
        }
    }

    var isVoiceRenderable: Bool {
        switch self {
        case .guildVoice, .guildStageVoice:
            true
        default:
            false
        }
    }
}
