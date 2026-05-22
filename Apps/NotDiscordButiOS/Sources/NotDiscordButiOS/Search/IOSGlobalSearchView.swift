import DiscordKit
import SwiftUI

struct IOSGlobalSearchView: View {
    let query: String
    @Environment(IOSAppModel.self) private var model

    var body: some View {
        let matchingPeople = model.filteredPeople(matching: query)
        let matchingGuilds = model.filteredGuilds(matching: query)

        List {
            if !matchingPeople.isEmpty {
                Section("Friends") {
                    ForEach(matchingPeople.prefix(5), id: \.user.id) { person in
                        Button {
                            model.setSelectedSource(.friend(person.user.id))
                        } label: {
                            HStack(spacing: 10) {
                                IOSDiscordAvatarView(user: person.user, size: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.displayName)
                                        .font(.subheadline)
                                    Text(person.detailText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !matchingGuilds.isEmpty {
                Section("Servers") {
                    ForEach(matchingGuilds.prefix(5), id: \.id) { guild in
                        Button {
                            model.setSelectedSource(.guild(guild.id))
                        } label: {
                            HStack(spacing: 10) {
                                IOSDiscordGuildIconView(guild: guild, size: 32)
                                Text(guild.name)
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if matchingPeople.isEmpty && matchingGuilds.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("No friends or servers match \"\(query)\"."))
            }
        }
    }
}
