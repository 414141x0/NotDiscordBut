import SwiftUI
import DiscordKit

@main
struct NotDiscordButiOSApp: App {
    @State private var model = IOSAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
