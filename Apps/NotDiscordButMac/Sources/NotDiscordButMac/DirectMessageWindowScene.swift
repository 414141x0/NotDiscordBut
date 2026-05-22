import DiscordKit
import SwiftUI

struct DirectMessageWindowScene: View {
    let appModel: AppModel
    let userID: UserID
    let initialDraft: String?

    @State private var model: DirectMessageWindowModel

    init(appModel: AppModel, userID: UserID, initialDraft: String?) {
        self.appModel = appModel
        self.userID = userID
        self.initialDraft = initialDraft
        _model = State(initialValue: DirectMessageWindowModel(
            appModel: appModel,
            userID: userID,
            initialDraft: initialDraft
        ))
    }

    var body: some View {
        DirectMessageWindowView(model: model)
            .task {
                await model.bootstrap()
            }
    }
}
