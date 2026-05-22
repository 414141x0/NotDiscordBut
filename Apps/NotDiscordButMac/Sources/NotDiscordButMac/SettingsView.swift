import Observation
import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsModel
    let canSignOut: Bool
    let onCleanCache: () -> Void
    let onSignOut: () -> Void

    @AppStorage("showInspector")
    private var showInspector = true

    @AppStorage("compactTimeline")
    private var compactTimeline = false

    @AppStorage("timelineFontSize")
    private var timelineFontSize = 14.0

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("Profile", value: model.launchProfileLabel)
                LabeledContent("Auth Kind", value: model.currentSession?.authKind.rawValue ?? "none")
                LabeledContent("User ID", value: model.currentSession?.userID?.rawValue ?? "unknown")
            }

            Section("Interface") {
                Toggle("Show Inspector", isOn: $showInspector)
                Toggle("Compact Timeline", isOn: $compactTimeline)
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Message Size", value: "\(Int(timelineFontSize)) pt")
                    Slider(value: $timelineFontSize, in: 12...18, step: 1)
                }
            }

            Section("Sync") {
                LabeledContent("Locale", value: model.userSettings?.locale ?? "n/a")
                LabeledContent("Theme", value: model.userSettings?.theme ?? "n/a")
                LabeledContent("Unread Buckets", value: "\(model.badgeSnapshot.unreadChannelCount)")
                LabeledContent("Pending Sends", value: "\(model.badgeSnapshot.pendingMessageCount)")
            }

            Section("Storage") {
                LabeledContent("Cache", value: model.cacheStatus)
                Button("Clean Local Cache", action: onCleanCache)
            }

            if let runtimeNotice = model.runtimeNotice {
                Section("Runtime Notice") {
                    Text(runtimeNotice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if canSignOut {
                Section {
                    Button("Sign Out", role: .destructive, action: onSignOut)
                }
            }
        }
        .formStyle(.grouped)
    }
}
