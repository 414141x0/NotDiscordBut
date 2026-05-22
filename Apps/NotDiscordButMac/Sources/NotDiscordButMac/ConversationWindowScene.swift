import DiscordKit
import SwiftUI

struct ConversationWindowScene: View {
    let appModel: AppModel
    let route: ConversationWindowRoute

    var body: some View {
        switch route {
        case let .directMessage(userID, initialDraft):
            DirectMessageWindowScene(appModel: appModel, userID: userID, initialDraft: initialDraft)
        case let .guild(guildID, channelID):
            ServerWindowScene(appModel: appModel, guildID: guildID, initialChannelID: channelID)
        }
    }
}
