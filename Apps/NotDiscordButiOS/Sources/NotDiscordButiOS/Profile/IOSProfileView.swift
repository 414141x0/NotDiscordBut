import DiscordKit
import SwiftUI

struct IOSProfileView: View {
    let userID: UserID
    @Environment(IOSAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    bannerSection
                    profileContent
                }
            }
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var bannerSection: some View {
        if let projection = model.profileSheetProjection {
            ZStack(alignment: .bottomLeading) {
                IOSDiscordBannerView(
                    url: DiscordCDN.userBannerURL(
                        userID: projection.user.id,
                        bannerHash: projection.profile?.bannerHash,
                        size: 600
                    ),
                    height: 140,
                    accentColor: Color(discordAccent: projection.displayAccentColor)
                )

                IOSDiscordAvatarView(user: projection.user, size: 72)
                    .overlay {
                        RoundedRectangle(cornerRadius: 72 * 0.32, style: .continuous)
                            .strokeBorder(.background, lineWidth: 4)
                    }
                    .offset(x: 16, y: 36)
            }
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var profileContent: some View {
        if let projection = model.profileSheetProjection {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(projection.user.displayName)
                        .font(.title2.weight(.bold))

                    Text(projection.user.tag)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let pronouns = projection.profile?.pronouns, !pronouns.isEmpty {
                        Text(pronouns)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let bio = projection.profile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !projection.resolvedRoles.isEmpty {
                    rolesSection(projection.resolvedRoles)
                }

                if !projection.mutualGuilds.isEmpty {
                    mutualGuildsSection(projection.mutualGuilds)
                }

                if !projection.mutualFriends.isEmpty {
                    mutualFriendsSection(projection.mutualFriends)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading profile…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    private func rolesSection(_ roles: [DiscordGuildRole]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Roles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            FlowLayout(spacing: 6) {
                ForEach(roles, id: \.id) { role in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(roleColor: role.color))
                            .frame(width: 10, height: 10)
                        Text(role.name)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.gray.opacity(0.12)))
                }
            }
        }
    }

    private func mutualGuildsSection(_ guilds: [DiscordGuild]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mutual Servers (\(guilds.count))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVStack(spacing: 8) {
                ForEach(guilds, id: \.id) { guild in
                    HStack(spacing: 10) {
                        IOSDiscordGuildIconView(guild: guild, size: 32)
                        Text(guild.name)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private func mutualFriendsSection(_ friends: [DiscordUser]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mutual Friends (\(friends.count))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVStack(spacing: 8) {
                ForEach(friends, id: \.id) { friend in
                    HStack(spacing: 10) {
                        IOSDiscordAvatarView(user: friend, size: 32)
                        Text(friend.displayName)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

private extension Color {
    init(roleColor: Int) {
        if roleColor == 0 {
            self = .secondary
            return
        }
        let red = Double((roleColor >> 16) & 0xFF) / 255
        let green = Double((roleColor >> 8) & 0xFF) / 255
        let blue = Double(roleColor & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }
}
