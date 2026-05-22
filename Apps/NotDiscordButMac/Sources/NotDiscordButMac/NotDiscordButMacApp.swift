import DiscordKit
import SwiftUI

@main
struct NotDiscordButMacApp: App {
    @State private var model = AppModel.makeDefault()

    var body: some Scene {
        WindowGroup("NotDiscordBut", id: "launcher") {
            RootView(model: model)
                .frame(minWidth: 980, minHeight: 680)
        }
        .defaultSize(width: 1320, height: 860)
        .commands {
            WorkspaceCommands(model: model)
        }

        WindowGroup("Conversation", for: ConversationWindowRoute.self) { $route in
            if let route {
                ConversationWindowScene(appModel: model, route: route)
            } else {
                ContentUnavailableView(
                    "No Conversation Selected",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Open a friend or server from the main workspace.")
                )
            }
        }
        .defaultSize(width: 1220, height: 820)

            Settings {
                SettingsView(
                    model: model.settings,
                    canSignOut: model.launchProfile == .live,
                    onCleanCache: {
                        Task {
                            await model.cleanCache()
                        }
                    },
                    onSignOut: {
                        Task {
                            await model.logout()
                    }
                }
            )
            .frame(width: 520)
            .padding(24)
        }
    }
}
