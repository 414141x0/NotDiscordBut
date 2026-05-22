import DiscordKit
import SwiftUI

struct ServerWindowScene: View {
    let appModel: AppModel
    let guildID: GuildID
    let initialChannelID: ChannelID?

    @State private var model: ServerWindowModel

    init(appModel: AppModel, guildID: GuildID, initialChannelID: ChannelID? = nil) {
        self.appModel = appModel
        self.guildID = guildID
        self.initialChannelID = initialChannelID
        _model = State(initialValue: ServerWindowModel(appModel: appModel, guildID: guildID, initialChannelID: initialChannelID))
    }

    var body: some View {
        ServerWindowView(model: model)
            .task {
                await model.bootstrap()
            }
    }
}
