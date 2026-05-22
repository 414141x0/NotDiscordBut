import DiscordKit
import SwiftUI

struct UserInspectorView: View {
    let projection: UserInspectorProjection?

    var body: some View {
        Group {
            if let projection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard(for: projection)
                        aboutSection(for: projection)

                        if !projection.resolvedRoles.isEmpty {
                            detailSection(title: "Roles") {
                                ProfileRoleGridView(roles: projection.resolvedRoles)
                            }
                        }

                        if !projection.mutualGuilds.isEmpty {
                            detailSection(title: "Mutual Servers") {
                                ForEach(projection.mutualGuilds, id: \.id) { guild in
                                    HStack(spacing: 10) {
                                        DiscordGuildIconView(guild: guild, size: 28)
                                        Text(guild.name)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }

                        if !projection.mutualFriends.isEmpty {
                            detailSection(title: "Mutual Friends") {
                                ForEach(projection.mutualFriends, id: \.id) { friend in
                                    HStack(spacing: 10) {
                                        DiscordAvatarView(user: friend, size: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(friend.displayName)
                                                .lineLimit(1)
                                            Text(friend.tag)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    "No Profile Selected",
                    systemImage: "person.crop.rectangle.stack",
                    description: Text("Click a username in chat to open a full profile inspector.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func headerCard(for projection: UserInspectorProjection) -> some View {
        let accent = Color(discordAccent: projection.displayAccentColor ?? projection.profile?.accentColor ?? projection.user.accentColor)
        let displayName = projection.guildMember?.nickname ?? projection.user.displayName

        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                DiscordBannerView(
                    url: DiscordCDN.userBannerURL(
                        userID: projection.user.id,
                        bannerHash: projection.profile?.bannerHash ?? projection.user.bannerHash,
                        size: 640
                    ),
                    height: 116,
                    accentColor: accent
                )

                DiscordAvatarView(user: projection.user, size: 82)
                    .padding(.leading, 18)
                    .offset(y: 36)
            }
            .padding(.bottom, 42)

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
                    .fixedSize(horizontal: false, vertical: true)

                Text(projection.user.tag)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let nickname = projection.guildMember?.nickname,
                   nickname != projection.user.displayName {
                    Text("Server nickname: \(nickname)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func aboutSection(for projection: UserInspectorProjection) -> some View {
        detailSection(title: "About") {
            if let pronouns = projection.profile?.pronouns, !pronouns.isEmpty {
                labeledValue("Pronouns", pronouns)
            }

            if let bio = projection.profile?.bio, !bio.isEmpty {
                labeledValue("Bio", bio)
            } else {
                labeledValue("Bio", "No profile bio yet.")
            }

            if let premiumType = projection.profile?.premiumType {
                labeledValue("Nitro", premiumType == 0 ? "No" : "Yes")
            }
        }
    }

    @ViewBuilder
    private func detailSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private func labeledValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
