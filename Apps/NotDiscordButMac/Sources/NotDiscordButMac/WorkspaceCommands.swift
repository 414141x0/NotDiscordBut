import SwiftUI

struct WorkspaceCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    let model: AppModel

    var body: some Commands {
        SidebarCommands()

        CommandMenu("Conversation") {
            Button("Open Selection in New Window") {
                guard let route = model.secondaryWindowRoute else {
                    return
                }
                openWindow(value: route)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandMenu("Account") {
            Button("Clean Local Cache") {
                Task {
                    await model.cleanCache()
                }
            }

            Button("Log Out") {
                Task {
                    await model.logout()
                }
            }
            .disabled(model.launchProfile != .live)
        }
    }
}
